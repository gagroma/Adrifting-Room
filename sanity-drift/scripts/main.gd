extends Node3D

# Main only coordinates the game loop. Player input, rooms, thoughts, plates,
# interface and audio live in their own scripts.

enum GameState { TITLE, PLAYING, COMPLETE }
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

var rooms: Array[Dictionary] = []
var room_builder: RoomBuilder
var player: PlayerController
var hud: GameHud
var audio: GameAudio
var guide: GuideRobot


func _ready() -> void:
	rooms = RoomCatalog.all_rooms()
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
	add_child(room_builder)

	player = PlayerController.new()
	player.name = "Player"
	player.anchor_requested.connect(_on_anchor_requested)
	player.skip_requested.connect(_on_skip_requested)
	player.restart_requested.connect(_restart_room)
	player.calm_requested.connect(func() -> void: _set_calm_mode(not calm_mode))
	add_child(player)

	hud = GameHud.new()
	hud.name = "HUD"
	hud.start_pressed.connect(_start_game)
	hud.restart_pressed.connect(_start_game)
	hud.calm_changed.connect(_set_calm_mode)
	add_child(hud)
	player.menu_start_requested.connect(_start_game)
	player.menu_controls_requested.connect(hud.toggle_vr_controls)
	player.guide_hit.connect(func(source_position: Vector3) -> void: guide.take_hit(source_position))

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
	game_state = GameState.TITLE
	guide.leave_room()
	player.set_playing(false)
	player.show_vr_menu()
	hud.show_title()


func _start_game() -> void:
	player.hide_vr_menu()
	room_index = 0
	cycles_used = 0
	run_started_msec = Time.get_ticks_msec()
	game_state = GameState.PLAYING
	player.set_playing(true)
	hud.show_game()
	_load_room(room_index)


func _restart_room() -> void:
	if game_state == GameState.PLAYING:
		_load_room(room_index)


func _load_room(index: int, keep_transition := false) -> void:
	room_index = index
	room_transitioning = keep_transition
	player.release_grab()
	player.set_vr_objective_visible(true)
	hud.show_game()
	sequence_step = 0
	var room := rooms[index]
	anchors_left = int(room["anchors"])
	room_builder.build_room(room)
	room_builder.set_calm_mode(calm_mode)
	var viewer: Node3D = player.xr_camera if player.xr_enabled else player.desktop_camera
	guide.enter_room(room, index, viewer)
	_begin_drift()


func _begin_drift() -> void:
	phase = Phase.DRIFT
	phase_time_left = float(rooms[room_index]["drift"])
	current_gravity = Vector3.ZERO
	warned_second = -1
	audio.play_tone(170.0, 0.16, -19.0)
	guide.on_drift()
	_update_status()


func _begin_warning() -> void:
	phase = Phase.WARNING
	phase_time_left = 5.0
	current_gravity = Vector3.ZERO
	warned_second = 6
	audio.play_tone(82.0, 1.3, -16.0)
	room_builder.highlight_next_plates(_next_direction())
	guide.on_warning(GameColors.direction_name(_next_direction()))


func _begin_fall() -> void:
	phase = Phase.FALLING
	phase_time_left = 3.6
	current_gravity = _next_direction()
	cycles_used += 1
	audio.play_tone(120.0, 0.65, -9.0, true)
	room_builder.highlight_next_plates(current_gravity)


func _finish_fall() -> void:
	phase = Phase.EVALUATE
	phase_time_left = 1.15
	current_gravity = Vector3.ZERO
	sequence_step += 1
	room_builder.release_all_anchors()
	_update_status()


func _process(delta: float) -> void:
	if game_state != GameState.PLAYING or room_transitioning:
		return
	phase_time_left = maxf(phase_time_left - delta, 0.0)
	match phase:
		Phase.DRIFT:
			if phase_time_left <= 0.0:
				_begin_warning()
		Phase.WARNING:
			var second := int(ceil(phase_time_left))
			if second != warned_second and second > 0:
				warned_second = second
				audio.play_tone(380.0 + (5 - second) * 55.0, 0.09, -15.0)
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
					guide.on_failed_cycle()
					_begin_drift()
	_update_status()


func _physics_process(delta: float) -> void:
	if game_state != GameState.PLAYING or phase != Phase.FALLING or room_transitioning:
		return
	room_builder.apply_gravity(current_gravity, player.grabbed_thought)
	room_builder.update_plates(delta, current_gravity)


func _complete_room() -> void:
	room_transitioning = true
	current_gravity = Vector3.ZERO
	player.release_grab()
	player.set_vr_objective_visible(false)
	audio.play_chord()
	guide.celebrate()
	room_builder.open_door()
	player.set_wrist_text("CHORD COMPLETE\nDream layer dissolving")
	await get_tree().create_timer(0.72).timeout
	if game_state != GameState.PLAYING:
		return
	room_builder.disintegrate_room(1.25)
	guide.leave_room()
	hud.transition_out(1.25)
	player.transition_out(1.25)
	audio.play_tone(74.0, 1.25, -12.0, true)
	await get_tree().create_timer(1.27).timeout
	if game_state != GameState.PLAYING:
		return
	room_builder.clear_room()
	await _play_consciousness_journey()
	if game_state != GameState.PLAYING:
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
	if game_state != GameState.PLAYING:
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
	room_builder.show_awakening_message()
	var elapsed := int((Time.get_ticks_msec() - run_started_msec) / 1000.0)
	var minutes := elapsed / 60
	var seconds := elapsed % 60
	hud.show_finish("%02d:%02d · gravity shifts: %d\nAll three dream layers complete" % [minutes, seconds, cycles_used])
	player.set_wrist_text("AWAKENING\nEvery thought is in place")
	audio.play_chord()


func _on_plate_activated(index: int) -> void:
	audio.play_tone(330.0 * pow(1.25, index), 0.42, -8.0)
	guide.on_plate_activated(room_builder.active_plate_count(), room_builder.plates.size())
	_update_status()


func _on_anchor_requested(thought: ThoughtProp) -> void:
	if anchors_left <= 0:
		audio.play_tone(95.0, 0.10, -18.0)
		return
	if not is_instance_valid(thought) or thought.anchored:
		return
	if thought == player.grabbed_thought:
		player.release_grab()
	thought.set_anchor(true)
	anchors_left -= 1
	audio.play_tone(720.0, 0.28, -10.0)
	_update_status()


func _on_skip_requested() -> void:
	if phase == Phase.DRIFT:
		phase_time_left = minf(phase_time_left, 0.12)


func _set_calm_mode(value: bool) -> void:
	calm_mode = value
	room_builder.set_calm_mode(value)
	_update_status()


func _next_direction() -> Vector3:
	var sequence: Array = rooms[room_index]["sequence"]
	return sequence[sequence_step % sequence.size()]


func _update_status() -> void:
	if game_state != GameState.PLAYING:
		return
	var room := rooms[room_index]
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
	player.set_vr_objective(
		room["name"], room["objective"], phase_text, phase_color,
		int(ceil(phase_time_left)), GameColors.direction_name(_next_direction()),
		active_plates, room_builder.plates.size(), anchors_left
	)


func _vignette_strength() -> float:
	var strength := 0.08
	if phase == Phase.WARNING:
		strength = lerpf(0.18, 0.72, 1.0 - phase_time_left / 5.0)
	elif phase == Phase.FALLING:
		strength = 0.54
	return strength * 0.42 if calm_mode else strength


func _unhandled_input(event: InputEvent) -> void:
	if game_state == GameState.PLAYING and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		guide.remind_objective()
		get_viewport().set_input_as_handled()
		return
	if game_state == GameState.TITLE and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_start_game()
