# ---------------------------------------------------------------------------
# projectile.gd — HarmonyProjectile (Area2D). Proyectil de disparos y
# habilidades del jugador:
#   - avanza con velocidad constante y vida limitada,
#   - al chocar aplica los efectos de ítems de la partida (run_items),
#   - registro por instancia para que los proyectiles perforantes no
#     impacten al mismo enemigo dos veces.
# ---------------------------------------------------------------------------
class_name HarmonyProjectile
extends Area2D

const VISUALS = preload("res://scripts/visual_assets.gd")

signal hit_enemy(member_index: int, damage: float)

var velocity := Vector2.ZERO
var damage := 10.0
# Integrante que disparó (para cadena de Armonía y efectos por miembro).
var member_index := 0
var lifetime := 1.8
var radius := 6.0
var projectile_color := Color.WHITE
# Si es perforante sigue volando tras acertar (Wheein).
var piercing := false
# Referencia al sistema de ítems de la partida (aplica efectos al impactar).
var item_effects
var consumed := false
# IDs de enemigos ya golpeados (solo útil con perforación).
var hit_ids: Dictionary = {}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	var image := VISUALS.sprite(self, VISUALS.cell(VISUALS.PROJECTILES, 1, clampi(member_index, 0, 3), 4, 5), radius * 5.0)
	image.rotation = velocity.angle()
	queue_redraw()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _draw() -> void:
	pass

# Colisión con un enemigo: aplica daño base modificado por los efectos de
# ítems, emite `hit_enemy` para la cadena y se consume salvo que perfore.
func _on_body_entered(body: Node) -> void:
	if consumed or not body.has_method("take_damage"):
		return
	var id := body.get_instance_id()
	if hit_ids.has(id):
		return
	hit_ids[id] = true
	VISUALS.burst(body, VISUALS.STATUS, 4, 6, 48.0, Vector2(0, -24))
	var actual := damage
	if is_instance_valid(item_effects):
		actual = item_effects.hit(body, damage, member_index)
	else:
		body.take_damage(damage, member_index)
	hit_enemy.emit(member_index, actual)
	if not piercing:
		consumed = true
		queue_free()
