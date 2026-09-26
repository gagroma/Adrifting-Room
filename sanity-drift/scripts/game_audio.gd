class_name GameAudio
extends Node

var enabled := true


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
