# ---------------------------------------------------------------------------
# player.gd — HarmonyPlayer (CharacterBody2D). Controla al equipo de 4
# integrantes con VIDA INDIVIDUAL (Voz):
#   - movimiento y disparo direccional (WASD),
#   - habilidad única por integrante (E), esquiva (Shift) y Ad-lib (Q),
#   - cadena de Armonía al conectar golpes con integrantes distintas,
#   - sinergias entre integrantes al alternar (tag skills),
#   - derrota y rotación automática cuando cae una integrante.
# ---------------------------------------------------------------------------
class_name HarmonyPlayer
extends CharacterBody2D

const VISUALS = preload("res://scripts/visual_assets.gd")
const SFX = preload("res://scripts/systems/sfx.gd")
const MemberIdentity = preload("res://scripts/systems/member_identity.gd")

signal stats_changed(data: Dictionary)
signal chain_changed(level: int, timer: float)
signal game_over

const ACTOR_ART = preload("res://scripts/actor_art.gd")
var art: AnimatedSprite2D

const RUN_ITEMS = preload("res://scripts/run_items.gd")
var items
# Ralentización por debuff (del enemigo FEEDBACK): tiempo restante y fuerza.
var slow_time := 0.0
var slow_strength := 0.0
# Escala aplicada al lanzar habilidades (0.5 en re-lanzamiento por Echo).
var cast_scale := 1.0

const PROJECTILE = preload("res://scripts/projectile.gd")

# Datos estáticos de las 4 integrantes: nombre, color, velocidad,
# daño base y cadencia de disparo (rate, en segundos).
var members := [
	{"name":"SOLAR","color":Color("ffd166"),"speed":260.0,"damage":15.0,"rate":0.28},
	{"name":"MOONBYUL","color":Color("c77dff"),"speed":300.0,"damage":11.0,"rate":0.20},
	{"name":"WHEEIN","color":Color("4cc9f0"),"speed":275.0,"damage":13.0,"rate":0.24},
	{"name":"HWASA","color":Color("ff5d5d"),"speed":245.0,"damage":19.0,"rate":0.38}
]

var active_index := 0
var voice_max := 100.0
# Voz (vida) de cada integrante, en el mismo orden que `members`.
var member_voice: Array[float] = [100.0, 100.0, 100.0, 100.0]
var team_defeated := false
# Existing combat code reads/writes the active member's health through this property.
var voice: float:
	get:
		return member_voice[active_index]
	set(value):
		member_voice[active_index] = clampf(value, 0.0, voice_max)
var harmony := 0.0
# Compostura: medidor que alimenta Ad-lib (Q). Independiente de Armonía/cadena.
var composure := 0.0
# Multiplicador meta permanente sobre ganancias de Compostura.
var composure_gain_mult := 1.0
# Flash rojo breve al recibir daño (lectura de peligro).
var hurt_flash := 0.0
# Ruta meta activa (solar/moonbyul/wheein/hwasa).
var meta_path := ""
var ability_damage_mult := 1.0
var dodge_cd_mult := 1.0
var speed_path_mult := 1.0
var harmony_path_mult := 1.0
var kill_composure_mult := 1.0
var adlib_damage_mult := 1.0
# Buff de evento path_empower (0–2) y sinergias de ruta v2.
var path_empower := 0
var dodge_shot_boost := 0.0
# Modifiers de sala (capa de variedad).
var room_mod_id := ""
var room_player_speed_mult := 1.0
var room_damage_dealt_mult := 1.0
var room_damage_taken_mult := 1.0
var room_composure_mult := 1.0
var room_ability_cd_mult := 1.0
var room_harmony_drain := 0.0
var room_kill_composure_mult := 1.0
var room_adlib_damage_mult := 1.0
var room_enemy_speed_mult := 1.0
var room_extra_hazards := 0
# Cooldowns: ataque, habilidad y esquiva; invulnerable = segundos sin recibir daño.
var attack_cd := 0.0
var ability_cd := 0.0
var dodge_cd := 0.0
var invulnerable := 0.0
# Cadena de Armonía: acumula distintas integrantes que aciertan golpes seguidos.
var chain_timer := 0.0
var chain_window := 2.6
var chain_members: Array[int] = []
var chain_level := 0
# Disparo: acciones y direcciones cardinales; `held_shots` guarda el orden
# de pulsación para que gane la tecla presionada más recientemente.
const SHOOT_ACTIONS = ["shoot_up", "shoot_left", "shoot_down", "shoot_right"]
const SHOOT_DIRECTIONS = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
var held_shots: Array[int] = []
var aim_dir := Vector2.RIGHT
var arena_rect := Rect2(72, 72, 1136, 576)

func _ready() -> void:
	# El sistema de ítems se monta como hijo del jugador.
	items = RUN_ITEMS.new()
	items.player = self
	add_child(items)
	art = ACTOR_ART.new()
	add_child(art)
	art.configure(active_index)
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()
	_emit_stats()

func _physics_process(delta: float) -> void:
	# Avance temporal de todos los sistemas/debuffs del inventario.
	items.tick(delta)
	slow_time = maxf(0.0, slow_time - delta)
	if slow_time <= 0.0: slow_strength = 0.0
	if Input.is_action_just_pressed("adlib"):
		items.start_adlib()
	attack_cd = max(attack_cd - delta, 0.0)
	ability_cd = max(ability_cd - delta, 0.0)
	dodge_cd = max(dodge_cd - delta, 0.0)
	invulnerable = max(invulnerable - delta, 0.0)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	dodge_shot_boost = maxf(0.0, dodge_shot_boost - delta)
	if room_harmony_drain > 0.0 and harmony > 0.0:
		harmony = maxf(0.0, harmony - room_harmony_drain * delta)
	_update_chain(delta)
	_update_shooting_direction()
	_handle_switch_inputs()
	_handle_movement()
	_handle_combat()
	art.locomotion(velocity.length() > 1.0, aim_dir.x)
	_emit_stats()
	move_and_slide()
	# Mantiene al personaje dentro de la arena.
	global_position.x = clamp(global_position.x, arena_rect.position.x + 18.0, arena_rect.end.x - 18.0)
	global_position.y = clamp(global_position.y, arena_rect.position.y + 18.0, arena_rect.end.y - 18.0)
	queue_redraw()

# Mueve con las flechas; aplica la velocidad de la integrante activa,
# multiplicadores de ítems y la ralentización activa.
func _handle_movement() -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_vec * float(members[active_index]["speed"]) * items.speed_multiplier() * speed_path_mult * room_player_speed_mult * (1.0 - slow_strength if slow_time > 0.0 else 1.0)

# Actualiza la dirección de disparo en función de las teclas WASD mantenidas:
# el orden del array guarda la más reciente (gana al soltar de atrás hacia delante).
func _update_shooting_direction() -> void:
	# Most recently pressed held key wins; releasing it restores the previous one.
	for index in range(SHOOT_ACTIONS.size()):
		if not Input.is_action_pressed(SHOOT_ACTIONS[index]):
			held_shots.erase(index)
		elif not held_shots.has(index):
			held_shots.append(index)
	if not held_shots.is_empty():
		aim_dir = SHOOT_DIRECTIONS[held_shots.back()]

func _handle_combat() -> void:
	# Disparo automático mientras se mantiene una tecla WASD y el CD lo permite.
	if not held_shots.is_empty() and attack_cd <= 0.0:
		_basic_attack()
	if Input.is_action_just_pressed("ability") and ability_cd <= 0.0:
		_use_ability()
	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0:
		_dodge()

# Disparo básico en la dirección de puntería; algunos atributos del
# proyectil dependen de la integrante (velocidad, radio, perforación).
func _basic_attack() -> void:
	if team_defeated:
		return
	art.action("attack", 0.25)
	attack_cd = float(members[active_index]["rate"])
	var projectile := PROJECTILE.new()
	projectile.global_position = global_position + aim_dir * 24.0
	projectile.member_index = active_index
	projectile.damage = float(members[active_index]["damage"]) * items.damage_multiplier(active_index) * room_damage_dealt_mult
	projectile.item_effects = items
	projectile.projectile_color = members[active_index]["color"]
	projectile.velocity = aim_dir * (620.0 if active_index != 3 else 500.0)
	projectile.radius = 5.0 if active_index == 1 else 7.0
	projectile.piercing = active_index == 2
	projectile.hit_enemy.connect(_on_projectile_hit)
	get_parent().add_child(projectile)

# Habilidad única por integrante. Consume 100 de energía y aplica el cooldown
# modificado por ítems. Con `repeat=true` se re-lanza por Echo Orb sin gasto.
# Cada integrante tiene un efecto propio desplegado en el `match`.
func _use_ability(repeat: bool = false) -> void:
	if team_defeated:
		return
	if not repeat and items.energy < 100.0:
		return
	if not repeat:
		items.energy -= 100.0
		ability_cd = items.ability_cooldown() * room_ability_cd_mult
		items.on_ability(active_index)
		SFX.play(MemberIdentity.sfx_for_path(MemberIdentity.PATHS[active_index]))
	cast_scale = (0.5 if repeat else 1.0) * (1.0 + 0.20 * items.skill_ranks[active_index]) * ability_damage_mult
	art.action("ability", 0.45)
	VISUALS.flash(self, VISUALS.cell(VISUALS.COMBAT, active_index, 3, 4, 6), 100.0, Vector2(0, -24))
	VISUALS.elemental_burst(self, active_index)
	if not repeat and meta_path == "solar":
		gain_composure(12.0)
	match active_index:
		0:
			# Solar: curación limitada + pulso de luz.
			items.heal_member(active_index, 8.0 * cast_scale)
			_radial_burst(8, 12.0, 430.0, false)
		1:
			# Moonbyul: reposicionamiento + control de masas.
			global_position += aim_dir * 105.0 * cast_scale
			global_position.x = clamp(global_position.x, arena_rect.position.x + 18.0, arena_rect.end.x - 18.0)
			global_position.y = clamp(global_position.y, arena_rect.position.y + 18.0, arena_rect.end.y - 18.0)
			_slow_nearby_enemies(180.0, 2.2 * cast_scale)
		2:
			# Wheein: trazo penetrante.
			for offset in [-0.16, 0.0, 0.16]:
				_spawn_projectile(aim_dir.rotated(offset), 20.0, 720.0, true, 8.0)
		3:
			# Hwasa: remate de área cercano.
			_radial_burst(12, 18.0, 330.0, true)
	cast_scale = 1.0
	if not repeat and items.count("echo_orb") > 0 and items.rng.randf() < 0.15:
		_use_ability(true)
	_emit_stats()

func _dodge() -> void:
	# Esquiva con impulso: breve invulnerabilidad y desplazamiento en la
	# dirección de movimiento (o de puntería si no hay input).
	if team_defeated:
		return
	art.action("dodge", 0.23)
	dodge_cd = 1.05 * dodge_cd_mult
	invulnerable = 0.22
	if meta_path == "moonbyul":
		dodge_shot_boost = 1.5
	var move_vec := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := move_vec.normalized() if move_vec.length() > 0.0 else aim_dir
	global_position += direction * 95.0 * (1.0 + 0.08 * items.count("speed_feather_charm")) * speed_path_mult

# Cambio manual de integrante (teclas 1-4): solo a una viva y distinta.
# Dispara las sinergias de ítems y el efecto de relevo de la nueva integrante.
func switch_to(index: int) -> void:
	if team_defeated or index < 0 or index >= members.size() or index == active_index:
		return
	if member_voice[index] <= 0.0:
		return
	var previous := active_index
	_activate_member(index)
	items.on_switch(previous, index)
	SFX.play(MemberIdentity.sfx_for_path(MemberIdentity.PATHS[index]))
	if meta_path == "wheein":
		items.heal_member(index, 4.0)
	_trigger_tag_skill(index)
	_emit_stats()

func _activate_member(index: int) -> void:
	# Cambia el sprite activo y la aparición; no toca la Voz (cada una es propia).
	active_index = index
	art.configure(index)
	queue_redraw()
	_emit_stats()

# Efecto de relevo de la integrante entrante (al alternar): defensa, control,
# proyectil perforante o ráfaga radial según quién entra.
func _trigger_tag_skill(index: int) -> void:
	match index:
		0:
			invulnerable = max(invulnerable, 0.30)
			items.heal_member(active_index, 3.0)
		1:
			_slow_nearby_enemies(210.0, 1.3)
		2:
			_spawn_projectile(aim_dir, 17.0, 760.0, true, 7.0)
		3:
			_radial_burst(8, 13.0, 290.0, false)

func _handle_switch_inputs() -> void:
	if Input.is_action_just_pressed("switch_1"): switch_to(0)
	if Input.is_action_just_pressed("switch_2"): switch_to(1)
	if Input.is_action_just_pressed("switch_3"): switch_to(2)
	if Input.is_action_just_pressed("switch_4"): switch_to(3)

# Crea un proyectil generado por habilidades/relevos (no por disparo básico).
func _spawn_projectile(direction: Vector2, dmg: float, speed: float, piercing: bool, radius: float) -> void:
	var projectile := PROJECTILE.new()
	projectile.global_position = global_position + direction * 24.0
	projectile.member_index = active_index
	projectile.damage = dmg * cast_scale * items.damage_multiplier(active_index)
	projectile.item_effects = items
	projectile.projectile_color = members[active_index]["color"]
	projectile.velocity = direction * speed
	projectile.piercing = piercing
	projectile.radius = radius
	projectile.hit_enemy.connect(_on_projectile_hit)
	get_parent().add_child(projectile)

# Ráfaga de proyectiles distribuidos en círculo alrededor del jugador.
func _radial_burst(count: int, dmg: float, speed: float, piercing: bool) -> void:
	for i in range(count):
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / float(count))
		_spawn_projectile(direction, dmg, speed, piercing, 6.0)

# Aplica un freno temporal a los enemigos dentro del radio indicado.
func _slow_nearby_enemies(radius: float, duration: float) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and global_position.distance_to(node.global_position) <= radius:
			if node.has_method("apply_slow"):
				node.apply_slow(duration)

# Cada acierto de proyectil: registra cadena y otorga Armonía
# (base + bonificación según nivel de cadena y multiplicadores de ítems).
func _on_projectile_hit(member_index: int, _damage: float) -> void:
	if team_defeated:
		return
	_register_chain_hit(member_index)
	harmony = min(100.0, harmony + (3.0 + chain_level * 1.5) * items.harmony_multiplier() * harmony_path_mult)
	gain_composure(CombatConstants.COMPOSURE_ON_HIT)
	_emit_stats()

func gain_composure(amount: float) -> void:
	composure = minf(CombatConstants.COMPOSURE_MAX, composure + amount * composure_gain_mult * room_composure_mult)

# Actualiza la cadena de Armonía: golpes de integrantes distintas suman nivel;
# al llegar a Cuarteto otorga Armonía extra y activa efectos de cuarteto.
func _register_chain_hit(member_index: int) -> void:
	if chain_timer <= 0.0:
		chain_members.clear()
	if not chain_members.has(member_index):
		chain_members.append(member_index)
		if chain_members.size() > chain_level:
			gain_composure(CombatConstants.COMPOSURE_ON_CHAIN_STEP)
	var previous_level := chain_level
	chain_level = chain_members.size()
	chain_timer = chain_window
	if chain_level >= 4 and previous_level < 4:
		harmony = min(100.0, harmony + 18.0 * items.harmony_multiplier())
		gain_composure(CombatConstants.COMPOSURE_ON_QUARTET)
		items.on_quartet()
	chain_changed.emit(chain_level, chain_timer)

# Cadencia de la cadena: se reinicia si no se conecta otro golpe a tiempo.
func _update_chain(delta: float) -> void:
	if chain_timer <= 0.0:
		return
	chain_timer -= delta
	if chain_timer <= 0.0:
		chain_members.clear()
		chain_level = 0
	chain_changed.emit(chain_level, max(chain_timer, 0.0))

# Recibe daño (contacto o proyectil enemigo). Los escudos absorben primero;
# si la integrante activa cae rota automáticamente a la siguiente viva con 1 s
# de protección. Cuando caen las cuatro: posible revivir (ítem) o derrota total.
func receive_damage(amount: float, corruption: bool = false, boss: bool = false) -> void:
	if team_defeated or invulnerable > 0.0 or voice <= 0.0:
		return
	var taken: float = items.absorb(amount * room_damage_taken_mult, corruption, boss)
	voice = maxf(0.0, voice - taken)
	items.after_damage()
	art.action("hurt", 0.18)
	hurt_flash = 0.22
	if is_inside_tree() and taken > 0.0:
		VISUALS.float_text(get_parent(), global_position + Vector2(0, -48), "-%d" % int(round(taken)), Color("ff5d5d") if boss or corruption else Color("ff8fa3"))
		VISUALS.burst(self, VISUALS.STATUS, 2, 6, 55.0, Vector2(0, -12), 0.28)
	invulnerable = 0.45
	chain_timer = 0.0
	chain_members.clear()
	chain_level = 0
	chain_changed.emit(0, 0.0)
	if voice <= 0.0:
		# Reliquia legendaria: salva a esta integrante una vez antes de rotar.
		if items.try_guardian_save(active_index):
			art.action("recover", 0.45)
			_emit_stats()
			return
		# Cycle forward, skipping fallen members. The replacement keeps its own HP.
		for offset in range(1, members.size()):
			var next_index := (active_index + offset) % members.size()
			if member_voice[next_index] > 0.0:
				invulnerable = 1.0
				var fallen := ACTOR_ART.new()
				get_parent().add_child(fallen)
				fallen.configure(active_index)
				# A stationary cosmetic copy lets the next member take over immediately.
				fallen.set_process(false)
				fallen.action("death", 0.5)
				fallen._align_feet()
				fallen.global_position = global_position + fallen.position
				fallen.animation_finished.connect(fallen.queue_free)
				_activate_member(next_index)
				return
		# Última integrante en pie: intenta revivir con el ítem, si no, derrota.
		if items.revive():
			art.action("recover", 0.7)
			_emit_stats()
			return
		team_defeated = true
		velocity = Vector2.ZERO
		art.action("death", 0.5)
		set_physics_process(false)
		_emit_stats()
		game_over.emit()
		return
	_emit_stats()

# Emite un resumen de estado para que el HUD e inventario se actualicen.
func _emit_stats() -> void:
	var name_label: String = MemberIdentity.hud_label(active_index)
	if not meta_path.is_empty():
		name_label = "%s  |  %s" % [name_label, MemberIdentity.path_tagline(meta_path)]
	if not room_mod_id.is_empty():
		name_label = "%s  ·  MOD %s" % [name_label, room_mod_id]
	stats_changed.emit({
		"member_name": name_label,
		"member_color": members[active_index]["color"],
		"active_index": active_index,
		"voice": voice,
		"voice_max": voice_max,
		"member_voice": member_voice.duplicate(),
		"team_defeated": team_defeated,
		"harmony": harmony,
		"composure": composure,
		"energy": items.energy,
		"shield": items.shields[active_index],
		"ability_cd": ability_cd,
		"dodge_cd": dodge_cd
	})

# Dibujo procedimental: campo de Solar, escudo circular, flecha de puntería,
# halo de color de la integrante e indicador de invulnerabilidad.
func _draw() -> void:
	if items != null and items.active("field"):
		draw_circle(items.field_center - global_position, 130.0, Color(1.0, 0.85, 0.2, 0.12))
	if items != null and items.shields[active_index] > 0:
		draw_arc(Vector2.ZERO, 31.0, 0, TAU, 32, Color.CYAN, 3.0)
	var c: Color = members[active_index]["color"]
	draw_ellipse_shadow()
	draw_circle(Vector2.ZERO, 23.0, Color(c, 0.24), false, 3.0)
	draw_line(aim_dir * 25.0, aim_dir * 34.0, Color.WHITE, 2.0)
	if invulnerable > 0.0:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color.WHITE, 2.0)
	if hurt_flash > 0.0:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, Color(1.0, 0.2, 0.25, 0.55 + hurt_flash), 3.0)

# Sombra elíptica bajo el personaje (levemente achatada para dar profundidad).
func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)

# Aplica un debuff de control (freno) considerando resistencias de ítems;
# devuelve el tiempo/valor final reducido del sistema de inventario.
func apply_debuff(duration: float, strength: float) -> void:
	var result: Vector2 = items.debuff(duration, strength, true)
	if result.x <= 0.0: return
	slow_time = maxf(slow_time, result.x)
	slow_strength = maxf(slow_strength if slow_time > 0.0 else 0.0, result.y)
