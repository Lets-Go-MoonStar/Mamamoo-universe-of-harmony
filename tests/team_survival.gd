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
	player.invulnerable = 0.0
	var losses := [0]
	player.game_over.connect(func(): losses[0] += 1)
	player.receive_damage(30.0)
	player.switch_to(1)
	check(player.voice == 100.0 and player.member_voice[0] == 70.0, "Switching preserves independent health")
	player.invulnerable = 0.0
	player.receive_damage(40.0)
	player.switch_to(0)
	check(player.voice == 73.0 and player.member_voice[1] == 60.0, "Solar tag healing affects Solar only")
	player._use_ability()
	check(player.voice == 81.0 and player.member_voice[1] == 60.0, "Solar ability heals only Solar")
	player.invulnerable = 0.0
	player.receive_damage(1000.0)
	check(player.active_index == 1 and player.voice == 60.0 and player.member_voice[0] == 0.0, "Lethal damage selects next survivor with preserved HP")
	check(losses[0] == 0 and player.is_physics_processing(), "First death keeps combat running")
	player.receive_damage(1000.0)
	check(player.voice == 60.0, "Replacement gets brief protection against simultaneous hits")
	player.switch_to(0)
	check(player.active_index == 1 and player.member_voice[0] == 0.0, "Fallen Solar cannot be selected or healed by switching")
	player.switch_to(3)
	player.invulnerable = 0.0
	player.receive_damage(1000.0)
	check(player.active_index == 1, "Automatic selection wraps and skips dead members")
	player.invulnerable = 0.0
	player.receive_damage(1000.0)
	check(player.active_index == 2 and losses[0] == 0, "Last survivor remains playable")
	player.invulnerable = 0.0
	player.receive_damage(1000.0)
	check(player.team_defeated and losses[0] == 1 and not player.is_physics_processing(), "Only the fourth death ends the game")
	player.invulnerable = 0.0
	player.receive_damage(1000.0)
	player.switch_to(0)
	player._use_ability()
	player._on_projectile_hit(0, 10.0)
	check(losses[0] == 1 and player.member_voice == [0.0, 0.0, 0.0, 0.0], "Defeat is final until restart and emits once")
	print("TEAM RESULT: %d failures" % failures)
	quit(1 if failures else 0)
