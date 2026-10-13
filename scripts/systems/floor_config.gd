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
static func make_default(floor_number: int) -> FloorConfig:
	var cfg := FloorConfig.new()
	cfg.floor_number = floor_number
	match floor_number:
		1, 2:
			cfg.min_rooms = 7
			cfg.max_rooms = 10
		3, 4, 5, 6, 7:
			cfg.min_rooms = 10
			cfg.max_rooms = 15
		_:
			cfg.min_rooms = 20
			cfg.max_rooms = 25
	cfg.difficulty_multiplier = 1.0 + (floor_number - 1) * 0.08
	cfg.damage_multiplier = 1.0 + (floor_number - 1) * 0.06
	cfg.biome_index = (floor_number - 1) % 9
	cfg.route_branch_chance = 0.55
	# Pool completo disponible para pisos sin archivo propio (4-13): el
	# director de encuentros filtra por rango de piso de cada variante.
	cfg.enemy_pool = [
		"res://resources/enemy_pool/echo.tres",
		"res://resources/enemy_pool/echo_swift.tres",
		"res://resources/enemy_pool/echo_armored.tres",
		"res://resources/enemy_pool/echo_corrupted.tres",
		"res://resources/enemy_pool/echo_elite.tres",
		"res://resources/enemy_pool/feedback.tres",
		"res://resources/enemy_pool/feedback_elite.tres",
		"res://resources/enemy_pool/mute.tres",
		"res://resources/enemy_pool/mute_elite.tres",
		"res://resources/enemy_pool/tuner.tres",
	]
	cfg.boss_pool = ["res://resources/boss_pool/eclipse.tres"]
	return cfg