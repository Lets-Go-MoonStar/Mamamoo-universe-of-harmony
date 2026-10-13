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
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	var player = scene.player
	var ui = scene.combat_hud
	player.set_physics_process(false)
	player.voice = 50.0
	player.harmony = 65.0
	player._emit_stats()
	check(ui.voice_bar.value == 50.0 and ui.harmony_bar.value == 65.0, "Meters reflect current combat values")
	ui.member_buttons[2].pressed.emit()
	check(player.active_index == 2 and ui.member_buttons[2].modulate == Color.WHITE, "UI selection switches and highlights Wheein")
	scene._on_chain_changed(4, 1.5)
	check("CUARTETO" in ui.chain_text.text, "Chain label shows quartet")
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/hud_preview.png")
	player.invulnerable = 0.0
	player.receive_damage(200.0)
	check(not ui.defeat_panel.visible and ui.member_buttons[2].disabled and ui.member_health_labels[2].text == "CAÍDA", "First death disables fallen member without defeat")
	check(ui.voice_bar.value == player.voice and player.active_index == 3, "HUD follows surviving replacement")
	for remaining in range(3):
		player.invulnerable = 0.0
		player.receive_damage(200.0)
	check(ui.voice_bar.value == 0.0 and ui.defeat_panel.visible, "Death empties meter and opens restart overlay")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/hud_defeat_preview.png")
	var restart = ui.defeat_panel.get_child(ui.defeat_panel.get_child_count() - 1)
	restart.pressed.emit()
	await process_frame
	await process_frame
	check(current_scene != scene and not current_scene.combat_hud.defeat_panel.visible, "Restart button loads a fresh game")
	check(current_scene.player.member_voice == [100.0, 100.0, 100.0, 100.0] and not current_scene.player.team_defeated, "Restart restores all four members")
	print("HUD RESULT: %d failures" % failures)
	quit(1 if failures else 0)
