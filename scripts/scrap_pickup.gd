class_name ScrapPickup
extends Area2D

## Little gold scrap bolts. Fly to the player, +1 scrap and +1 HP each.

var vel := Vector2.ZERO
var age := 0.0


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	vel = Vector2(randf_range(-160, 160), randf_range(-380, -180))
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	age += delta
	vel.y += 1400.0 * delta
	position += vel * delta
	if position.y > 292.0:
		position.y = 292.0
		vel.y *= -0.4
		vel.x *= 0.7
	var player := get_tree().get_first_node_in_group("player") as PlayerMech
	if player != null and not player.dead:
		var d: float = position.distance_to(player.position + Vector2(0, -60))
		if d < maxf(player.magnet_r, 110.0):
			position = position.move_toward(player.position + Vector2(0, -60), 560.0 * delta)
	if age > 25.0:
		queue_free()
	queue_redraw()


func _on_body(b: Node2D) -> void:
	if b.is_in_group("player"):
		var p := b as PlayerMech
		p.game.add_scrap(1)
		p.heal(1.0)
		queue_free()


func _draw() -> void:
	var c := Vector2(0, sin(age * 6.0) * 3.0)
	draw_circle(c, 12, Color(1, 0.84, 0.37, 0.25))
	var pts := PackedVector2Array([
		c + Vector2(3, -9), c + Vector2(-5, 1), c + Vector2(0, 1),
		c + Vector2(-3, 9), c + Vector2(5, -1), c + Vector2(0, -1),
	])
	draw_colored_polygon(pts, Color("ffd75e"))
