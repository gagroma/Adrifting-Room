extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	game.set("audio_enabled", false)
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	game.set_process(false)
	game.set_physics_process(false)
	var builder := game.get("room_builder") as RoomBuilder
	var player := game.get("player") as PlayerController
	# Ignore real desktop mouse events while measuring camera stability.
	player.set_process_unhandled_input(false)
	var camera_rest := player.desktop_camera.global_transform
	var capture := "--capture-shift" in OS.get_cmdline_user_args()
	for room_index in range(3):
		game.call("_load_room", room_index)
		var fx = builder.shift_fx
		fx.set_process(false)
		var lamp_rest := builder.room_lamp.light_energy
		var furniture_rest: Transform3D = fx.furniture[0].transform
		var thought_rest := builder.thoughts[0].transform
		game.call("_begin_warning")
		_check(fx.warning_active and fx.surfaces.visible, "warning starts room effects")
		fx.update_warning(2.0)
		fx._process(0.0)
		_check(fx.furniture[0].transform == furniture_rest, "furniture only trembles in the final second")
		for direction in [Vector3.DOWN, Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			builder.begin_shift_warning(direction, 5.0)
			builder.update_shift_warning(0.4)
			fx._process(0.0)
			var mote := builder.drift_visual.get_child(0) as Node3D
			_check(mote.global_basis.y.normalized().dot(direction) > 0.99, "dust aligns with every gravity direction")
			_check(mote.basis.y.length() > mote.basis.x.length() * 4.0 and mote.basis.y.length() > mote.basis.z.length() * 4.0, "dust stretches along the aligned axis, not world Y")
			_check(fx.furniture[0].transform != furniture_rest, "furniture trembles before the shift")
			_check(builder.thoughts[0].transform == thought_rest, "visual effects never move puzzle objects")
		builder.set_calm_mode(true)
		_check(fx.furniture[0].transform == furniture_rest, "comfort mode restores furniture immediately")
		_check(is_equal_approx(builder.room_lamp.light_energy, lamp_rest), "comfort mode keeps room lighting steady")
		_check(not builder.drift_visual.visible, "comfort mode hides drifting dust")
		builder.set_calm_mode(false)
		if capture:
			game.call("_begin_warning")
			game.set("phase_time_left", 0.7)
			game.call("_update_status")
			builder.update_shift_warning(0.7)
			fx._process(0.0)
			fx.set_process(false)
			await _capture("warning_%d" % room_index)
		game.call("_begin_fall")
		_check(fx.impact_left > 0.0 and fx.flash.light_energy > 0.0, "fall triggers a colored impact")
		_check(fx.furniture[0].transform == furniture_rest, "impact restores furniture")
		if capture:
			game.call("_update_status")
			fx.set_process(false)
			await _capture("impact_%d" % room_index)
		fx._process(0.5)
		_check(not fx.surfaces.visible and is_zero_approx(fx.flash.light_energy), "impact fades out completely")
		_check(is_equal_approx(builder.room_lamp.light_energy, lamp_rest), "room light is restored after impact")
		game.call("_begin_warning")
		builder.update_shift_warning(0.4)
		fx._process(0.0)
		builder.disintegrate_room(0.1)
		_check(not fx.is_processing() and not fx.surfaces.visible, "transition cancels warning effects")
		_check(fx.furniture[0].transform == furniture_rest, "transition starts from original furniture transforms")
	_check(player.desktop_camera.global_transform == camera_rest, "effects do not shake the camera")
	var audio := game.get("audio") as GameAudio
	var kick := audio._make_gravity_impact()
	_check(kick.data.size() > 0 and kick.get_length() < 0.5, "impact audio is a short generated bass hit")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("SANITY_DRIFT_GRAVITY_SHIFT_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _capture(label: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/shift_%s.png" % label)
	_check(error == OK, "rendered preview saved")
