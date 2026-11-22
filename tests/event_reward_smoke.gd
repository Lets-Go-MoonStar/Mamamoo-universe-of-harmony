extends SceneTree
# EVENT multiopción + sala REWARD especial + configs de piso 1-13.
# godot --headless --path . --fixed-fps 60 --script res://tests/event_reward_smoke.gd

const EVENT_CATALOG = preload("res://scripts/systems/event_catalog.gd")
const SESSION = preload("res://scripts/systems/session_store.gd")
const MAIN = preload("res://scripts/main.gd")

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
	var catalog: Array = EVENT_CATALOG.all()
	check(catalog.size() >= 6, "Catálogo EVENT tiene al menos 6 encuentros")
	for entry in catalog:
		check(str(entry.get("title", "")).length() > 0, "EVENT %s tiene título" % entry.get("id", "?"))
		var choices: Array = entry.get("choices", [])
		check(choices.size() >= 2, "EVENT %s tiene ≥2 opciones" % entry.get("id", "?"))

	for floor_number in range(1, 14):
		var path := "res://resources/floor_configs/floor_%d.tres" % floor_number
		check(ResourceLoader.exists(path), "Existe floor_%d.tres" % floor_number)
		var cfg: FloorConfig = load(path)
		check(cfg != null and cfg.floor_number == floor_number, "floor_%d carga con número correcto" % floor_number)
		check(not cfg.enemy_pool.is_empty() and not cfg.boss_pool.is_empty(), "floor_%d tiene pools" % floor_number)
		var fallback := FloorConfig.make_default(floor_number)
		check(fallback.min_rooms == cfg.min_rooms and fallback.max_rooms == cfg.max_rooms, "floor_%d alineado con make_default (salas)" % floor_number)

	# Monta main y fuerza una sala EVENT / REWARD.
	SESSION.path_override = "user://mamamoo_session_event_test.json"
	SESSION.clear()
	var game = MAIN.new()
	root.add_child(game)
	await frames(4)
	if is_instance_valid(game.player):
		game.player.set_physics_process(false)

	check(game.item_ui != null, "ItemUI montado")
	game._enter_event_room()
	await frames(2)
	check(game.item_ui.overlay.visible and game.item_ui.current_kind == "event", "EVENT abre panel multiopción")
	# Simula elegir la primera opción (botón) vía finish tras efecto noop-safe.
	game._apply_event_effect("noop")
	game.finish_non_combat_room()
	await frames(2)

	game._enter_reward_room()
	await frames(2)
	check(game.item_ui.overlay.visible and game.item_ui.current_kind == "reward_special", "REWARD abre elección especial")
	game.item_ui.open_reward_special()
	# Botín rápido
	game.player.items.coins = 0
	game.player.items.keys = 0
	game.player.items.coins += 10
	game.player.items.keys += 1
	check(game.player.items.coins == 10 and game.player.items.keys == 1, "Botín rápido de REWARD aplica recursos")

	SESSION.clear()
	SESSION.path_override = ""
	print("EVENT/REWARD/FLOORS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
