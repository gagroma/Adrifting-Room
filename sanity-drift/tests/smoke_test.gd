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
	var builder := game.get("room_builder") as RoomBuilder
	var player := game.get("player") as PlayerController
	var hud := game.get("hud") as GameHud
	var guide := game.get("guide") as GuideRobot
	_check(player.vr_menu.visible, "interactive VR start menu is visible before play")
	_check(player.vr_menu.start_button is Button and player.vr_menu.controls_button is Button, "VR menu has interactive buttons")
	var menu_ray_origin := player.vr_menu.to_global(Vector3(0.0, -0.03, 1.0))
	var menu_ray_direction := player.vr_menu.global_transform.basis * Vector3.FORWARD
	player.vr_menu.update_pointer(menu_ray_origin, menu_ray_direction)
	_check(player.vr_menu.hovered_button == player.vr_menu.start_button, "VR ray highlights the start button")
	game.call("_start_game")
	await process_frame
	_check(int(game.get("game_state")) == 1, "game enters PLAYING state")
	_check(not player.vr_menu.visible, "interactive VR start menu hides after play")
	_check(player.vr_objective.visible, "VR puzzle panel appears after play")
	_check("8 kg" in player.vr_objective.objective_label.text, "VR puzzle panel explains the bedroom objective")
	_check(builder.thoughts.size() == 2, "bedroom has a true and a false memory")
	_check(builder.thoughts.any(func(thought: ThoughtProp) -> bool: return thought.is_false_memory()), "bedroom contains an unstable false memory")
	_check(builder.plates.size() == 1, "bedroom has one plate")
	_check(builder.thoughts[0] is ThoughtProp, "thought uses its own component")
	_check(builder.plates[0] is PressurePad, "plate uses its own component")
	_check(guide.visible and guide.model != null, "robot guide appears in the bedroom")
	var floor_gap := Vector2(guide.global_position.x - player.desktop_camera.global_position.x, guide.global_position.z - player.desktop_camera.global_position.z).length()
	_check(is_equal_approx(guide.position.y, GuideRobot.FLOOR_Y) and absf(floor_gap - 5.0) < 0.5, "guide starts on the floor about five meters ahead")
	_check(guide.animation_controller.clips.has("wave") and guide.animation_controller.clips.has("walking"), "robot gesture and movement clips are available")
	var guide_start := guide.position
	guide._process(0.2)
	_check(guide.position.distance_to(guide_start) > 0.01 and guide.animation_controller.moving, "guide walks into position")
	_check("Walking" in guide.animation_controller.player.current_animation, "walking movement plays the imported walking clip")
	guide._process(2.0)
	guide._process(0.02)
	_check(guide.speech.visible and hud.guide_panel.visible, "guide dialogue appears in 3D and desktop HUD")
	guide._process(0.3)
	var toward_camera := player.desktop_camera.global_position - guide.global_position
	toward_camera.y = 0.0
	_check(guide.model.global_transform.basis.z.normalized().dot(toward_camera.normalized()) > 0.85, "robot faces the camera with its front")
	_check(guide.head_mesh.transform.basis.get_rotation_quaternion().angle_to(guide.head_rest.basis.get_rotation_quaternion()) > 0.01, "guide turns its head toward the camera while speaking")
	var head_parent := guide.head_mesh.get_parent() as Node3D
	var camera_direction := (player.desktop_camera.global_position - guide.head_mesh.global_position).normalized()
	var rest_forward := -(head_parent.global_transform.basis * guide.head_rest.basis.y).normalized()
	var speaking_forward := -guide.head_mesh.global_transform.basis.y.normalized()
	_check(speaking_forward.dot(camera_direction) > rest_forward.dot(camera_direction), "head turn improves its aim toward the camera")
	_check(guide.voice_player.playing, "guide plays a robot voice chirp when speaking")
	guide.remind_objective()
	_check("8 kg" in guide.speech.text, "guide can repeat the room objective")
	var hit_source := Node3D.new()
	root.add_child(hit_source)
	hit_source.global_position = guide.global_position + Vector3(0.0, 1.0, 3.0)
	hit_source.look_at(guide.global_position + Vector3(0.0, 1.0, 0.0))
	await physics_frame
	var guide_hit: Dictionary = player.call("_raycast_from", hit_source)
	_check(not guide_hit.is_empty() and guide_hit["collider"] == guide.hitbox, "guide can be targeted by the player ray")
	var before_hit := guide.position
	player.call("_begin_grab", guide_hit, hit_source.global_position)
	_check(guide.motion_state == GuideRobot.MotionState.DRIFTING and guide.hit_player.playing, "clicking the guide plays hit sound and starts drift")
	guide.move_to(Vector3(2.35, GuideRobot.FLOOR_Y, -1.05))
	guide._process(0.4)
	_check(guide.position.y > GuideRobot.FLOOR_Y + 0.2, "hit sends the guide briefly into the air")
	guide._process(1.0)
	guide._process(1.0)
	guide._process(5.0)
	_check(guide.motion_state == GuideRobot.MotionState.GUIDING and guide.position.distance_to(before_hit) < 0.05, "guide lands and walks back to its exact pre-hit position")
	hit_source.queue_free()
	_check(player.xr_origin is XROrigin3D, "XR origin exists")
	_check(player.xr_camera is XRCamera3D, "XR camera exists")
	_check(player.left_hand is XRController3D and player.right_hand is XRController3D, "both tracked controllers exist")
	_check(player.wrist_label.pixel_size <= 0.001, "VR wrist display remains compact")

	var desktop_camera := player.desktop_camera
	var click_body := builder.thoughts[0]
	click_body.position = desktop_camera.global_position - desktop_camera.global_transform.basis.z * 3.0
	click_body.linear_velocity = Vector3.ZERO
	await physics_frame
	var direct_hit: Dictionary = player.call("_raycast_from", desktop_camera)
	_check(not direct_hit.is_empty(), "desktop camera ray reaches a thought")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	await process_frame
	_check(is_instance_valid(player.grabbed_thought), "left mouse button reaches remote grab")
	var release_click := InputEventMouseButton.new()
	release_click.button_index = MOUSE_BUTTON_LEFT
	release_click.pressed = false
	root.push_input(release_click)
	await process_frame
	_check(not is_instance_valid(player.grabbed_thought), "left mouse release drops the thought")

	game.call("_begin_warning")
	_check(guide.animation_controller.moving and "Walking" in guide.animation_controller.player.current_animation, "guide walks to a new spot for the gravity warning")
	game.call("_begin_fall")
	var test_body := builder.thoughts[0]
	var test_plate := builder.plates[0]
	test_body.position = test_plate.global_position + Vector3.UP * 0.62
	test_body.linear_velocity = Vector3.ZERO
	for frame in range(24):
		await physics_frame
	_check((game.get("current_gravity") as Vector3) == Vector3.DOWN, "bedroom gravity points down")
	_check(test_plate.latched, "a heavy thought activates the floor plate")

	game.call("_load_room", 1)
	await process_frame
	_check(builder.thoughts.size() == 4, "kitchen has three thought types plus a false memory")
	_check(builder.plates.size() == 2, "kitchen has two plates")
	_check("heavy thought" in player.vr_objective.objective_label.text, "VR puzzle panel updates for the kitchen")
	_check(guide.visible and guide.room_number == 1, "guide follows into the kitchen")

	game.call("_load_room", 2)
	await process_frame
	_check(int(game.get("anchors_left")) == 1, "library grants one anchor")
	_check(builder.plates.size() == 2, "library has a two-step puzzle")
	_check("Anchor one thought" in player.vr_objective.objective_label.text, "VR puzzle panel updates for the library")
	_check(guide.visible and guide.room_number == 2, "guide follows into the library")
	var library_body := builder.thoughts[0]
	game.call("_on_anchor_requested", library_body)
	_check(library_body.freeze and library_body.anchored, "anchor freezes a thought")
	_check(int(game.get("anchors_left")) == 0, "anchor is consumed")
	game.call("_finish_fall")
	_check(not library_body.freeze and not library_body.anchored, "anchor releases after the next fall")

	hud.show_title()
	hud.show_vr_controls()
	_check(hud.controls_panel.visible and not hud.title_panel.visible, "VR controls guide opens from the title screen")
	hud.toggle_vr_controls()
	_check(hud.title_panel.visible and not hud.controls_panel.visible, "VR controls guide returns to the title screen")
	hud.show_game()
	hud.transition_out(0.03)
	builder.disintegrate_room(0.03)
	await create_timer(0.08).timeout
	_check(hud.get_transition_progress() > 0.95, "consciousness blur reaches full strength")
	hud.transition_in(0.03)
	await create_timer(0.08).timeout
	_check(hud.get_transition_progress() < 0.05, "consciousness blur clears for the next room")
	_check(player.xr_fade is MeshInstance3D, "VR comfort fade exists")

	var rooms: Array = game.get("rooms")
	_check(rooms.size() == 3, "three playable rooms exist")
	_check(rooms[0]["theme"] == "bedroom", "first room uses the bedroom theme")
	_check(rooms[1]["theme"] == "kitchen", "second room uses the kitchen theme")
	_check(rooms[2]["theme"] == "library", "third room uses the library theme")
	_check((rooms[2]["sequence"] as Array).size() == 3, "library gravity sequence exists")
	var journey := ConsciousnessJourney.new()
	root.add_child(journey)
	await process_frame
	_check(journey.travelers.size() > 90, "thought-space flight has moving streaks and rings")
	journey.queue_free()

	game.call("_load_room", 0)
	await process_frame
	game.call("_complete_room")
	await create_timer(6.35).timeout
	_check(int(game.get("room_index")) == 1, "full transition advances to the kitchen")
	_check(not bool(game.get("room_transitioning")), "full transition returns control to the player")
	_check(builder.thoughts.size() == 4, "the new room is playable after thought-space flight")
	game.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("SANITY_DRIFT_SMOKE_TEST: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("SANITY_DRIFT_SMOKE_TEST: " + failure)
		quit(1)
