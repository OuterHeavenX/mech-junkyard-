class_name DebrisChunk
extends Node2D

## A tumbling chunk of wreckage with bounce + fade.

var vel := Vector2.ZERO
var rot := 0.0
var rot_v := 0.0
var col := Color.GRAY
var size := 9.0
var t := 0.0
var life := 1.5
var ground_y := 292.0


func setup(pos: Vector2, p_vel: Vector2, p_col: Color, p_size: float) -> void:
	position = pos
	vel = p_vel
	col = p_col
	size = p_size
	rot = randf() * TAU
	rot_v = randf_range(-9, 9)


func _process(delta: float) -> void:
	t += delta
	vel.y += 1900.0 * delta
	position += vel * delta
	rot += rot_v * delta
	if position.y > ground_y:
		position.y = ground_y
		vel.y *= -0.35
		vel.x *= 0.65
		rot_v *= 0.6
	modulate.a = clampf(1.0 - t / life, 0.0, 1.0)
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	var r := Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size))
	draw_rect(r, col)
	draw_rect(r, col.darkened(0.4), false, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
