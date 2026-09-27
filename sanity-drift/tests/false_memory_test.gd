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
	await process_frame

	var builder := game.get("room_builder") as RoomBuilder
	var player := game.get("player") as PlayerController
	var hud := game.get("hud") as GameHud
	var plate := builder.plates[0]
	var real_memory: ThoughtProp
	var false_memory: ThoughtProp
	for thought in builder.thoughts:
		if thought.is_false_memory():
			false_memory = thought
		elif thought.thought_kind == "memory":
			real_memory = thought
	_check(is_instance_valid(false_memory), "a false memory is present in the first room")
	if not is_instance_valid(false_memory):
		_finish()
		return
	_check(is_instance_valid(real_memory), "a real memory is present for visual comparison")
	_check(false_memory.display_name == real_memory.display_name, "the fake has the same name as a real memory before activation")
	_check(false_memory.base_color == real_memory.base_color, "the fake has the same color as a real memory before activation")
	_check(not false_memory.danger_label.visible, "the fake has no visible warning before touching a plate")

	false_memory.global_position = plate.global_position - plate.gravity_direction * 0.62
	plate.update_contact(0.01, plate.gravity_direction, builder.thoughts)
	_check(false_memory.false_warning_active, "touching an active plate starts the red bomb warning")
	_check(is_equal_approx(plate.danger_time_left, 5.0), "the false-memory countdown starts at five seconds")
	false_memory.global_position += Vector3(3.5, 0.0, 0.0)
	plate.update_contact(0.1, Vector3.ZERO, builder.thoughts)
	_check(not false_memory.false_warning_active, "removing the false memory cancels the countdown")

	false_memory.global_position = plate.global_position - plate.gravity_direction * 0.62
	plate.update_contact(0.01, plate.gravity_direction, builder.thoughts)
	plate.update_contact(5.0, Vector3.ZERO, builder.thoughts)
	_check(int(game.get("game_state")) == 4, "letting the countdown expire causes a game loss")
	_check(bool(game.get("room_transitioning")), "the room locks while the explosion destroys it")
	await create_timer(1.5).timeout
	_check(hud.finish_panel.visible and "COLLAPSED" in hud.finish_title.text, "desktop defeat screen appears after the explosion")
	_check(player.vr_menu.visible and "COLLAPSED" in player.vr_menu.finish_title.text, "VR defeat screen appears after the explosion")
	_check(hud.finish_restart_button.text == "RETRY ROOM", "defeat screen offers a room retry")

	hud.finish_restart_button.pressed.emit()
	await process_frame
	_check(int(game.get("game_state")) == 1 and not bool(game.get("room_transitioning")), "retry rebuilds the failed room")
	_check(builder.thoughts.any(func(item: ThoughtProp) -> bool: return item.is_false_memory()), "retry restores the false-memory puzzle")

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SANITY_DRIFT_FALSE_MEMORY_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SANITY_DRIFT_FALSE_MEMORY_TEST: " + failure)
		quit(1)
