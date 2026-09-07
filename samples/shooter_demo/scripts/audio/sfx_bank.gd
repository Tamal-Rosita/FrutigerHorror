extends Object
class_name SfxBank

## Procedural placeholder weapon sounds (PCM-synthesized at runtime, no assets).
## Replace later by swapping these calls for real stream assets.

const RATE := 22050


static func play_shot(parent: Node, pitch_var: float, with_bullet: bool) -> void:
	var wav := _bullet_sound() if with_bullet else _dry_sound()
	_play(parent, wav, 1.0 + pitch_var, -4.0 if with_bullet else -10.0)


static func play_reload(parent: Node) -> void:
	_play(parent, _reload_sound(), 1.0, -6.0)


static func play_hit(parent: Node) -> void:
	_play(parent, _hit_sound(), randf_range(0.95, 1.1), -8.0)


static func _play(parent: Node, stream: AudioStreamWAV, pitch: float, volume_db: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


static func _bullet_sound() -> AudioStreamWAV:
	var body := 0.45 * (randf() * 0.3 + 0.85)
	return _synth(0.12, func(t: float) -> float:
		var v := randf_range(-1.0, 1.0) * exp(-t * 70.0)
		v += sin(TAU * 130.0 * t) * body * exp(-t * 30.0)
		return v * 0.9)


static func _dry_sound() -> AudioStreamWAV:
	return _synth(0.06, func(t: float) -> float:
		return randf_range(-1.0, 1.0) * exp(-t * 110.0) * 0.5 + sin(TAU * 900.0 * t) * exp(-t * 160.0) * 0.25)


static func _reload_sound() -> AudioStreamWAV:
	return _synth(0.6, func(t: float) -> float:
		var v := 0.0
		if t < 0.05: # mag release click
			v += randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.8
		elif t > 0.18 and t < 0.5: # magazine slide noise
			v += randf_range(-1.0, 1.0) * exp(-(t - 0.18) * 45.0) * 0.35
		if t > 0.42 and t < 0.6: # bolt clack
			var tt := t - 0.42
			v += sin(TAU * 700.0 * tt) * exp(-tt * 140.0) * 0.5
		return v)


static func _hit_sound() -> AudioStreamWAV:
	return _synth(0.1, func(t: float) -> float:
		return sin(TAU * (1200.0 + 400.0 * exp(-t * 30.0)) * t) * exp(-t * 90.0) * 0.7)


static func _synth(duration: float, sample_fn: Callable) -> AudioStreamWAV:
	var count := int(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var s: float = clampf(sample_fn.call(t), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
