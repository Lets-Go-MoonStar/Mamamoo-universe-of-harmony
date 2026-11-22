# ---------------------------------------------------------------------------
# enemy.gd — HarmonyEnemy (CharacterBody2D). Enemigo de IA dirigido por datos:
#   - `setup` conserva las 4 variantes clásicas del prototipo (compat. tests),
#   - `setup_data` construye cualquier variante desde un EnemyData (.tres):
#     arquetipos chaser / swarm / tank / ranged / élite,
#   - `setup_boss` construye un jefe desde BossData, con fases por umbrales
#     de vida (100/70/35), abilities (ranged|enrage) y proyectil; la sala del
#     jefe contiene únicamente al jefe, sin invocación de refuerzos,
#   - efectos cosméticos/de estado: flash, freno, quemadura, marca de Eclipse
#     y barra de vida (más alta y ancha para jefes).
# ---------------------------------------------------------------------------
class_name HarmonyEnemy
extends CharacterBody2D

const VISUALS = preload("res://scripts/visual_assets.gd")

const ACTOR_ART = preload("res://scripts/actor_art.gd")
const ENEMY_BULLET = preload("res://scripts/enemy_projectile.gd")
var art: AnimatedSprite2D
var art_index := 0
var dying := false

signal defeated(enemy: HarmonyEnemy)
signal boss_phase_changed(phase: int)

# Datos fuente (opcionales): si se configuró con resource, aquí está el origen.
var data: EnemyData
var boss_data: BossData
var is_boss := false
var ranged := false
var enraged := false

# Atributos por defecto (los sobreescribe la configuración elegida).
var max_hp := 55.0
var hp := 55.0
var move_speed := 95.0
var contact_damage := 9.0
# Alcance y cadencia de ataque: usados por arquetipos ranged (proyectil) y
# para el enfriamiento del daño por contacto en los cuerpo a cuerpo.
var attack_range := 36.0
var attack_cooldown := 0.85
var target: Node2D
var enemy_color := Color("8d4bb7")
# Flash blanco al recibir daño y CD de daño por contacto.
var hit_flash := 0.0
var contact_cd := 0.0
# Frenado por habilidades/ítems del jugador.
var slow_timer := 0.0
var slow_factor := 0.45
# Estados aplicados por ítems: quemadura (Hwasa) y marca de Eclipse (Moonbyul).
var burn_time := 0.0
var eclipse_time := 0.0
# Última integrante que golpeó al enemigo (para reacciones elementales).
var last_member := -1
var label := "ECHO"
# Fase activa del jefe (1 = inicial); empieza al configurarse como jefe.
var current_phase := 0
# CD de disparo para arquetipos ranged y reinicio de la fase del jefe en 0.
var fired_cd := 0.0
# Dash firmado (Hex Echo / Beat Crusher): embestida corta hacia el jugador.
var dash_cd := 0.0
var dash_time := 0.0
var dash_dir := Vector2.ZERO
# Telegraph: aviso visible antes de dash/disparo/pull.
var telegraph_time := 0.0
var telegraph_kind := ""
var snare_cd := 0.0
var pull_cd := 0.0
var beam_cd := 0.0
var beam_dir := Vector2.RIGHT
var taught_telegraph := false
const SFX = preload("res://scripts/systems/sfx.gd")
const HAZARD = preload("res://scripts/systems/arena_hazard.gd")
const FEEL = preload("res://scripts/systems/combat_feel.gd")

# Configura la variante clásica del prototipo (compatibilidad con tests).
func setup(new_target: Node2D, variant: int = 0) -> void:
	target = new_target
	is_boss = false
	ranged = false
	art_index = variant % 4
	match art_index:
		0:
			label = "ECHO"
			enemy_color = Color("9d4edd")
			max_hp = 48.0
			move_speed = 105.0
		1:
			label = "MUTE"
			enemy_color = Color("5465ff")
			max_hp = 65.0
			move_speed = 75.0
		2:
			label = "FEEDBACK"
			enemy_color = Color("ff477e")
			max_hp = 82.0
			move_speed = 62.0
		3:
			label = "ECLIPSE"
			enemy_color = Color("dfb45e")
			max_hp = 220.0
			move_speed = 42.0
			contact_damage = 16.0
	hp = max_hp
	current_phase = 0

# Configura desde un EnemyData: estadísticas, arquetipo IA y sprite del pool.
func setup_data(new_target: Node2D, enemy_data: EnemyData, hp_mult := 1.0, dmg_mult := 1.0) -> void:
	data = enemy_data
	target = new_target
	is_boss = false
	label = enemy_data.get_display_name()
	art_index = enemy_data.sprite_index % 4
	enemy_color = _archetype_color(enemy_data.archetype)
	max_hp = enemy_data.max_hp * hp_mult
	move_speed = enemy_data.speed
	contact_damage = enemy_data.damage * dmg_mult
	attack_range = maxf(24.0, enemy_data.attack_range if enemy_data.attack_range > 0.0 else 36.0)
	attack_cooldown = enemy_data.attack_cooldown if enemy_data.attack_cooldown > 0.0 else 0.85
	ranged = enemy_data.archetype == "ranged"
	hp = max_hp
	current_phase = 0
	enraged = false
	if enemy_data.is_elite:
		max_hp *= 1.8
		hp = max_hp
		enemy_color = enemy_color.lightened(0.15)

# Configura un jefe con fases, abilities y proyectiles propios (BossData).
func setup_boss(new_target: Node2D, boss: BossData) -> void:
	boss_data = boss
	target = new_target
	is_boss = true
	label = boss.get_display_name()
	art_index = boss.sprite_index % 4
	enemy_color = Color("dfb45e") if boss.arena_index < 8 else Color("ffd166")
	max_hp = boss.hp
	move_speed = boss.speed
	contact_damage = boss.damage
	attack_range = maxf(24.0, 260.0 if boss.abilities.has("ranged") else 36.0)
	attack_cooldown = 1.1
	ranged = boss.abilities.has("ranged")
	hp = max_hp
	current_phase = 1
	enraged = false

func _ready() -> void:
	art = ACTOR_ART.new()
	add_child(art)
	var visual_index := art_index
	if is_boss:
		visual_index = 3
	elif data != null:
		visual_index = {"chaser": 0, "ranged": 1, "tank": 4, "swarm": 5}.get(data.archetype, 2)
		# Fast melee variant uses the assassin; ranged tuner uses the totem.
		if data.id == "echo_swift":
			visual_index = 2
		elif data.id == "tuner":
			visual_index = 5
	art.configure(visual_index, true, boss_data.id if is_boss and boss_data != null else "")
	if is_boss:
		scale = Vector2(1.35, 1.35)
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Tiempos de estado (quemadura, eclipse), cooldowns y flash.
	if burn_time > 0.0 and not dying:
		# Ardor: DoT ligero definitivo (CombatConstants.ARDOR_DOT_PER_SEC).
		take_damage(CombatConstants.ARDOR_DOT_PER_SEC * delta, -1)
	burn_time = maxf(0.0, burn_time - delta)
	eclipse_time = maxf(0.0, eclipse_time - delta)
	queue_redraw()
	if hit_flash > 0.0:
		hit_flash -= delta
		queue_redraw()
	if contact_cd > 0.0:
		contact_cd -= delta
	if slow_timer > 0.0:
		slow_timer -= delta
	art.modulate = Color(2.0, 2.0, 2.0) if hit_flash > 0.0 else Color.WHITE
	if is_boss:
		_check_boss_phase()
	# Si el objetivo es inválido o el equipo cayó, se queda inmóvil.
	if not is_instance_valid(target) or target.team_defeated:
		art.locomotion(false, 0.0)
		return
	if dying:
		return
	var direction := global_position.direction_to(target.global_position)
	var room_spd := 1.0
	if is_instance_valid(target) and "room_enemy_speed_mult" in target:
		room_spd = float(target.room_enemy_speed_mult)
	var speed_mult := (slow_factor if slow_timer > 0.0 else 1.0) * (1.3 if enraged else 1.0) * room_spd
	dash_cd = maxf(0.0, dash_cd - delta)
	snare_cd = maxf(0.0, snare_cd - delta)
	pull_cd = maxf(0.0, pull_cd - delta)
	beam_cd = maxf(0.0, beam_cd - delta)
	if telegraph_time > 0.0:
		telegraph_time = maxf(0.0, telegraph_time - delta)
		velocity = Vector2.ZERO
		if telegraph_kind == "beam" and is_instance_valid(target):
			beam_dir = global_position.direction_to(target.global_position)
		if telegraph_time <= 0.0:
			_resolve_telegraph()
		move_and_slide()
		art.locomotion(false, direction.x)
		queue_redraw()
		return
	if dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		velocity = dash_dir * move_speed * 3.2 * speed_mult
		_melee_contact()
		move_and_slide()
		art.locomotion(true, dash_dir.x)
		return
	if _has_ability("beam") and beam_cd <= 0.0 and global_position.distance_to(target.global_position) < 260.0:
		beam_dir = direction
		_begin_telegraph("beam", 0.85)
	elif _has_ability("dash") and dash_cd <= 0.0 and global_position.distance_to(target.global_position) > 90.0:
		_begin_telegraph("dash", 0.55 if _has_ability("telegraph") else 0.15)
	elif _has_ability("snare") and snare_cd <= 0.0:
		_begin_telegraph("snare", 0.7)
	elif _has_ability("pull") and pull_cd <= 0.0 and global_position.distance_to(target.global_position) < 220.0:
		_begin_telegraph("pull", 0.8)
	elif ranged:
		_ranged_behavior(delta, direction, speed_mult)
	else:
		velocity = direction * move_speed * speed_mult
		_melee_contact()
	move_and_slide()
	art.locomotion(velocity.length() > 1.0, direction.x)

func _begin_telegraph(kind: String, duration: float) -> void:
	telegraph_kind = kind
	telegraph_time = duration
	SFX.play("telegraph")
	var tip := "!"
	if not taught_telegraph:
		taught_telegraph = true
		tip = "¡APARTA!"
	elif kind == "beam":
		tip = "BEAM"
	elif kind == "pull":
		tip = "PULL"
	VISUALS.float_text(get_parent(), global_position + Vector2(0, -50), tip, Color("ffd166"))

func _resolve_telegraph() -> void:
	var kind := telegraph_kind
	telegraph_kind = ""
	if not is_instance_valid(target):
		return
	match kind:
		"dash":
			dash_dir = global_position.direction_to(target.global_position)
			dash_time = 0.22
			dash_cd = 2.8 if data != null and data.is_elite else 3.4
			VISUALS.burst(self, VISUALS.COMBAT, 1, 4, 70.0, Vector2(0, -10), 0.25)
		"snare":
			snare_cd = 4.5
			var hazard = HAZARD.new()
			get_parent().add_child(hazard)
			hazard.setup(target, target.global_position, 62.0, contact_damage * 0.7)
			SFX.play("hazard")
		"pull":
			pull_cd = 5.0
			if target is CharacterBody2D:
				target.global_position = target.global_position.lerp(global_position, 0.45)
			VISUALS.burst(self, VISUALS.STATUS, 3, 6, 90.0, Vector2.ZERO, 0.35)
			VISUALS.float_text(get_parent(), global_position + Vector2(0, -40), "PULL", Color("c77dff"))
			_melee_contact()
		"beam":
			beam_cd = 4.2
			_resolve_beam()
		"shot":
			_fire_projectile()
		_:
			pass

func _resolve_beam() -> void:
	var tip := global_position + beam_dir * CombatConstants.BEAM_LENGTH
	VISUALS.float_text(get_parent(), tip, "BEAM", Color("ff5964"))
	SFX.play("hazard")
	FEEL.hit_enemy(get_parent(), tip, contact_damage, true)
	if is_instance_valid(target) and target.has_method("receive_damage"):
		var to_t: Vector2 = target.global_position - global_position
		var along := to_t.dot(beam_dir)
		if along > 0.0 and along < CombatConstants.BEAM_LENGTH:
			var perp := absf(to_t.cross(beam_dir))
			if perp <= CombatConstants.BEAM_WIDTH:
				target.receive_damage(contact_damage * 1.15, _has_ability("corruption"), _contact_boss_flag())
				if _has_ability("silence") and target is HarmonyPlayer:
					target.ability_cd = maxf(target.ability_cd, CombatConstants.SILENCE_ABILITY_LOCK)
					VISUALS.float_text(get_parent(), target.global_position + Vector2(0, -40), "SILENCE", Color("4cc9f0"))

# Arquetipo ranged: mantiene distancia de tiro, se desplaza en perpendicular
# (finta) y dispara un proyectil enemigo cuando el CD está listo.
func _ranged_behavior(delta: float, direction: Vector2, speed_mult: float) -> void:
	fired_cd = maxf(0.0, fired_cd - delta)
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range * 0.85:
		velocity = direction * move_speed * speed_mult
	elif distance < attack_range * 0.55:
		velocity = -direction * move_speed * 0.55 * speed_mult
	else:
		velocity = direction.orthogonal() * move_speed * 0.35 * speed_mult
	if fired_cd <= 0.0 and distance <= attack_range and distance > 30.0:
		if (is_boss or _has_ability("telegraph")) and telegraph_time <= 0.0 and telegraph_kind == "":
			var shot_warn := 0.35
			if is_boss:
				shot_warn = 0.55 if current_phase >= 2 and _has_ability("phase_storm") else 0.45
			_begin_telegraph("shot", shot_warn)
		else:
			_fire_projectile()

# Crea un proyectil enemigo (enemy_projectile.gd) hacia el jugador.
func _fire_projectile() -> void:
	fired_cd = attack_cooldown
	if is_boss and boss_data != null:
		VISUALS.boss_ability_burst(self, boss_data.id, 2 if boss_data.id == "overlord" else 3, 100.0)
	var bullet := ENEMY_BULLET.new()
	bullet.global_position = global_position
	bullet.damage = contact_damage
	bullet.corruption = _has_ability("corruption")
	bullet.boss = is_boss
	bullet.velocity = global_position.direction_to(target.global_position) * (300.0 if is_boss else 240.0)
	art.action("attack", 0.4)
	get_parent().add_child(bullet)

# Contacto cuerpo a cuerpo: daño (más corrupción/control según variante).
func _melee_contact() -> void:
	if global_position.distance_to(target.global_position) > attack_range or contact_cd > 0.0:
		return
	if target.has_method("receive_damage"):
		var can_debuff: bool = target.invulnerable <= 0.0
		target.receive_damage(contact_damage, _has_ability("corruption"), _contact_boss_flag())
		if can_debuff and _has_ability("debuff") and not target.team_defeated:
			target.apply_debuff(2.0, 0.20)
		if can_debuff and _has_ability("silence") and target is HarmonyPlayer:
			target.ability_cd = maxf(target.ability_cd, CombatConstants.SILENCE_ABILITY_LOCK)
			VISUALS.float_text(get_parent(), target.global_position + Vector2(0, -40), "SILENCE", Color("4cc9f0"))
	art.action("ability" if is_boss else "attack", 0.4)
	contact_cd = attack_cooldown

# Recibe daño; si la vida llega a 0 emite `defeated` y se elimina. Los élites
# con "enrage" entran en furia por debajo del 50%.
func take_damage(amount: float, _member_index: int = -1) -> void:
	if dying or amount <= 0.0:
		return
	hp -= amount
	hit_flash = 0.16
	queue_redraw()
	if is_inside_tree() and amount >= 1.0:
		var tint := Color("ffd166") if is_boss or (data != null and data.is_elite) else Color("f8f8ff")
		VISUALS.float_text(get_parent(), global_position + Vector2(0, -40), "-%d" % int(round(amount)), tint)
		FEEL.hit_enemy(get_parent(), global_position, amount, amount >= 18.0 or is_boss)
	_maybe_enrage()
	if hp <= 0.0:
		dying = true
		if is_inside_tree():
			FEEL.kill_pop(get_parent(), global_position)
			if _has_ability("split"):
				_spawn_splitling()
			var row := 0
			if data != null:
				row = {"chaser": 0, "ranged": 1, "tank": 3, "swarm": 4}.get(data.archetype, 2)
			var ghost := VISUALS.sprite(get_parent(), VISUALS.cell(VISUALS.OVERVIEW, 3, row, 4, 6), 65.0, position + Vector2(0, -22))
			var fade := ghost.create_tween()
			fade.tween_property(ghost, "modulate:a", 0.0, 0.3)
			fade.tween_callback(ghost.queue_free)
		defeated.emit(self)
		queue_free()

func _spawn_splitling() -> void:
	if data == null or not is_inside_tree():
		return
	var child := HarmonyEnemy.new()
	var soft := data.duplicate(true)
	soft.max_hp = maxf(12.0, data.max_hp * CombatConstants.SPLIT_HP_FRAC)
	soft.damage = maxf(4.0, data.damage * 0.55)
	soft.is_elite = false
	soft.abilities = []
	soft.difficulty_cost = 1
	soft.display_name = str(data.display_name) + " Echo"
	child.setup_data(target, soft, 1.0, 1.0)
	child.global_position = global_position + Vector2(28, -12)
	child.add_to_group("enemies")
	get_parent().add_child(child)
	var host := get_tree().current_scene
	if host != null and host.has_method("_on_enemy_defeated"):
		child.defeated.connect(host._on_enemy_defeated)
		if "room_budget" in host:
			host.room_budget = int(host.room_budget) + 1
	VISUALS.float_text(get_parent(), child.global_position, "SPLIT", Color("c77dff"))

# Verifica umbrales de fase del jefe: emite la señal y activa la furia si el
# jefe posee "enrage". La sala del jefe NO invoca refuerzos en ningún cambio.
func _check_boss_phase() -> void:
	if boss_data == null or hp <= 0.0:
		return
	var frac: float = hp / max_hp
	var phase := boss_data.phase_for(frac)
	if phase == current_phase:
		_maybe_enrage()
		return
	current_phase = phase
	boss_phase_changed.emit(current_phase)
	if boss_data != null:
		VISUALS.boss_ability_burst(self, boss_data.id, mini(7, current_phase + 3), 150.0)
	_maybe_enrage()

# Activa la furia (solo una vez): +50% daño y +30% velocidad bajo el 50% de vida.
func _maybe_enrage() -> void:
	if enraged or not _has_ability("enrage") or hp <= 0.0:
		return
	if hp <= max_hp * 0.5:
		enraged = true
		contact_damage *= 1.5
		move_speed *= 1.3

func _has_ability(ability: String) -> bool:
	if data != null:
		return data.abilities.has(ability)
	if boss_data != null:
		return boss_data.abilities.has(ability)
	# Legado: la variante 3 (Eclipse prototipo) marcaba corrupción y jefe.
	return art_index == 3 and ability in ["corruption", "enrage"]

# Indica si este contacto debe tratarse como "jefe" ante el jugador
# (afecta a cómo el sistema de ítems absorbe el daño).
func _contact_boss_flag() -> bool:
	if boss_data != null:
		return true
	if data != null:
		return is_boss
	return art_index == 3

# Aplica un freno: mantiene el factor más intenso y el mayor tiempo.
func apply_slow(duration: float, factor: float = 0.45) -> void:
	slow_factor = minf(slow_factor, factor) if slow_timer > 0.0 else factor
	slow_timer = max(slow_timer, duration)

# Color identificativo de cada arquetipo (para las variantes del pool).
static func _archetype_color(archetype: String) -> Color:
	match archetype:
		"ranged": return Color("5465ff")
		"tank": return Color("ff477e")
		"swarm": return Color("c77dff")
		"chaser": return Color("9d4edd")
		_: return Color("dfb45e")

# Dibujo procedimental: aros de estado (quemadura/eclipse), sombra, halo
# de color y barra de vida superior (más alta para jefes).
func _draw() -> void:
	if burn_time > 0.0:
		draw_arc(Vector2.ZERO, 26, 0, TAU, 24, Color.ORANGE_RED, 2.0)
	if eclipse_time > 0.0:
		draw_arc(Vector2.ZERO, 29, 0, TAU, 24, Color.MEDIUM_PURPLE, 2.0)
	var c := Color.WHITE if hit_flash > 0.0 else (Color.WHITE if enraged else enemy_color)
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2.ZERO, 22.0, Color(c, 0.22), false, 3.0)
	var is_large := is_boss or art_index == 3
	var hp_ratio: float = clamp(hp / max_hp, 0.0, 1.0)
	var bar_width := 52.0 if is_boss else 40.0
	draw_rect(Rect2(-bar_width * 0.5, -85 if is_large else -66, bar_width, 5), Color("2a2433"))
	draw_rect(Rect2(-bar_width * 0.5, -85 if is_large else -66, bar_width * hp_ratio, 5), Color("f1fa8c"))
	if enraged:
		draw_arc(Vector2.ZERO, 25.0, 0.0, TAU, 24, Color("ff5964"), 2.0)
	if data != null and data.is_elite:
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 28, Color("ffd166", 0.85), 2.5)
	if _has_ability("dash") and dash_cd <= 0.4:
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 16, Color("4cc9f0", 0.7), 1.5)
	if telegraph_time > 0.0:
		var pulse := 1.0 - clampf(telegraph_time / 0.8, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 18.0 + pulse * 16.0, 0.0, TAU, 28, Color("ffd166", 0.55 + pulse * 0.4), 3.0)
		if telegraph_kind in ["dash", "pull"] and is_instance_valid(target):
			var tip := (target.global_position - global_position).limit_length(70.0)
			draw_line(Vector2.ZERO, tip, Color("ff5964", 0.65), 2.0)
		if telegraph_kind == "beam":
			var end := beam_dir * CombatConstants.BEAM_LENGTH
			draw_line(Vector2.ZERO, end, Color("ff5964", 0.35 + pulse * 0.4), CombatConstants.BEAM_WIDTH * 0.35)
			draw_circle(end, 10.0, Color("ffd166", 0.5))
