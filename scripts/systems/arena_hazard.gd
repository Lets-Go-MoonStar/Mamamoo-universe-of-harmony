# ---------------------------------------------------------------------------
# systems/arena_hazard.gd — Zona de arena con telegraph (aviso → daño).
# Estilos visuales distintos para que set pieces / storms se lean y “peguen”.
# ---------------------------------------------------------------------------
class_name ArenaHazard
extends Node2D

const SFX = preload("res://scripts/systems/sfx.gd")
const VISUALS = preload("res://scripts/visual_assets.gd")

var radius := 68.0
var warn_time := CombatConstants.HAZARD_WARN
var danger_time := CombatConstants.HAZARD_DANGER
var damage := 9.0
var timer := 0.0
var warning := true
var target: Node2D
var pulses_left := CombatConstants.HAZARD_PULSES
# normal | elite | storm — cambia color, SFX y feedback.
var style := "normal"

func setup(player: Node2D, at: Vector2, rad := 68.0, dmg := 9.0, hazard_style := "normal") -> void:
	target = player
	global_position = at
	radius = rad
	damage = dmg
	style = hazard_style
	if style == "elite":
		warn_time = CombatConstants.ELITE_HAZARD_WARN
	add_to_group("hazards")

func _physics_process(delta: float) -> void:
	timer += delta
	if warning:
		if timer >= warn_time:
			warning = false
			timer = 0.0
			SFX.play("warn" if style == "normal" else "setpiece")
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
	var burst_row := 2 if style != "storm" else 1
	VISUALS.burst(self, VISUALS.COMBAT, burst_row, 4, radius * 1.15, Vector2.ZERO, 0.32)
	var label := "¡ZONA!"
	var col := Color("ff5964")
	match style:
		"elite":
			label = "ÉLITE"
			col = Color("ffd166")
			SFX.play("hazard")
		"storm":
			label = "STORM"
			col = Color("c77dff")
			SFX.play("phase")
		_:
			SFX.play("hazard")
	VISUALS.float_text(get_parent(), global_position, label, col)
	if is_instance_valid(target) and target.has_method("receive_damage"):
		if global_position.distance_to(target.global_position) <= radius:
			target.receive_damage(damage, false, false)

func _draw() -> void:
	var warn_col := Color("4cc9f0", 0.28)
	var danger_col := Color("ff5d5d", 0.42)
	var tick_col := Color("ffd166", 0.7)
	match style:
		"elite":
			warn_col = Color("ffd166", 0.30)
			danger_col = Color("ff9f1c", 0.48)
			tick_col = Color("fff3b0", 0.85)
		"storm":
			warn_col = Color("c77dff", 0.32)
			danger_col = Color("9b5de5", 0.50)
			tick_col = Color("f15bb5", 0.8)
	var col := warn_col if warning else danger_col
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, col.lightened(0.2), 2.8)
	# Cruz interior en élite / storm para que el patrón se lea al primer vistazo.
	if style != "normal":
		var arm := radius * 0.55
		draw_line(Vector2(-arm, 0), Vector2(arm, 0), Color(col.lightened(0.3), 0.55), 2.0)
		draw_line(Vector2(0, -arm), Vector2(0, arm), Color(col.lightened(0.3), 0.55), 2.0)
	if warning:
		var t := clampf(timer / warn_time, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius * t, 0.0, TAU, 32, tick_col, 2.4)
		draw_arc(Vector2.ZERO, radius * (0.35 + t * 0.65), 0.0, TAU * t, 24, tick_col, 1.5)
