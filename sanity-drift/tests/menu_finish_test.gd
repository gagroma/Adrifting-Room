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

	var campaign_rooms: Array = game.get("rooms")
	_check(campaign_rooms.size() == 6, "normal and hard rooms form one six-level campaign")
	_check(str(campaign_rooms[0]["name"]) == "BEDROOM" and "HARD" in str(campaign_rooms[3]["name"]), "hard rooms follow the three normal rooms")

	game.call("_start_game")
	await process_frame
	game.call("_toggle_pause")
	_check(bool(game.get("pause_active")) and paused, "pause freezes the scene tree during gameplay")
	_check(hud.pause_panel.visible and player.vr_menu.pause_page.visible, "desktop and VR pause menus appear together")
	_check(player.vr_menu.resume_button is Button and player.vr_menu.pause_restart_button is Button and player.vr_menu.quit_button is Button, "VR pause menu offers continue, restart, and exit")
	hud.pause_resume_button.pressed.emit()
	_check(not bool(game.get("pause_active")) and not paused, "continue resumes the game")
	if paused:
		paused = false
		game.set("pause_active", false)
	player.pause_requested.emit()
	_check(bool(game.get("pause_active")), "left-controller menu action toggles pause")
	player.vr_menu.hovered_button = player.vr_menu.resume_button
	player.vr_menu.press_hovered()
	_check(not bool(game.get("pause_active")), "VR continue button resumes the game")
	if paused:
		paused = false
		game.set("pause_active", false)

	game.call("_load_room", 3)
	await process_frame
	var configured_room: Dictionary = game.get("current_room_data")
	_check(is_equal_approx(float(configured_room["drift"]), 11.7), "later hard levels shorten the Drift phase")
	_check(configured_room["name"] == "BEDROOM II · HARD", "level four continues with the hard bedroom")
	_check(builder.plates.size() == 3 and builder.thoughts.size() == 6, "hard bedroom expands the normal weight puzzle")
	_check((configured_room["sequence"] as Array) == [Vector3.DOWN], "hard bedroom keeps the normal downward-gravity principle")

	game.call("_load_room", 4)
	await process_frame
	configured_room = game.get("current_room_data")
	_check(configured_room["name"] == "KITCHEN II · HARD", "level five continues with the hard kitchen")
	_check(builder.plates.size() == 4 and builder.thoughts.size() == 7, "hard kitchen has four plates and two false memories")
	_check((configured_room["sequence"] as Array) == [Vector3.DOWN, Vector3.UP], "hard kitchen keeps the normal heavy/light gravity principle")

	game.call("_load_room", 5)
	await process_frame
	configured_room = game.get("current_room_data")
	_check(configured_room["name"] == "LIBRARY II · HARD", "level six continues with the hard library")
	_check(builder.plates.size() == 3 and builder.thoughts.size() == 6, "hard library expands the simultaneous-contact puzzle")
	_check((configured_room["sequence"] as Array).size() == 3 and int(game.get("anchors_left")) == 2, "hard library adds a third direction and second anchor")
	var memory := builder.thoughts[0]
	var test_thoughts: Array[ThoughtProp] = [memory]
	for plate in builder.plates:
		memory.global_position = plate.global_position - plate.gravity_direction * 0.6
		plate.update_contact(0.3, plate.gravity_direction, test_thoughts)
	_check(builder.all_plates_active(), "every hard-library live plate can be activated by a valid heavy thought")
	game.call("_begin_warning")
	_check(is_equal_approx(float(game.get("phase_time_left")), 3.0), "hard mode shortens the warning")

	game.call("_finish_game")
	await process_frame
	_check(hud.finish_panel.visible, "full completion shows the desktop final screen")
	_check(player.vr_menu.visible and player.vr_menu.finish_page.visible, "full completion shows the VR final screen")
	_check(hud.finish_menu_button is Button and player.vr_menu.finish_menu_button is Button, "both final screens offer a main-menu button")
	_check("six dream layers" in hud.finish_stats.text, "final results record the full campaign")

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
