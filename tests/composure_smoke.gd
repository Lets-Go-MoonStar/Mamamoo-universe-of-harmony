extends SceneTree
# Compostura, Ad-lib y constantes de reacción.
# godot --headless --path . --fixed-fps 60 --script res://tests/composure_smoke.gd

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
	check(CombatConstants.ADLIB_DURATION == 5.0, "Ad-lib dura 5 s")
	check(CombatConstants.ARDOR_DOT_PER_SEC == 3.0, "Ardor DoT = 3/s")
	check(CombatConstants.REACTION_NOTE_BASE == 0.15, "Nota base = 15%")
	check(CombatConstants.COMPOSURE_ON_HIT == 4.0, "Compostura por golpe = 4")

	var player: HarmonyPlayer = PLAYER.new()
	root.add_child(player)
	await frames(2)
	player.set_physics_process(false)
	check(player.composure == 0.0, "Compostura inicia en 0")
	player.gain_composure(CombatConstants.COMPOSURE_ON_HIT)
	check(is_equal_approx(player.composure, 4.0), "gain_composure suma por golpe")
	player.items.start_adlib()
	check(not player.items.active("adlib"), "Sin Compostura completa no hay Ad-lib")
	player.composure = CombatConstants.ADLIB_COST
	player.items.start_adlib()
	check(player.items.active("adlib") and is_equal_approx(player.composure, 0.0), "Q/Ad-lib gasta 100 Compostura")
	check(is_equal_approx(float(player.items.timers.adlib), CombatConstants.ADLIB_DURATION), "Ventana Ad-lib = duración constante")

	# Ardor DoT: enemigo con burn pierde vida con el tiempo.
	var enemy := HarmonyEnemy.new()
	enemy.setup(player)
	enemy.max_hp = 100.0
	enemy.hp = 100.0
	enemy.burn_time = CombatConstants.ARDOR_DURATION
	root.add_child(enemy)
	enemy.set_physics_process(true)
	await frames(60)
	check(enemy.hp < 100.0 or enemy.dying, "Ardor aplica DoT con el tiempo")
	enemy.queue_free()
	await frames(1)

	print("COMPOSURE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
