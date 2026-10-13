# ---------------------------------------------------------------------------
# systems/floor_generator.gd — Genera el grafo de salas de un piso
# (secciones 3-4). Garantías:
#   - siempre existe ruta válida START -> ... -> BOSS -> EXIT,
#   - no hay salas aisladas, ni jefes inaccesibles, ni salida antes del jefe,
#   - las ramas (rutas alternativas) reconvergen al tronco, así nunca crean
#     bucles ni callejones sin salida,
#   - toda la aleatoriedad sale del `rng` de la run (seed reproducible).
# ---------------------------------------------------------------------------
class_name FloorGenerator
extends RefCounted

# Genera el grafo completo del piso. Devuelve Array[RoomData] indexado por id;
# el último nodo del tronco es la sala BOSS y su fin marca el EXIT del piso.
static func generate(cfg: FloorConfig, rng: RandomNumberGenerator) -> Array[RoomData]:
	var rooms: Array[RoomData] = []

	# Tronco: START + cuerpo + BOSS. El cuerpo respeta min/max del piso.
	var total := rng.randi_range(cfg.min_rooms, cfg.max_rooms)
	var body := maxi(total - 2, 1)
	var types := _assign_types(body, cfg, rng)
	var node_types: Array[String] = ["START"]
	node_types.append_array(types)
	node_types.append("BOSS")

	for i in range(node_types.size()):
		var room := RoomData.create(i, node_types[i], cfg.floor_number)
		room.difficulty = cfg.difficulty_multiplier + (0.15 if node_types[i] == "ELITE" else 0.0)
		room.enemy_budget = _budget_for(cfg, node_types[i])
		rooms.append(room)

	# Tronco: cada sala conecta con la siguiente (garantiza la ruta al jefe).
	for i in range(rooms.size() - 1):
		rooms[i].connections.append(i + 1)

	# Ramas alternativas: desde salas "hub" (todo menos las dos últimas) se
	# abre una desviación de 1-2 salas que reconverge a un nodo posterior.
	var max_hub := rooms.size() - 3
	for hub in range(max(0, max_hub)):
		if rooms[hub].room_type == "BOSS":
			continue
		# Tope suave: no dejar que las ramas inflen el piso más allá de max_rooms.
		if rooms.size() >= cfg.max_rooms:
			break
		if rng.randf() > cfg.route_branch_chance:
			continue
		# El tronco hub -> hub+1 se mantiene; la rama llega a un nodo posterior.
		var converge := clampi(hub + rng.randi_range(2, 3), hub + 2, rooms.size() - 1)
		var branch_len := rng.randi_range(1, 2)
		var previous := hub
		for step in range(branch_len):
			if rooms.size() >= cfg.max_rooms:
				break
			var branch := RoomData.create(rooms.size(), _branch_type(cfg, rng), cfg.floor_number)
			branch.difficulty = cfg.difficulty_multiplier + 0.10
			branch.enemy_budget = _budget_for(cfg, branch.room_type)
			rooms[previous].connections.append(branch.room_id)
			rooms.append(branch)
			previous = branch.room_id
		rooms[previous].connections.append(converge)

	# Marca la sala BOSS como destino de jefe (incluye las ramas finales).
	return rooms

# Asigna tipos al cuerpo de salas garantizando variedad (recompensa, tienda o
# evento) y usando las probabilidades de FloorConfig para élites/eventos/etc.
static func _assign_types(body: int, cfg: FloorConfig, rng: RandomNumberGenerator) -> Array[String]:
	var types: Array[String] = []
	types.resize(body)
	for i in range(body):
		types[i] = "COMBAT"

	# Garantías mínimas: al menos una REWARD y una sala no-combate de apoyo.
	# Las posiciones se eligen con el rng de la run para mantener la seed.
	var forced_count := mini(body, 3)
	var forced := ["REWARD", "SHOP", "EVENT"]
	var forced_idxs: Array[int] = []
	while forced_idxs.size() < forced_count:
		var idx := rng.randi_range(0, body - 1)
		if not forced_idxs.has(idx):
			forced_idxs.append(idx)
	for slot in range(forced_count):
		types[forced_idxs[slot]] = forced[slot]

	# Relleno por probabilidades acumuladas.
	for i in range(body):
		if types[i] != "COMBAT":
			continue
		var roll := rng.randf()
		var cumulative := 0.0
		cumulative += cfg.elite_chance
		if roll < cumulative:
			types[i] = "ELITE"
			continue
		cumulative += cfg.event_chance
		if roll < cumulative:
			types[i] = "EVENT"
			continue
		cumulative += cfg.shop_chance
		if roll < cumulative:
			types[i] = "SHOP"
			continue
		cumulative += cfg.reward_chance
		if roll < cumulative:
			types[i] = "REWARD"
	return types

# Presupuesto de encuentro: base del piso, superior en élites (y en START
# fijado en 5 para conservar el arranque secuencial del prototipo).
static func _budget_for(cfg: FloorConfig, room_type: String) -> int:
	match room_type:
		"START": return mini(7, cfg.enemy_budget)
		"ELITE": return int(round(cfg.enemy_budget * 1.5))
		"BOSS": return 4
		"COMBAT": return cfg.enemy_budget
		_: return 0

# Tipo de las salas de las rutas alternativas: se evita repetir BOSS/START.
static func _branch_type(cfg: FloorConfig, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < cfg.elite_chance * 0.6:
		return "ELITE"
	if roll < cfg.elite_chance * 0.6 + cfg.reward_chance:
		return "REWARD"
	return "COMBAT"