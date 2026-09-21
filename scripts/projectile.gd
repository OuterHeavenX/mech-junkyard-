class_name BoltShot
extends Area2D

## Scrap-cannon bolt. Friendly bolts hit enemies; enemy bolts (unused yet) hit the player.

var game: MechGame
var vel := Vector2.ZERO
var dmg := 10.0
var friendly := true
var life := 1.4
var col := Color(1, 0.7, 0.25)
var t := 0.0


func setup(pos: Vector2, dir: Vector2, p_dmg: float, p_friendly: bool) -> void:
	position = pos
	vel = dir.normalized() * 780.0
	dmg = p_dmg
	friendly = p_friendly


func _ready() -> void:
	collision_layer = 16
	collision_mask = 4 if friendly else 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	position += vel * delta
	if life <= 0.0 or absf(position.x) > 700.0:
		queue_free()
		return
	queue_redraw()


func _on_body(b: Node2D) -> void:
	if friendly and b.is_in_group("enemies"):
		(b as EnemyMech).take_damage(dmg, signf(vel.x), false)
		_impact()
	elif not friendly and b.is_in_group("player"):
		(b as PlayerMech).take_damage(dmg, position.x - signf(vel.x) * 10.0)
		_impact()


func _impact() -> void:
	game.spawn_sparks(position, col, 10)
	game.add_shake(0.12)
	queue_free()


func _draw() -> void:
	var d := vel.normalized()
	for i in 3:
		draw_circle(-d * i * 9.0, 9.0 - i * 2.2, Color(col, 0.9 - i * 0.25))
	draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.95))
