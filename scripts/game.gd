class_name MechGame
extends Node2D

## Arena orchestrator: waves, spawning, drops, FX, screen shake, end states.

const WAVES: Array = [
	{"walker": 3},
	{"walker": 4, "speeder": 2},
	{"walker": 4, "speeder": 3, "crusher": 1},
	{"walker": 4, "speeder": 3, "crusher": 1, "gunner": 2},
	{"walker": 5, "speeder": 4, "crusher": 2, "gunner": 2, "charger": 2},
]

const ENEMY_NAMES := {"walker": "RUST WALKER", "speeder": "SPEEDER",
	"crusher": "CRUSHER", "gunner": "GUNNER", "charger": "CHARGER"}

const DROP_POOLS: Dictionary = {
	"walker": [["arm", "rusty_fist"], ["leg", "spring_legs"], ["core", "armor_core"], ["leg", "turbo_legs"]],
	"speeder": [["leg", "turbo_legs"], ["core", "magnet_core"], ["arm", "buzzsaw"], ["leg", "spring_legs"]],
	"crusher": [["arm", "crusher_fist"], ["arm", "cannon_arm"], ["core", "regen_core"], ["core", "armor_core"]],
	"gunner": [["arm", "cannon_arm"], ["core", "magnet_core"], ["leg", "turbo_legs"], ["core", "regen_core"]],
	"charger": [["arm", "crusher_fist"], ["leg", "spring_legs"], ["core", "armor_core"], ["arm", "buzzsaw"]],
}

var player: PlayerMech
var hud: MechHUD
var touch: TouchControls
var cam: Camera2D
var floor_y := 280.0
var wave_idx := 0
var spawn_queue: Array = []
var spawn_t := 0.0
var scrap := 0
var shake := 0.0
var state := "fight" # fight | shop | over | victory
var rng := RandomNumberGenerator.new()
var _lamps: Array = []
var _lamp_t := 0.0


func _ready() -> void:
	rng.seed = 20260920
	_setup_input()
	add_child(JunkyardBG.new())
	player = PlayerMech.new()
	player.game = self
	player.position = Vector2(-320, floor_y)
	add_child(player)
	cam = Camera2D.new()
	cam.position = Vector2(0, 20)
	add_child(cam)
	cam.make_current()
	touch = TouchControls.new()
	add_child(touch)
	hud = MechHUD.new()
	hud.game = self
	add_child(hud)
	# TouchControls looked for the group in player._ready, which ran before it
	# existed — re-link now.
	player.touch = touch
	_setup_lighting()
	start_wave(0)
	refresh_hud()


func _setup_input() -> void:
	if InputMap.has_action("move_left"):
		return # persists across scene reloads
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_W, KEY_UP, KEY_SPACE])
	_add_keys("attack", [KEY_J, KEY_X])
	_add_keys("dash", [KEY_K, KEY_SHIFT, KEY_L])


func _add_keys(action: String, keys: Array) -> void:
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func spawn_dust(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.amount = 9
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.spread = 160.0
	p.direction = Vector2(0, -1)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 190.0
	p.gravity = Vector2(0, 260)
	p.damping_min = 60.0
	p.damping_max = 140.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(0.62, 0.57, 0.5, 0.55)
	p.position = pos + Vector2(0, -6)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _lamp_texture() -> Texture2D:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1.0, 0.62, 0.28, a))
	return ImageTexture.create_from_image(img)


func _setup_lighting() -> void:
	var cm := CanvasModulate.new()
	cm.color = Color(0.86, 0.88, 1.0)
	add_child(cm)
	# Flickering work-lamps over the fire pits.
	var tex := _lamp_texture()
	for f in [Vector2(-420, 240), Vector2(180, 245), Vector2(520, 238)]:
		var lamp := PointLight2D.new()
		lamp.texture = tex
		lamp.texture_scale = 4.2
		lamp.energy = 0.85
		lamp.position = f
		add_child(lamp)
		_lamps.append(lamp)


func _process(delta: float) -> void:
	# Screen shake.
	shake = maxf(0.0, shake - delta * 2.2)
	if shake > 0.0:
		cam.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * 14.0
	else:
		cam.offset = Vector2.ZERO
	# Lamp flicker.
	_lamp_t += delta
	for i in _lamps.size():
		var lamp: PointLight2D = _lamps[i]
		lamp.energy = 0.85 + 0.18 * sin(_lamp_t * 9.0 + i * 2.4) + 0.08 * sin(_lamp_t * 23.0 + i * 5.1)
	if state == "fight":
		if not spawn_queue.is_empty():
			spawn_t -= delta
			if spawn_t <= 0.0:
				spawn_t = 1.1
				var etype: String = spawn_queue.pop_back()
				spawn_enemy(etype)
		elif get_tree().get_nodes_in_group("enemies").is_empty():
			if wave_idx >= WAVES.size() - 1:
				victory()
			else:
				state = "shop"
				if player != null:
					player.heal(25.0)
				announce("WAVE CLEARED!", Color("7dff9a"))
				sfx("heal", -4.0)
				hud.show_shop(true)
				refresh_hud()


func start_wave(i: int) -> void:
	spawn_queue.clear()
	var w: Dictionary = WAVES[i]
	for etype in w:
		for n in int(w[etype]):
			spawn_queue.append(etype)
	spawn_queue.shuffle()
	spawn_t = 0.5
	var bits: Array = []
	for etype in w:
		bits.append("%s x%d" % [ENEMY_NAMES.get(etype, etype), int(w[etype])])
	hud.announce("WAVE %d" % (i + 1), Color("ff9a3c"), "  ·  ".join(bits))
	sfx("wave_horn", -4.0)
	refresh_hud()


func next_wave() -> void:
	if state != "shop":
		return
	hud.show_shop(false)
	sfx("ui_click", -4.0)
	wave_idx += 1
	start_wave(wave_idx)
	state = "fight"


# --- scrap shop (between waves) ---
func shop_cost(item: String) -> int:
	match item:
		"repair":
			return 15 + 10 * wave_idx
		"plating":
			return 45
		"crate":
			return 60
	return 9999


func buy(item: String) -> void:
	if state != "shop" or player == null or player.dead:
		return
	var cost := shop_cost(item)
	if scrap < cost:
		announce("NOT ENOUGH SCRAP", Color("e05252"))
		sfx("ui_click", -8.0, 0.7)
		return
	scrap -= cost
	match item:
		"repair":
			player.heal(50.0)
			popup("+50 HP", player.position + Vector2(0, -170), Color("7dff9a"))
		"plating":
			player.max_hp += 25.0
			player.heal(25.0)
			popup("MAX HP +25", player.position + Vector2(0, -170), Color("7dff9a"))
		"crate":
			var pool: Array = []
			for plist in DROP_POOLS.values():
				pool.append_array(plist)
			var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
			spawn_part_pickup(pick[0], pick[1], player.position + Vector2(rng.randf_range(-80, 80), -40))
	sfx("shop_buy", -3.0)
	refresh_hud()


func spawn_enemy(etype: String, at_x: float = 99999.0) -> void:
	var e := EnemyMech.new()
	e.setup(etype, self)
	if at_x > 90000.0:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		at_x = side * rng.randf_range(480, 590)
	e.position = Vector2(at_x, floor_y)
	add_child(e)
	spawn_sparks(e.position + Vector2(0, -80), Color(0.8, 0.3, 0.2), 10)


func on_enemy_died(e: EnemyMech) -> void:
	var base := e.position + Vector2(0, -60)
	# Wreck debris in the enemy's colors.
	var t: Dictionary = EnemyMech.TYPES[e.etype]
	spawn_debris(base, [t["body"], t["dark"], t["accent"]], 12 if e.etype != "crusher" else 18)
	spawn_sparks(base, Color(1, 0.6, 0.2), 14)
	sfx("explosion", -4.0)
	add_shake(0.3 if e.etype != "crusher" else 0.55)
	popup("WRECKED", base + Vector2(0, -60), Color("ffd75e"))
	# Scrap burst.
	var n_scrap := 3 + wave_idx
	for i in n_scrap:
		var s := ScrapPickup.new()
		s.position = base + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 0))
		add_child(s)
	# 1-2 part drops from the enemy's loot pool.
	var pool: Array = DROP_POOLS[e.etype]
	var drop: Array = pool[rng.randi_range(0, pool.size() - 1)]
	spawn_part_pickup(drop[0], drop[1], base + Vector2(rng.randf_range(-60, 60), -10))
	if rng.randf() < 0.45:
		var drop2: Array = pool[rng.randi_range(0, pool.size() - 1)]
		spawn_part_pickup(drop2[0], drop2[1], base + Vector2(rng.randf_range(-60, 60), -10))


func spawn_part_pickup(ptype: String, pid: String, pos: Vector2) -> void:
	# Cap ground clutter: oldest pickup fades out.
	var pickups := get_tree().get_nodes_in_group("pickups")
	if pickups.size() >= 14:
		pickups[0].queue_free()
	var p := PartPickup.new()
	p.setup(ptype, pid)
	p.position = Vector2(clampf(pos.x, -600, 600), floor_y - 12.0)
	add_child(p)


func spawn_debris(pos: Vector2, colors: Array, count: int) -> void:
	for i in count:
		var d := DebrisChunk.new()
		add_child(d)
		d.setup(pos, Vector2(rng.randf_range(-320, 320), rng.randf_range(-650, -150)),
			colors[rng.randi_range(0, colors.size() - 1)], rng.randf_range(6, 15))


func spawn_sparks(pos: Vector2, col: Color, count: int) -> void:
	var p := CPUParticles2D.new()
	p.amount = count
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = col
	p.position = pos
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func popup(text: String, pos: Vector2, col: Color) -> void:
	var d := DamagePopup.new()
	add_child(d)
	d.setup(text, pos, col)


func announce(text: String, col: Color = Color.WHITE) -> void:
	hud.announce(text, col)


## Null-safe SFX via the AudioMan autoload (avoids a hard compile-time
## dependency so -s script-mode tests keep working).
func sfx(sfx_name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var a := get_tree().root.get_node_or_null("AudioMan")
	if a != null:
		a.play(sfx_name, vol_db, pitch)


func add_scrap(n: int) -> void:
	scrap += n
	refresh_hud()


func add_shake(a: float) -> void:
	shake = minf(1.0, shake + a)


func refresh_hud() -> void:
	if hud != null:
		hud.refresh()


func game_over() -> void:
	if state == "over":
		return
	state = "over"
	hud.show_end(false)


func victory() -> void:
	if state == "victory":
		return
	state = "victory"
	hud.announce("JUNKYARD CHAMPION!", Color("ffd75e"))
	hud.show_end(true)


func restart() -> void:
	get_tree().reload_current_scene()
