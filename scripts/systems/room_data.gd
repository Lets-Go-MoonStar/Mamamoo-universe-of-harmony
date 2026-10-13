# ---------------------------------------------------------------------------
# systems/room_data.gd — Representa un nodo del grafo de un piso (sección 3).
# Guarda tipo, conexiones, dificultad, presupuesto de enemigos, recompensa y
# estado de visita/completado. Lo crea FloorGenerator a partir de FloorConfig.
# ---------------------------------------------------------------------------
class_name RoomData
extends Resource

@export var room_id: int = 0
@export var room_type: String = "COMBAT"
@export var connections: Array[int] = []
@export var difficulty: float = 1.0
@export var enemy_budget: int = 5
@export var enemies: Array[String] = []
@export var reward_kind: String = "combat"
@export var completed: bool = false
@export var visited: bool = false
@export var floor: int = 1

# Creamos nodos de sala con esta factoría para mantener el grafo consistente.
static func create(id: int, room_type: String, floor: int) -> RoomData:
	var room := RoomData.new()
	room.room_id = id
	room.room_type = room_type
	room.floor = floor
	room.reward_kind = _reward_kind_for(room_type)
	return room

func is_combat() -> bool:
	return room_type in ["START", "COMBAT", "ELITE", "BOSS"]

static func _reward_kind_for(room_type: String) -> String:
	match room_type:
		"BOSS": return "boss"
		"ELITE": return "elite"
		"REWARD": return "reward"
		_: return "combat"

# Etiqueta legible para el mapa/ruta.
func type_label() -> String:
	match room_type:
		"START": return "Inicio"
		"BOSS": return "JEFE"
		"ELITE": return "Élite"
		"EVENT": return "Evento"
		"SHOP": return "Tienda"
		"REWARD": return "Recompensa"
		"REST": return "Descanso"
		_ : return "Combate"