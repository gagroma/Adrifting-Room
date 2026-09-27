extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return

	var game := packed.instantiate()
	game.set("audio_enabled", false)
	root.add_child(game)
	await process_frame
	var player := game.get("player") as PlayerController
	var builder := game.get("room_builder") as RoomBuilder
	var guide := game.get("guide") as GuideRobot

	_check(player.vr_menu.tutorial_button is Button, "VR title menu has a tutorial button")
	var tutorial_ray_origin := player.vr_menu.to_global(Vector3(0.0, -0.155, 1.0))
	var tutorial_ray_direction := player.vr_menu.global_transform.basis * Vector3.FORWARD
	player.vr_menu.update_pointer(tutorial_ray_origin, tutorial_ray_direction)
	_check(player.vr_menu.hovered_button == player.vr_menu.tutorial_button, "VR ray highlights the tutorial button")
	player.vr_menu.press_hovered()
	await process_frame

	_check(int(game.get("game_state")) == 3, "tutorial starts as its own game mode")
	_check(not player.vr_menu.visible, "VR menu hides during training")
	_check(builder.thoughts.size() == 1 and builder.plates.size() == 1, "training room has one thought and one target")
	_check(guide.visible and guide.room_number == -1, "the existing guide robot enters the training room")
	_check("grab" in player.vr_objective.objective_label.text.to_lower(), "the first live objective teaches grab")
	var guide_key := InputEventKey.new()
	guide_key.physical_keycode = KEY_K
	guide_key.pressed = true
	root.push_input(guide_key)
	await process_frame
	_check("grab" in guide.speech.text.to_lower(), "K asks the guide to repeat the current objective")
	var comfort_key := InputEventKey.new()
	comfort_key.physical_keycode = KEY_O
	comfort_key.pressed = true
	root.push_input(comfort_key)
	await process_frame
	_check(bool(game.get("calm_mode")), "O toggles comfort mode")
	root.push_input(comfort_key)
	await process_frame

	var thought := builder.thoughts[0]
	player.call("_begin_grab", {"collider": thought}, player.desktop_camera.global_position)
	_check(int(game.get("tutorial_step")) == 1, "grabbing advances to distance control")
	player.grab_distance_changed.emit(player.grab_distance + 0.5)
	_check(int(game.get("tutorial_step")) == 2, "changing distance advances to release")
	player.release_grab()
	_check(int(game.get("tutorial_step")) == 3, "releasing advances to push")
	game.call("_on_anchor_requested", thought)
	_check(thought.anchored and int(game.get("tutorial_step")) == 3, "an early anchor is stored while the push lesson is active")
	thought.global_position += Vector3(0.0, 0.0, -0.4)
	game.call("_process", 0.1)
	_check(int(game.get("tutorial_step")) == 5 and thought.anchored, "a physically anchored thought advances the lesson even when anchored early")
	var skip_key := InputEventKey.new()
	skip_key.physical_keycode = KEY_P
	skip_key.pressed = true
	root.push_input(skip_key)
	await process_frame
	_check(int(game.get("tutorial_step")) == 6 and float(game.get("phase_time_left")) <= 0.12, "skip starts the guided gravity lesson")
	game.call("_finish_fall")
	_check(not thought.anchored, "the tutorial demonstrates that an anchor lasts for one fall")

	game.call("_complete_room")
	_check(bool(game.get("room_transitioning")), "tutorial completion locks the room while the robot celebrates")
	await create_timer(4.2).timeout
	_check(int(game.get("game_state")) == 0 and player.vr_menu.visible, "completed tutorial returns to the title menu")
	var tutorial_key := InputEventKey.new()
	tutorial_key.physical_keycode = KEY_U
	tutorial_key.pressed = true
	root.push_input(tutorial_key)
	await process_frame
	_check(int(game.get("game_state")) == 3, "U starts the tutorial from the title screen")
	var old_thought := builder.thoughts[0]
	var restart_key := InputEventKey.new()
	restart_key.physical_keycode = KEY_L
	restart_key.pressed = true
	root.push_input(restart_key)
	await process_frame
	_check(builder.thoughts[0] != old_thought, "L restarts the current room")

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SANITY_DRIFT_TUTORIAL_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SANITY_DRIFT_TUTORIAL_TEST: " + failure)
		quit(1)
