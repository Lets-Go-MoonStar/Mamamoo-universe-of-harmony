# ---------------------------------------------------------------------------
# systems/enemy_data.gd — Recurso data-driven de un enemigo (sección 7 de la
# especificación). Una variante = un .tres que comparte IA (archetype) con
# sus hermanas y modifica estadísticas, coste, sprite y rangos de piso.
# Los pools y encuentros se construyen únicamente leyendo estos datos.
# ---------------------------------------------------------------------------
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: String = "chaser"
@export var max_hp: float = 55.0
@export var damage: float = 9.0
@export var speed: float = 95.0
@export var defense: float = 0.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.85
@export var difficulty_cost: int = 1
@export var abilities: Array[String] = []
@export var resistances: Dictionary = {}
@export var weaknesses: Dictionary = {}
@export var sprite_index: int = 0
@export var min_floor: int = 1
@export var max_floor: int = 13
@export var is_elite: bool = false


func get_display_name() -> String:
	return display_name if display_name != "" else id