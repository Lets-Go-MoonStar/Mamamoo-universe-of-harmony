extends SceneTree
# Auditoría de flujos corregidos (P1–P5 / navegación / escalado).
# godot --headless --path . --fixed-fps 60 --script res://tests/logic_audit.gd

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func run() -> void:
	await _check_route_panel_closes()
	_check_elite_weights()
	_check_zero_budget()
	_check_floor_scaling()
	await _check_boss_room_solo_and_clear()
	await _check_floor_13_ends_clean()
	print("LOGIC AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_route_panel_closes() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(2)
	# Completa START y abre rutas como hace el juego.
	scene.run.complete_current()
	scene.awaiting_reward = true
	scene.item_ui.show_routes()
	await frames(2)
	check(scene.item_ui.overlay.visible, "Panel de rutas visible tras completar START")
	check(paused, "Árbol pausado con el panel de rutas")
	var options: Array = scene.run.next_options()
	check(not options.is_empty(), "Hay al menos una ruta disponible")
	if options.is_empty():
		scene.queue_free()
		await frames(1)
		return
	# Forzar COMBAT: salas de servicio reabren panel propio al entrar.
	options[0].room_type = "COMBAT"
	options[0].enemy_budget = 5
	var route_button: Button = null
	for child in scene.item_ui.content.get_children():
		if child is Button and String(child.text).begins_with("Ir a:"):
			route_button = child
			break
	if route_button != null:
		route_button.pressed.emit()
	else:
		scene.awaiting_reward = false
		scene.item_ui.close()
		scene.go_to_room(options[0].room_id)
	await frames(2)
	check(not scene.item_ui.overlay.visible, "Ir a sala cierra el overlay de rutas")
	check(not paused, "Ir a sala reanuda el árbol")
	scene.queue_free()
	await frames(1)

func _check_elite_weights() -> void:
	var combat := RewardManager.weights_for("combat")
	var elite := RewardManager.weights_for("elite")
	check(elite["RARE"] > combat["RARE"] and elite["EPIC"] > combat["EPIC"], "Pesos élite mejoran Rare/Epic frente a combate")
	check(RewardManager.weights_for("boss")["COMMON"] == 0.0, "Pesos de jefe excluyen COMMON")

func _check_zero_budget() -> void:
	var run := RunManager.new()
	run.new_run(42)
	var waves := EncounterDirector.build_encounter(run.load_enemy_pool(), 0, run.rng, 1, "medium")
	check(waves.is_empty(), "Presupuesto 0 no genera enemigos")
	run.queue_free()

func _check_floor_scaling() -> void:
	var run := RunManager.new()
	run.new_run(7)
	run.goto_floor(13)
	var cfg := run.floor_config()
	check(cfg.difficulty_multiplier > 1.5 and cfg.damage_multiplier > 1.4, "Piso 13 escala HP/DMG por encima de 1.4")
	var pool := run.load_enemy_pool()
	check(not pool.is_empty(), "Pool de enemigos disponible en piso 13")
	if not pool.is_empty():
		var sample: EnemyData = pool[0]
		for candidate in pool:
			if not candidate.is_elite:
				sample = candidate
				break
		var enemy := HarmonyEnemy.new()
		enemy.setup_data(null, sample, cfg.difficulty_multiplier, cfg.damage_multiplier)
		var expected := sample.max_hp * cfg.difficulty_multiplier
		check(is_equal_approx(enemy.max_hp, expected), "setup_data aplica multiplicador de dificultad")
		check(is_equal_approx(enemy.contact_damage, sample.damage * cfg.damage_multiplier), "setup_data aplica multiplicador de daño")
		enemy.free()
	run.queue_free()

func _check_boss_room_solo_and_clear() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	# Fuerza sala BOSS del piso actual (sin pasar por enter_room / conexiones).
	var boss_room: RoomData = null
	for room in scene.run.floor_map:
		if room.room_type == "BOSS":
			boss_room = room
			break
	check(boss_room != null, "Existe sala BOSS en el grafo")
	if boss_room == null:
		scene.queue_free()
		await frames(1)
		return
	scene.run.current_room_id = boss_room.room_id
	scene._begin_current_room()
	await frames(4)
	var enemies := get_nodes_in_group("enemies")
	var boss_count := 0
	for enemy in enemies:
		if enemy.is_boss:
			boss_count += 1
	check(enemies.size() == 1 and boss_count == 1, "Sala BOSS contiene únicamente al jefe")
	if enemies.is_empty():
		scene.queue_free()
		await frames(1)
		return
	var boss: HarmonyEnemy = enemies[0]
	boss.take_damage(100000.0, 0)
	await frames(4)
	check(scene.awaiting_floor_start or scene.awaiting_reward, "Derrotar al jefe abre transición / recompensa de jefe")
	scene.queue_free()
	await frames(1)

func _check_floor_13_ends_clean() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.run.goto_floor(13)
	var boss_room: RoomData = null
	for room in scene.run.floor_map:
		if room.room_type == "BOSS":
			boss_room = room
			break
	check(boss_room != null, "Piso 13 tiene sala BOSS")
	if boss_room == null:
		scene.queue_free()
		await frames(1)
		return
	scene.run.current_room_id = boss_room.room_id
	scene._begin_current_room()
	await frames(3)
	var enemies := get_nodes_in_group("enemies")
	check(not enemies.is_empty() and enemies[0].is_boss, "Piso 13 spawnea al jefe")
	if enemies.is_empty():
		scene.queue_free()
		await frames(1)
		return
	enemies[0].take_damage(100000.0, 0)
	await frames(3)
	# Confirma transición post-jefe: no debe re-entrar la sala BOSS completada.
	scene.start_after_boss()
	await frames(3)
	var after := get_nodes_in_group("enemies")
	var respawned_boss := false
	for enemy in after:
		if enemy.is_boss:
			respawned_boss = true
	check(not respawned_boss, "Tras piso 13 no se regenera un segundo jefe")
	scene.queue_free()
	await frames(1)
