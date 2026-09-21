class_name DamagePopup
extends Node2D

## Floating damage / pickup text.

var text := ""
var col := Color.WHITE
var t := 0.0
const LIFE := 0.8


func setup(p_text: String, pos: Vector2, p_col: Color) -> void:
	text = p_text
	col = p_col
	position = pos


func _process(delta: float) -> void:
	t += delta
	position.y -= 95.0 * delta
	modulate.a = clampf(1.0 - t / LIFE, 0.0, 1.0)
	if t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := 120.0
	draw_string_outline(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 20, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 20, col)
