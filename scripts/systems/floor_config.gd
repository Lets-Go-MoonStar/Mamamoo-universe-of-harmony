# ---------------------------------------------------------------------------
# systems/floor_config.gd — Recurso de configuración de un piso (sección 2).
# Todo número de la generación (habitaciones, presupuesto, probabilidades,
# biomas) es editable aquí, sin tocar el código central.
# ---------------------------------------------------------------------------
class_name FloorConfig
extends Resource

@export var floor_number: int = 1
@export var min_rooms: int = 7
@export var max_rooms: int = 10
@export var difficulty_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var enemy_budget: int = 6
@export var elite_chance: float = 0.18
@export var event_chance: float = 0.18
@export var shop_chance: float = 0.18
@export var reward_chance: float = 0.18
@export var boss_pool: Array[String] = []
@export var enemy_pool: Array[String] = []
@export var biome_index: int = 0
# Probabilidad de abrir una ruta alternativa (rama) en cada sala "hub".
@export var route_branch_chance: float = 0.55

# Piso por defecto para tramos sin archivo: respeta los rangos de la
# especificación (1-2: 7-10, 3-7: 10-15, 8-13: 20-25) y el escalado hp/dmg.
# Los .tres en resources/floor_configs/ tienen prioridad al cargar.
static func make_default(floor_number: int) -> FloorConfig:
	var cfg := FloorConfig.new()
	cfg.floor_number = floor_number
	match floor_number:
		1, 2:
			cfg.min_rooms = 7
			cfg.max_rooms = 10
			cfg.enemy_budget = 5 if floor_number == 1 else 6
			cfg.elite_chance = 0.14 if floor_number == 1 else 0.17
			cfg.event_chance = 0.14
			cfg.shop_chance = 0.15
			cfg.reward_chance = 0.15
			cfg.route_branch_chance = 0.50 if floor_number == 1 else 0.55
		3, 4, 5, 6, 7:
			cfg.min_rooms = 10
			cfg.max_rooms = 15
			cfg.enemy_budget = 7 + int((floor_number - 3) / 2)
			cfg.elite_chance = 0.20 + (floor_number - 3) * 0.015
			cfg.event_chance = 0.16
			cfg.shop_chance = 0.17
			cfg.reward_chance = 0.16
			cfg.route_branch_chance = 0.58
		_:
			# Tramo largo más corto y con más EVENT/REWARD para romper monotonía.
			cfg.min_rooms = 14 + (floor_number - 8)
			cfg.max_rooms = 18 + (floor_number - 8)
			cfg.enemy_budget = 10 + (floor_number - 8)
			cfg.elite_chance = 0.30 + (floor_number - 8) * 0.015
			cfg.event_chance = 0.20
			cfg.shop_chance = 0.16
			cfg.reward_chance = 0.18
			cfg.route_branch_chance = 0.64
	cfg.difficulty_multiplier = 1.0 + (floor_number - 1) * 0.08
	cfg.damage_multiplier = 1.0 + (floor_number - 1) * 0.055
	cfg.biome_index = (floor_number - 1) % 9
	cfg.enemy_pool = enemy_pool_for(floor_number)
	cfg.boss_pool = boss_pool_for(floor_number)
	return cfg

static func enemy_pool_for(floor_number: int) -> Array[String]:
	var early: Array[String] = [
		"res://resources/enemy_pool/echo.tres",
		"res://resources/enemy_pool/echo_swift.tres",
		"res://resources/enemy_pool/feedback.tres",
		"res://resources/enemy_pool/mute.tres",
	]
	var mid: Array[String] = [
		"res://resources/enemy_pool/echo_armored.tres",
		"res://resources/enemy_pool/tuner.tres",
		"res://resources/enemy_pool/echo_corrupted.tres",
		"res://resources/enemy_pool/echo_elite.tres",
	]
	var late: Array[String] = [
		"res://resources/enemy_pool/feedback_elite.tres",
		"res://resources/enemy_pool/mute_elite.tres",
	]
	var extra: Array[String] = [
		"res://resources/enemy_pool/resonance_drone.tres",
		"res://resources/enemy_pool/pulse_swarm.tres",
		"res://resources/enemy_pool/hex_echo.tres",
		"res://resources/enemy_pool/mirror_siren.tres",
		"res://resources/enemy_pool/beat_crusher.tres",
		"res://resources/enemy_pool/tempo_snare.tres",
		"res://resources/enemy_pool/choir_shade.tres",
		"res://resources/enemy_pool/grav_anchor.tres",
		"res://resources/enemy_pool/stage_marshal.tres",
		"res://resources/enemy_pool/lane_diva.tres",
		"res://resources/enemy_pool/rift_caller.tres",
	]
	var pool: Array[String] = early.duplicate()
	if floor_number >= 2:
		pool.append_array(mid.slice(0, 2))
	if floor_number >= 3:
		pool.append_array(mid.slice(2, 4))
	if floor_number >= 4:
		pool.append_array(late)
		pool.append(extra[2])
	if floor_number >= 5:
		pool.append(extra[0])
		pool.append(extra[5])
	if floor_number >= 6:
		pool.append(extra[1])
		pool.append(extra[6])
		pool.append(extra[8])
	if floor_number >= 7:
		pool.append(extra[3])
		pool.append(extra[7])
		pool.append(extra[9])
	if floor_number >= 8:
		pool.append(extra[4])
		pool.append(extra[10])
	return pool

static func boss_pool_for(floor_number: int) -> Array[String]:
	var bosses: Array[String] = []
	if floor_number <= 2:
		bosses.append("res://resources/boss_pool/overlord.tres")
	if floor_number >= 2 and floor_number <= 4:
		bosses.append("res://resources/boss_pool/critic.tres")
	if floor_number >= 3 and floor_number <= 4:
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if floor_number >= 5 and floor_number <= 7:
		bosses.append("res://resources/boss_pool/crystal_warden.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if floor_number >= 8 and floor_number <= 10:
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if floor_number >= 11:
		# Pico final: Void Conductor dominante.
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/void_conductor.tres")
		bosses.append("res://resources/boss_pool/eclipse.tres")
	if bosses.is_empty():
		bosses.append("res://resources/boss_pool/eclipse.tres")
	return bosses