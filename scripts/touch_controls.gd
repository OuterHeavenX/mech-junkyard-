class_name TouchControls
extends CanvasLayer

## Left-half virtual joystick + right-side ATK / JUMP / DASH buttons.
## Only visible on touch devices. The player polls take_*() edge triggers.

var active := false
var joy_vec := Vector2.ZERO

var _joy_id := -1
var _joy_origin := Vector2.ZERO
var _joy_cur := Vector2.ZERO
var _jump_q := false
var _attack_q := false
var _dash_q := false
var _zone: Control


func _ready() -> void:
	add_to_group("touch_controls")
	layer = 10
	active = DisplayServer.is_touchscreen_available()
	visible = active
	if not active:
		return
	# Left-half joystick zone.
	_zone = Control.new()
	_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zone.offset_right = -640.0
	_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_zone)
	_zone.gui_input.connect(_on_zone_input)
	_zone.draw.connect(_draw_zone)
	# Right-side buttons.
	_mk_button("ATK", Vector2(1090, 540), Vector2(150, 150), func() -> void: _attack_q = true)
	_mk_button("JUMP", Vector2(920, 580), Vector2(120, 120), func() -> void: _jump_q = true)
	_mk_button("DASH", Vector2(1090, 400), Vector2(110, 110), func() -> void: _dash_q = true)


func _mk_button(text: String, pos: Vector2, size: Vector2, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 26)
	b.modulate = Color(1, 1, 1, 0.55)
	b.button_down.connect(on_press)
	add_child(b)


func _on_zone_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and _joy_id == -1:
			_joy_id = ev.index
			_joy_origin = ev.position
			_joy_cur = ev.position
			joy_vec = Vector2.ZERO
			_zone.queue_redraw()
		elif not ev.pressed and ev.index == _joy_id:
			_joy_id = -1
			joy_vec = Vector2.ZERO
			_zone.queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == _joy_id:
		_joy_cur = ev.position
		var d := _joy_cur - _joy_origin
		joy_vec = d.limit_length(70.0) / 70.0
		_zone.queue_redraw()


func _draw_zone() -> void:
	if _joy_id == -1:
		return
	_zone.draw_circle(_joy_origin, 62, Color(1, 1, 1, 0.18))
	_zone.draw_arc(_joy_origin, 62, 0, TAU, 32, Color(1, 1, 1, 0.4), 3.0)
	_zone.draw_circle(_joy_origin + joy_vec * 62.0, 28, Color(1, 1, 1, 0.45))


func take_jump() -> bool:
	var q := _jump_q
	_jump_q = false
	return q


func take_attack() -> bool:
	var q := _attack_q
	_attack_q = false
	return q


func take_dash() -> bool:
	var q := _dash_q
	_dash_q = false
	return q
