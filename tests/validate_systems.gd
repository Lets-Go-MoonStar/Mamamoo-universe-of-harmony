extends SceneTree

func _initialize() -> void:
	print("=== VALIDACION SISTEMAS (seeds x5) ===")
	var pools := [
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
	for path in pools:
		var data: EnemyData = load(path)
		assert(data is EnemyData, "No carga: " + path)
		assert(data.min_floor <= data.max_floor, "Rango invertido: " + path)
	print("Enemigos OK:", pools.size())

	var bosses := [
		"res://resources/boss_pool/overlord.tres",
		"res://resources/boss_pool/critic.tres",
		"res://resources/boss_pool/eclipse.tres",
	]
	for path in bosses:
		var b: BossData = load(path)
		assert(b is BossData, "No carga jefe: " + path)
		assert(b.phase_thresholds().size() >= 2)
	print("Jefes OK:", bosses.size())

	var floors := [1, 2, 3]
	for f in floors:
		var cfg: FloorConfig = FloorConfig.make_default(f)
		if ResourceLoader.exists("res://resources/floor_configs/floor_%d.tres" % f):
			cfg = load("res://resources/floor_configs/floor_%d.tres" % f)
		assert(cfg.floor_number == f)

	for seed in [0, 1, 42, 987654, 20260920]:
		var run := RunManager.new()
		run.new_run(seed)
		for f in range(1, 4):
			run.goto_floor(f)
			assert(run.floor_map.size() >= 2, "Piso sin salas")
			_assert_valid_graph(run)
			var start := run.room(0)
			assert(start.room_type == "START", "primera sala no es START")
			var boss: RoomData = null
			for room in run.floor_map:
				if room.room_type == "BOSS":
					boss = room
					break
			assert(boss != null, "sin sala BOSS")
			assert(boss.connections.is_empty(), "Boss no es terminal en grafo")
			var pool := run.load_enemy_pool()
			assert(not pool.is_empty(), "pool enemiga vacia piso %d" % f)
			assert(run.pick_boss() is BossData, "sin jefe piso %d" % f)
			print("  seed=%d piso=%d salas=%d pool=%d" % [seed, f, run.floor_map.size(), pool.size()])
		run.queue_free()
	print("### VALIDACION OK (5 seeds x 3 pisos) ###")
	quit(0)

func _assert_valid_graph(run: RunManager) -> void:
	# (1) Toda sala alcanzable desde START por el grafo.
	var reachable: Array[bool] = []
	reachable.resize(run.floor_map.size())
	reachable.fill(false)
	var stack := [0]
	reachable[0] = true
	while not stack.is_empty():
		var id: int = stack.pop_back()
		for nxt in run.room(id).connections:
			if not reachable[nxt]:
				reachable[nxt] = true
				stack.append(nxt)
	for i in range(run.floor_map.size()):
		assert(reachable[i], "Sala %d inalcanzable" % i)
	# (2) Alguna sala conecta con la BOSS (la ruta al jefe es siempre accesible).
	var boss_id := -1
	for i in range(run.floor_map.size()):
		if run.room(i).room_type == "BOSS":
			boss_id = i
			break
	var predecessor := false
	for i in range(run.floor_map.size()):
		if i != boss_id and run.room(i).connections.has(boss_id):
			predecessor = true
			break
	assert(predecessor, "Boss sin predecesor")