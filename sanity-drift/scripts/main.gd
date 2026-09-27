extends Node3D

# Main only coordinates the game loop. Player input, rooms, thoughts, plates,
# interface and audio live in their own scripts.

enum GameState { TITLE, PLAYING, COMPLETE, TUTORIAL, FAILED }
enum Phase { DRIFT, WARNING, FALLING, EVALUATE }

var game_state := GameState.TITLE
var phase := Phase.DRIFT
var phase_time_left := 0.0
var room_index := 0
var sequence_step := 0
var current_gravity := Vector3.ZERO
var warned_second := -1
var cycles_used := 0
var run_started_msec := 0
var calm_mode := false
var anchors_left := 0
var room_transitioning := false
var audio_enabled := true
var pause_active := false
var tutorial_room: Dictionary = {}
var current_room_data: Dictionary = {}
var active_anchor: ThoughtProp
var tutorial_step := 0
var tutorial_push_thought: ThoughtProp
var tutorial_push_origin := Vector3.ZERO
var tutorial_push_start_distance := 0.0
var tutorial_anchor_seen := false
var failed_was_tutorial := false

const TUTORIAL_OBJECTIVES := [
	"Aim at the Memory and grab it.",
	"While holding it, change its distance.",
	"Release the Memory to throw it gently.",
	"Push the Memory away from you.",
	"Aim at the Memory and anchor it.",
	"End the Drift phase early and watch the gravity warning.",
	"Place a Memory above the plate. If it flashes red, pull it away before the countdown ends."
]

var rooms: Array[Dictionary] = []
var hard_rooms: Array[Dictionary] = []
var room_builder: RoomBuilder
var player: PlayerController
var hud: GameHud
var audio: GameAudio
var guide: GuideRobot

const NORMAL_ROOM_COUNT := 3


func _ready() -> void:
	rooms = RoomCatalog.all_rooms()
	hard_rooms = RoomCatalog.hard_rooms()
	rooms.append_array(hard_rooms)
	tutorial_room = RoomCatalog.tutorial_room()
	_build_world_environment()
	_create_game_systems()
	_show_title()
	player.try_enable_xr()
	if "--preview-game" in OS.get_cmdline_user_args():
		call_deferred("_start_game")


func _create_game_systems() -> void:
	room_builder = RoomBuilder.new()
	room_builder.name = "RoomBuilder"
	room_builder.plate_activated.connect(_on_plate_activated)
	room_builder.false_thought_accepted.connect(_on_false_thought_accepted)
	add_child(room_builder)

	player = PlayerController.new()
	player.name = "Player"
	player.anchor_requested.connect(_on_anchor_requested)
	player.skip_requested.connect(_on_skip_requested)
	player.restart_requested.connect(_restart_room)
	player.calm_requested.connect(func() -> void: _set_calm_mode(not calm_mode))
	player.pause_requested.connect(_toggle_pause)
	player.pause_resume_requested.connect(_resume_game)
	player.pause_restart_requested.connect(_restart_from_pause)
	player.quit_requested.connect(_quit_game)
	add_child(player)

	hud = GameHud.new()
	hud.name = "HUD"
	hud.start_pressed.connect(_start_game)
	hud.tutorial_pressed.connect(_start_tutorial)
	hud.restart_pressed.connect(_start_or_retry)
	hud.menu_pressed.connect(_return_to_title)
	hud.calm_changed.connect(_set_calm_mode)
	hud.pause_resume_pressed.connect(_resume_game)
	hud.pause_restart_pressed.connect(_restart_from_pause)
	hud.quit_pressed.connect(_quit_game)
	add_child(hud)
	player.menu_start_requested.connect(_start_or_retry)
	player.menu_tutorial_requested.connect(_start_tutorial)
	player.menu_main_requested.connect(_return_to_title)
	player.menu_controls_requested.connect(hud.toggle_vr_controls)
	player.guide_hit.connect(func(source_position: Vector3) -> void: guide.take_hit(source_position))
	player.thought_grabbed.connect(_on_thought_grabbed)
	player.thought_released.connect(_on_thought_released)
	player.thought_pushed.connect(_on_thought_pushed)
	player.grab_distance_changed.connect(_on_grab_distance_changed)

	audio = GameAudio.new()
	audio.name = "Audio"
	audio.enabled = audio_enabled
	add_child(audio)

	guide = GuideRobot.new()
	guide.name = "GuideRobot"
	guide.dialogue_changed.connect(hud.set_guide_dialogue)
	add_child(guide)
	guide.leave_room()


func _build_world_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = GameColors.DARK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7774b8")
	environment.ambient_light_energy = 0.7
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = GameColors.NIGHT
	environment.fog_density = 0.012
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color("ddd8ff")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)


func _show_title() -> void:
	if get_tree().paused:
		get_tree().paused = false
	pause_active = false
	game_state = GameState.TITLE
	guide.leave_room()
	player.set_playing(false)
	player.show_vr_menu()
	hud.show_title()


func _start_game() -> void:
	if get_tree().paused:
		get_tree().paused = false
	pause_active = false
	player.hide_vr_menu()
	room_index = 0
	cycles_used = 0
	run_started_msec = Time.get_ticks_msec()
	game_state = GameState.PLAYING
	player.set_playing(true)
	hud.show_game()
	_load_room(room_index)


func _start_or_retry() -> void:
	if game_state != GameState.FAILED:
		_start_game()
		return
	player.hide_vr_menu()
	player.set_playing(true)
	hud.show_game()
	if failed_was_tutorial:
		game_state = GameState.TUTORIAL
		_load_tutorial()
	else:
		game_state = GameState.PLAYING
		_load_room(room_index)


func _start_tutorial() -> void:
	player.hide_vr_menu()
	cycles_used = 0
	run_started_msec = Time.get_ticks_msec()
	game_state = GameState.TUTORIAL
	player.set_playing(true)
	hud.show_game()
	_load_tutorial()


func _return_to_title() -> void:
	if get_tree().paused:
		get_tree().paused = false
	pause_active = false
	room_transitioning = false
	current_gravity = Vector3.ZERO
	player.release_grab()
	room_builder.clear_room()
	_show_title()


func _restart_room() -> void:
	if game_state == GameState.PLAYING:
		_load_room(room_index)
	elif game_state == GameState.TUTORIAL:
		_load_tutorial()


func _load_tutorial() -> void:
	room_transitioning = false
	player.release_grab()
	active_anchor = null
	player.set_vr_objective_visible(true)
	hud.show_game()
	sequence_step = 0
	anchors_left = int(tutorial_room["anchors"])
	current_room_data = tutorial_room
	room_builder.build_room(current_room_data)
	room_builder.set_calm_mode(calm_mode)
	var viewer: Node3D = player.xr_camera if player.xr_enabled else player.desktop_camera
	guide.enter_tutorial(current_room_data, viewer)
	phase = Phase.DRIFT
	phase_time_left = float(tutorial_room["drift"])
	current_gravity = Vector3.ZERO
	warned_second = -1
	tutorial_step = 0
	tutorial_push_thought = null
	tutorial_anchor_seen = false
	_set_tutorial_step(0)
	audio.play_tone(170.0, 0.16, -19.0)
	_update_status()


func _load_room(index: int, keep_transition := false) -> void:
	room_index = index
	room_transitioning = keep_transition
	player.release_grab()
	active_anchor = null
	player.set_vr_objective_visible(true)
	hud.show_game()
	sequence_step = 0
	var source_room := rooms[index]
	var room := _configured_room(source_room, index)
	current_room_data = room
	anchors_left = int(room["anchors"])
	room_builder.build_room(room)
	room_builder.set_calm_mode(calm_mode)
	var viewer: Node3D = player.xr_camera if player.xr_enabled else player.desktop_camera
	guide.enter_room(room, index, viewer)
	_begin_drift()


func _begin_drift() -> void:
	room_builder.reset_shift_effects()
	phase = Phase.DRIFT
	phase_time_left = float(_active_room()["drift"])
	current_gravity = Vector3.ZERO
	warned_second = -1
	audio.play_tone(170.0, 0.16, -19.0)
	guide.on_drift()
	_update_status()


func _begin_warning() -> void:
	phase = Phase.WARNING
	phase_time_left = _warning_duration()
	current_gravity = Vector3.ZERO
	warned_second = int(ceil(phase_time_left)) + 1
	audio.play_tone(82.0, 1.3, -16.0)
	room_builder.highlight_next_plates(_next_direction())
	room_builder.begin_shift_warning(_next_direction(), phase_time_left)
	guide.on_warning(GameColors.direction_name(_next_direction()))


func _begin_fall() -> void:
	phase = Phase.FALLING
	phase_time_left = 3.6
	current_gravity = _next_direction()
	cycles_used += 1
	audio.play_gravity_impact(calm_mode)
	room_builder.play_shift_impact(current_gravity)
	room_builder.highlight_next_plates(current_gravity)


func _finish_fall() -> void:
	phase = Phase.EVALUATE
	phase_time_left = 1.15
	current_gravity = Vector3.ZERO
	sequence_step += 1
	if not _uses_reusable_anchor():
		room_builder.release_all_anchors()
	_update_status()


func _process(delta: float) -> void:
	if not _is_gameplay_active() or room_transitioning:
		return
	_check_tutorial_push_motion()
	_check_tutorial_anchor_state()
	# Training waits indefinitely for the core interactions before allowing the
	# first gravity shift. The player never loses the lesson to a countdown.
	if game_state == GameState.TUTORIAL and phase == Phase.DRIFT and tutorial_step < 5:
		phase_time_left = float(tutorial_room["drift"])
		_update_status()
		return
	phase_time_left = maxf(phase_time_left - delta, 0.0)
	match phase:
		Phase.DRIFT:
			if phase_time_left <= 0.0:
				_begin_warning()
		Phase.WARNING:
			room_builder.update_shift_warning(phase_time_left)
			var second := int(ceil(phase_time_left))
			if second != warned_second and second > 0:
				warned_second = second
				audio.play_tone(380.0 + (_warning_duration() - second) * 55.0, 0.09, -15.0)
			if phase_time_left <= 0.0:
				_begin_fall()
		Phase.FALLING:
			if phase_time_left <= 0.0:
				_finish_fall()
		Phase.EVALUATE:
			if phase_time_left <= 0.0:
				if room_builder.all_plates_active():
					_complete_room()
				else:
					if game_state == GameState.TUTORIAL:
						_set_tutorial_step(6)
						guide.say_now("The anchor held for one fall, then released. Now place the Memory above the glowing plate.", "yes", 6.5)
					else:
						guide.on_failed_cycle()
					_begin_drift()
	_update_status()


func _physics_process(delta: float) -> void:
	if not _is_gameplay_active() or room_transitioning:
		return
	if phase == Phase.FALLING:
		room_builder.apply_gravity(current_gravity, player.grabbed_thought)
	room_builder.update_plates(delta, current_gravity)
	if bool(_active_room().get("simultaneous_plates", false)) and room_builder.all_plates_active():
		_complete_room()


func _complete_room() -> void:
	room_builder.reset_shift_effects()
	if game_state == GameState.TUTORIAL:
		_complete_tutorial()
		return
	room_transitioning = true
	current_gravity = Vector3.ZERO
	player.release_grab()
	player.set_vr_objective_visible(false)
	audio.play_chord()
	guide.celebrate()
	var plate_link_delay := room_builder.play_plate_link_completion()
	if plate_link_delay > 0.0:
		await get_tree().create_timer(plate_link_delay).timeout
		if not _is_gameplay_active():
			return
	room_builder.open_door()
	player.set_wrist_text("CHORD COMPLETE\nDream layer dissolving")
	await get_tree().create_timer(0.72).timeout
	if not _is_gameplay_active():
		return
	room_builder.disintegrate_room(1.25)
	guide.leave_room()
	hud.transition_out(1.25)
	player.transition_out(1.25)
	audio.play_tone(74.0, 1.25, -12.0, true)
	await get_tree().create_timer(1.27).timeout
	if not _is_gameplay_active():
		return
	room_builder.clear_room()
	await _play_consciousness_journey()
	if not _is_gameplay_active():
		return
	room_index += 1
	if room_index >= rooms.size():
		_finish_game()
	else:
		_load_room(room_index, true)
	hud.transition_in(0.9)
	player.transition_in(0.9)
	await get_tree().create_timer(0.92).timeout
	room_transitioning = false


func _complete_tutorial() -> void:
	room_builder.reset_shift_effects()
	room_transitioning = true
	current_gravity = Vector3.ZERO
	player.release_grab()
	player.set_vr_objective_visible(false)
	audio.play_chord()
	guide.say_now("Training complete! You can now guide thoughts through the dream.", "dance", 4.0)
	player.set_wrist_text("TUTORIAL COMPLETE\nReady to enter the dream")
	await get_tree().create_timer(4.1).timeout
	if game_state != GameState.TUTORIAL:
		return
	room_builder.clear_room()
	room_transitioning = false
	_show_title()


func _play_consciousness_journey() -> void:
	hud.show_journey()
	var journey := ConsciousnessJourney.new()
	journey.name = "ConsciousnessJourney"
	add_child(journey)
	audio.play_tone(108.0, 2.35, -17.0, true)
	hud.transition_in(0.62)
	player.transition_in(0.62)
	await get_tree().create_timer(0.65).timeout
	await get_tree().create_timer(1.75).timeout
	if not _is_gameplay_active():
		journey.queue_free()
		return
	hud.transition_out(0.68)
	player.transition_out(0.68)
	audio.play_tone(196.0, 0.7, -14.0, true)
	await get_tree().create_timer(0.71).timeout
	journey.queue_free()


func _finish_game() -> void:
	game_state = GameState.COMPLETE
	guide.leave_room()
	player.set_playing(false)
	player.show_vr_finish_menu()
	room_builder.show_awakening_message()
	var elapsed := int((Time.get_ticks_msec() - run_started_msec) / 1000.0)
	var minutes := elapsed / 60
	var seconds := elapsed % 60
	hud.show_finish("%02d:%02d · gravity shifts: %d\nAll six dream layers complete · NORMAL → HARD" % [minutes, seconds, cycles_used])
	player.set_wrist_text("AWAKENING\nEvery thought is in place")
	audio.play_chord()


func _on_false_thought_accepted(thought: ThoughtProp, _plate: PressurePad) -> void:
	if not _is_gameplay_active() or room_transitioning:
		return
	failed_was_tutorial = game_state == GameState.TUTORIAL
	room_transitioning = true
	current_gravity = Vector3.ZERO
	player.release_grab()
	player.set_vr_objective_visible(false)
	guide.say_now("False Memory accepted! The dream is collapsing!", "no", 3.0)
	player.set_wrist_text("FALSE MEMORY\nDETONATION")
	audio.play_tone(54.0, 1.35, -2.0, true)
	audio.play_tone(31.0, 1.7, -4.0, true)
	room_builder.explode_room(thought.global_position, 1.35)
	hud.set_vignette_strength(0.95)
	game_state = GameState.FAILED
	await get_tree().create_timer(1.4).timeout
	if game_state != GameState.FAILED:
		return
	guide.leave_room()
	player.set_playing(false)
	player.show_vr_game_over()
	hud.show_game_over(str(current_room_data.get("name", "THE ROOM")))
	player.set_wrist_text("DREAM COLLAPSED\nFalse memory accepted")


func _on_plate_activated(index: int) -> void:
	audio.play_tone(330.0 * pow(1.25, index), 0.42, -8.0)
	guide.on_plate_activated(room_builder.active_plate_count(), room_builder.plates.size())
	_update_status()


func _on_anchor_requested(thought: ThoughtProp) -> void:
	if not is_instance_valid(thought):
		return
	if _uses_reusable_anchor() and thought == active_anchor and thought.anchored:
		_recover_active_anchor(thought)
		return
	if anchors_left <= 0 or thought.anchored:
		audio.play_tone(95.0, 0.10, -18.0)
		return
	if _uses_reusable_anchor() and not room_builder.can_anchor_on_active_plate(thought, current_gravity):
		audio.play_tone(95.0, 0.10, -18.0)
		guide.say_now("A live plate must light before its Memory can be anchored.", "no", 4.0)
		return
	if thought == player.grabbed_thought:
		player.release_grab()
	thought.set_anchor(true)
	if _uses_reusable_anchor():
		active_anchor = thought
	if game_state == GameState.TUTORIAL:
		tutorial_anchor_seen = true
	anchors_left -= 1
	audio.play_tone(720.0, 0.28, -10.0)
	if game_state == GameState.TUTORIAL and tutorial_step == 4:
		_complete_tutorial_anchor()
	_update_status()


func _on_skip_requested() -> void:
	if phase == Phase.DRIFT:
		if game_state == GameState.TUTORIAL and tutorial_step == 5:
			_set_tutorial_step(6)
			guide.say_now("Good. The warning shows where gravity turns. During FALL, every free thought moves that way.", "wave", 6.0)
		phase_time_left = minf(phase_time_left, 0.12)


func _set_calm_mode(value: bool) -> void:
	calm_mode = value
	room_builder.set_calm_mode(value)
	_update_status()


func _toggle_pause() -> void:
	if pause_active:
		_resume_game()
	elif _is_gameplay_active() and not room_transitioning:
		_set_pause(true)


func _set_pause(value: bool) -> void:
	if value == pause_active:
		return
	if value:
		pause_active = true
		player.release_grab()
		player.set_playing(false)
		player.show_vr_pause_menu()
		hud.show_pause()
		get_tree().paused = true
	else:
		get_tree().paused = false
		pause_active = false
		player.hide_vr_pause_menu()
		player.set_playing(true)
		player.set_vr_objective_visible(true)
		hud.show_game()
		_update_status()


func _resume_game() -> void:
	if pause_active:
		_set_pause(false)


func _restart_from_pause() -> void:
	if pause_active:
		_set_pause(false)
	_restart_room()


func _quit_game() -> void:
	if get_tree().paused:
		get_tree().paused = false
	get_tree().quit()


func _next_direction() -> Vector3:
	var sequence: Array = _active_room()["sequence"]
	return sequence[sequence_step % sequence.size()]


func _update_status() -> void:
	if not _is_gameplay_active():
		return
	var room := _active_room()
	var active_plates := room_builder.active_plate_count()
	var phase_text := "DRIFT · ARRANGE THOUGHTS"
	var wrist_phase := "DRIFT"
	var phase_color := GameColors.FLOAT
	if phase == Phase.WARNING:
		phase_text = "THE DREAM IS SHIFTING"
		wrist_phase = "SHIFTING"
		phase_color = GameColors.DANGER
	elif phase == Phase.FALLING:
		phase_text = "FALL"
		wrist_phase = "FALL"
		phase_color = GameColors.PAD
	elif phase == Phase.EVALUATE:
		phase_text = "THOUGHT SETTLED"
		wrist_phase = "SETTLED"
		phase_color = Color.WHITE

	hud.update_status(
		room["name"], room["subtitle"], phase_text, phase_color,
		int(ceil(phase_time_left)), GameColors.direction_name(_next_direction()),
		active_plates, room_builder.plates.size(), anchors_left, calm_mode
	)
	hud.set_interaction_text(player.get_hovered_text())
	hud.set_vignette_strength(_vignette_strength())
	player.set_wrist_text("%s  %02d\n%s\nP %d/%d  ·  A %d" % [
		wrist_phase, int(ceil(phase_time_left)), GameColors.direction_name(_next_direction()),
		active_plates, room_builder.plates.size(), anchors_left
	])
	var objective := str(room["objective"])
	if game_state == GameState.TUTORIAL:
		objective = TUTORIAL_OBJECTIVES[tutorial_step]
	player.set_vr_objective(
		room["name"], objective, phase_text, phase_color,
		int(ceil(phase_time_left)), GameColors.direction_name(_next_direction()),
		active_plates, room_builder.plates.size(), anchors_left
	)


func _vignette_strength() -> float:
	var strength := 0.08
	if phase == Phase.WARNING:
		strength = lerpf(0.18, 0.72, 1.0 - phase_time_left / _warning_duration())
	elif phase == Phase.FALLING:
		strength = 0.54
	return strength * 0.42 if calm_mode else strength


func _active_room() -> Dictionary:
	return current_room_data


func _configured_room(source: Dictionary, index: int) -> Dictionary:
	var result := source.duplicate(true)
	if index >= NORMAL_ROOM_COUNT:
		result["drift"] = maxf(8.0, float(result["drift"]) * 0.65)
	return result


func _warning_duration() -> float:
	if game_state == GameState.PLAYING and room_index >= NORMAL_ROOM_COUNT:
		return 3.0
	return 5.0


func _is_gameplay_active() -> bool:
	return game_state == GameState.PLAYING or game_state == GameState.TUTORIAL


func _set_tutorial_step(step: int) -> void:
	tutorial_step = clampi(step, 0, TUTORIAL_OBJECTIVES.size() - 1)
	guide.set_objective(TUTORIAL_OBJECTIVES[tutorial_step])
	_update_status()


func _on_thought_grabbed(thought: ThoughtProp) -> void:
	if _uses_reusable_anchor() and thought == active_anchor:
		_recover_active_anchor(thought)
	if game_state == GameState.TUTORIAL and tutorial_step == 0 and not thought.is_false_memory():
		_set_tutorial_step(1)
		guide.say_now("Great! The thought follows your hand or gaze. Change its distance with the right stick or mouse wheel.", "thumbsup", 6.0)


func _recover_active_anchor(thought: ThoughtProp) -> void:
	if is_instance_valid(thought) and thought.anchored:
		thought.set_anchor(false)
	active_anchor = null
	anchors_left = int(_active_room().get("anchors", 0))
	audio.play_tone(510.0, 0.2, -12.0)
	_update_status()


func _uses_reusable_anchor() -> bool:
	return bool(_active_room().get("reusable_anchor", false))


func _on_grab_distance_changed(_distance: float) -> void:
	if game_state == GameState.TUTORIAL and tutorial_step == 1 and is_instance_valid(player.grabbed_thought):
		_set_tutorial_step(2)
		guide.say_now("That moves a held thought nearer or farther. Release the trigger or mouse button to throw it gently.", "yes", 6.0)


func _on_thought_released(thought: ThoughtProp) -> void:
	if game_state == GameState.TUTORIAL and tutorial_step == 2:
		# Keep the release lesson visible, but stop its remaining throw velocity
		# from being mistaken for the separate push lesson that follows.
		thought.linear_velocity *= 0.15
		tutorial_push_thought = thought
		tutorial_push_origin = thought.global_position
		tutorial_push_start_distance = _tutorial_viewer_position().distance_to(thought.global_position)
		_set_tutorial_step(3)
		guide.say_now("Released! Use right grip or the right mouse button to push the thought away from you.", "wave", 5.5)


func _on_thought_pushed(thought: ThoughtProp) -> void:
	if game_state == GameState.TUTORIAL and tutorial_step == 3:
		_complete_tutorial_push(thought)


func _check_tutorial_push_motion() -> void:
	if game_state != GameState.TUTORIAL or tutorial_step != 3 or not is_instance_valid(tutorial_push_thought):
		return
	var current_position := tutorial_push_thought.global_position
	var moved := current_position.distance_to(tutorial_push_origin)
	var current_distance := _tutorial_viewer_position().distance_to(current_position)
	if moved >= 0.22 and current_distance >= tutorial_push_start_distance + 0.18:
		_complete_tutorial_push(tutorial_push_thought)


func _complete_tutorial_push(thought: ThoughtProp) -> void:
	thought.linear_velocity *= 0.2
	tutorial_push_thought = null
	_set_tutorial_step(4)
	guide.say_now("Push gives a quick nudge. Aim with the left hand, then use left trigger, grip, or I to anchor it.", "yes", 6.0)


func _check_tutorial_anchor_state() -> void:
	if game_state != GameState.TUTORIAL or tutorial_step != 4:
		return
	if tutorial_anchor_seen:
		_complete_tutorial_anchor()
		return
	for thought in room_builder.thoughts:
		if is_instance_valid(thought) and thought.anchored:
			_complete_tutorial_anchor()
			return


func _complete_tutorial_anchor() -> void:
	if tutorial_step != 4:
		return
	_set_tutorial_step(5)
	guide.say_now("Anchored! It will stay fixed through the next fall. Now press X, P, or click the left thumbstick.", "thumbsup", 6.0)


func _tutorial_viewer_position() -> Vector3:
	var viewer: Node3D = player.xr_camera if player.xr_enabled else player.desktop_camera
	return viewer.global_position


func _unhandled_input(event: InputEvent) -> void:
	if _is_gameplay_active() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
		guide.remind_objective()
		get_viewport().set_input_as_handled()
		return
	if game_state == GameState.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_game()
		elif event.physical_keycode == KEY_U:
			_start_tutorial()
