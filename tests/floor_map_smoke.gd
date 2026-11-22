extends SceneTree
# Smoke del mapa visual de rutas.
# godot --headless --path . --fixed-fps 60 --script res://tests/floor_map_smoke.gd

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
	await frames(2)
	scene.run.complete_current()
	scene.awaiting_reward = true
	scene.item_ui.show_routes()
	await frames(2)
	check(scene.item_ui.overlay.visible, "Panel de rutas visible")
	var map: Control = null
	for child in scene.item_ui.content.get_children():
		if child.get_script() == preload("res://scripts/floor_map.gd"):
			map = child
			break
	check(map != null, "Mapa del piso añadido al panel de rutas")
	if map != null:
		check(map.positions.size() == scene.run.floor_map.size(), "Mapa posiciona todas las salas del piso")
		var options: Array = scene.run.next_options()
		check(map.selectable.size() == options.size(), "Nodos seleccionables = next_options")
		if not options.is_empty() and map.positions.has(options[0].room_id):
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = map.positions[options[0].room_id]
			map._gui_input(click)
			await frames(3)
			check(scene.run.current_room_id == options[0].room_id, "Clic en nodo del mapa entra a esa sala")
			check(not scene.item_ui.overlay.visible, "Elegir en el mapa cierra el overlay")
	print("FLOOR MAP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
