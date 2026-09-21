class_name PartPickup
extends Area2D

## A mech part lying on the ground. Walks-over equip; magnet cores pull it in.

var part_type := "arm"
var part_id := "rusty_fist"
var bob := 0.0
var age := 0.0
const LIFE := 45.0


func setup(ptype: String, pid: String) -> void:
	part_type = ptype
	part_id = pid


func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	add_child(shape)
	bob = randf() * TAU
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	bob += delta * 3.0
	age += delta
	# Magnet pull toward the player.
	var player := get_tree().get_first_node_in_group("player") as PlayerMech
	if player != null and not player.dead:
		var d: float = position.distance_to(player.position + Vector2(0, -60))
		if d < player.magnet_r and d > 8.0:
			position = position.move_toward(player.position + Vector2(0, -60), 520.0 * delta)
	if age > LIFE:
		var a := clampf(1.0 - (age - LIFE) / 2.0, 0.0, 1.0)
		modulate.a = a
		if a <= 0.0:
			queue_free()
	queue_redraw()


func _on_body(b: Node2D) -> void:
	if b.is_in_group("player"):
		(b as PlayerMech).try_pickup(self)


func _draw() -> void:
	var col := PartsDB.part_color(part_type, part_id)
	var yo := sin(bob) * 5.0
	# Glow pad.
	for i in 3:
		draw_circle(Vector2(0, yo), 26.0 - i * 6.0, Color(col, 0.12 + 0.08 * i))
	# Icon per part.
	var c := Vector2(0, yo - 6)
	match part_type:
		"arm":
			match part_id:
				"crusher_fist":
					draw_rect(Rect2(c + Vector2(-15, -13), Vector2(30, 26)), Color("3a3f45"))
					draw_rect(Rect2(c + Vector2(-15, -13), Vector2(30, 8)), col)
				"buzzsaw":
					draw_circle(c, 15, Color("c9d4dc"))
					draw_circle(c, 15, Color("5a646e"), false, 2.0)
					for t in 8:
						var a := bob * 2.0 + TAU * t / 8.0
						draw_line(c + Vector2(cos(a), sin(a)) * 13, c + Vector2(cos(a), sin(a)) * 18, Color("e8eef2"), 3.0)
				"cannon_arm":
					draw_rect(Rect2(c + Vector2(-20, -7), Vector2(40, 14)), Color("3a3f45"))
					draw_circle(c + Vector2(20, 0), 6, col)
				_:
					draw_circle(c, 13, Color("3a3f45"))
					draw_circle(c + Vector2(3, -3), 7, col)
		"leg":
			for lx in [-9.0, 9.0]:
				draw_line(c + Vector2(lx, -14), c + Vector2(lx, 12), Color("3a3f45"), 8.0)
				draw_rect(Rect2(c + Vector2(lx - 9, 8), Vector2(18, 7)), col)
		"core":
			var pts := PackedVector2Array()
			for i in 6:
				var a := TAU * i / 6.0 + bob * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * 15.0)
			draw_colored_polygon(pts, Color("3a3f45"))
			draw_circle(c, 7, col)
	# Label.
	var font := ThemeDB.fallback_font
	var nm := PartsDB.part_name(part_type, part_id)
	draw_string(font, Vector2(-60, 34 + yo * 0.3), nm, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.9))
