## Autoload: pooled one-shot SFX players + looping ambient music.
## AudioMan.play("punch"), AudioMan.play("pickup_clank", -4.0)
## (no class_name: the autoload singleton itself provides the global name)
extends Node

const SFX := ["punch", "heavy_slam", "spark_zap", "saw", "cannon",
	"explosion", "player_hurt", "arm_rip", "pickup_clank", "scrap_tick",
	"ui_click", "shop_buy", "heal", "wave_horn", "jump", "dash", "land"]

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in SFX:
		var s: AudioStream = RawLoader.load_wav("res://assets/audio/%s.wav" % n)
		if s != null:
			_streams[n] = s
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	var loop: AudioStream = RawLoader.load_wav("res://assets/audio/ambient_loop.wav")
	if loop != null:
		_music.stream = loop
		_music.volume_db = -10.0
		add_child(_music)
		_music.play()


func play(sfx_name: String, vol_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = _streams.get(sfx_name)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.volume_db = vol_db
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return
