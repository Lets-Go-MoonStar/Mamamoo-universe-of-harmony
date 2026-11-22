extends SceneTree
# Profundidad de jugabilidad: foes firmados, meta upgrades, eventos late, feedback.
# godot --headless --path . --fixed-fps 60 --script res://tests/gameplay_depth_smoke.gd

const META = preload("res://scripts/systems/meta_progress.gd")
const EVENT_CATALOG = preload("res://scripts/systems/event_catalog.gd")
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
	META.path_override = "user://mamamoo_meta_depth_test.json"
	if FileAccess.file_exists(META.file_path()):
		DirAccess.open("user://").remove(META.file_path().get_file())

	for path in [
		"res://resources/enemy_pool/hex_echo.tres",
		"res://resources/enemy_pool/mirror_siren.tres",
		"res://resources/enemy_pool/beat_crusher.tres",
		"res://resources/boss_pool/crystal_warden.tres",
	]:
		check(ResourceLoader.exists(path), "Existe %s" % path.get_file())

	var hex: EnemyData = load("res://resources/enemy_pool/hex_echo.tres")
	check(hex.abilities.has("dash") and hex.abilities.has("debuff"), "Hex Echo tiene dash+debuff")
	var crusher: EnemyData = load("res://resources/enemy_pool/beat_crusher.tres")
	check(crusher.is_elite and crusher.min_floor == 8, "Beat Crusher élite late")

	var cfg8: FloorConfig = load("res://resources/floor_configs/floor_8.tres")
	check(cfg8.min_rooms <= 16 and cfg8.event_chance >= 0.18, "Piso 8 más corto y con más eventos")
	check(cfg8.enemy_pool.has("res://resources/enemy_pool/beat_crusher.tres"), "Piso 8 incluye Beat Crusher")
	check(cfg8.boss_pool.has("res://resources/boss_pool/void_conductor.tres"), "Piso 8 pico Void Conductor")

	var cfg6: FloorConfig = load("res://resources/floor_configs/floor_6.tres")
	check(cfg6.boss_pool.has("res://resources/boss_pool/crystal_warden.tres"), "Piso 6 pico Crystal Warden")

	var early_events: Array = EVENT_CATALOG.for_floor(3)
	var late_events: Array = EVENT_CATALOG.for_floor(9)
	check(late_events.size() > early_events.size(), "Pisos late añaden eventos exclusivos")
	var late_ids: Array = []
	for e in late_events:
		late_ids.append(e.get("id", ""))
	check(late_ids.has("eclipse_rite") and late_ids.has("void_bargain"), "Eventos late presentes")

	# Meta upgrades
	var data := META.load_data()
	data["star_fragments"] = 100
	META.save_data(data)
	check(META.can_buy_upgrade("voice_bonus"), "Puede comprar voice_bonus")
	check(META.buy_upgrade("voice_bonus"), "Compra voice_bonus")
	check(META.upgrade_level("voice_bonus") == 1, "Nivel upgrade = 1")
	var bonuses: Dictionary = META.run_bonuses()
	check(float(bonuses.get("voice_max_bonus", 0.0)) == 4.0, "Bonus voz = +4")
	check(float(bonuses.get("composure_mult", 1.0)) >= 1.0, "Composure mult definido")

	# Feedback: daño flotante / hurt flash
	var player: HarmonyPlayer = PLAYER.new()
	root.add_child(player)
	await frames(2)
	player.set_physics_process(false)
	player.composure_gain_mult = 2.0
	player.composure = 0.0
	player.gain_composure(10.0)
	check(is_equal_approx(player.composure, 20.0), "composure_gain_mult aplica")
	player.receive_damage(8.0)
	check(player.hurt_flash > 0.0, "hurt_flash al recibir daño")

	# Encuentro late favorece variedad (al menos no vacío)
	var pool: Array = []
	for path in FloorConfig.enemy_pool_for(10):
		pool.append(load(path))
	var waves: Array = EncounterDirector.build_encounter(pool, 12, RandomNumberGenerator.new(), 10, "medium")
	check(not waves.is_empty(), "Encounter late genera oleadas")

	META.path_override = ""
	print("GAMEPLAY DEPTH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
