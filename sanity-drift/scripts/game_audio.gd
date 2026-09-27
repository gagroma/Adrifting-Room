class_name GameAudio
extends Node

var enabled := true
var gravity_impact_stream: AudioStreamWAV


func _ready() -> void:
	if enabled:
		gravity_impact_stream = _make_gravity_impact()


func play_gravity_impact(soft := false) -> void:
	if not enabled:
		return
	if gravity_impact_stream == null:
		gravity_impact_stream = _make_gravity_impact()
	var player := AudioStreamPlayer.new()
	player.stream = gravity_impact_stream
	player.volume_db = -17.0 if soft else -10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_gravity_impact() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.48
	var sample_count := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for index in range(sample_count):
		var time := float(index) / stream.mix_rate
		# A descending kick with a harmonic audible on small headset speakers.
		var frequency := 48.0 + 90.0 * exp(-time * 24.0)
		phase += TAU * frequency / stream.mix_rate
		var envelope := minf(time / 0.008, 1.0) * exp(-time * 9.0)
		envelope *= clampf((duration - time) / 0.045, 0.0, 1.0)
		var sample := (sin(phase) * 0.65 + sin(phase * 2.0) * 0.18) * envelope
		data.encode_s16(index * 2, int(sample * 32767.0))
	stream.data = data
	return stream


func play_tone(frequency: float, duration: float, volume_db: float, sweep := false) -> void:
	if not enabled:
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / float(stream.mix_rate)
		var envelope := sin(PI * minf(time / maxf(duration, 0.001), 1.0))
		var current_frequency := frequency * (1.0 + (time / duration) * 0.42) if sweep else frequency
		var sample := sin(TAU * current_frequency * time) * envelope * 0.42
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	stream.data = data
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_chord() -> void:
	play_tone(261.63, 0.9, -13.0)
	await get_tree().create_timer(0.08).timeout
	play_tone(329.63, 0.82, -13.0)
	await get_tree().create_timer(0.08).timeout
	play_tone(392.00, 0.74, -13.0)
