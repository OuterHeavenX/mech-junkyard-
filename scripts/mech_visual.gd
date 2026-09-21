class_name MechVisual
extends Node2D

## Procedural mech drawing shared by the player and enemies.
## Owner sets palette / arm / animation state; this node redraws every frame.

var body_col := Color("3fa7c4")
var dark_col := Color("1d2b33")
var accent_col := Color("ff9a3c")
var glow_col := Color("7df9ff")
var arm_id := "rusty_fist"
var walk_phase := 0.0
var stride := 0.0 # 0 = idle, up to ~14 when moving
var attack_t := 0.0 # 1 -> 0 punch animation
var facing := 1
var hurt_t := 0.0
var mech_scale := 1.0
var saw_spin := 0.0
var spiky := false # crusher enemies get torso spikes


func _process(delta: float) -> void:
	if attack_t > 0.0:
		attack_t = maxf(0.0, attack_t - delta * 3.5)
	if hurt_t > 0.0:
		hurt_t = maxf(0.0, hurt_t - delta * 5.0)
	saw_spin += delta * (22.0 if arm_id == "buzzsaw" else 2.0)
	queue_redraw()


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var s := mech_scale
	var fx := float(facing)
	# Ground shadow.
	_ellipse(Vector2(0, 6 * s), 36 * s, 9 * s, Color(0, 0, 0, 0.35))

	var hip_y := -56.0 * s
	# Legs (two-segment, animated walk).
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var ph := walk_phase + (PI if i == 1 else 0.0)
		var swing := sin(ph) * stride * s
		var lift := maxf(0.0, cos(ph)) * stride * 0.35 * s
		var hip := Vector2(side * 10.0 * s, hip_y)
		var foot := Vector2(side * 10.0 * s + swing, -lift)
		var mid := (hip + foot) * 0.5 + Vector2(side * 5.0 * s, -4.0 * s)
		draw_line(hip, mid, dark_col, 10.0 * s)
		draw_line(mid, foot, dark_col, 8.0 * s)
		draw_rect(Rect2(foot + Vector2(-11, -6) * s, Vector2(22, 9) * s), dark_col)
		draw_rect(Rect2(foot + Vector2(-11, -6) * s, Vector2(22, 3) * s), accent_col)

	# Torso.
	var torso := Rect2(Vector2(-24, -114) * s, Vector2(48, 62) * s)
	draw_rect(torso, body_col)
	draw_rect(Rect2(Vector2(-24, -114) * s, Vector2(48, 14) * s), dark_col)
	draw_rect(Rect2(Vector2(-18, -94) * s, Vector2(36, 30) * s), body_col.darkened(0.25))
	# Rivets.
	for rp in [Vector2(-18, -108), Vector2(18, -108), Vector2(-18, -58), Vector2(18, -58)]:
		draw_circle(rp * s, 2.2 * s, dark_col)
	if spiky:
		for sx in [-16.0, 0.0, 16.0]:
			var base := Vector2(sx * s, -114.0 * s)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-6, 0) * s, base + Vector2(6, 0) * s, base + Vector2(0, -14) * s]), dark_col)

	# Head + visor.
	draw_rect(Rect2(Vector2(-15, -140) * s, Vector2(30, 28) * s), dark_col)
	var vx := (2.0 if fx > 0.0 else -14.0) * s
	draw_rect(Rect2(Vector2(vx, -134) * s, Vector2(12, 11) * s), glow_col)
	draw_line(Vector2(-6, -140) * s, Vector2(-6, -152) * s, dark_col, 3.0 * s)
	draw_circle(Vector2(-6, -154) * s, 3.0 * s, accent_col)

	# Arm, anchored at shoulder.
	var shoulder := Vector2(24.0 * fx * s, -100.0 * s)
	draw_circle(shoulder, 11.0 * s, dark_col)
	var ext := sin(attack_t * PI) * 34.0 * s if attack_t > 0.0 else 0.0
	var hand := shoulder + Vector2((24.0 * s + ext) * fx, 8.0 * s)
	match arm_id:
		"none":
			draw_line(shoulder, hand, dark_col, 7.0 * s)
			if attack_t > 0.0:
				for k in 3:
					var a := -0.6 + 0.6 * float(k) + attack_t * 2.0
					var d := Vector2(cos(a) * fx, sin(a)) * 16.0 * s
					draw_line(hand, hand + d, Color(0.6, 0.9, 1.0, attack_t), 3.0 * s)
		"buzzsaw":
			draw_line(shoulder, hand, dark_col, 9.0 * s)
			var bc: Vector2 = hand + Vector2(14.0 * fx * s, 0)
			draw_circle(bc, 17.0 * s, Color("c9d4dc"))
			draw_circle(bc, 17.0 * s, Color("5a646e"), false, 2.0 * s)
			for t in 8:
				var a := saw_spin + TAU * float(t) / 8.0
				var p1 := bc + Vector2(cos(a), sin(a)) * 15.0 * s
				var p2 := bc + Vector2(cos(a), sin(a)) * 21.0 * s
				draw_line(p1, p2, Color("e8eef2"), 4.0 * s)
			draw_circle(bc, 5.0 * s, accent_col)
		"cannon_arm":
			var tip := shoulder + Vector2((52.0 * s + ext) * fx, 8.0 * s)
			draw_line(shoulder + Vector2(0, 8 * s), tip, dark_col, 15.0 * s)
			draw_line(shoulder + Vector2(0, 8 * s), tip, body_col.darkened(0.2), 9.0 * s)
			if attack_t > 0.35:
				draw_circle(tip, 10.0 * s * attack_t, Color(1.0, 0.7, 0.2, attack_t))
		"crusher_fist":
			draw_line(shoulder, hand, dark_col, 12.0 * s)
			var hc := hand + Vector2(10.0 * fx * s, 0)
			draw_rect(Rect2(hc + Vector2(-17, -15) * s, Vector2(34, 30) * s), dark_col)
			draw_rect(Rect2(hc + Vector2(-17, -15) * s, Vector2(34, 9) * s), accent_col)
			draw_rect(Rect2(hc + Vector2(-17, 6) * s, Vector2(34, 9) * s), accent_col)
		_:
			draw_line(shoulder, hand, dark_col, 9.0 * s)
			draw_circle(hand, 11.0 * s, dark_col)
			draw_circle(hand + Vector2(3 * fx, -3) * s, 6.0 * s, accent_col)

	# Hurt flash.
	if hurt_t > 0.0:
		draw_rect(torso, Color(1, 1, 1, hurt_t * 0.55))
