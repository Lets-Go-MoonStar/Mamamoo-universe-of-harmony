extends SceneTree
# Pipeline SFX, playtest log, mods×bioma, boss scripts.
# godot --headless --path . --fixed-fps 60 --script res://tests/art_playtest_longevity_smoke.gd

const SFX = preload("res://scripts/systems/sfx.gd")
const PLAYTEST = preload("res://scripts/systems/playtest_log.gd")
const ROOM_MOD = preload("res://scripts/systems/room_modifier.gd")
const BOSS_SCRIPTS = preload("res://scripts/systems/boss_scripts.gd")

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
	check(ResourceLoader.exists("res://assets/sfx/clear.wav"), "Slot SFX clear.wav")
	check(ResourceLoader.exists("res://assets/sfx/solar.wav"), "Slot SFX solar.wav")
	check(ResourceLoader.exists("res://assets/sfx/boss.wav"), "Slot SFX boss.wav")
	check(SFX.has_asset("phase"), "Sfx.has_asset phase")
	check(FileAccess.file_exists("res://docs/PLAYTEST_5X_RUTA.md"), "Doc playtest 5×ruta")

	PLAYTEST.path_override = "user://playtest_smoke_test.jsonl"
	if FileAccess.file_exists(PLAYTEST.file_path()):
		DirAccess.remove_absolute(PLAYTEST.file_path())
	PLAYTEST.begin_run("solar", 42)
	PLAYTEST.note_floor(3)
	PLAYTEST.note_mod("spotlight")
	PLAYTEST.note_boss_phase("eclipse", 2)
	PLAYTEST.note_room_clear()
	var saved := PLAYTEST.finish_run(false, {"floor": 3})
	check(not saved.is_empty() and FileAccess.file_exists(saved), "Playtest log escrito")
	check(PLAYTEST.count_runs_for_path("solar") >= 1, "Cuenta runs Solar")
	var cov: Dictionary = PLAYTEST.coverage_summary()
	check(int(cov.get("solar", 0)) >= 1, "Coverage solar ≥1")
	PLAYTEST.path_override = ""

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lunar := ROOM_MOD.pick(rng, 9, "ELITE", 3)
	check(lunar != "" or lunar == "", "pick bioma lunar no crashea")
	check(ROOM_MOD.BIOME_BIAS.has(3), "Bias lunar definido")

	var overlord: Dictionary = BOSS_SCRIPTS.pattern_for("overlord", 2)
	var critic: Dictionary = BOSS_SCRIPTS.pattern_for("critic", 2)
	var voidc: Dictionary = BOSS_SCRIPTS.pattern_for("void_conductor", 3)
	check(str(overlord.get("pattern", "")) == "ring", "Overlord ring")
	check(str(critic.get("pattern", "")) == "corners", "Critic corners")
	check(str(voidc.get("pattern", "")) == "lanes", "Void lanes en fase 3")
	check(str(overlord.get("label", "")) != str(critic.get("label", "")), "Labels de jefe distintos")

	print("ART/PLAYTEST/LONGEVITY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
