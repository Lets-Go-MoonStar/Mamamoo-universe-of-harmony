extends SceneTree
# Suites del sistema procedural: grafo de salas, reproducibilidad por seed,
# EncounterBudget con oleadas, rarezas del RewardManager y flujo completo.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, text: String) -> void:
	print(("PASS: " if value else "FAIL: ") + text)
	if not value: failures += 1

func run() -> void:
	run_logic()
	await run_scene()
	await run_boss_scene()
	print("FLOOR RESULT: %d failures" % failures)
	quit(1 if failures else 0)

# --- Lógica pura (sin escena) ----------------------------------------------

func run_logic() -> void:
	# (1) Reproducibilidad: misma seed -> mismo grafo y mismos encuentros.
	for seed in [1, 7, 2026]:
		var a := RunManager.new()
		var b := RunManager.new()
		a.new_run(seed)
		b.new_run(seed)
		for floor in range(1, 5):
			a.goto_floor(floor)
			b.goto_floor(floor)
			var equal := a.floor_map.size() == b.floor_map.size()
			if equal:
				for i in range(a.floor_map.size()):
					if a.room(i).room_type != b.room(i).room_type or a.room(i).connections != b.room(i).connections or a.room(i).enemy_budget != b.room(i).enemy_budget:
						equal = false
						break
			check(equal, "Seed %d piso %d: grafo reproducible" % [seed, floor])
			var wa := a.prepare_encounter("small")
			var wb := b.prepare_encounter("small")
			check(_serialize(wa) == _serialize(wb), "Seed %d piso %d: encuentro reproducible" % [seed, floor])
		a.queue_free()
		b.queue_free()

	# (2) Garantías del grafo en varias seeds: todo alcanzable y jefe con predecesor.
	for seed in [3, 99, 12345]:
		var run := RunManager.new()
		run.new_run(seed)
		for floor in range(1, 4):
			run.goto_floor(floor)
			_assert_graph(run, "Seed %d piso %d" % [seed, floor])
		run.queue_free()

	# (3) EncounterDirector: presupuesto, oleadas y élites al final.
	for seed in [5, 2502]:
		var run := RunManager.new()
		run.new_run(seed)
		for floor in range(1, 4):
			run.goto_floor(floor)
			# START siempre tiene presupuesto (mini(7, budget)), apto para la prueba.
			var budget: int = run.room(0).enemy_budget
			var waves := EncounterDirector.build_encounter(run.load_enemy_pool(), budget, run.rng, floor, "medium")
			check(not waves.is_empty() and _wave_total_cost(waves) <= budget, "Piso %d: presupuesto respetado (%d <= %d)" % [floor, _wave_total_cost(waves), budget])
			var active := EncounterDirector.max_active("medium")
			for wave in waves:
				check(wave.size() <= active, "Piso %d: oleada con %d activos <= %d" % [floor, wave.size(), active])
			if waves.size() > 1:
				var elites_last := true
				for wave_index in range(waves.size() - 1):
					for enemy in waves[wave_index]:
						if enemy.is_elite: elites_last = false
				check(elites_last, "Piso %d: los élites solo salen al final" % floor)
		run.queue_free()

	# (4) RewardManager: pesos válidos y rareza legal por tipo de sala.
	for kind in ["combat", "elite", "reward", "boss"]:
		var weights := RewardManager.weights_for(kind)
		var total := 0.0
		for rarity in RewardManager.RARITIES:
			total += weights[rarity]
		check(total > 0.0 and weights["COMMON"] >= 0.0, "Pesos válidos para sala %s" % kind)
		if kind == "boss":
			check(weights["COMMON"] == 0.0 and not RewardManager.allowed_in("boss", "COMMON"), "El jefe nunca da ítems comunes")
	var roll_rng := RandomNumberGenerator.new()
	roll_rng.seed = 99
	var rarities := {}
	for i in range(200):
		var rarity := RewardManager.roll_rarity("combat", roll_rng)
		rarities[rarity] = rarities.get(rarity, 0) + 1
	print("  rarezas combat (200 tiradas): ", rarities)

# --- Integración con la escena ---------------------------------------------

func run_scene() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.player
	player.set_physics_process(false)
	var start_room: RoomData = scene.run.current_room()
	check(start_room.room_type == "START", "La run arranca en una sala START")
	var frames_passed := 0
	for i in range(3):
		await process_frame
		if scene.item_ui.status.text.contains("Piso 1"):
			frames_passed += 1
	check(frames_passed >= 1, "El HUD muestra el piso actual")
	# Derrotar el presupuesto de la sala abre la recompensa con 3 opciones. Los
# refuerzos llegan escalonados (timer), así que se repite el barrido hasta que
# el panel de recompensa confirma la limpieza de la sala.
	var panel_waits := 0
	while not (scene.awaiting_reward and scene.item_ui.overlay.visible) and panel_waits < 12:
		for enemy in get_nodes_in_group("enemies"):
			if enemy.hp > 0.0:
				enemy.take_damage(10000.0)
		await process_frame
		panel_waits += 1
	check(scene.awaiting_reward and scene.item_ui.overlay.visible, "Sala limpiada -> panel de recompensa abierto")
	check(scene.item_ui.choices.size() == 3, "Tres opciones de recompensa distintas")
	# Elegir una recompensa y navegar pulsando el botón real de rutas (COV-4):
	# el panel debe cerrarse y el árbol reanudarse antes de entrar a la sala.
	# Se fuerza la ruta a COMBAT: las salas de servicio abren su propio panel.
	var option: RoomData = scene.run.next_options()[0] if scene.run.next_options().size() > 0 else null
	check(option != null, "Existe al menos una ruta desde START")
	scene.awaiting_reward = false
	scene.item_ui.overlay.hide()
	scene.item_ui.current_kind = ""
	paused = false
	if option != null:
		option.room_type = "COMBAT"
		option.enemy_budget = 5
		scene.item_ui.show_routes()
		await process_frame
		var route_button: Button = null
		for child in scene.item_ui.content.get_children():
			if child is Button and (child.text as String).begins_with("Ir a:"):
				route_button = child
				break
		check(route_button != null, "El panel de rutas muestra el botón Ir a: <tipo>")
		if route_button != null:
			route_button.pressed.emit()
			await process_frame
			check(scene.run.current_room().room_id == option.room_id, "La ruta elegida pasa a ser la sala actual")
			check(scene.run.current_room().visited, "La sala elegida queda marcada como visitada")
			check(not scene.item_ui.overlay.visible, "Pulsar la ruta cierra el panel de rutas")
			check(not paused, "Pulsar la ruta reanuda el árbol de la escena")
	scene.queue_free()
	await process_frame

# Jefe de piso: la sala BOSS contiene únicamente al jefe (sin invocación de
# refuerzos), con fases por umbral de vida y proyectiles del arquetipo ranged.
func run_boss_scene() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.player
	player.set_physics_process(false)
	scene.run.new_run(4404)
	scene.run.goto_floor(1)
	var boss_id := -1
	for room in scene.run.floor_map:
		if room.room_type == "BOSS":
			boss_id = room.room_id
			break
	check(boss_id >= 0, "El piso 1 contiene una sala BOSS")
	scene.run.current_room_id = boss_id
	scene._begin_current_room()
	await process_frame
	var enemies := get_nodes_in_group("enemies")
	check(enemies.size() == 1 and enemies[0] is HarmonyEnemy and enemies[0].is_boss,
		"La sala BOSS solo contiene al jefe, sin refuerzos")
	if enemies.size() != 1:
		scene.queue_free()
		return
	var boss_node: HarmonyEnemy = enemies[0]
	# Verificación determinista de fases (sin depender del ciclo de física).
	boss_node.take_damage(boss_node.max_hp * 0.4)
	boss_node._check_boss_phase()
	check(boss_node.current_phase == 2, "Al bajar del 70%% el jefe entra en fase 2")
	check(get_nodes_in_group("enemies").size() == 1 and get_nodes_in_group("enemies")[0] == boss_node,
		"El cambio de fase no invoca refuerzos en la sala del jefe")
	boss_node.take_damage(boss_node.max_hp * 0.3)
	boss_node._check_boss_phase()
	check(boss_node.current_phase == 3, "Al bajar del 35%% el jefe entra en fase 3")
	check(get_nodes_in_group("enemies").size() == 1, "El jefe se mantiene en solitario en fase 3")
	# Derrotar al jefe (y solo al jefe) activa la transición de piso.
	boss_node.take_damage(100000.0)
	await process_frame
	check(scene.awaiting_floor_start, "Derrotar al jefe activa la transición de piso")
	check(scene.item_ui.overlay.visible and scene.item_ui.current_kind == "boss",
		"Derrotar al jefe abre el panel de recompensa de jefe")
	scene.queue_free()
	await process_frame

func _serialize(waves: Array) -> Array:
	var out: Array = []
	for wave in waves:
		var ids: Array = []
		for enemy in wave:
			ids.append(enemy.id)
		out.append(ids)
	return out

func _wave_total_cost(waves: Array) -> int:
	var total := 0
	for wave in waves:
		for enemy in wave:
			total += enemy.difficulty_cost
	return total

func _assert_graph(run: RunManager, tag: String) -> void:
	var boss_id := -1
	for id in range(run.floor_map.size()):
		var room := run.room(id)
		if room.room_type == "BOSS":
			boss_id = id
			break
	check(boss_id >= 0, "%s: existe sala BOSS" % tag)
	var reachable: Array[bool] = []
	reachable.resize(run.floor_map.size())
	reachable.fill(false)
	var stack := [0]
	reachable[0] = true
	while not stack.is_empty():
		var id: int = stack.pop_back()
		for next_id in run.room(id).connections:
			if not reachable[next_id]:
				reachable[next_id] = true
				stack.append(next_id)
	var all_reachable := true
	for id in range(run.floor_map.size()):
		if not reachable[id]: all_reachable = false
	check(all_reachable, "%s: todas las salas alcanzables desde START" % tag)
	var has_predecessor := false
	for id in range(run.floor_map.size()):
		if id != boss_id and run.room(id).connections.has(boss_id):
			has_predecessor = true
			break
	check(has_predecessor, "%s: ruta directa de acceso al jefe" % tag)