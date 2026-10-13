extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + description)
	if not condition:
		failures += 1

func run() -> void:
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_process(false)
	scene.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	for index in range(4):
		scene.player.switch_to(index)
		for action in ["idle", "move", "attack", "ability", "dodge", "hurt", "death"]:
			var frames: SpriteFrames = scene.player.art.sprite_frames
			check(frames.has_animation(action) and frames.get_frame_count(action) > 0, "Member %d has %s frames" % [index, action])
		var enemy := HarmonyEnemy.new()
		enemy.setup(scene.player, index)
		enemy.position = Vector2(240 + index * 245, 510)
		scene.actors.add_child(enemy)
		enemy.set_physics_process(false)
		check(enemy.art.sprite_frames.get_frame_count("move") == 4, "Enemy %d loads animation" % index)
	scene.player.switch_to(0)
	scene.player.position = Vector2(640, 575)
	for index in range(scene.BACKGROUNDS.size()):
		scene.select_stage(index)
		check(scene.stage_index == index and scene.stage_selector.selected == index, "Stage %d is selectable" % index)
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/art_stage_%d.png" % index)
	check(scene.BACKGROUNDS.size() == 9, "All nine backgrounds are available")
	scene.select_stage(0)
	print("ART RESULT: %d failures" % failures)
	quit(1 if failures else 0)
