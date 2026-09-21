class_name RawLoader
extends RefCounted

## Runtime asset loader that bypasses the editor import pipeline.
## Reads raw PNG/WAV bytes from res:// (works in exported builds where files
## are stored unimported) and decodes them on the CPU. Results are cached so
## repeated loads (e.g. one SpriteMech per enemy) share a single texture.
##
## Why this exists: the headless editor import in this environment scans files
## but never produces .ctex/.sample conversions, so load("res://...png")
## fails at runtime ("No loader found") and mechs render invisible. Loading
## raw bytes directly is deterministic on every platform, including iOS Safari
## (which also can't use S3TC-compressed textures).

static var _tex_cache: Dictionary = {}
static var _wav_cache: Dictionary = {}


static func load_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var img := Image.new()
		if img.load_png_from_buffer(bytes) == OK:
			tex = ImageTexture.create_from_image(img)
		else:
			push_error("RawLoader: failed to decode PNG: " + path)
	else:
		push_error("RawLoader: texture file not found: " + path)
	_tex_cache[path] = tex
	return tex


static func load_wav(path: String) -> AudioStreamWAV:
	if _wav_cache.has(path):
		return _wav_cache[path] as AudioStreamWAV
	var stream: AudioStreamWAV = null
	if FileAccess.file_exists(path):
		stream = _parse_wav(path, FileAccess.get_file_as_bytes(path))
	else:
		push_error("RawLoader: audio file not found: " + path)
	_wav_cache[path] = stream
	return stream


## Minimal RIFF/WAVE parser for the PCM files make_audio.py produces
## (22050 Hz, mono, 16-bit). Returns null on anything it can't handle.
static func _parse_wav(path: String, bytes: PackedByteArray) -> AudioStreamWAV:
	if bytes.size() < 44:
		push_error("RawLoader: WAV too small: " + path)
		return null
	if bytes.slice(0, 4).get_string_from_ascii() != "RIFF" \
			or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		push_error("RawLoader: not a RIFF/WAVE file: " + path)
		return null
	var channels := 0
	var mix_rate := 0
	var bits := 0
	var data_pos := -1
	var data_len := 0
	var pos := 12
	while pos + 8 <= bytes.size():
		var chunk_id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size := int(bytes.decode_u32(pos + 4))
		if chunk_id == "fmt " and pos + 24 <= bytes.size():
			if bytes.decode_u16(pos + 8) != 1: # PCM only
				push_error("RawLoader: non-PCM WAV: " + path)
				return null
			channels = bytes.decode_u16(pos + 10)
			mix_rate = bytes.decode_u32(pos + 12)
			bits = bytes.decode_u16(pos + 22)
		elif chunk_id == "data":
			data_pos = pos + 8
			data_len = mini(chunk_size, bytes.size() - data_pos)
			break
		pos += 8 + chunk_size + (chunk_size & 1) # chunks are word-aligned
	if data_pos < 0 or channels < 1 or channels > 2 or mix_rate <= 0:
		push_error("RawLoader: unsupported WAV layout: " + path)
		return null
	var stream := AudioStreamWAV.new()
	match bits:
		8:
			stream.format = AudioStreamWAV.FORMAT_8_BITS
		16:
			stream.format = AudioStreamWAV.FORMAT_16_BITS
		_:
			push_error("RawLoader: unsupported WAV bit depth %d: %s" % [bits, path])
			return null
	stream.mix_rate = mix_rate
	stream.stereo = channels == 2
	stream.data = bytes.slice(data_pos, data_pos + data_len)
	return stream
