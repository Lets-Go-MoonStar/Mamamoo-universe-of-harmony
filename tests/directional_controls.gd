extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures += 1

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tick(count: int = 2) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame

func shots(scene: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in scene.actors.get_children():
		if child is HarmonyProjectile:
			result.append(child)
	return result

func run() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await tick()
	var player = scene.player
	var codes := [KEY_W, KEY_A, KEY_S, KEY_D]
	var directions := [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
	for i in range(4):
		for shot in shots(scene):
			shot.queue_free()
		await tick()
		var start: Vector2 = player.position
		player.attack_cd = 0.0
		key(codes[i], true)
		await tick()
		var projectiles := shots(scene)
		check(projectiles.size() == 1 and projectiles[0].velocity.normalized().is_equal_approx(directions[i]), "WASD key %d fires its cardinal direction" % i)
		check(player.position.is_equal_approx(start), "Firing key %d does not move the character" % i)
		key(codes[i], false)
		await tick()
	key(KEY_W, true)
	key(KEY_RIGHT, true)
	var start: Vector2 = player.position
	await tick(25)
	check(player.position.x > start.x + 50 and player.aim_dir == Vector2.UP, "Arrows move independently while holding fire")
	check(shots(scene).size() >= 2, "Holding a firing key repeats shots")
	key(KEY_D, true)
	await tick()
	check(player.aim_dir == Vector2.RIGHT, "Newest firing key wins without diagonal aiming")
	key(KEY_D, false)
	await tick()
	check(player.aim_dir == Vector2.UP, "Releasing newest key restores the held direction")
	key(KEY_W, false)
	key(KEY_RIGHT, false)
	await tick()
	player.attack_cd = 0.0
	var count := shots(scene).size()
	key(KEY_LEFT, true)
	await tick()
	check(shots(scene).size() == count and player.aim_dir == Vector2.UP, "Movement alone does not fire or change aim")
	key(KEY_LEFT, false)
	key(KEY_SPACE, true)
	await tick()
	check(shots(scene).size() == count, "Old Space binding no longer fires")
	key(KEY_SPACE, false)
	scene._setup_inputs()
	check(InputMap.action_get_events("move_left").size() == 1, "Restart setup does not duplicate controls")
	print("CONTROLS RESULT: %d failures" % failures)
	quit(1 if failures else 0)
