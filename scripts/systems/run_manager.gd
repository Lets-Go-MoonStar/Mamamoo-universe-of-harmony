# ---------------------------------------------------------------------------
# systems/run_manager.gd — Estado y flujo de una run (sección 20-21 y 24).
#   - run_seed reproducible (la misma seed genera el mismo mapa y encuentros),
#   - piso actual, grafo de salas, conteo de progreso,
#   - pools de enemigos y selección de jefe válida para el piso,
#   - señales estandarizadas (room_completed, boss_defeated, floor_completed,
#     run_completed) para desacoplar a los demás sistemas del MC central.
# ---------------------------------------------------------------------------
class_name RunManager
extends Node

signal room_completed(room: RoomData)
signal boss_defeated(boss: BossData)
signal floor_completed(floor_number: int)
signal run_completed

var run_seed := 0
var rng := RandomNumberGenerator.new()
var current_floor := 1
var current_room_id := 0
var rooms_completed := 0
var bosses_defeated: Array[String] = []
var floor_map: Array[RoomData] = []
# Oleadas del encuentro de la sala actual (calculadas una sola vez al entrar).
var battle_waves: Array = []
var active_wave := 0
var _floor_config: FloorConfig
var _current_boss: BossData

func new_run(seed_value := 0) -> void:
	run_seed = seed_value if seed_value != 0 else randi()
	rng.seed = run_seed
	bosses_defeated.clear()
	rooms_completed = 0
	current_floor = 1
	goto_floor(1)

func goto_floor(floor_number: int) -> void:
	current_floor = floor_number
	_floor_config = load_floor_config(floor_number)
	floor_map = FloorGenerator.generate(_floor_config, rng)
	current_room_id = 0
	battle_waves = []
	active_wave = 0

func floor_config() -> FloorConfig:
	return _floor_config

# Carga el recurso del piso; si no existe, genera una config por defecto que
# respeta los rangos de la especificación (sección 2) y el escalado (sección 9).
func load_floor_config(floor_number: int) -> FloorConfig:
	var path := "res://resources/floor_configs/floor_%d.tres" % floor_number
	if ResourceLoader.exists(path):
		return load(path)
	return FloorConfig.make_default(floor_number)

func room(id: int) -> RoomData:
	if id >= 0 and id < floor_map.size():
		return floor_map[id]
	return null

func current_room() -> RoomData:
	return room(current_room_id)

# Salas a las que se puede avanzar desde la sala actual (rutas alternativas).
func next_options() -> Array[RoomData]:
	var current := current_room()
	var options: Array[RoomData] = []
	if current == null:
		return options
	for id in current.connections:
		var candidate := room(id)
		if candidate != null and not candidate.completed:
			options.append(candidate)
	return options

# Marca la sala actual como completada. Para BOSS dispara la señal y el
# siguiente piso (o el final de la run en el piso 13).
func complete_current() -> void:
	var current := current_room()
	if current == null or current.completed:
		return
	current.completed = true
	rooms_completed += 1
	room_completed.emit(current)
	if current.room_type == "BOSS":
		var boss := _current_boss
		if boss != null:
			bosses_defeated.append(boss.id)
			boss_defeated.emit(boss)
		floor_completed.emit(current_floor)
		if current_floor >= 13:
			run_completed.emit()
		else:
			goto_floor(current_floor + 1)

# Entra en la sala indicada (solo si es una opción válida de la actual).
func enter_room(room_id: int) -> RoomData:
	var target := room(room_id)
	var current := current_room()
	if target == null or current == null or not current.connections.has(room_id):
		return null
	current_room_id = room_id
	target.visited = true
	return target

# Prepara el encuentro de la sala actual (una vez por sala). Devuelve oleadas.
func prepare_encounter(tier: String = "medium") -> Array:
	if current_room() == null:
		return []
	battle_waves = EncounterDirector.build_encounter(load_enemy_pool(), current_room().enemy_budget, rng, current_floor, tier)
	active_wave = 0
	return battle_waves

func next_wave() -> Array:
	if active_wave < battle_waves.size():
		var wave: Array = battle_waves[active_wave]
		active_wave += 1
		return wave
	return []

# Toda la pool de enemigos del piso (rutas del FloorConfig), como EnemyData.
func load_enemy_pool() -> Array:
	if _floor_config == null:
		return []
	var pool: Array = []
	for path in _floor_config.enemy_pool:
		if ResourceLoader.exists(path):
			pool.append(load(path))
	return pool

# Elige el jefe del piso: válido para el tramo y no repetido en la run.
func pick_boss() -> BossData:
	var candidates: Array[BossData] = []
	for path in _floor_config.boss_pool:
		if not ResourceLoader.exists(path):
			continue
		var data: BossData = load(path)
		if data.min_floor <= current_floor and data.max_floor >= current_floor \
			and not bosses_defeated.has(data.id):
			candidates.append(data)
	# Fallback: si se repiten todos, se permite repetir (necesario por finito).
	if candidates.is_empty():
		for path in _floor_config.boss_pool:
			if ResourceLoader.exists(path):
				candidates.append(load(path))
	if candidates.is_empty():
		return null
	_current_boss = candidates[rng.randi_range(0, candidates.size() - 1)]
	return _current_boss

# Tamaño de sala por número de conexiones (para el tope de enemigos activos).
func tier_for(room: RoomData = null) -> String:
	room = current_room() if room == null else room
	if room == null:
		return "medium"
	var degree := room.connections.size()
	if room.enemy_budget >= 10:
		return "large"
	return "medium" if room.enemy_budget >= 6 else "small"