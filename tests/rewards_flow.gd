extends SceneTree
# Flujo de recompensas / rutas / servicios entre salas.
# godot --headless --path . --fixed-fps 60 --script res://tests/rewards_flow.gd

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
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(3)
	var player = scene.player
	var ui = scene.item_ui
	check(player != null and ui != null, "Escena monta jugador e ItemUI")

	# Limpia oleada inicial y fuerza recompensa de combate.
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(2)
	ui.queue_reward("combat")
	await frames(2)
	check(ui.overlay.visible or not ui.pending.is_empty() or not ui.choices.is_empty(), "Recompensa de combate encolada / visible")
	if ui.overlay.visible and not ui.choices.is_empty():
		var chosen: String = ui.choices[0]
		ui.choose(chosen)
		await frames(2)
		check(player.items.count(chosen) > 0 or chosen in ["heart_recovery_potion", "treasure_chest", "legendary_celestial_chest"], "Elección de recompensa aplicada o consumible")
	elif not ui.choices.is_empty():
		ui.choose(ui.choices[0])
		await frames(1)

	# Llave / ticket / monedas para servicios.
	player.items.keys = 1
	player.items.tickets = 1
	player.items.coins = 5
	ui.show_routes()
	await frames(2)
	check(ui.overlay.visible, "Panel de rutas / servicios visible")
	check(paused, "Combate pausado durante servicios")

	# Cerrar y continuar a una sala de combate.
	var options: Array = scene.run.next_options()
	check(not options.is_empty(), "Hay rutas tras START/recompensa")
	if not options.is_empty():
		# Forzar COMBAT: SHOP/EVENT/REST reabren su propio panel al entrar.
		options[0].room_type = "COMBAT"
		options[0].enemy_budget = 5
		ui.show_routes_refresh()
		await frames(1)
		var route_button: Button = null
		for child in ui.content.get_children():
			if child is Button and String(child.text).begins_with("Ir a:"):
				route_button = child
				break
		if route_button != null:
			route_button.pressed.emit()
		else:
			scene.awaiting_reward = false
			ui.close()
			scene.go_to_room(options[0].room_id)
		await frames(3)
		check(not ui.overlay.visible, "Overlay cerrado al entrar a la siguiente sala")
		check(not paused, "Árbol reanudado al entrar a la siguiente sala")

	# Pesos de rareza por tipo (integración RewardManager ↔ UI).
	var boss_w := RewardManager.weights_for("boss")
	var combat_w := RewardManager.weights_for("combat")
	check(boss_w["COMMON"] == 0.0 and combat_w["COMMON"] > 0.0, "Jefe y combate usan pesos distintos")
	check(RewardManager.allowed_in("boss", "COMMON") == false, "COMMON no permitido en recompensa de jefe")

	print("REWARDS FLOW: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
