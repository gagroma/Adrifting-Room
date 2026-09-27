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
	var hud := game.get("hud") as GameHud
	var player := game.get("player") as PlayerController
	var builder := game.get("room_builder") as RoomBuilder

	_check(hud.difficulty_button is Button, "desktop title has a difficulty choice")
	_check(player.vr_menu.difficulty_button is Button, "VR title has a difficulty choice")
	hud.difficulty_button.pressed.emit()
	await process_frame
	_check(bool(game.get("hard_mode")), "difficulty choice enables hard mode")
	_check("HARD" in hud.difficulty_button.text and "HARD" in player.vr_menu.difficulty_button.text, "desktop and VR difficulty choices stay synchronized")

	game.call("_start_game")
	await process_frame
	var configured_room: Dictionary = game.get("current_room_data")
	_check(is_equal_approx(float(configured_room["drift"]), 11.7), "hard mode shortens the new puzzle's Drift phase")
	_check(configured_room["name"] == "FRACTURED BEDROOM", "hard mode loads a new bedroom puzzle")
	_check(builder.plates.size() == 3 and builder.thoughts.size() == 3, "hard bedroom has three plates and three thoughts")
	_check((configured_room["sequence"] as Array).size() == 3, "hard bedroom has a three-direction sequence")

	game.call("_load_room", 1)
	await process_frame
	configured_room = game.get("current_room_data")
	_check(configured_room["name"] == "CROSSED KITCHEN", "hard mode loads a new kitchen puzzle")
	_check(builder.plates.size() == 4 and builder.thoughts.size() == 5, "hard kitchen has four plates and five thoughts")
	_check((configured_room["sequence"] as Array).size() == 4, "hard kitchen has a four-direction sequence")

	game.call("_load_room", 2)
	await process_frame
	configured_room = game.get("current_room_data")
	_check(configured_room["name"] == "INFINITE LIBRARY", "hard mode loads a new library puzzle")
	_check(builder.plates.size() == 5 and builder.thoughts.size() == 5, "hard library has five plates and five thoughts")
	_check((configured_room["sequence"] as Array).size() == 5 and int(game.get("anchors_left")) == 2, "hard library has five gravity directions and two anchors")
	var memory := builder.thoughts[0]
	var test_thoughts: Array[ThoughtProp] = [memory]
	for plate in builder.plates:
		memory.global_position = plate.global_position - plate.gravity_direction * 0.6
		plate.update_contact(0.3, plate.gravity_direction, test_thoughts)
	_check(builder.all_plates_active(), "every hard-library plate can be activated by a valid heavy thought")
	game.call("_begin_warning")
	_check(is_equal_approx(float(game.get("phase_time_left")), 3.0), "hard mode shortens the warning")

	game.call("_finish_game")
	await process_frame
	_check(hud.finish_panel.visible, "full completion shows the desktop final screen")
	_check(player.vr_menu.visible and player.vr_menu.finish_page.visible, "full completion shows the VR final screen")
	_check(hud.finish_menu_button is Button and player.vr_menu.finish_menu_button is Button, "both final screens offer a main-menu button")
	_check("HARD" in hud.finish_stats.text, "final results record the selected difficulty")

	hud.finish_menu_button.pressed.emit()
	await process_frame
	_check(int(game.get("game_state")) == 0, "main-menu button returns to the title state")
	_check(hud.title_panel.visible and player.vr_menu.start_page.visible, "desktop and VR title menus are restored")
	_check(builder.get_child_count() == 0, "returning to the title clears the completed room")

	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SANITY_DRIFT_MENU_FINISH_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SANITY_DRIFT_MENU_FINISH_TEST: " + failure)
		quit(1)
