extends SceneTree
# Identidad Mamamoo + modifiers de sala.
# godot --headless --path . --fixed-fps 60 --script res://tests/identity_mods_smoke.gd

const IDENTITY = preload("res://scripts/systems/member_identity.gd")
const ROOM_MOD = preload("res://scripts/systems/room_modifier.gd")
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

func run() -> void:
	check(IDENTITY.display_name(0) == "Solar", "Solar nombre")
	check(IDENTITY.display_name(3) == "Hwasa", "Hwasa nombre")
	check(IDENTITY.stage_title(0, "solar").find("Solar") >= 0, "Stage feat. Solar")
	check(IDENTITY.path_tagline("wheein").find("Wheein") >= 0, "Tagline Wheein")
	check(IDENTITY.sfx_for_path("hwasa") == "hwasa", "SFX path Hwasa")

	check(ROOM_MOD.all_ids().size() == 8, "8 modifiers")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var picked := ROOM_MOD.pick(rng, 6, "ELITE")
	check(picked != "" or picked == "", "pick élite no crashea")

	var p: HarmonyPlayer = PLAYER.new()
	root.add_child(p)
	p.set_physics_process(false)
	var def: Dictionary = ROOM_MOD.apply(p, "spotlight")
	check(not def.is_empty() and p.room_damage_taken_mult > 1.0, "spotlight aplica daño recibido")
	check(p.room_mod_id == "spotlight", "room_mod_id set")
	ROOM_MOD.apply(p, "dense_fog")
	check(p.room_extra_hazards == 1 and p.room_player_speed_mult < 1.0, "dense_fog haz+slow")
	ROOM_MOD.clear(p)
	check(p.room_mod_id.is_empty() and is_equal_approx(p.room_damage_taken_mult, 1.0), "clear resetea mods")
	p.queue_free()

	print("IDENTITY/MODS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
