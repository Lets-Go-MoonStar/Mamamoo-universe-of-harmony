# ---------------------------------------------------------------------------
# enemy_projectile.gd — EnemyProjectile (Area2D). Proyectil disparado por
# arquetipos ranged (Mute/Afinador) y jefes con la ability "ranged":
#   - avanza recto con vida limitada,
#   - al tocar a la jugadora aplica receive_damage (corrupción/jefe según
#     quién lo lanzó) y se consume.
# ---------------------------------------------------------------------------
class_name EnemyProjectile
extends Area2D

const VISUALS = preload("res://scripts/visual_assets.gd")

var velocity := Vector2.ZERO
var damage := 8.0
# Corrupción y flag de "jefe" heredados del actor que disparó.
var corruption := false
var boss := false
var lifetime := 2.4
var radius := 6.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	modulate = Color(1.0, 0.55, 0.75) if corruption else Color("c77dff")
	var image := VISUALS.sprite(self, VISUALS.cell(VISUALS.PROJECTILES, 2, 4, 4, 5), radius * 5.0)
	image.rotation = velocity.angle()
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

# Impacto sobre la jugadora: evita doble golpe y se consume al acertar.
func _on_body_entered(body: Node) -> void:
	if not body.has_method("receive_damage"):
		return
	if body is HarmonyPlayer and body.team_defeated:
		return
	body.receive_damage(damage, corruption, boss)
	queue_free()

# Dibujo procedimental: núcleo brillante con halo del color heredado.
func _draw() -> void:
	pass