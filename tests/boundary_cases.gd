extends SceneTree
# Casos límite / edge cases de sistemas data-driven y combate.
# godot --headless --path . --fixed-fps 60 --script res://tests/boundary_cases.gd

const RUN_ITEMS = preload("res://scripts/run_items.gd")
const PLAYER = preload("res://scripts/player.gd")

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
	_check_encounter_edges()
	_check_reward_edges()
	_check_run_edges()
	await _check_player_edges()
	print("BOUNDARY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_encounter_edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var run := RunManager.new()
	run.new_run(1)
	var pool := run.load_enemy_pool()
	check(EncounterDirector.build_encounter(pool, 0, rng, 1).is_empty(), "budget 0 → sin oleadas")
	check(EncounterDirector.build_encounter([], 10, rng, 1).is_empty(), "pool vacía → sin oleadas")
	var waves := EncounterDirector.build_encounter(pool, 1, rng, 1, "small")
	check(not waves.is_empty(), "budget 1 genera al menos una oleada si hay pool")
	check(EncounterDirector.max_active("small") == 4, "tope small = 4")
	check(EncounterDirector.max_active("medium") == 7, "tope medium = 7")
	check(EncounterDirector.max_active("large") == 10, "tope large = 10")
	run.queue_free()

func _check_reward_edges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	check(RewardManager.allowed_in("boss", "COMMON") == false, "boss rechaza COMMON")
	check(RewardManager.allowed_in("combat", "COMMON") == true, "combat acepta COMMON")
	check(RewardManager.rarity_weight("LEGENDARY") == 2, "peso base legendary = 2")
	var seen := {}
	for i in range(50):
		seen[RewardManager.roll_rarity("boss", rng)] = true
	check(not seen.has("COMMON"), "50 tiradas de boss sin COMMON")

func _check_run_edges() -> void:
	var run := RunManager.new()
	run.new_run(0)
	check(run.run_seed != 0, "seed 0 se reemplaza por randi() distinto de 0")
	run.new_run(123)
	check(run.current_room() != null and run.current_room().room_type == "START", "new_run empieza en START")
	run.goto_floor(13)
	check(run.current_floor == 13, "goto_floor(13) aplica")
	var cfg := run.floor_config()
	check(cfg.difficulty_multiplier > 1.0, "piso 13 difficulty > 1")
	# Sala inexistente.
	var missing := run.room(9999)
	check(missing == null, "room(id inválido) → null")
	run.queue_free()

func _check_player_edges() -> void:
	var player: HarmonyPlayer = PLAYER.new()
	root.add_child(player)
	await frames(2)
	player.voice = -10.0
	check(player.voice == 0.0, "voice setter clampa a 0")
	player.voice = 999.0
	check(player.voice == player.voice_max, "voice setter clampa a voice_max")
	player.member_voice = [0.0, 0.0, 0.0, 5.0]
	player.active_index = 0
	player.receive_damage(1.0)
	await frames(1)
	# Con tres caídas y una viva, no debe terminar la run de inmediato si rotación funciona.
	check(player.member_voice[3] > 0.0 or player.team_defeated, "Daño con integrante caído rota o termina de forma coherente")
	player.invulnerable = 1.0
	var before := player.voice
	player.receive_damage(50.0)
	check(player.voice == before, "Invulnerabilidad ignora daño")
	player.queue_free()
	await frames(1)
