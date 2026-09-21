class_name EnemyMech
extends CharacterBody2D

## Mech AI: walker/speeder/crusher melee, gunner keeps range and fires bolts,
## charger telegraphs then dashes. Dies into parts.

const GRAV := 2200.0

const TYPES: Dictionary = {
	"walker": {"hp": 42.0, "speed": 95.0, "dmg": 8.0, "range": 80.0, "scale": 1.0,
		"body": Color("6b7f5e"), "dark": Color("2a3325"), "accent": Color("c4a03f")},
	"speeder": {"hp": 26.0, "speed": 185.0, "dmg": 6.0, "range": 72.0, "scale": 0.88,
		"body": Color("7f6b5e"), "dark": Color("332a25"), "accent": Color("3fc4a0")},
	"crusher": {"hp": 110.0, "speed": 62.0, "dmg": 18.0, "range": 95.0, "scale": 1.35,
		"body": Color("7f5e5e"), "dark": Color("332525"), "accent": Color("c43f3f")},
	"gunner": {"hp": 34.0, "speed": 80.0, "dmg": 10.0, "range": 420.0, "scale": 0.95,
		"body": Color("735e80"), "dark": Color("2d2533"), "accent": Color("bf8cff")},
	"charger": {"hp": 70.0, "speed": 70.0, "dmg": 16.0, "range": 70.0, "scale": 1.12,
		"body": Color("8c7a52"), "dark": Color("382f1e"), "accent": Color("ff8c33")},
}

var game: MechGame
var etype := "walker"
var hp := 42.0
var max_hp := 42.0
var speed := 95.0
var dmg := 8.0
var atk_range := 80.0
var state := "chase"
var state_t := 0.0
var facing := -1
var dead := false
var fire_cd := 0.0
var charge_cd := 2.0
var charge_dir := 1.0
var visual: SpriteMech


func setup(p_etype: String, p_game: MechGame) -> void:
	etype = p_etype
	game = p_game
	var t: Dictionary = TYPES[etype]
	hp = float(t["hp"])
	max_hp = hp
	speed = float(t["speed"])
	dmg = float(t["dmg"])
	atk_range = float(t["range"])


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0
	var t: Dictionary = TYPES[etype]
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 130) * float(t["scale"])
	shape.position = Vector2(0, -70) * float(t["scale"])
	shape.shape = rect
	add_child(shape)
	visual = SpriteMech.new()
	visual.mode = "enemy"
	visual.etype = etype
	visual.mech_scale = float(t["scale"])
	add_child(visual)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var player: PlayerMech = game.player
	var floor_y: float = game.floor_y
	velocity.y += GRAV * delta
	state_t -= delta
	fire_cd = maxf(0.0, fire_cd - delta)
	charge_cd = maxf(0.0, charge_cd - delta)

	if player == null or player.dead:
		velocity.x = 0.0
	else:
		var dx: float = player.position.x - position.x
		var adx := absf(dx)
		if etype == "gunner":
			_gunner_ai(dx, adx, delta)
		elif etype == "charger":
			_charger_ai(dx, adx, delta, player)
		else:
			_melee_ai(dx, adx, delta, player)

	position += velocity * delta
	if position.y > floor_y:
		position.y = floor_y
		velocity.y = 0.0
	position.x = clampf(position.x, -600.0, 600.0)

	visual.facing = facing
	visual.walk_phase += absf(velocity.x) * delta * 0.05
	visual.stride = lerpf(visual.stride, clampf(absf(velocity.x) / maxf(speed, 1.0), 0.0, 1.0) * 12.0, delta * 8.0)


func _separation() -> float:
	var push := 0.0
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != self:
			var ox: float = position.x - o.position.x
			if absf(ox) < 50.0:
				push += signf(ox) * 40.0
	return push


func _melee_ai(dx: float, adx: float, _delta: float, player: PlayerMech) -> void:
	match state:
		"chase":
			facing = int(signf(dx)) if dx != 0.0 else facing
			velocity.x = signf(dx) * speed + _separation()
			if adx < atk_range:
				state = "windup"
				state_t = 0.45 if etype != "crusher" else 0.65
				velocity.x = 0.0
		"windup":
			velocity.x = 0.0
			facing = int(signf(dx)) if dx != 0.0 else facing
			if state_t <= 0.0:
				state = "strike"
				state_t = 0.12
				visual.attack_t = 1.0
		"strike":
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.7 if etype != "crusher" else 1.0
				if adx < atk_range + 30.0 and absf(player.position.y - position.y) < 120.0:
					player.take_damage(dmg, position.x)
					if etype == "crusher":
						game.add_shake(0.35)
		"recover":
			velocity.x = 0.0
			if state_t <= 0.0:
				state = "chase"


func _gunner_ai(dx: float, adx: float, _delta: float) -> void:
	# Keeps its distance and fires scrap bolts.
	facing = int(signf(dx)) if dx != 0.0 else facing
	match state:
		"chase":
			if adx > atk_range + 60.0:
				velocity.x = signf(dx) * speed + _separation()
			elif adx < atk_range - 80.0:
				velocity.x = -signf(dx) * speed * 0.8
			else:
				velocity.x = _separation() * 0.5
				if fire_cd <= 0.0:
					state = "aim"
					state_t = 0.5
					velocity.x = 0.0
		"aim":
			velocity.x = 0.0
			visual.hurt_t = maxf(visual.hurt_t, 0.15) # visor glint telegraph
			if state_t <= 0.0:
				state = "chase"
				fire_cd = 2.4
				visual.attack_t = 1.0
				var b := BoltShot.new()
				b.game = game
				b.col = Color(0.85, 0.6, 1.0)
				get_parent().add_child(b)
				b.setup(position + Vector2(50.0 * facing, -92), Vector2(facing, -0.05), dmg, false)
				b.vel = b.vel.normalized() * 520.0
				game.sfx("cannon", -8.0, 1.3)
				game.spawn_sparks(position + Vector2(50.0 * facing, -92), Color(0.85, 0.6, 1.0), 6)


func _charger_ai(dx: float, adx: float, _delta: float, player: PlayerMech) -> void:
	match state:
		"chase":
			facing = int(signf(dx)) if dx != 0.0 else facing
			velocity.x = signf(dx) * speed + _separation()
			if adx < 430.0 and charge_cd <= 0.0:
				state = "telegraph"
				state_t = 0.7
				velocity.x = 0.0
				charge_dir = signf(dx) if dx != 0.0 else float(facing)
		"telegraph":
			# Flashing warning before the dash.
			velocity.x = 0.0
			visual.hurt_t = 0.25 + 0.2 * sin(state_t * 30.0)
			if state_t <= 0.0:
				state = "charge"
				state_t = 0.55
				visual.attack_t = 1.0
				game.sfx("dash", -2.0, 0.6)
		"charge":
			velocity.x = charge_dir * 720.0
			game.spawn_dust(position + Vector2(-charge_dir * 20.0, 0))
			if absf(player.position.x - position.x) < 60.0 and absf(player.position.y - position.y) < 130.0:
				player.take_damage(dmg, position.x)
				state = "tired"
				state_t = 1.4
				velocity.x = 0.0
			elif state_t <= 0.0:
				state = "tired"
				state_t = 1.4
				charge_cd = 3.5
		"tired":
			velocity.x = 0.0
			if state_t <= 0.0:
				state = "chase"


func take_damage(amount: float, dir: float, heavy: bool) -> void:
	if dead:
		return
	hp -= amount
	visual.hurt_t = 1.0
	var kb := 320.0 if heavy else 140.0
	velocity.x = dir * kb
	velocity.y = -160.0 if heavy else -60.0
	var col := Color("ffd75e") if not heavy else Color("ff9a3c")
	game.popup(str(int(round(amount))), position + Vector2(randf_range(-10, 10), -150 * visual.mech_scale), col)
	game.spawn_sparks(position + Vector2(0, -90 * visual.mech_scale), Color(1, 0.85, 0.4), 10 if heavy else 5)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	game.on_enemy_died(self)
	queue_free()
