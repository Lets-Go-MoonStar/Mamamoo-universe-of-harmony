# ---------------------------------------------------------------------------
# combat_feel.gd — Peso de golpe: hitstop, nudge, SFX. Shortcut sin art real.
# ---------------------------------------------------------------------------
class_name CombatFeel
extends RefCounted

const SFX = preload("res://scripts/systems/sfx.gd")
const VISUALS = preload("res://scripts/visual_assets.gd")

static var _freeze_left := 0.0
static var _host: Node

static func ensure(host: Node) -> void:
	_host = host

static func hit_enemy(world: Node, at: Vector2, amount: float, big := false) -> void:
	SFX.play("hit")
	if is_instance_valid(world) and world is Node2D:
		VISUALS.nudge(world as Node2D, 3.5 if not big else 7.0, 0.10 if not big else 0.16)
	_hitstop(0.035 if not big else 0.055)
	if big and is_instance_valid(world):
		VISUALS.float_text(world, at + Vector2(0, -56), "HIT", Color("ffd166"))

static func kill_pop(world: Node, at: Vector2) -> void:
	SFX.play("clear")
	if is_instance_valid(world) and world is Node2D:
		VISUALS.nudge(world as Node2D, 9.0, 0.18)
		VISUALS.burst(world, VISUALS.COMBAT, 0, 4, 90.0, at - (world as Node2D).global_position, 0.35)
	_hitstop(0.07)

static func player_hurt(world: Node) -> void:
	SFX.play("warn")
	if is_instance_valid(world) and world is Node2D:
		VISUALS.nudge(world as Node2D, 8.0, 0.14)
	_hitstop(0.045)

static func _hitstop(seconds: float) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_freeze_left = maxf(_freeze_left, seconds)
	if Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.15
	var tree := _host.get_tree()
	if tree == null:
		Engine.time_scale = 1.0
		return
	# Restaura tras el freeze (usa timer real vía SceneTreeTimer con process_always).
	var t := tree.create_timer(seconds, true, false, true)
	t.timeout.connect(func():
		Engine.time_scale = 1.0
		_freeze_left = 0.0)
