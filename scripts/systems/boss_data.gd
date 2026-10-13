# ---------------------------------------------------------------------------
# systems/boss_data.gd — Recurso data-driven de un jefe (secciones 10-12).
# Cada jefe vive en un .tres; las fases son umbrales de vida calculados con
# `phase_count` (2-3) sobre los estándar 100-70-35%. Los "abilities" son
# tags interpretados por el controlador del jefe (ranged | enrage).
# ---------------------------------------------------------------------------
class_name BossData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hp: float = 300.0
@export var damage: float = 16.0
@export var speed: float = 60.0
@export var phase_count: int = 2
@export var abilities: Array[String] = []
@export var arena_index: int = 0
@export var difficulty: int = 1
@export var min_floor: int = 1
@export var max_floor: int = 13
@export var sprite_index: int = 3
@export var exclusive_rewards: Array[String] = []

# Umbrales de vida (fracción) para cada fase: [1.0, 0.7, 0.35].
func phase_thresholds() -> Array[float]:
	match phase_count:
		2: return [1.0, 0.5]
		3: return [1.0, 0.7, 0.35]
		_: return [1.0, 0.7, 0.35, 0.15]

# Fase activa (1-based) según la fracción de vida restante.
func phase_for(health_fraction: float) -> int:
	var thresholds := phase_thresholds()
	for index in range(thresholds.size() - 1, 0, -1):
		if health_fraction <= thresholds[index]:
			return index + 1
	return 1


func get_display_name() -> String:
	return display_name if display_name != "" else id