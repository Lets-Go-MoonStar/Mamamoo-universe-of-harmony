# ---------------------------------------------------------------------------
# main.gd — Nodo raíz de la escena. Orquesta la run procedural:
#   - registra los controles (InputMap),
#   - crea al jugador, el HUD, el inventario y el RunManager (seed central),
#   - recorre el grafo de salas del piso (combate, élite, jefe, tienda,
#     evento, descanso, recompensa) respetando el EncounterBudget y oleadas,
#   - reinicia con la MISMA seed en R y genera una NUEVA run en M.
# ---------------------------------------------------------------------------
extends Node2D

const VISUALS = preload("res://scripts/visual_assets.gd")

const ITEM_UI = preload("res://scripts/item_ui.gd")
var item_ui
# Número de sala visible (run-wide); lo mantiene `_begin_current_room`.
var room_number := 1
var room_kills := 0
var room_budget := 0
# true mientras el panel de recompensa está abierto (pausa el combate).
var awaiting_reward := false
# true tras derrotar al jefe: la transición de piso se confirma en la ruta.
var awaiting_floor_start := false

const COMBAT_HUD = preload("res://scripts/combat_hud.gd")
const RUN_MANAGER = preload("res://scripts/systems/run_manager.gd")
const SESSION = preload("res://scripts/systems/session_store.gd")
const EVENT_CATALOG = preload("res://scripts/systems/event_catalog.gd")
const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")
const SFX = preload("res://scripts/systems/sfx.gd")
const META = preload("res://scripts/systems/meta_progress.gd")
const ARENA_HAZARD = preload("res://scripts/systems/arena_hazard.gd")

const BACKGROUNDS = [
	preload("res://assets/backgrounds/eclipse_arena_background.png"),
	preload("res://assets/backgrounds/starlight_palace_background.png"),
	preload("res://assets/backgrounds/sunrise_gardens_background.png"),
	preload("res://assets/backgrounds/moonlit_ruins_background.png"),
	preload("res://assets/backgrounds/crystal_waterfalls_background.png"),
	preload("res://assets/backgrounds/inferno_castle_background.png"),
	preload("res://assets/backgrounds/neon_city_background.png"),
	preload("res://assets/backgrounds/shattered_void_background.png"),
	preload("res://assets/backgrounds/eclipse_throne_background.png")
]
const STAGE_NAMES = ["Arena del eclipse", "Palacio estelar", "Jardines del amanecer", "Ruinas lunares", "Cascadas de cristal", "Castillo de fuego", "Ciudad neón", "Vacío fragmentado", "Trono del eclipse"]
var stage_index := 0
var stage_selector: OptionButton
# Contenedor de todos los actores (jugador + enemigos); ordena por Y.
var actors: Node2D

const PLAYER = preload("res://scripts/player.gd")
const ENEMY = preload("res://scripts/enemy.gd")

var player: HarmonyPlayer
var hud: CanvasLayer
var combat_hud: Control
# Sistema de la run actual (grafo, pisos, pools, seed).
var run: RunManager
# Índice de la oleada activa dentro de run.battle_waves.
var wave_index := 0
# Temporizador entre oleadas y total de enemigos que debe derrotar la sala.
var spawn_timer := 0.0
var spawned := 0
var defeated := 0
var rng := RandomNumberGenerator.new()
var arena_rect := Rect2(90, 442, 1100, 164)
var _intro_floor_shown := -1

func _ready() -> void:
	rng.randomize()
	_setup_inputs()
	SFX.ensure(self)
	stage_index = int(get_tree().get_meta("stage_index", 0))
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	_create_player()
	_create_hud()
	# La run se construye con la seed guardada (R la reproduce) o se
	# restaura desde SessionStore si hay partida entre sesiones.
	run = RUN_MANAGER.new()
	add_child(run)
	run.run_completed.connect(_on_run_completed)
	var restored := _try_restore_session()
	if not restored:
		run.new_run(int(get_tree().get_meta("run_seed", 0)))
	get_tree().set_meta("run_seed", run.run_seed)
	room_kills = 0
	player.items.changed.connect(_autosave_session)
	_apply_meta_bonuses()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if run.current_room() != null:
		var room: RoomData = run.current_room()
		# Sala ya completada: reanudamos en el panel de rutas (sin repetir premio).
		if restored and room.completed:
			awaiting_reward = true
			item_ui.show_routes()
		else:
			_begin_current_room()
	_autosave_session()
	queue_redraw()

# Registra todas las acciones de teclado en el InputMap (teclas físicas).
func _setup_inputs() -> void:
	_add_key_action("shoot_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("shoot_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("shoot_up", KEY_W)
	_add_key_action("move_up", KEY_UP)
	_add_key_action("shoot_down", KEY_S)
	_add_key_action("move_down", KEY_DOWN)
	_add_key_action("ability", KEY_E)
	_add_key_action("dodge", KEY_SHIFT)
	_add_key_action("switch_1", KEY_1)
	_add_key_action("switch_2", KEY_2)
	_add_key_action("switch_3", KEY_3)
	_add_key_action("switch_4", KEY_4)
	_add_key_action("restart", KEY_R)
	_add_key_action("new_seed", KEY_M)
	_add_key_action("next_stage", KEY_N)
	_add_key_action("inventory", KEY_I)
	_add_key_action("adlib", KEY_Q)
	_add_key_action("pause_game", KEY_ESCAPE)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	# Atajos globales: escenario (N), reiniciar con la misma seed (R) y
	# nueva run con seed distinta (M). Pausa con Esc.
	if Input.is_action_just_pressed("pause_game"):
		if is_instance_valid(combat_hud) and (not is_instance_valid(item_ui) or not item_ui.overlay.visible):
			combat_hud.toggle_pause()
	if Input.is_action_just_pressed("next_stage"):
		select_stage((stage_index + 1) % BACKGROUNDS.size())
	if Input.is_action_just_pressed("restart"):
		# R: misma seed desde cero (descarta la sesión guardada).
		SESSION.clear()
		get_tree().paused = false
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("new_seed"):
		SESSION.clear()
		get_tree().paused = false
		get_tree().set_meta("run_seed", rng.randi() + 1)
		get_tree().reload_current_scene()
	if combat_hud != null and combat_hud.paused_game:
		return
	if not is_instance_valid(player) or player.team_defeated:
		return
	# Si hay oleadas pendientes, la siguiente aparece tras un breve respiro.
	if awaiting_reward or awaiting_floor_start:
		return
	if wave_index < run.battle_waves.size() - 1:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").is_empty():
			wave_index += 1
			_spawn_wave(run.battle_waves[wave_index])

# Crea al jugador en el centro de la arena y conecta sus señales con el HUD.
func _create_player() -> void:
	player = PLAYER.new()
	player.global_position = arena_rect.get_center()
	player.arena_rect = arena_rect
	actors.add_child(player)
	player.stats_changed.connect(_on_stats_changed)
	player.chain_changed.connect(_on_chain_changed)
	player.game_over.connect(_on_game_over)

# Construye el HUD, el selector de escenario y el panel de recompensas/rutas.
func _create_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	combat_hud = COMBAT_HUD.new()
	hud.add_child(combat_hud)
	combat_hud.setup(player)
	stage_selector = OptionButton.new()
	stage_selector.position = Vector2(910, 112)
	stage_selector.size = Vector2(344, 36)
	for stage_name in STAGE_NAMES:
		stage_selector.add_item(stage_name)
	stage_selector.select(stage_index)
	stage_selector.tooltip_text = "Selecciona escenario · N: siguiente"
	stage_selector.item_selected.connect(select_stage)
	combat_hud.add_child(stage_selector)
	combat_hud.move_child(combat_hud.defeat_panel, combat_hud.get_child_count() - 1)
	item_ui = ITEM_UI.new()
	hud.add_child(item_ui)
	item_ui.setup(self)
	player._emit_stats()

# Cambia el escenario de fondo (bioma del piso o manual) y lo persiste.
func select_stage(index: int) -> void:
	stage_index = clampi(index, 0, BACKGROUNDS.size() - 1)
	get_tree().set_meta("stage_index", stage_index)
	if is_instance_valid(stage_selector):
		stage_selector.select(stage_index)
	queue_redraw()

# --- Flujo de salas ---------------------------------------------------------

# Arranca (o entra) la sala actual del grafo: prepara el encuentro según el
# tipo de sala, limpia actores sobrantes y reinicia las cuentas locales.
func _begin_current_room() -> void:
	var room: RoomData = run.current_room()
	if room == null:
		return
	_clear_actors_except_player()
	room_number = run.rooms_completed + 1
	room_kills = 0
	spawned = 0
	wave_index = 0
	spawn_timer = 0.0
	room_budget = 1
	player.global_position = arena_rect.get_center()
	player.invulnerable = 1.5
	select_stage(_biome_for(room))
	awaiting_reward = false
	awaiting_floor_start = false
	if room.room_type == "START" and _intro_floor_shown != run.current_floor:
		_intro_floor_shown = run.current_floor
		combat_hud.show_floor_intro(run.current_floor, STAGE_NAMES[_biome_for(room) % STAGE_NAMES.size()])
	match room.room_type:
		"BOSS":
			_spawn_boss()
		"START", "COMBAT", "ELITE":
			run.prepare_encounter(run.tier_for(room))
			var total := 0
			for wave in run.battle_waves:
				total += wave.size()
			room_budget = maxi(1, total)
			_spawn_wave(run.battle_waves[0])
			if room.room_type != "START":
				_spawn_room_hazards(room)
		"EVENT":
			_enter_event_room()
		"REST":
			_enter_rest_room()
		"SHOP":
			_enter_shop_room()
		"REWARD":
			_enter_reward_room()
	player._emit_stats()

# Bioma (fondo) de la sala: el definido por el piso, con la arena del jefe
# en el trono del eclipse.
func _biome_for(room: RoomData) -> int:
	if room.room_type == "BOSS":
		return 8
	var cfg := run.floor_config()
	return cfg.biome_index % BACKGROUNDS.size()

func _clear_actors_except_player() -> void:
	for child in actors.get_children():
		if child == player:
			continue
		child.queue_free()
	for hazard in get_tree().get_nodes_in_group("hazards"):
		hazard.queue_free()

# Genera una oleada de enemigos data-driven en los bordes de la arena.
func _spawn_wave(wave: Array) -> void:
	var cfg := run.floor_config()
	for enemy_data in wave:
		var enemy := ENEMY.new()
		enemy.setup_data(player, enemy_data, cfg.difficulty_multiplier, cfg.damage_multiplier)
		enemy.global_position = _random_edge_position()
		enemy.add_to_group("enemies")
		enemy.defeated.connect(_on_enemy_defeated)
		actors.add_child(enemy)
		spawned += 1

# Puzzle de sala: patrones rotan por piso/seed para no quemar un solo set piece.
func _spawn_room_hazards(room: RoomData) -> void:
	if room == null or room.room_type not in ["COMBAT", "ELITE", "BOSS"]:
		return
	if run.current_floor < 4:
		return
	var rad := 60.0 + run.current_floor * 1.5
	var dmg := 7.0 + run.current_floor * 0.4
	if room.room_type == "ELITE":
		var elite_pat := _elite_pattern_for_room()
		var count := 4 if elite_pat in ["cross", "corners", "diagonal"] else 3
		_spawn_hazard_pattern(elite_pat, count, rad, dmg + CombatConstants.ELITE_HAZARD_DMG_BONUS, "elite")
		SFX.play("setpiece")
		VISUALS.float_text(self, arena_rect.get_center() + Vector2(0, -80), "SET PIECE · %s" % elite_pat.to_upper(), Color("ffd166"))
		VISUALS.nudge(self as Node2D, 4.0, 0.16)
		return
	# Combate late: a veces un patrón suave en vez de zonas sueltas.
	if room.room_type == "COMBAT" and run.current_floor >= 8 and rng.randf() < 0.35:
		_spawn_hazard_pattern("lanes", 2, rad * 0.9, dmg, "normal")
		return
	var count := 1 if room.room_type == "COMBAT" else 2
	for i in range(count):
		var at := Vector2(
			rng.randf_range(arena_rect.position.x + 80.0, arena_rect.end.x - 80.0),
			rng.randf_range(arena_rect.position.y + 40.0, arena_rect.end.y - 40.0)
		)
		_spawn_hazard_at(at, rad, dmg, "normal")

func _elite_pattern_for_room() -> String:
	# Preferencias por habilidades del pool élite si hay marshal/diva/rift en sala.
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is HarmonyEnemy and node.data != null:
			if node._has_ability("lanes"):
				return "lanes"
			if node._has_ability("corners"):
				return "corners"
			if node._has_ability("setpiece"):
				return "cross"
	var patterns: Array[String] = ["cross", "diagonal", "corners", "lanes", "ring"]
	var idx := int(abs(run.run_seed) + run.current_floor * 3 + run.rooms_completed) % patterns.size()
	return patterns[idx]

func _spawn_hazard_at(at: Vector2, rad: float, dmg: float, style := "normal") -> void:
	var hazard = ARENA_HAZARD.new()
	actors.add_child(hazard)
	hazard.setup(player, at, rad, dmg, style)
	if style == "normal":
		VISUALS.float_text(self, at, "ZONA", Color("4cc9f0"))

func _spawn_hazard_pattern(kind: String, count: int, rad: float, dmg: float, style := "normal") -> void:
	var center := arena_rect.get_center()
	var span := mini(arena_rect.size.x, arena_rect.size.y) * 0.28
	for i in range(count):
		var at := center
		match kind:
			"cross":
				match i % 4:
					0: at = center + Vector2(0, -span)
					1: at = center + Vector2(span, 0)
					2: at = center + Vector2(0, span)
					_: at = center + Vector2(-span, 0)
			"ring":
				var ang := TAU * float(i) / float(maxi(count, 1)) - PI * 0.5
				at = center + Vector2(cos(ang), sin(ang)) * span
			"diagonal":
				match i % 4:
					0: at = center + Vector2(-span, -span) * 0.75
					1: at = center + Vector2(span, -span) * 0.75
					2: at = center + Vector2(span, span) * 0.75
					_: at = center + Vector2(-span, span) * 0.75
			"corners":
				var hx := arena_rect.size.x * 0.32
				var hy := arena_rect.size.y * 0.30
				match i % 4:
					0: at = center + Vector2(-hx, -hy)
					1: at = center + Vector2(hx, -hy)
					2: at = center + Vector2(hx, hy)
					_: at = center + Vector2(-hx, hy)
			"lanes":
				var lane_y := arena_rect.size.y * 0.22
				at = center + Vector2((-0.5 + float(i % 2)) * arena_rect.size.x * 0.35, (-0.5 + float(i / 2)) * lane_y * 2.0)
				if count <= 2:
					at = center + Vector2(0, (-0.5 + float(i)) * lane_y * 2.2)
			_:
				at = center
		_spawn_hazard_at(at, rad, dmg, style)

# Genera el jefe del piso (usado en salas BOSS) con sus refuerzos.
func _spawn_boss() -> void:
	var boss: BossData = run.pick_boss()
	if boss == null:
		return
	combat_hud.show_boss_intro(boss.get_display_name())
	var enemy := ENEMY.new()
	enemy.setup_boss(player, boss)
	enemy.global_position = Vector2(arena_rect.get_center().x, arena_rect.position.y + 90.0)
	enemy.add_to_group("enemies")
	enemy.defeated.connect(_on_enemy_defeated)
	if not enemy.boss_phase_changed.is_connected(_on_boss_phase_changed):
		enemy.boss_phase_changed.connect(_on_boss_phase_changed)
	actors.add_child(enemy)
	spawned += 1
	_spawn_room_hazards(run.current_room())

# Set piece de jefe: phase_storm rota patrón por fase (anillo → diagonal → lanes).
func _on_boss_phase_changed(phase: int) -> void:
	if phase < 2:
		return
	SFX.play("phase")
	VISUALS.float_text(self, arena_rect.get_center() + Vector2(0, -100), "¡FASE %d!" % phase, Color("ff5964"))
	VISUALS.screen_pulse(self, Color("c77dff", 0.32), 0.4)
	VISUALS.nudge(self as Node2D, 8.0, 0.22)
	var has_storm := false
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is HarmonyEnemy and node.is_boss and node._has_ability("phase_storm"):
			has_storm = true
			break
	if not has_storm:
		return
	var rad := 70.0 + run.current_floor * 1.2
	var dmg := 9.0 + run.current_floor * 0.5 + CombatConstants.BOSS_STORM_DMG_BONUS
	var storm_pat := "ring"
	match phase:
		2: storm_pat = "ring"
		3: storm_pat = "diagonal"
		_: storm_pat = "lanes"
	var count := 3 if storm_pat == "ring" else 4
	_spawn_hazard_pattern(storm_pat, count, rad, dmg, "storm")

# Cada eliminación: contabiliza, aplica efectos del inventario, dispara la
# siguiente oleada si procede, o completa la sala cuando ya no hay enemigos.
func _on_enemy_defeated(_enemy: HarmonyEnemy) -> void:
	defeated += 1
	room_kills += 1
	if is_instance_valid(player):
		player.items.on_kill(_enemy)
		player._emit_stats()
	if current_room_type() == "BOSS":
		# En la sala del jefe solo su derrota completa la sala: matar a un
		# refuerzo no debe activar la victoria ni el avance de piso.
		if _enemy.is_boss:
			_handle_boss_cleared()
		return
	# La sala se completa cuando se derrotó todo su presupuesto; las oleadas
	# intermedias se intercalan en _process esperando que no queden enemigos.
	if room_kills >= room_budget:
		_handle_room_cleared()

func current_room_type() -> String:
	var room := run.current_room()
	return room.room_type if room != null else ""

# Completa una sala de combate: marca en el grafo y abre la recompensa.
func _handle_room_cleared() -> void:
	run.complete_current()
	awaiting_reward = true
	var cleared := run.current_room()
	item_ui.queue_reward(cleared.reward_kind if cleared != null else "combat")
	room_number = run.rooms_completed + 1
	player.invulnerable = 1.5
	SFX.play("clear")
	VISUALS.burst(self, VISUALS.COMBAT, 0, 4, 90.0, player.global_position - global_position + Vector2(0, -20), 0.4)
	VISUALS.float_text(self, player.global_position + Vector2(0, -55), "SALA LIMPIA", Color("ffd166"))
	_autosave_session()

func _apply_meta_bonuses() -> void:
	var bonuses: Dictionary = META.run_bonuses()
	player.voice_max += float(bonuses.get("voice_max_bonus", 0.0))
	for i in range(4):
		player.member_voice[i] = player.voice_max
	player.items.coins += int(bonuses.get("start_coins", 0))
	player.composure_gain_mult = float(bonuses.get("composure_mult", 1.0))
	player.items.shop_discount = int(bonuses.get("shop_discount", 0))
	player.meta_path = str(bonuses.get("path", ""))
	player.path_empower = 0
	_refresh_path_bonuses()
	player._emit_stats()

func _refresh_path_bonuses() -> void:
	player.ability_damage_mult = 1.0
	player.dodge_cd_mult = 1.0
	player.speed_path_mult = 1.0
	player.harmony_path_mult = 1.0
	player.kill_composure_mult = 1.0
	player.adlib_damage_mult = 1.0
	player.chain_window = 2.6
	var empower := 1.0 + CombatConstants.PATH_EMPOWER_STEP * float(player.path_empower)
	match player.meta_path:
		"solar":
			player.ability_damage_mult = 1.18 * empower
		"moonbyul":
			player.dodge_cd_mult = 0.80 / empower
			player.speed_path_mult = 1.10 * empower
		"wheein":
			player.harmony_path_mult = 1.25 * empower
			player.chain_window = 2.6 + CombatConstants.WHEEIN_CHAIN_BONUS
		"hwasa":
			player.kill_composure_mult = 1.60 * empower
			player.adlib_damage_mult = 1.12 * empower

# Completa el jefe: abre la recompensa especial del jefe; la confirmación del
# piso (avanzar) ocurre al pulsar continuar en la transición.
func _handle_boss_cleared() -> void:
	awaiting_reward = true
	awaiting_floor_start = true
	item_ui.queue_reward("boss")
	room_number = run.rooms_completed + 1

# Confirma la transición de piso tras la recompensa del jefe: el RunManager
# completa la sala BOSS, avanza al siguiente piso y arranca su START.
func start_after_boss() -> void:
	awaiting_floor_start = false
	awaiting_reward = false
	run.complete_current()
	var next := run.current_room()
	if next != null and not next.completed:
		_begin_current_room()
	_autosave_session()

# --- Salas fuera de combate -------------------------------------------------

# Recompensa: el jugador elige objeto mejorado, botín o descanso.
func _enter_reward_room() -> void:
	awaiting_reward = true
	item_ui.open_reward_special()

# Descanso: cura un 30% del equipo estando en la sala REST.
func _enter_rest_room() -> void:
	player.items.heal_team(0.30)
	player._emit_stats()
	run.complete_current()
	awaiting_reward = true
	item_ui.show_routes()
	room_number = run.rooms_completed + 1

# Evento: catálogo con varias decisiones (riesgo/beneficio).
func _enter_event_room() -> void:
	var catalog: Array = EVENT_CATALOG.for_floor(run.current_floor)
	var pick: Dictionary = catalog[run.rng.randi_range(0, catalog.size() - 1)]
	var choices: Array = []
	for raw in pick.get("choices", []):
		var entry: Dictionary = raw
		var effect_id: String = str(entry.get("effect", "noop"))
		choices.append({
			"text": str(entry.get("text", "…")),
			"fn": _event_effect_callable(effect_id),
		})
	item_ui.open_event_choices(str(pick.get("title", "EVENTO")), choices)

func _event_effect_callable(effect_id: String) -> Callable:
	return func(): _apply_event_effect(effect_id)

func _apply_event_effect(effect_id: String) -> void:
	match effect_id:
		"heal_30":
			player.items.heal_team(0.30)
		"heal_15":
			player.items.heal_team(0.15)
		"pay_ticket":
			if player.items.coins >= 5:
				player.items.coins -= 5
				player.items.tickets += 1
		"composure_25":
			player.gain_composure(25.0)
		"composure_20":
			player.gain_composure(20.0)
		"composure_15":
			player.gain_composure(15.0)
		"coins_hurt":
			player.items.coins += 12
			player.voice = maxf(1.0, player.voice - 20.0)
		"buy_key":
			if player.items.coins >= 8:
				player.items.coins -= 8
				player.items.keys += 1
		"random_item":
			_grant_random_item("")
		"buy_potion":
			if player.items.coins >= 6 and player.items.can_acquire("heart_recovery_potion"):
				player.items.coins -= 6
				player.items.acquire("heart_recovery_potion")
		"challenge":
			player.voice = maxf(1.0, player.voice - 15.0)
			player.items.keys += 1
			player.gain_composure(40.0)
		"xp_40":
			player.items.xp += 40.0
			while player.items.xp >= 100.0:
				player.items.xp -= 100.0
				player.items.level += 1
				player.items.reward_requested.emit("level")
		"uncommon_item":
			_grant_random_item("UNCOMMON")
		"sync":
			player.harmony = minf(100.0, player.harmony + 20.0)
			player.gain_composure(20.0)
		"coins_8":
			player.items.coins += 8
		"eclipse_rite":
			player.voice = maxf(1.0, player.voice - 25.0)
			_grant_random_item("RARE")
		"composure_for_keys":
			if player.composure >= 50.0:
				player.composure = 0.0
				player.items.keys += 2
		"void_pay":
			if player.items.coins >= 12:
				player.items.coins -= 12
				player.items.tickets += 1
				player.gain_composure(40.0)
		"void_gamble":
			player.voice = maxf(1.0, player.voice - 10.0)
			player.items.coins += 15
		"encore_solo":
			player.gain_composure(35.0)
			for i in range(4):
				if i != player.active_index and player.member_voice[i] > 0.0:
					player.member_voice[i] = maxf(1.0, player.member_voice[i] - 8.0)
		"path_empower":
			if player.meta_path.is_empty():
				player.gain_composure(30.0)
			elif player.path_empower >= CombatConstants.PATH_EMPOWER_MAX:
				player.gain_composure(25.0)
				VISUALS.float_text(self, player.global_position + Vector2(0, -70), "RUTA MÁX", Color("4cc9f0"))
			else:
				player.path_empower = mini(CombatConstants.PATH_EMPOWER_MAX, player.path_empower + 1)
				_refresh_path_bonuses()
				VISUALS.float_text(self, player.global_position + Vector2(0, -70), "RUTA↑", Color("ffd166"))
		"path_cross_rehearsal":
			_grant_random_item("RARE")
			player.gain_composure(20.0)
		_:
			pass
	VISUALS.float_text(self, player.global_position + Vector2(0, -50), "EVENTO", Color("4cc9f0"))
	player._emit_stats()

# Otorga un ítem adquirible al azar; min_rarity filtra rareza mínima opcional.
func _grant_random_item(min_rarity: String) -> void:
	const ORDER := ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
	var min_rank := ORDER.find(min_rarity) if not min_rarity.is_empty() else 0
	var pool: Array[String] = []
	for entry in ITEM_CATALOG.all():
		if entry.id in ["treasure_chest", "legendary_celestial_chest"]:
			continue
		if not player.items.can_acquire(entry.id):
			continue
		var rank := ORDER.find(str(entry.rarity))
		if rank < min_rank:
			continue
		pool.append(entry.id)
	if pool.is_empty():
		player.items.coins += 5
		return
	player.items.acquire(pool[run.rng.randi_range(0, pool.size() - 1)])

# Tienda: tres ítems con precio por rareza; la salida activa la ruta.
func _enter_shop_room() -> void:
	item_ui.open_shop()

# Completa la sala no-combate tras su interacción (usado por item_ui).
func finish_non_combat_room() -> void:
	run.complete_current()
	awaiting_reward = true
	room_number = run.rooms_completed + 1
	item_ui.close()
	_autosave_session()

# --- Navegación del grafo ------------------------------------------------

# Avanza a una sala concreta del grafo y arranca su encuentro. Si el panel de
# rutas quedara abierto, lo cierra y reanuda el árbol antes de entrar.
func go_to_room(room_id: int) -> void:
	awaiting_reward = false
	if item_ui.overlay.visible:
		item_ui.overlay.hide()
		get_tree().paused = false
	if run.enter_room(room_id) == null:
		return
	_begin_current_room()
	_autosave_session()

# Compatibilidad: continúa a la primera opción de la ruta (siguiente sala
# del tronco). Usado también por la brújula/contraseña de los tests.
func start_next_room() -> void:
	var options := run.next_options()
	if options.is_empty():
		return
	go_to_room(options[0].room_id)

func _on_game_over() -> void:
	SESSION.clear()
	combat_hud.show_run_end(false, _run_summary())

func _on_run_completed() -> void:
	SESSION.clear()
	combat_hud.show_run_end(true, _run_summary())

func _run_summary() -> Dictionary:
	var item_count := 0
	if is_instance_valid(player) and player.items != null:
		for id in player.items.owned:
			item_count += int(player.items.owned[id])
	return {
		"floor": run.current_floor if run != null else 1,
		"rooms": run.rooms_completed if run != null else 0,
		"bosses": run.bosses_defeated.size() if run != null else 0,
		"coins": player.items.coins if is_instance_valid(player) else 0,
		"items": item_count,
	}

# --- Persistencia de sesión -----------------------------------------------

func _try_restore_session() -> bool:
	var data: Dictionary = SESSION.read()
	if data.is_empty():
		return false
	run.import_session(data.get("run", {}))
	player.items.import_session(data.get("items", {}))
	var voices: Array = data.get("member_voice", [])
	for i in range(4):
		player.member_voice[i] = float(voices[i]) if i < voices.size() else player.voice_max
	player.active_index = clampi(int(data.get("active_index", 0)), 0, 3)
	player.harmony = float(data.get("harmony", 0.0))
	player.composure = float(data.get("composure", 0.0))
	awaiting_reward = bool(data.get("awaiting_reward", false))
	awaiting_floor_start = bool(data.get("awaiting_floor_start", false))
	if player.art != null:
		player.art.configure(player.active_index)
	player._emit_stats()
	return true

func _autosave_session() -> void:
	if not is_instance_valid(player) or player.team_defeated or run == null:
		return
	SESSION.write({
		"run": run.export_session(),
		"items": player.items.export_session(),
		"member_voice": player.member_voice.duplicate(),
		"active_index": player.active_index,
		"harmony": player.harmony,
		"composure": player.composure,
		"stage_index": stage_index,
		"awaiting_reward": awaiting_reward,
		"awaiting_floor_start": awaiting_floor_start,
	})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave_session()

# --- HUD y señales ----------------------------------------------------------

func _on_stats_changed(data: Dictionary) -> void:
	if is_instance_valid(combat_hud):
		combat_hud.update_stats(data, defeated)

func _on_chain_changed(level: int, timer: float) -> void:
	if is_instance_valid(combat_hud):
		combat_hud.update_chain(level, timer)

# Punto de aparición en uno de los cuatro lados del rectángulo de la arena.
func _random_edge_position() -> Vector2:
	var side := rng.randi_range(0, 3)
	match side:
		0: return Vector2(rng.randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.position.y + 30.0)
		1: return Vector2(rng.randf_range(arena_rect.position.x, arena_rect.end.x), arena_rect.end.y - 30.0)
		2: return Vector2(arena_rect.position.x + 30.0, rng.randf_range(arena_rect.position.y, arena_rect.end.y))
		_: return Vector2(arena_rect.end.x - 30.0, rng.randf_range(arena_rect.position.y, arena_rect.end.y))

# Dibuja el escenario de fondo y bandas HUD legibles.
func _draw() -> void:
	draw_texture_rect(BACKGROUNDS[stage_index], Rect2(0, 0, 1280, 720), false)
	var biome_tiles: Texture2D = VISUALS.LUNAR_TILESET if stage_index == 3 else VISUALS.NEON_TILESET if stage_index == 6 else null
	if biome_tiles != null:
		var tile := VISUALS.region(biome_tiles, Rect2(0, 0, 96, 96))
		draw_texture_rect(tile, Rect2(92, 474, 72, 72), false)
		draw_texture_rect(tile, Rect2(1116, 474, 72, 72), false)
	var masonry := VISUALS.ARCHITECTURE
	for x in [30.0, 1160.0]:
		draw_texture_rect(VISUALS.region(masonry, Rect2(625, 288, 69, 165)), Rect2(x, 265, 70, 170), false)
	for x in [165.0, 945.0]:
		draw_texture_rect(VISUALS.region(masonry, Rect2(177, 490, 212, 90)), Rect2(x, 355, 170, 72), false)
	draw_texture_rect(VISUALS.region(masonry, Rect2(575, 983, 165, 137)), Rect2(572, 285, 136, 113), false)
	draw_rect(Rect2(0, 0, 1280, 110), Color(0.015, 0.015, 0.04, 0.80))
	draw_rect(Rect2(0, 620, 1280, 100), Color(0.015, 0.015, 0.04, 0.84))
	draw_rect(arena_rect, Color(0.8, 0.75, 1.0, 0.22), false, 1.0)

# Tipo de la siguiente sala posible (legado, para la brújula).
func next_room_kind() -> String:
	var options := run.next_options()
	if options.is_empty():
		return "boss" if awaiting_floor_start else "normal"
	return options[0].room_type.to_lower()

# Tipo de la sala actual (lo usa el HUD/status).
func room_kind(_number: int) -> String:
	return current_room_type().to_lower()
