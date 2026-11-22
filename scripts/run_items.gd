# ---------------------------------------------------------------------------
# run_items.gd — Sistema de ítems de la PARTIDA (Node hijo del jugador).
# Aquí están TODOS los efectos de los 32 objetos del catálogo:
#   - inventario (owned) y recursos (monedas, llaves, tickets, xp, nivel),
#   - multiplicadores de velocidad/daño/Armonía y cooldown de habilidad,
#   - escudos por integrante, curación y resurrección,
#   - temporizadores de efectos activos (adlib, field, duo, trio, stilla...),
#   - reacciones elementales, cadena de cuarteto, Encore y reliquias.
# ---------------------------------------------------------------------------
extends Node

const VISUALS = preload("res://scripts/visual_assets.gd")

signal changed
signal reward_requested(kind: String)
const CATALOG = preload("res://scripts/item_catalog.gd")
var player
# Cantidad poseída de cada ítem (clave = id del catálogo).
var owned: Dictionary = {}
var coins := 0
var keys := 0
var tickets := 0
var xp := 0.0
var level := 1
var energy := 100.0
# Escudos (cantidad y tiempo restante) por integrante, mismas 4 entradas.
var shields: Array[float] = [0.0, 0.0, 0.0, 0.0]
var shield_times: Array[float] = [0.0, 0.0, 0.0, 0.0]
# Temporizadores genéricos de efectos activos (clave = nombre del efecto).
var timers: Dictionary = {}
# Pareja elegida para el vínculo de dúo y niveles de pergamino por integrante.
var duo: Array[int] = [0, 1]
var skill_ranks: Array[int] = [0, 0, 0, 0]
# Historial de cambios de integrante (para el trío/emblema y la órbita).
var switch_history: Dictionary = {}
var switch_count := 0
var elapsed := 0.0
var adlib_extension := 0.0
var revival_used := false
# Stage Guardian Veil: una salvación por integrante (índice -> ya usada).
var guardian_saved: Array[bool] = [false, false, false, false]
var field_center := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# Cantidad poseída de un ítem por su id.
func count(id: String) -> int:
	return int(owned.get(id, 0))

# true mientras un efecto con temporizador está vigente.
func active(id: String) -> bool:
	return float(timers.get(id, 0.0)) > 0.0

# ¿Se puede adquirir un ítem? Respeta el límite de acumulación del catálogo
# y que la pluma de resurrección sea de un solo uso por partida.
func can_acquire(id: String) -> bool:
	var item := CATALOG.entry(id)
	if item.is_empty() or (id == "revival_feather" and revival_used):
		return false
	return count(id) < int(item.max_stacks)

# Adquiere un ítem y aplica su efecto inmediato (curaciones, reliquias,
# consumibles como pociones/cofres/pluma, pergamino y vínculo de dúo).
func acquire(id: String, selected: int = -1, second: int = -1) -> bool:
	if not can_acquire(id):
		return false
	if id == "duo_bond_charm" and (selected < 0 or second < 0 or selected == second or selected > 3 or second > 3):
		return false
	if id == "skill_scroll" and (selected < 0 or selected > 3):
		return false
	owned[id] = count(id) + 1
	match id:
		"star_coin": coins += 1
		"golden_key": keys += 1
		"starlight_ticket": tickets += 1
		"heart_recovery_potion":
			heal_team(0.25)
			owned.erase(id)
		"voice_amplifier_crystal": player.voice_max = 115.0
		"skill_scroll": skill_ranks[selected] += 1
		"duo_bond_charm": duo.assign([selected, second])
		"treasure_chest":
			owned.erase(id)
			reward_requested.emit("chest")
		"legendary_celestial_chest":
			heal_team(0.20)
			owned.erase(id)
			reward_requested.emit("legendary")
	player.chain_window = 2.6 + 0.5 * count("harmony_crystal_shard")
	changed.emit()
	player._emit_stats()
	return true

# Cura a una integrante viva; el crisol amplificador aumenta la cura recibida.
func heal_member(index: int, amount: float) -> void:
	if player.member_voice[index] > 0.0:
		if index == player.active_index and player.member_voice[index] < player.voice_max and amount > 0:
			VISUALS.burst(player, VISUALS.STATUS, 0, 6, 85.0, Vector2(0, -20))
		player.member_voice[index] = minf(player.voice_max, player.member_voice[index] + amount * (1.0 + 0.10 * count("voice_amplifier_crystal")))

# Cura a las integrantes vivas con una fracción de la Voz máxima (no revive).
func heal_team(fraction: float) -> void:
	for index in range(4):
		heal_member(index, fraction * player.voice_max)

# Otorga un escudo por integrante (mayor reemplaza al menor); el talismán de
# Solar añade 1 s de duración.
func add_shield(index: int, fraction: float, duration: float = 6.0) -> void:
	if player.member_voice[index] <= 0.0:
		return
	if index == player.active_index:
		VISUALS.burst(player, VISUALS.STATUS, 1, 6, 90.0, Vector2(0, -20))
	shields[index] = maxf(shields[index], fraction * player.voice_max)
	shield_times[index] = maxf(shield_times[index], duration + (1.0 if index == 0 and count("void_protection_talisman") > 0 else 0.0))

# Cantidad de daño que realmente atraviesa el escudo (tras resistencias de
# corrupción y contra jefe); el escudo bloquea hasta agotarse.
func absorb(amount: float, corruption: bool = false, boss: bool = false) -> float:
	if corruption and count("void_protection_talisman") > 0:
		amount *= 0.85
	if boss and count("boss_seal_fragment") >= 3:
		amount *= 0.9
	var i: int = player.active_index
	var blocked := minf(shields[i], amount)
	shields[i] -= blocked
	return maxf(0.0, amount - blocked)

# Tras recibir daño, la reliquia defensiva otorga un escudo con su cooldown.
func after_damage() -> void:
	if count("shield_relic") > 0 and not active("shield_cd"):
		add_shield(player.active_index, 0.12)
		timers.shield_cd = 12.0

# Stage Guardian Veil: salva a una integrante la primera vez que caería.
# Devuelve true si absorbió la caída (deja 15% Voz + invulnerabilidad).
func try_guardian_save(index: int) -> bool:
	if count("stage_guardian_veil") == 0 or index < 0 or index > 3:
		return false
	if guardian_saved[index]:
		return false
	guardian_saved[index] = true
	player.member_voice[index] = player.voice_max * 0.15
	player.invulnerable = 1.5
	VISUALS.burst(player, VISUALS.STATUS, 1, 6, 95.0, Vector2(0, -24))
	changed.emit()
	return true

# Pluma de resurrección: revive a las cuatro con 30% de Voz y 1 s de
# protección; se consume y utiliza una sola vez por partida.
func revive() -> bool:
	if count("revival_feather") == 0 or revival_used:
		return false
	revival_used = true
	owned.erase("revival_feather")
	for i in range(4):
		player.member_voice[i] = player.voice_max * 0.3
	player.invulnerable = 1.0
	changed.emit()
	return true

# Avance temporal por fotograma: temporizadores, escudos, regeneración de
# energía (batería/trio) y el campo de Solar (escudo único por integrante
# mientras permanezca dentro del radio).
func tick(delta: float) -> void:
	elapsed += delta
	for key in timers.keys():
		timers[key] = maxf(0.0, float(timers[key]) - delta)
	for i in range(4):
		shield_times[i] = maxf(0.0, shield_times[i] - delta)
		if shield_times[i] <= 0.0:
			shields[i] = 0.0
	var regen := 1.0 + 0.20 * count("energy_battery") + (0.10 if active("trio") else 0.0)
	energy = minf(100.0, energy + delta * 20.0 * regen)
	if active("field") and player.global_position.distance_to(field_center) <= 130.0:
		# One shield per member per field; consumed shields do not regenerate every frame.
		var key := "field_given_%d" % player.active_index
		if not active(key):
			add_shield(player.active_index, 0.06, float(timers.field))
			timers[key] = float(timers.field)

# Multiplicador de velocidad: plumas, medallón con trío, trío y núcleo
# durante Ad-lib; tope combinado de +35%.
func speed_multiplier() -> float:
	var bonus := 0.10 * count("speed_feather_charm")
	bonus += 0.06 if player.chain_level >= 3 and count("crown_badge") > 0 else 0.0
	bonus += 0.10 if active("trio") else 0.0
	bonus += 0.15 if active("adlib") and count("ad_lib_spark_core") > 0 else 0.0
	return 1.0 + minf(0.35, bonus)

# Multiplicador de generación de Armonía: fragmentos, medallón, trío y
# Encore; tope combinado de +60%.
func harmony_multiplier() -> float:
	var bonus := 0.08 * count("harmony_crystal_shard")
	bonus += 0.06 if player.chain_level >= 3 and count("crown_badge") > 0 else 0.0
	bonus += 0.10 if active("trio") else 0.0
	bonus += 0.25 if active("encore") else 0.0
	return 1.0 + minf(0.60, bonus)

# Cooldown de habilidad: gemas reducen (-8% cada una, tope 40%) y Encore -20%.
func ability_cooldown() -> float:
	return 4.5 * (1.0 - minf(0.40, 0.08 * count("music_note_gem") + (0.20 if active("encore") else 0.0)))

# Multiplicador de daño: medallón por cadena, potenciador de cadena según el
# nivel, dúo, Encore, núcleo durante Ad-lib y campo de Solar (tope +100%).
func damage_multiplier(member: int) -> float:
	var bonus := 0.06 if player.chain_level >= 3 and count("crown_badge") > 0 else 0.0
	if count("harmony_chain_enhancer") > 0:
		bonus += [0.0, 0.04, 0.08, 0.12, 0.20][clampi(player.chain_level, 0, 4)]
	bonus += 0.15 if active("duo") else 0.0
	bonus += 0.20 if active("encore") else 0.0
	bonus += 0.12 if active("adlib") and count("ad_lib_spark_core") > 0 else 0.0
	bonus += 0.12 if active("field") and player.global_position.distance_to(field_center) <= 130.0 else 0.0
	return 1.0 + minf(1.0, bonus)

# Al cambiar de integrante: órbita cósmica rara (daño de área cada 4 cambios),
# activación del dúo, trío (emblema), y estallido de la marca de Moonbyul
# cuando la nueva integrante golpea a un enemigo con eclipse.
func on_switch(previous: int, current: int) -> void:
	if not switch_history.has(previous): switch_history[previous] = elapsed
	switch_count += 1
	if count("curtain_call_brooch") > 0 and active("adlib"):
		player.harmony = minf(100.0, player.harmony + 6.0)
	if count("rare_cosmic_orb") > 0 and switch_count % 4 == 0:
		area_damage(player.global_position, 160.0, 20.0)
		player.harmony = minf(100.0, player.harmony + 8.0)
	if count("duo_bond_charm") > 0 and duo.has(previous) and duo.has(current) and not active("duo_cd"):
		timers.duo = 4.0
		timers.duo_cd = 6.0
	switch_history[current] = elapsed
	var recent := 0
	for time in switch_history.values():
		if elapsed - float(time) <= 5.0:
			recent += 1
	if count("trio_emblem") > 0 and recent >= 3:
		timers.trio = 6.0
	if count("moonbyul_lunar_dagger_sigil") > 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.eclipse_time > 0.0 and not enemy.dying:
				enemy.eclipse_time = 0.0
				var amount: float = float(player.members[current].damage) * 1.2
				if current == 3 and enemy.hp / enemy.max_hp < 0.35:
					amount *= 1.10
				enemy.take_damage(amount, current)
				if current == 0:
					add_shield(0, 0.05)
				elif current == 2:
					area_damage(enemy.global_position, 90.0, 8.0, enemy)

# Al alcanzar Cuarteto en la cadena: onda del potenciador y efectos de la
# corona del cuarteto (Encore, escudos para Solar y freno masivo de Moonbyul).
func on_quartet() -> void:
	if count("harmony_chain_enhancer") > 0:
		area_damage(player.global_position, 170.0, 10.0)
	if count("quartet_crown") > 0:
		timers.encore = 5.0
		if player.member_voice[0] > 0.0:
			for i in range(4): add_shield(i, 0.08, 5.0)
		if player.member_voice[1] > 0.0:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if player.global_position.distance_to(enemy.global_position) < 210.0:
					enemy.apply_slow(5.0, 0.75)

# Ad-lib con Q: consume la Armonía (100) y abre la ventana de 5 s.
func start_adlib() -> void:
	if player.harmony < 100.0 or active("adlib"):
		return
	player.harmony = 0.0
	timers.adlib = 5.0
	adlib_extension = 0.0
	if count("curtain_call_brooch") > 0:
		energy = minf(100.0, energy + 25.0)
		changed.emit()
		player._emit_stats()

# Reacciones de ítems al lanzar una habilidad: el campo de Solar (reliquia)
# y la superarmadura del talismán de Hwasa.
func on_ability(member: int) -> void:
	if member == 0 and count("solar_sun_relic") > 0 and not active("field_cd"):
		field_center = player.global_position
		timers.field = 4.0
		timers.field_cd = 8.0
		for i in range(4): timers.erase("field_given_%d" % i)
	if member == 3 and count("void_protection_talisman") > 0:
		timers.superarmor = 0.3

# Daño de área: golpea a todo enemigo en un radio (opcionalmente excluyendo
# a uno, usado por la explosión de Hwasa para no golpear al objetivo ya muerto).
func area_damage(origin: Vector2, radius: float, amount: float, excluded: Node = null) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != excluded and not enemy.dying and origin.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(amount, -1)

# Punto de entrada de UN golpe de proyectil al enemigo. Aquí se aplican:
#   - bonos condicionales (frenado, vida baja, contra jefe),
#   - críticos de Hwasa durante Encore,
#   - marca de Eclipse (Moonbyul) y quemadura (Hwasa),
#   - reacciones elementales: golpe de otra integrante sobre enemigo con
#     estado propaga en Wheein (nota) o durante Encore,
#   - explosión al morir con Ardor (rosa de fuego de Hwasa).
# Devuelve el daño final aplicado.
func hit(enemy, amount: float, member: int) -> float:
	if enemy.dying or player.team_defeated:
		return 0.0
	var bonus := 0.0
	if enemy.slow_timer > 0.0: bonus += 0.10 * count("moon_token")
	if enemy.hp / enemy.max_hp < 0.35: bonus += 0.12 * count("flame_emblem")
	if enemy.is_boss: bonus += 0.03 * count("boss_seal_fragment")
	amount *= 1.0 + minf(1.0, bonus)
	# Critical hits are introduced only by Encore's Hwasa bonus (10% chance).
	if member == 3 and active("encore") and rng.randf() < 0.10:
		amount *= 1.65
	if member == 1 and enemy.slow_timer > 0.0 and count("moonbyul_lunar_dagger_sigil") > 0:
		enemy.eclipse_time = 5.0
	if member == 3 and count("hwasa_fire_rose_relic") > 0:
		enemy.burn_time = 4.0
	var reaction: bool = enemy.last_member >= 0 and enemy.last_member != member and (enemy.slow_timer > 0.0 or enemy.burn_time > 0.0)
	enemy.last_member = member
	var propagate := member == 2 and reaction and ((count("wheein_melody_droplet_relic") > 0 and not active("note_cd")) or active("encore"))
	var origin: Vector2 = enemy.global_position
	var burning: bool = enemy.burn_time > 0.0
	enemy.take_damage(amount, member)
	if propagate:
		timers.note_cd = 3.0
		var nearest = null
		var distance := INF
		for other in get_tree().get_nodes_in_group("enemies"):
			if other != enemy and not other.dying and origin.distance_to(other.global_position) < distance:
				nearest = other
				distance = origin.distance_to(other.global_position)
		if nearest != null:
			if burning: nearest.burn_time = maxf(nearest.burn_time, 1.4)
			nearest.take_damage(amount * (0.35 if count("wheein_melody_droplet_relic") > 0 else 0.15), -1)
	if enemy.dying and burning and count("hwasa_fire_rose_relic") > 0:
		area_damage(origin, 110.0, amount * 0.40, enemy)
	return amount

# Al derrotar a un enemigo: moneda, experiencia (más contra Eclipse, con
# bonificación del orbe de EXP) y subidas de nivel que abren otra elección;
# el núcleo de Ad-lib extiende la ventana hasta un máximo de 3 s.
func on_kill(enemy) -> void:
	coins += 1
	owned.star_coin = coins
	xp += (30.0 if enemy.is_boss else 10.0) * (1.0 + 0.15 * count("exp_star_orb"))
	while xp >= 100.0:
		xp -= 100.0
		level += 1
		reward_requested.emit("level")
	if active("adlib") and count("ad_lib_spark_core") > 0 and adlib_extension < 3.0:
		var extension := minf(0.5, 3.0 - adlib_extension)
		timers.adlib += extension
		adlib_extension += extension
	changed.emit()

# Aplica resistencias a un debuff de control: el talismán reduce su fuerza
# (y más en Moonbyul), Wheein acorta la duración y Hwasa con superarmadura
# lo anula. Devuelve la duración/fuerza finales (Vector2).
func debuff(duration: float, strength: float, control: bool = false) -> Vector2:
	if count("void_protection_talisman") > 0:
		strength *= 0.85
		if player.active_index == 1 and control: strength *= 0.85
		if player.active_index == 2: duration *= 0.80
		if player.active_index == 3 and active("superarmor"): return Vector2.ZERO
	return Vector2(duration, strength)
