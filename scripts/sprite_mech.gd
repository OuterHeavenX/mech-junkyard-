class_name SpriteMech
extends Node2D

## Blender-rendered mech sprite rig. Drop-in replacement for MechVisual:
## same public fields (facing, arm_id, walk_phase, stride, attack_t, hurt_t,
## mech_scale) plus mode/etype selectors. Origin at the feet, like MechVisual.
##
## Player: body frames (no arm) + separate arm sprites per equipped part,
## swapped at the shoulder. Enemies: full-body frames with the arm baked in.

var facing := 1
var arm_id := "rusty_fist"
var walk_phase := 0.0
var stride := 0.0
var attack_t := 0.0
var hurt_t := 0.0
var mech_scale := 1.0
var mode := "player" # player | enemy
var etype := "walker"

const BODY_OFF := Vector2(0, -143) # feet (sprite y=313) -> node origin
const ARM_OFF := Vector2(1.4, -220) # shoulder pivot in node space
const PLAYER_ARMS := ["rusty_fist", "crusher_fist", "buzzsaw", "cannon_arm"]

var _body: Sprite2D
var _arm: Sprite2D
var _t := 0.0
var _body_frames: Dictionary = {}
var _arm_frames: Dictionary = {}


func _ready() -> void:
	_body = Sprite2D.new()
	_body.centered = true
	_body.position = BODY_OFF
	add_child(_body)
	_arm = Sprite2D.new()
	_arm.centered = true
	_arm.position = ARM_OFF # arm renders are centered on the shoulder pivot
	add_child(_arm)
	_load_frames()


func _load_frames() -> void:
	if mode == "player":
		for f in ["idle0", "idle1", "walk0", "walk1", "walk2", "walk3", "attack"]:
			_body_frames[f] = RawLoader.load_texture("res://assets/sprites/player/body_%s.png" % f)
		for aid in PLAYER_ARMS:
			_arm_frames[aid] = {
				"rest": RawLoader.load_texture("res://assets/sprites/player/arm_%s_rest.png" % aid),
				"attack": RawLoader.load_texture("res://assets/sprites/player/arm_%s_attack.png" % aid),
			}
	else:
		for f in ["idle", "walk0", "walk1", "walk2", "walk3", "attack"]:
			_body_frames[f] = RawLoader.load_texture("res://assets/sprites/enemies/%s_%s.png" % [etype, f])


func _process(delta: float) -> void:
	_t += delta
	if attack_t > 0.0:
		attack_t = maxf(0.0, attack_t - delta * 3.5)
	if hurt_t > 0.0:
		hurt_t = maxf(0.0, hurt_t - delta * 5.0)

	var key := "attack" if attack_t > 0.45 else ""
	if key == "":
		if stride > 0.2:
			key = "walk%d" % (int(walk_phase / 1.1) % 4)
		elif mode == "player":
			key = "idle%d" % (int(_t * 1.6) % 2)
		else:
			key = "idle" if _body_frames.has("idle") else "idle0"
	if _body_frames.has(key):
		_body.texture = _body_frames[key]

	# Facing flip; keep world scale from mech_scale.
	scale = Vector2(mech_scale * float(facing), mech_scale)

	# Player arm overlay.
	if mode == "player" and _arm_frames.has(arm_id):
		_arm.visible = true
		var set: Dictionary = _arm_frames[arm_id]
		_arm.texture = set["attack"] if attack_t > 0.45 else set["rest"]
		if arm_id == "buzzsaw":
			_arm.rotation += delta * 20.0
		elif _arm.rotation != 0.0:
			_arm.rotation = 0.0
	else:
		_arm.visible = false

	# Hurt flash.
	var b := 1.0 + hurt_t * 1.6
	modulate = Color(b, b, b)
