extends SceneTree
# Builds divergentes, hazards, telegraphs y foes nuevos (sin await de física).
# godot --headless --path . --fixed-fps 60 --script res://tests/spectacle_builds_smoke.gd

const META = preload("res://scripts/systems/meta_progress.gd")
const HAZARD = preload("res://scripts/systems/arena_hazard.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func run() -> void:
	META.path_override = "user://mamamoo_meta_spectacle_test.json"
	var meta_file := META.file_path()
	if FileAccess.file_exists(meta_file):
		DirAccess.remove_absolute(meta_file)

	for path in [
		"res://resources/enemy_pool/tempo_snare.tres",
		"res://resources/enemy_pool/choir_shade.tres",
		"res://resources/enemy_pool/grav_anchor.tres",
	]:
		check(ResourceLoader.exists(path), "Existe %s" % path.get_file())

	var snare: EnemyData = load("res://resources/enemy_pool/tempo_snare.tres")
	check(snare.abilities.has("snare") and snare.abilities.has("telegraph"), "Tempo Snare snare+telegraph")
	var shade: EnemyData = load("res://resources/enemy_pool/choir_shade.tres")
	check(shade.abilities.has("telegraph") and shade.abilities.has("dash"), "Choir Shade telegraph+dash")
	var anchor: EnemyData = load("res://resources/enemy_pool/grav_anchor.tres")
	check(anchor.is_elite and anchor.abilities.has("pull"), "Grav Anchor élite con pull")

	var cfg5: FloorConfig = load("res://resources/floor_configs/floor_5.tres")
	check(cfg5.enemy_pool.has("res://resources/enemy_pool/tempo_snare.tres"), "Piso 5 incluye Tempo Snare")
	var cfg7: FloorConfig = load("res://resources/floor_configs/floor_7.tres")
	check(cfg7.enemy_pool.has("res://resources/enemy_pool/grav_anchor.tres"), "Piso 7 incluye Grav Anchor")
	var cfg9: FloorConfig = load("res://resources/floor_configs/floor_9.tres")
	check(cfg9.enemy_pool.has("res://resources/enemy_pool/choir_shade.tres"), "Piso 9 incluye Choir Shade")

	var data := META.load_data()
	data["star_fragments"] = 200
	META.save_data(data)
	var picked_solar: bool = META.select_path("solar")
	check(picked_solar, "Elige ruta Solar")
	check(META.current_path() == "solar", "Ruta Solar activa")
	var picked_hwasa: bool = META.select_path("hwasa")
	check(picked_hwasa, "Cambia a ruta Hwasa (respec 20)")
	check(META.current_path() == "hwasa", "Ruta Hwasa activa")
	var bonuses: Dictionary = META.run_bonuses()
	check(str(bonuses.get("path", "")) == "hwasa", "run_bonuses expone path")
	check(META.PATH_DEFS.has("moonbyul") and META.PATH_DEFS.has("wheein"), "4 rutas definidas")

	var hazard = HAZARD.new()
	hazard.warn_time = 0.9
	hazard.danger_time = 0.5
	hazard.radius = 50.0
	check(hazard.warning and hazard.pulses_left == 4, "Hazard arranca en aviso")

	var enemy := HarmonyEnemy.new()
	enemy._begin_telegraph("shot", 0.2)
	check(enemy.telegraph_time > 0.0 and enemy.telegraph_kind == "shot", "Telegraph de disparo activo")
	enemy.queue_free()
	hazard.queue_free()

	META.path_override = ""
	print("SPECTACLE/BUILDS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
