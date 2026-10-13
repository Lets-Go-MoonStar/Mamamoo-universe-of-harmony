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

func _ready() -> void:
	rng.randomize()
	_setup_inputs()
	stage_index = int(get_tree().get_meta("stage_index", 0))
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	_create_player()
	_create_hud()
	# La run se construye con la seed guardada (R la reproduce).
	run = RUN_MANAGER.new()
	add_child(run)
	run.new_run(int(get_tree().get_meta("run_seed", 0)))
	get_tree().set_meta("run_seed", run.run_seed)
	if run.current_room() != null:
		_begin_current_room()
	room_kills = 0
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

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	# Atajos globales: escenario (N), reiniciar con la misma seed (R) y
	# nueva run con seed distinta (M).
	if Input.is_action_just_pressed("next_stage"):
		select_stage((stage_index + 1) % BACKGROUNDS.size())
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if Input.is_action_just_pressed("new_seed"):
		get_tree().set_meta("run_seed", rng.randi() + 1)
		get_tree().reload_current_scene()
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

# Genera el jefe del piso (usado en salas BOSS) con sus refuerzos.
func _spawn_boss() -> void:
	var boss: BossData = run.pick_boss()
	if boss == null:
		return
	var enemy := ENEMY.new()
	enemy.setup_boss(player, boss)
	enemy.global_position = Vector2(arena_rect.get_center().x, arena_rect.position.y + 90.0)
	enemy.add_to_group("enemies")
	enemy.defeated.connect(_on_enemy_defeated)
	actors.add_child(enemy)
	spawned += 1

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

# --- Salas fuera de combate -------------------------------------------------

# Recompensa gratuita (tipo "reward", pesos mejores que combate normal).
func _enter_reward_room() -> void:
	run.complete_current()
	awaiting_reward = true
	item_ui.queue_reward("reward")
	room_number = run.rooms_completed + 1

# Descanso: cura un 30% del equipo estando en la sala REST.
func _enter_rest_room() -> void:
	player.items.heal_team(0.30)
	player._emit_stats()
	run.complete_current()
	awaiting_reward = true
	item_ui.show_routes()
	room_number = run.rooms_completed + 1

# Evento aleatorio con efecto único (caso de uso tipo "sala EVENT").
func _enter_event_room() -> void:
	var options := [
		{"text": "Una palabra de consuelo cura a todo el equipo (+25%% de Voz)", "fn": _event_heal},
		{"text": "Hallas monedas perdidas (+8 monedas)", "fn": _event_coins},
		{"text": "Una llave antigua aparece en tu bolsillo (+1 llave)", "fn": _event_key},
	]
	var pick: Dictionary = options[run.rng.randi_range(0, options.size() - 1)]
	item_ui.open_event(pick["text"], pick["fn"])

func _event_heal() -> void:
	player.items.heal_team(0.25)
	player._emit_stats()

func _event_coins() -> void:
	player.items.coins += 8

func _event_key() -> void:
	player.items.keys += 1

# Tienda: tres ítems con precio por rareza; la salida activa la ruta.
func _enter_shop_room() -> void:
	item_ui.open_shop()

# Completa la sala no-combate tras su interacción (usado por item_ui).
func finish_non_combat_room() -> void:
	run.complete_current()
	awaiting_reward = true
	room_number = run.rooms_completed + 1
	item_ui.close()

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

# Compatibilidad: continúa a la primera opción de la ruta (siguiente sala
# del tronco). Usado también por la brújula/contraseña de los tests.
func start_next_room() -> void:
	var options := run.next_options()
	if options.is_empty():
		return
	go_to_room(options[0].room_id)

func _on_game_over() -> void:
	combat_hud.show_defeat()

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
