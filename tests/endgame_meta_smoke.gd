extends SceneTree
# Fin de run, meta-progresión, SFX, pausa e intros.
# godot --headless --path . --fixed-fps 60 --script res://tests/endgame_meta_smoke.gd

const META = preload("res://scripts/systems/meta_progress.gd")
const SFX = preload("res://scripts/systems/sfx.gd")
const MAIN = preload("res://scripts/main.gd")
const SESSION = preload("res://scripts/systems/session_store.gd")

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
	META.path_override = "user://mamamoo_meta_test.json"
	SESSION.path_override = "user://mamamoo_session_endgame_test.json"
	# Limpia meta de prueba.
	if FileAccess.file_exists(META.file_path()):
		DirAccess.open("user://").remove(META.file_path().get_file())
	SESSION.clear()

	check(META.discovered_count() == 0, "Meta inicia sin descubrimientos")
	META.discover("shield_relic")
	check(META.is_discovered("shield_relic"), "discover marca ítem")
	var after_loss: Dictionary = META.record_run(false, 3, 5)
	check(int(after_loss.get("runs_lost", 0)) == 1, "record_run cuenta derrota")
	check(int(after_loss.get("star_fragments", 0)) > 0, "Fragmentos por progreso")
	var after_win: Dictionary = META.record_run(true, 13, 40)
	check(int(after_win.get("runs_won", 0)) == 1, "record_run cuenta victoria")
	check(int(after_win.get("best_floor", 0)) == 13, "best_floor actualiza")

	check(ResourceLoader.exists("res://resources/enemy_pool/resonance_drone.tres"), "Existe resonance_drone")
	check(ResourceLoader.exists("res://resources/enemy_pool/pulse_swarm.tres"), "Existe pulse_swarm")
	check(ResourceLoader.exists("res://resources/boss_pool/void_conductor.tres"), "Existe void_conductor")
	var cfg8: FloorConfig = load("res://resources/floor_configs/floor_8.tres")
	check(cfg8.boss_pool.has("res://resources/boss_pool/void_conductor.tres"), "Piso 8 incluye Void Conductor")
	check(cfg8.enemy_pool.has("res://resources/enemy_pool/resonance_drone.tres"), "Piso 8 incluye Resonance Drone")

	var game = MAIN.new()
	root.add_child(game)
	await frames(4)
	SFX.ensure(game)
	SFX.play("ui")
	check(is_instance_valid(SFX._player), "Sfx monta AudioStreamPlayer")

	check(game.combat_hud != null, "HUD montado")
	game.combat_hud.show_floor_intro(1, "Prueba")
	check(game.combat_hud.intro_panel.visible, "Intro de piso visible")
	game.combat_hud.show_boss_intro("Echo Overlord")
	check(game.combat_hud.intro_title.text == "JEFE", "Intro de jefe")

	game.combat_hud.toggle_pause()
	check(game.combat_hud.paused_game and game.get_tree().paused, "Pausa activa el árbol")
	game.combat_hud.toggle_pause()
	check(not game.combat_hud.paused_game and not game.get_tree().paused, "Pausa se quita")

	game.combat_hud.show_run_end(false, {"floor": 2, "rooms": 4, "bosses": 0, "coins": 3, "items": 2})
	check(game.combat_hud.defeat_panel.visible, "Panel de fin de run (derrota)")
	check(game.combat_hud.end_title.text.findn("DERROTADO") >= 0, "Título de derrota")
	game.combat_hud.show_run_end(true, {"floor": 13, "rooms": 50, "bosses": 13, "coins": 40, "items": 10})
	check(game.combat_hud.end_title.text.findn("VICTORIA") >= 0, "Título de victoria")

	SESSION.clear()
	SESSION.path_override = ""
	META.path_override = ""
	print("ENDGAME/META: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
