extends SceneTree
# Persistencia de sesión: inventario + progreso entre partidas.
# godot --headless --path . --fixed-fps 60 --script res://tests/session_smoke.gd

const PLAYER = preload("res://scripts/player.gd")
const RUN_MANAGER = preload("res://scripts/systems/run_manager.gd")
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
	SESSION.path_override = "user://mamamoo_session_test.json"
	SESSION.clear()
	check(not SESSION.has_save(), "Sin archivo de sesión al inicio")

	var player: HarmonyPlayer = PLAYER.new()
	root.add_child(player)
	await frames(2)
	player.set_physics_process(false)
	var items = player.items
	check(items.acquire("shield_relic"), "Adquiere shield_relic")
	check(items.acquire("star_coin"), "Adquiere star_coin")
	items.coins = 7
	items.keys = 2
	items.tickets = 1
	items.skill_ranks[0] = 2
	player.member_voice[1] = 42.0
	player.composure = 55.0
	player.active_index = 2

	var run_mgr: RunManager = RUN_MANAGER.new()
	root.add_child(run_mgr)
	run_mgr.new_run(4242)
	run_mgr.complete_current()
	var options := run_mgr.next_options()
	check(not options.is_empty(), "Hay rutas tras completar START")
	if not options.is_empty():
		run_mgr.enter_room(options[0].room_id)

	var payload := {
		"run": run_mgr.export_session(),
		"items": items.export_session(),
		"member_voice": player.member_voice.duplicate(),
		"active_index": player.active_index,
		"harmony": player.harmony,
		"composure": player.composure,
		"awaiting_reward": true,
		"awaiting_floor_start": false,
	}
	check(SESSION.write(payload), "Escribe sesión en user://")
	check(SESSION.has_save(), "Archivo de sesión existe")

	# Nueva partida en memoria: importa lo guardado.
	var player2: HarmonyPlayer = PLAYER.new()
	root.add_child(player2)
	await frames(2)
	player2.set_physics_process(false)
	var run2: RunManager = RUN_MANAGER.new()
	root.add_child(run2)
	var loaded: Dictionary = SESSION.read()
	check(not loaded.is_empty(), "Lee sesión no vacía")
	check(int(loaded.get("version", 0)) == SESSION.VERSION, "Versión de sesión = 1")
	run2.import_session(loaded.get("run", {}))
	player2.items.import_session(loaded.get("items", {}))
	var voices: Array = loaded.get("member_voice", [])
	for i in range(4):
		player2.member_voice[i] = float(voices[i]) if i < voices.size() else player2.voice_max
	player2.active_index = int(loaded.get("active_index", 0))
	player2.composure = float(loaded.get("composure", 0.0))

	check(run2.run_seed == 4242, "Seed restaurada")
	check(run2.current_room_id == run_mgr.current_room_id, "Sala actual restaurada")
	check(player2.items.count("shield_relic") == 1, "Inventario restaura shield_relic")
	check(player2.items.coins == 7 and player2.items.keys == 2, "Recursos restaurados")
	check(player2.items.skill_ranks[0] == 2, "Rangos de pergamino restaurados")
	check(is_equal_approx(player2.member_voice[1], 42.0), "Voz de integrante restaurada")
	check(player2.active_index == 2, "Integrante activa restaurada")
	check(is_equal_approx(player2.composure, 55.0), "Compostura restaurada")
	check(bool(loaded.get("awaiting_reward", false)), "Flag awaiting_reward persistido")

	SESSION.clear()
	check(not SESSION.has_save(), "clear() elimina la sesión")
	SESSION.path_override = ""

	print("SESSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
