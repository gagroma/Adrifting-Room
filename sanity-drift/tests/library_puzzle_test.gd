extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var game := packed.instantiate()
	game.set("audio_enabled", false)
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	game.call("_load_room", 2)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)

	var builder := game.get("room_builder") as RoomBuilder
	var player := game.get("player") as PlayerController
	var room := game.get("current_room_data") as Dictionary
	var link = builder.plate_link
	var capture := "--capture-link" in OS.get_cmdline_user_args()
	var memories := builder.thoughts.filter(func(thought: ThoughtProp) -> bool: return thought.thought_kind == "memory")
	var first_memory := memories[0] as ThoughtProp
	var second_memory := memories[1] as ThoughtProp
	var plate_i := builder.plates[0]
	var plate_ii := builder.plates[1]

	_check(bool(room.get("simultaneous_plates", false)), "library requires simultaneous plate contact")
	_check(bool(room.get("reusable_anchor", false)), "library uses a reusable anchor")
	_check((room["sequence"] as Array) == [Vector3.RIGHT, Vector3.DOWN], "library sequence is RIGHT then DOWN")
	_check(plate_i.continuous_contact and plate_ii.continuous_contact, "both library plates continuously check their contents")
	_check(is_instance_valid(link), "library builds a visible connection between its two live plates")

	for thought_index in range(builder.thoughts.size()):
		var thought := builder.thoughts[thought_index]
		thought.global_position = Vector3(-3.6 + thought_index * 1.8, 3.4, 3.2)
		thought.linear_velocity = Vector3.ZERO
		thought.angular_velocity = Vector3.ZERO
	first_memory.global_position = plate_i.global_position - Vector3.RIGHT * 0.62
	game.call("_on_anchor_requested", first_memory)
	_check(not first_memory.anchored, "anchor cannot be deployed before plate I lights")
	plate_i.update_contact(0.3, Vector3.DOWN, builder.thoughts)
	_check(not plate_i.latched, "plate I cannot activate during the wrong gravity shift")

	game.set("current_gravity", Vector3.RIGHT)
	plate_i.update_contact(0.3, Vector3.RIGHT, builder.thoughts)
	_check(plate_i.latched, "plate I activates during RIGHT")
	link._process(0.2)
	_check(link.energy_i > 0.99 and is_zero_approx(link.energy_ii), "plate I lights only the first half of the connection")
	game.call("_on_anchor_requested", first_memory)
	_check(first_memory.anchored and int(game.get("anchors_left")) == 0, "lit plate I allows the anchor to deploy")
	game.call("_finish_fall")
	plate_i.update_contact(0.01, Vector3.ZERO, builder.thoughts)
	_check(plate_i.latched, "anchored Memory keeps plate I active between falls")
	if capture:
		await _capture("library_link_half")

	player.call("_begin_grab", {"collider": first_memory}, player.desktop_camera.global_position)
	plate_i.update_contact(0.01, Vector3.ZERO, builder.thoughts)
	_check(not first_memory.anchored and int(game.get("anchors_left")) == 1, "grabbing recovers the reusable anchor")
	_check(not plate_i.latched, "plate I switches off when its unanchored Memory is no longer held by matching gravity")
	link._process(0.2)
	_check(is_zero_approx(link.energy_i), "first half fades when plate I switches off")
	player.release_grab()
	# Re-place the Memory explicitly; graphical preview frames allow rigid bodies
	# to settle between the two independent test scenarios.
	first_memory.global_position = plate_i.global_position - Vector3.RIGHT * 0.62
	first_memory.linear_velocity = Vector3.ZERO
	first_memory.angular_velocity = Vector3.ZERO

	game.set("current_gravity", Vector3.RIGHT)
	plate_i.update_contact(0.3, Vector3.RIGHT, builder.thoughts)
	_check(plate_i.latched, "plate I can relight after recovering the anchor")
	game.call("_on_anchor_requested", first_memory)
	_check(first_memory.anchored, "recovered anchor can be deployed again on plate I")
	game.set("current_gravity", Vector3.DOWN)
	second_memory.global_position = plate_ii.global_position - Vector3.DOWN * 0.62
	second_memory.linear_velocity = Vector3.ZERO
	second_memory.angular_velocity = Vector3.ZERO
	if capture:
		second_memory.freeze = true
	builder.update_plates(0.3, Vector3.DOWN)
	_check(plate_i.latched and plate_ii.latched, "anchored plate I and occupied plate II are active together")
	_check(builder.all_plates_active(), "both live plate checks pass simultaneously")
	link._process(0.2)
	_check(link.energy_i > 0.99 and link.energy_ii > 0.99, "both connection halves glow when both plates are active")
	if capture:
		await _capture("library_link_both")
	_check(builder.all_plates_active(), "rendered preview keeps both plate contacts active")
	_check(not bool(game.get("room_transitioning")), "library is still waiting for its completion check")

	var door_start := builder.door_mesh.position.y
	_check(bool(game.call("_is_gameplay_active")), "gameplay remains active before the completion pulse")
	if capture:
		# The rendered preview has already verified both live contacts. Invoke the
		# same completion path directly so later frames only visualize the pulse.
		game.call("_complete_room")
	else:
		game.call("_physics_process", 0.01)
	_check(bool(game.get("room_transitioning")), "simultaneous contact completes the library immediately")
	_check(link.completion_active and link.completion_pulse.visible and link.pulse_light.light_energy > 0.0, "completion launches a glowing energy pulse from plate I")
	_check(is_equal_approx(builder.door_mesh.position.y, door_start), "door waits for the connection pulse")
	if capture:
		link.set_process(false)
		link._process(link.COMPLETION_DURATION * 0.5)
		_check(link.completion_pulse.position.is_equal_approx(link.relay_point), "completion pulse reaches the door relay halfway through")
		await _capture("library_link_pulse")
	await create_timer(link.COMPLETION_DURATION + 0.08).timeout
	_check(builder.door_mesh.position.y > door_start, "door starts opening after the pulse reaches plate II")
	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SANITY_DRIFT_LIBRARY_PUZZLE_TEST: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("SANITY_DRIFT_LIBRARY_PUZZLE_TEST: " + failure)
	quit(1)


func _capture(label: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/%s.png" % label)
	_check(error == OK, "rendered library connection preview saved")
