class_name JunkyardBG
extends Node2D

## Layered procedural junkyard backdrop: gradient dusk sky, moon, far silhouettes,
## mid junk piles, animated fire pits, blinking beacons, hazard-striped floor.

var t := 0.0
var rng := RandomNumberGenerator.new()
var far_shapes: Array = []
var mid_shapes: Array = []
var floor_bits: Array = []
var fires: Array = [Vector2(-420, 300), Vector2(180, 305), Vector2(520, 298)]
var beacons: Array = [Vector2(-260, 90), Vector2(360, 60)]


func _ready() -> void:
	rng.seed = 1337
	# Far silhouette junk mounds.
	for i in 26:
		var x := rng.randf_range(-700, 700)
		var w := rng.randf_range(60, 200)
		var h := rng.randf_range(30, 130)
		far_shapes.append([x, w, h])
	# Mid piles with girders.
	for i in 18:
		var x := rng.randf_range(-680, 680)
		var w := rng.randf_range(40, 140)
		var h := rng.randf_range(20, 90)
		mid_shapes.append([x, w, h, rng.randf_range(0, TAU)])
	# Floor scatter.
	for i in 60:
		floor_bits.append([rng.randf_range(-640, 640), rng.randf_range(320, 700),
			rng.randf_range(4, 16), rng.randf_range(0, TAU)])


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _mound(c: Vector2, w: float, h: float, col: Color, jag: float) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-w / 2, 0))
	var n := 7
	for i in n + 1:
		var fx := -w / 2 + w * i / n
		var fy := -h * (0.55 + 0.45 * absf(sin(i * jag + w)))
		pts.append(c + Vector2(fx, fy))
	pts.append(c + Vector2(w / 2, 0))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	# Dusk gradient sky.
	var top := Color("141c2e")
	var mid := Color("2b2135")
	var hor := Color("59331f")
	var bands := 24
	for i in bands:
		var f := float(i) / bands
		var c := top.lerp(mid, clampf(f * 2.0, 0, 1)).lerp(hor, clampf((f - 0.5) * 2.0, 0, 1))
		draw_rect(Rect2(-700, -400 + f * 680, 1400, 680.0 / bands + 1), c)
	# Moon + glow.
	var moon := Vector2(430, -260)
	for i in 4:
		draw_circle(moon, 90 - i * 16, Color(0.9, 0.85, 0.7, 0.05 + 0.03 * i))
	draw_circle(moon, 34, Color("e8dfc8"))
	draw_circle(moon + Vector2(-10, -6), 8, Color("d3c9b2"))
	draw_circle(moon + Vector2(9, 8), 5, Color("d3c9b2"))
	# Far silhouettes.
	for s in far_shapes:
		_mound(Vector2(s[0], 280), s[1], s[2], Color("1c2333"), 1.7)
	# Crane silhouette.
	draw_rect(Rect2(-620, -40, 14, 320), Color("161c28"))
	draw_rect(Rect2(-690, -52, 150, 12), Color("161c28"))
	draw_line(Vector2(-620, -52), Vector2(-560, 40), Color("161c28"), 4.0)
	draw_rect(Rect2(-566, 40, 12, 26), Color("161c28"))
	# Mid junk piles.
	for s in mid_shapes:
		_mound(Vector2(s[0], 292), s[1], s[2], Color("232b3a"), 2.3)
		var gx: float = s[0]
		var ga: float = s[3]
		draw_line(Vector2(gx - 30, 292), Vector2(gx + 30, 292 - s[2] - 40), Color("2e3747"), 6.0)
	# Blinking beacons.
	for b in beacons:
		var on := sin(t * 3.0 + b.x) > 0.2
		draw_line(b + Vector2(0, 120), b, Color("161c28"), 5.0)
		draw_circle(b, 6, Color(1, 0.2, 0.2) if on else Color(0.4, 0.1, 0.1))
		if on:
			draw_circle(b, 14, Color(1, 0.2, 0.2, 0.25))
	# Ground.
	draw_rect(Rect2(-700, 280, 1400, 440), Color("2a2622"))
	draw_rect(Rect2(-700, 280, 1400, 10), Color("3a352d"))
	# Hazard stripes along the fight line.
	var stripe_w := 40.0
	var x := -680.0
	var k := 0
	while x < 680.0:
		var c := Color("c9a227") if k % 2 == 0 else Color("26221c")
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 280), Vector2(x + stripe_w / 2, 280),
			Vector2(x + stripe_w / 2 - 12, 296), Vector2(x - 12, 296)]), c)
		x += stripe_w / 2
		k += 1
	# Floor scatter bits.
	for b in floor_bits:
		var bp := Vector2(b[0], b[1])
		var bs: float = b[2]
		var ba: float = b[3]
		var p1 := bp + Vector2(cos(ba), sin(ba)) * bs
		var p2 := bp - Vector2(cos(ba), sin(ba)) * bs
		draw_line(p1, p2, Color("3d3830"), 3.0)
	# Fire pits: glow + animated flames + rising smoke dots.
	for f in fires:
		var fl := 0.75 + 0.25 * sin(t * 9.0 + f.x)
		for i in 3:
			draw_circle(f, 46 - i * 12, Color(1, 0.5, 0.15, 0.06 * fl + 0.02 * i))
		draw_ell(f)
		for i in 5:
			var fx2: float = f.x + sin(t * 7.0 + i * 1.7 + f.x) * 8.0
			var fy2: float = f.y - 8.0 - i * 9.0 - sin(t * 11.0 + i * 2.3) * 4.0
			var fs := (10.0 - i * 1.4) * fl
			draw_colored_polygon(PackedVector2Array([
				Vector2(fx2 - fs * 0.5, fy2), Vector2(fx2 + fs * 0.5, fy2), Vector2(fx2, fy2 - fs)]),
				Color(1.0, 0.45 + 0.1 * i, 0.1))
		# Smoke.
		for i in 4:
			var st := fmod(t * 0.5 + i * 0.25 + f.x * 0.01, 1.0)
			var sp: Vector2 = f + Vector2(sin(st * 5.0 + i) * 14.0, -20.0 - st * 90.0)
			draw_circle(sp, 6.0 + st * 10.0, Color(0.15, 0.14, 0.16, 0.25 * (1.0 - st)))


func draw_ell(c: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(c + Vector2(cos(a) * 34.0, sin(a) * 9.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
