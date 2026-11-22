extends SceneTree
# Set pieces (élite cruz, phase_storm, evento path) + rutas v2.
# godot --headless --path . --fixed-fps 60 --script res://tests/set_pieces_smoke.gd

const META = preload("res://scripts/systems/meta_progress.gd")
const EVENTS = preload("res://scripts/systems/event_catalog.gd")

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
	check(ResourceLoader.exists("res://resources/enemy_pool/stage_marshal.tres"), "Existe Stage Marshal")
	var marshal: EnemyData = load("res://resources/enemy_pool/stage_marshal.tres")
	check(marshal.is_elite and marshal.abilities.has("setpiece"), "Marshal élite setpiece")
	check(marshal.abilities.has("snare") and marshal.abilities.has("pull"), "Marshal snare+pull")

	var cfg6: FloorConfig = load("res://resources/floor_configs/floor_6.tres")
	check(cfg6.enemy_pool.has("res://resources/enemy_pool/stage_marshal.tres"), "Piso 6 incluye Stage Marshal")

	var eclipse: BossData = load("res://resources/boss_pool/eclipse.tres")
	check(eclipse.abilities.has("phase_storm"), "Eclipse tiene phase_storm")
	var voidc: BossData = load("res://resources/boss_pool/void_conductor.tres")
	check(voidc.abilities.has("phase_storm"), "Void Conductor tiene phase_storm")

	var late: Array = EVENTS.late_events()
	var has_path_encore := false
	for ev in late:
		if str(ev.get("id", "")) == "path_encore":
			has_path_encore = true
			var effects: Array = []
			for c in ev.get("choices", []):
				effects.append(str(c.get("effect", "")))
			check(effects.has("path_empower"), "path_encore ofrece path_empower")
	check(has_path_encore, "Evento late path_encore presente")

	check(META.PATH_DEFS["solar"]["desc"].find("Compostura") >= 0, "Solar describe sinergia")
	check(META.PATH_DEFS["moonbyul"]["desc"].find("esquivar") >= 0, "Moonbyul describe post-esquiva")

	print("SET PIECES/ROUTES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
