class_name EnemyMech
extends CharacterBody2D

## Simple walker AI: approach the player, wind up, melee strike, die into parts.

const GRAV := 2200.0

const TYPES: Dictionary = {
	"walker": {"hp": 42.0, "speed": 95.0, "dmg": 8.0, "range": 80.0, "scale": 1.0,
		"body": Color("6b7f5e"), "dark": Color("2a3325"), "accent": Color("c4a03f"), "glow": Color("ffb347")},
	"speeder": {"hp": 26.0, "speed": 185.0, "dmg": 6.0, "range": 72.0, "scale": 0.88,
		"body": Color("7f6b5e"), "dark": Color("332a25"), "accent": Color("3fc4a0"), "glow": Color("7dffd4")},
	"crusher": {"hp": 110.0, "speed": 62.0, "dmg": 18.0, "range": 95.0, "scale": 1.35,
		"body": Color("7f5e5e"), "dark": Color("332525"), "accent": Color("c43f3f"), "glow": Color("ff6b6b")},
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
var visual: MechVisual


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
	visual = MechVisual.new()
	visual.body_col = t["body"]
	visual.dark_col = t["dark"]
	visual.accent_col = t["accent"]
	visual.glow_col = t["glow"]
	visual.mech_scale = float(t["scale"])
	visual.spiky = etype == "crusher"
	visual.arm_id = "crusher_fist" if etype == "crusher" else "rusty_fist"
	add_child(visual)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var player: PlayerMech = game.player
	var floor_y: float = game.floor_y
	velocity.y += GRAV * delta
	state_t -= delta

	if player == null or player.dead:
		velocity.x = 0.0
	else:
		var dx: float = player.position.x - position.x
		var adx := absf(dx)
		match state:
			"chase":
				facing = int(signf(dx)) if dx != 0.0 else facing
				# Gentle separation so walkers don't stack.
				var push := 0.0
				for o in get_tree().get_nodes_in_group("enemies"):
					if o != self:
						var ox: float = position.x - o.position.x
						if absf(ox) < 50.0:
							push += signf(ox) * 40.0
				velocity.x = signf(dx) * speed + push
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

	position += velocity * delta
	if position.y > floor_y:
		position.y = floor_y
		velocity.y = 0.0
	position.x = clampf(position.x, -600.0, 600.0)

	visual.facing = facing
	visual.walk_phase += absf(velocity.x) * delta * 0.05
	visual.stride = lerpf(visual.stride, clampf(absf(velocity.x) / speed, 0.0, 1.0) * 12.0, delta * 8.0)


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
