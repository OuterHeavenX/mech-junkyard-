class_name PlayerMech
extends CharacterBody2D

## The player's mech. Reads keyboard + touch input, owns the part loadout.

const GRAV := 2200.0
const DASH_SPEED := 950.0
const DASH_TIME := 0.18
const DASH_CD := 0.9

var game: MechGame
var touch: TouchControls
var hp := 100.0
var max_hp := 100.0
var loadout := {"arm": "rusty_fist", "leg": "basic_legs", "core": "none"}
var facing := 1
var attack_cd := 0.0
var dash_cd := 0.0
var dash_t := 0.0
var dash_dir := 1
var jumps_left := 1
var multi_ticks := 0
var multi_t := 0.0
var magnet_r := 90.0
var dead := false
var visual: SpriteMech
var _was_air := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 130)
	shape.position = Vector2(0, -70)
	shape.shape = rect
	add_child(shape)
	visual = SpriteMech.new()
	visual.mode = "player"
	visual.arm_id = str(loadout["arm"])
	add_child(visual)
	touch = get_tree().get_first_node_in_group("touch_controls") as TouchControls


func leg_speed() -> float:
	return float(PartsDB.LEGS[str(loadout["leg"])]["speed"])


func max_jumps() -> int:
	return int(PartsDB.LEGS[str(loadout["leg"])]["jumps"])


func _physics_process(delta: float) -> void:
	if dead:
		return
	var floor_y: float = game.floor_y
	# --- input ---
	var mx := Input.get_axis("move_left", "move_right")
	var want_jump := Input.is_action_just_pressed("jump")
	var want_attack := Input.is_action_just_pressed("attack")
	var want_dash := Input.is_action_just_pressed("dash")
	if touch != null and touch.active:
		mx += touch.joy_vec.x
		if touch.take_jump():
			want_jump = true
		if touch.take_attack():
			want_attack = true
		if touch.take_dash():
			want_dash = true
	mx = clampf(mx, -1.0, 1.0)

	var grounded := position.y >= floor_y - 1.0
	if grounded:
		jumps_left = max_jumps()

	# --- dash ---
	dash_cd = maxf(0.0, dash_cd - delta)
	if want_dash and dash_cd <= 0.0 and dash_t <= 0.0:
		dash_t = DASH_TIME
		dash_cd = DASH_CD
		dash_dir = facing if mx == 0.0 else int(sign(mx))
		game.spawn_sparks(position + Vector2(0, -60), Color(0.6, 0.9, 1.0), 8)
		game.spawn_dust(position)
		game.sfx("dash", -6.0)

	if dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0)
	else:
		# --- move ---
		var spd := leg_speed()
		velocity.x = mx * spd
		if mx != 0.0:
			facing = int(sign(mx))
		# --- gravity / jump ---
		velocity.y += GRAV * delta
		if want_jump and jumps_left > 0:
			velocity.y = -720.0
			jumps_left -= 1
			game.spawn_sparks(position, Color(0.7, 0.7, 0.7, 0.8), 5)
			game.sfx("jump", -6.0)

	position += velocity * delta
	if position.y > floor_y:
		position.y = floor_y
		velocity.y = 0.0
	var now_air := position.y < floor_y - 1.0
	if _was_air and not now_air:
		# Just landed.
		game.spawn_dust(position)
		game.sfx("land", -8.0)
	_was_air = now_air
	position.x = clampf(position.x, -600.0, 600.0)

	# --- attack ---
	attack_cd = maxf(0.0, attack_cd - delta)
	if want_attack and attack_cd <= 0.0:
		do_attack()
	# buzzsaw multi-hit ticks
	if multi_ticks > 0:
		multi_t -= delta
		if multi_t <= 0.0:
			multi_t = 0.08
			multi_ticks -= 1
			_melee_hit(float(PartsDB.ARMS["buzzsaw"]["dmg"]), float(PartsDB.ARMS["buzzsaw"]["range"]), false)
			if multi_ticks == 0:
				attack_cd = float(PartsDB.ARMS["buzzsaw"]["rate"]) * float(PartsDB.ARMS["buzzsaw"]["hits"])

	# --- regen core ---
	if str(loadout["core"]) == "regen_core" and hp < max_hp:
		hp = minf(max_hp, hp + float(PartsDB.CORES["regen_core"]["regen"]) * delta)

	# --- visual ---
	visual.facing = facing
	visual.arm_id = str(loadout["arm"])
	visual.walk_phase += absf(velocity.x) * delta * 0.045
	visual.stride = lerpf(visual.stride, clampf(absf(velocity.x) / leg_speed(), 0.0, 1.0) * 14.0, delta * 10.0)


func do_attack() -> void:
	if dead:
		return
	var arm: Dictionary = PartsDB.ARMS[str(loadout["arm"])]
	attack_cd = float(arm["rate"])
	visual.attack_t = 1.0
	match str(arm["kind"]):
		"spark", "melee", "heavy":
			_melee_hit(float(arm["dmg"]), float(arm["range"]), str(arm["kind"]) == "heavy")
			if str(arm["kind"]) == "heavy":
				game.sfx("heavy_slam")
			elif str(arm["kind"]) == "spark":
				game.sfx("spark_zap", -4.0)
			else:
				game.sfx("punch", -3.0)
		"multi":
			multi_ticks = int(arm["hits"])
			multi_t = 0.0
			game.sfx("saw", -4.0)
		"ranged":
			var from := position + Vector2(52.0 * facing, -92)
			var b := BoltShot.new()
			b.game = game
			get_parent().add_child(b)
			b.setup(from, Vector2(facing, 0), float(arm["dmg"]), true)
			game.sfx("cannon", -4.0)


func _melee_hit(dmg: float, reach: float, heavy: bool) -> void:
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: Vector2 = e.position - position
		if absf(d.y) < 110.0 and absf(d.x) <= reach and (signf(d.x) == float(facing) or absf(d.x) < reach * 0.5):
			e.take_damage(dmg, facing, heavy)
			hit_any = true
	if hit_any:
		if heavy:
			game.add_shake(0.45)
			game.spawn_sparks(position + Vector2(70 * facing, -80), Color(1, 0.8, 0.3), 14)
		else:
			game.spawn_sparks(position + Vector2(60 * facing, -80), Color(1, 0.9, 0.5), 6)


func take_damage(amount: float, from_x: float) -> void:
	if dead or dash_t > 0.0:
		return
	if str(loadout["core"]) == "armor_core":
		amount *= 1.0 - float(PartsDB.CORES["armor_core"]["armor"])
	hp -= amount
	visual.hurt_t = 1.0
	game.sfx("player_hurt", -4.0)
	game.popup(str(int(round(amount))), position + Vector2(0, -150), Color("ff6b6b"))
	game.spawn_sparks(position + Vector2(0, -90), Color(1, 0.4, 0.3), 8)
	var dir := signf(position.x - from_x)
	if dir == 0.0:
		dir = 1.0
	velocity.x = dir * 260.0
	velocity.y = -220.0
	game.add_shake(0.25)
	# Heavy hits can rip your arm clean off — the core fantasy.
	if amount >= 15.0 and str(loadout["arm"]) != "none" and randf() < 0.35:
		_rip_arm()
	if hp <= 0.0:
		_die()
	game.refresh_hud()


func _rip_arm() -> void:
	var old := str(loadout["arm"])
	loadout["arm"] = "none"
	game.spawn_part_pickup("arm", old, position + Vector2(randf_range(-40, 40), -70))
	game.announce("ARM RIPPED OFF!", Color("ff6b6b"))
	game.sfx("arm_rip")
	game.refresh_hud()


func try_pickup(pickup: PartPickup) -> void:
	if dead:
		return
	equip_part(pickup.part_type, pickup.part_id)
	pickup.queue_free()


func equip_part(ptype: String, pid: String) -> void:
	var old := str(loadout[ptype])
	if old == pid:
		game.add_scrap(5)
		game.popup("+5 SCRAP", position + Vector2(0, -160), Color("ffd75e"))
		return
	loadout[ptype] = pid
	if ptype == "core":
		magnet_r = float(PartsDB.CORES[pid].get("magnet", 90.0))
	if old != "none":
		# Deferred: equip often happens inside a physics callback (body_entered).
		game.call_deferred("spawn_part_pickup", ptype, old, position + Vector2(randf_range(-50, 50), -40))
	game.announce("EQUIPPED: " + PartsDB.part_name(ptype, pid), PartsDB.part_color(ptype, pid))
	game.spawn_sparks(position + Vector2(0, -90), PartsDB.part_color(ptype, pid), 12)
	game.sfx("pickup_clank", -3.0)
	game.refresh_hud()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func _die() -> void:
	dead = true
	game.spawn_debris(position + Vector2(0, -70), [Color("3fa7c4"), Color("1d2b33"), Color("ff9a3c")], 16)
	game.spawn_sparks(position + Vector2(0, -80), Color(1, 0.6, 0.2), 24)
	game.add_shake(0.8)
	visible = false
	set_physics_process(false)
	game.game_over()
