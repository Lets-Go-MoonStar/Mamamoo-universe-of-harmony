# ---------------------------------------------------------------------------
# systems/arena_hazard.gd — Zona de arena con telegraph (aviso → daño).
# Obliga a reposicionarse: el puzzle de sala mínimo del prototipo.
# ---------------------------------------------------------------------------
class_name ArenaHazard
extends Node2D

const SFX = preload("res://scripts/systems/sfx.gd")
const VISUALS = preload("res://scripts/visual_assets.gd")

var radius := 68.0
var warn_time := 1.15
var danger_time := 0.75
var damage := 9.0
var timer := 0.0
var warning := true
var target: Node2D
var pulses_left := 4

func setup(player: Node2D, at: Vector2, rad := 68.0, dmg := 9.0) -> void:
	target = player
	global_position = at
	radius = rad
	damage = dmg
	add_to_group("hazards")

func _physics_process(delta: float) -> void:
	timer += delta
	if warning:
		if timer >= warn_time:
			warning = false
			timer = 0.0
			SFX.play("warn")
	else:
		if timer >= danger_time:
			_pulse()
			warning = true
			timer = 0.0
			pulses_left -= 1
			if pulses_left <= 0:
				queue_free()
				return
	queue_redraw()

func _pulse() -> void:
	VISUALS.burst(self, VISUALS.COMBAT, 2, 4, radius * 1.1, Vector2.ZERO, 0.3)
	VISUALS.float_text(get_parent(), global_position, "¡ZONA!", Color("ff5964"))
	if is_instance_valid(target) and target.has_method("receive_damage"):
		if global_position.distance_to(target.global_position) <= radius:
			target.receive_damage(damage, false, false)

func _draw() -> void:
	var col := Color("4cc9f0", 0.28) if warning else Color("ff5d5d", 0.42)
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, col.lightened(0.2), 2.5)
	if warning:
		var t := clampf(timer / warn_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 32, Color("ffd166", 0.7), 2.0)
