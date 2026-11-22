extends SceneTree
# Cofre celestial: roll_choices(kind=legendary) ofrece 3 reliquias legendarias.
# godot --headless --path . --fixed-fps 60 --script res://tests/celestial_chest_smoke.gd

const CATALOG = preload("res://scripts/item_catalog.gd")

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
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(1)
	scene.item_ui.current_kind = "legendary"
	scene.item_ui.roll_choices()
	check(scene.item_ui.choices.size() == 3, "Cofre celestial ofrece 3 opciones")
	var seen := {}
	var ok := true
	for id in scene.item_ui.choices:
		var entry := CATALOG.entry(id)
		if entry.rarity != "LEGENDARY" or id == "legendary_celestial_chest" or seen.has(id):
			ok = false
		seen[id] = true
	check(ok, "Las 3 opciones son reliquias legendarias distintas (sin el cofre)")
	print("CELESTIAL CHEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
