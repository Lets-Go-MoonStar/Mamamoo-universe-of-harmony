extends SceneTree

# Run with: godot --headless --path . --fixed-fps 60 --script res://tests/combat_smoke.gd
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
	scene.set_process(false)
	var player = scene.player
	check(not get_nodes_in_group("enemies").is_empty(), "Scene creates player and a first combat wave")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await frames(2)
	var start: Vector2 = player.position
	Input.action_press("move_right")
	await frames(20)
	Input.action_release("move_right")
	check(player.position.x > start.x + 50.0, "Movement responds to input")
	player.position = Vector2(640, 360)
	player.set_physics_process(false)
	player.aim_dir = Vector2.RIGHT
	var target := HarmonyEnemy.new()
	target.setup(player)
	target.position = player.position + Vector2(110, 0)
	scene.add_child(target)
	target.set_physics_process(false)
	player._basic_attack()
	await frames(20)
	check(target.hp < target.max_hp, "Basic projectile damages enemy through physics collision")
	check(player.chain_level == 1 and player.harmony > 0, "Real hit starts chain and grants harmony")
	target.queue_free()
	await frames(2)
	for member in range(1, 4):
		player.switch_to(member)
		check(player.active_index == member, "Switch to member %d" % member)
		player._use_ability()
	await frames(120)
	player._register_chain_hit(1)
	player._register_chain_hit(2)
	player._register_chain_hit(3)
	check(player.chain_level == 4, "Four distinct members reach quartet")
	player._update_chain(3.0)
	check(player.chain_level == 0, "Chain expires")
	player.invulnerable = 0.0
	player.voice = 100.0
	player.receive_damage(9.0)
	check(player.voice == 91.0, "Direct damage reduces health")
	player._dodge()
	player.receive_damage(9.0)
	check(player.voice == 91.0, "Dodge prevents damage")
	player.invulnerable = 0.0
	player.position = Vector2(640, 360)
	var contact := HarmonyEnemy.new()
	contact.setup(player)
	contact.position = player.position + Vector2(70, 0)
	scene.add_child(contact)
	await frames(120)
	check(player.voice < 91.0, "Enemy contact damages stationary player (distance %.3f)" % contact.position.distance_to(player.position))
	contact.queue_free()
	await frames(2)
	var victim := HarmonyEnemy.new()
	scene.add_child(victim)
	victim.set_physics_process(false)
	var deaths := [0]
	victim.defeated.connect(func(_enemy): deaths[0] += 1)
	victim.take_damage(100.0)
	victim.take_damage(100.0)
	check(deaths[0] == 1, "Two lethal hits in one frame count one defeat (actual %d)" % deaths[0])
	await frames(2)
	var enemies: Array[HarmonyEnemy] = []
	for i in range(2):
		var enemy := HarmonyEnemy.new()
		enemy.position = Vector2(900, 500)
		scene.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	var projectile := HarmonyProjectile.new()
	projectile.position = Vector2(900, 500)
	scene.add_child(projectile)
	await frames(5)
	var damaged := 0
	for enemy in enemies:
		if enemy.hp < enemy.max_hp:
			damaged += 1
	check(damaged == 1, "Non-piercing projectile damages one overlapping enemy (actual %d)" % damaged)
	player.member_voice.fill(0.0)
	player.voice = 5.0
	player.invulnerable = 0.0
	var displayed_health := [0.0]
	player.stats_changed.connect(func(data): displayed_health[0] = data["voice"])
	player.receive_damage(9.0)
	check(player.voice == 0 and not player.is_physics_processing(), "Death stops player with zero health")
	check(displayed_health[0] == 0.0, "HUD receives zero health on death (actual %.1f)" % displayed_health[0])
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
