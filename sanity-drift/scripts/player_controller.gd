class_name PlayerController
extends Node3D

signal anchor_requested(thought: ThoughtProp)
signal skip_requested
signal restart_requested
signal calm_requested
signal menu_start_requested
signal menu_controls_requested
signal guide_hit(source_position: Vector3)

var playing := false
var xr_enabled := false
var xr_interface: XRInterface

var desktop_yaw: Node3D
var desktop_pitch: Node3D
var desktop_camera: Camera3D
var xr_origin: XROrigin3D
var xr_camera: XRCamera3D
var left_hand: XRController3D
var right_hand: XRController3D
var wrist_label: Label3D
var xr_pointer: MeshInstance3D
var xr_fade: MeshInstance3D
var xr_fade_material: StandardMaterial3D
var vr_menu: VRMenu
var vr_objective: VRObjectivePanel

var grabbed_thought: ThoughtProp
var grab_distance := 4.0
var yaw := 0.0
var pitch := -0.05
var xr_trigger_down := false
var xr_grip_down := false
var xr_anchor_down := false
var xr_skip_down := false


func _ready() -> void:
	_build_desktop_rig()
	_build_xr_rig()


func try_enable_xr() -> bool:
	if "--desktop" in OS.get_cmdline_user_args() or "--preview-game" in OS.get_cmdline_user_args():
		return false
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		return false
	var ready := xr_interface.is_initialized()
	if not ready:
		ready = xr_interface.initialize()
	if not ready:
		return false
	xr_enabled = true
	get_viewport().use_xr = true
	get_viewport().vrs_mode = Viewport.VRS_XR
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	desktop_camera.current = false
	xr_camera.current = true
	return true


func set_playing(value: bool) -> void:
	playing = value
	if is_instance_valid(vr_objective):
		vr_objective.visible = value
	if not value:
		release_grab()
	if value and not xr_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif not value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func get_hovered_text() -> String:
	if xr_enabled or not playing:
		return ""
	if is_instance_valid(grabbed_thought):
		return "%s\nRelease LMB · RMB to push · wheel for distance" % grabbed_thought.display_name
	var hit := _raycast_from(desktop_camera)
	if not hit.is_empty() and hit["collider"] is ThoughtProp:
		return "%s\nLMB — remote grab   RMB — push" % (hit["collider"] as ThoughtProp).display_name
	if not hit.is_empty() and hit["collider"] is Area3D and (hit["collider"] as Area3D).is_in_group("guide_hitbox"):
		return "ROBOT GUIDE\nLMB — give the guide a playful bump"
	return ""


func set_wrist_text(text: String) -> void:
	if is_instance_valid(wrist_label):
		wrist_label.text = text


func set_vr_objective(room_name: String, objective: String, phase_text: String, phase_color: Color, seconds: int, next_direction: String, active_plates: int, total_plates: int, anchors: int) -> void:
	if is_instance_valid(vr_objective):
		vr_objective.update_status(room_name, objective, phase_text, phase_color, seconds, next_direction, active_plates, total_plates, anchors)


func set_vr_objective_visible(value: bool) -> void:
	if is_instance_valid(vr_objective):
		vr_objective.visible = value


func show_vr_menu() -> void:
	if is_instance_valid(vr_menu):
		vr_menu.visible = true
		vr_menu.show_start_page()
	if is_instance_valid(wrist_label):
		wrist_label.visible = false
	if is_instance_valid(xr_pointer):
		xr_pointer.visible = false


func hide_vr_menu() -> void:
	if is_instance_valid(vr_menu):
		vr_menu.visible = false
	if is_instance_valid(wrist_label):
		wrist_label.visible = true
	if is_instance_valid(xr_pointer):
		xr_pointer.visible = true


func transition_out(duration := 1.25) -> Tween:
	var tween := create_tween()
	tween.tween_method(_set_xr_fade_alpha, 0.0, 0.985, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func transition_in(duration := 0.9) -> Tween:
	var tween := create_tween()
	tween.tween_method(_set_xr_fade_alpha, 0.985, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func release_grab() -> void:
	if is_instance_valid(grabbed_thought):
		grabbed_thought.set_grab_highlight(false)
	grabbed_thought = null


func _process(delta: float) -> void:
	if playing and xr_enabled:
		_poll_xr_input(delta)
	elif xr_enabled:
		_poll_xr_menu_input()


func _physics_process(_delta: float) -> void:
	if not playing or not is_instance_valid(grabbed_thought):
		return
	var source: Node3D = right_hand if xr_enabled else desktop_camera
	var target := source.global_position + (-source.global_transform.basis.z * grab_distance)
	var offset := target - grabbed_thought.global_position
	grabbed_thought.linear_velocity = (offset * 8.5).limit_length(13.0)
	grabbed_thought.angular_velocity *= 0.84


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		release_grab()
		if not xr_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if not playing or xr_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0024
		pitch = clampf(pitch - event.relative.y * 0.0024, -1.35, 1.35)
		desktop_yaw.rotation.y = yaw
		desktop_pitch.rotation.x = pitch
		return

	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_grab(_raycast_from(desktop_camera), desktop_camera.global_position)
			else:
				release_grab()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_push_from(desktop_camera)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			grab_distance = clampf(grab_distance - 0.45, 1.5, 9.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			grab_distance = clampf(grab_distance + 0.45, 1.5, 9.5)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_A:
			var anchor_target := grabbed_thought
			if not is_instance_valid(anchor_target):
				var hit := _raycast_from(desktop_camera)
				if not hit.is_empty():
					anchor_target = hit["collider"] as ThoughtProp
			if is_instance_valid(anchor_target):
				anchor_requested.emit(anchor_target)
		elif event.physical_keycode == KEY_SPACE:
			skip_requested.emit()
		elif event.physical_keycode == KEY_R:
			restart_requested.emit()
		elif event.physical_keycode == KEY_C:
			calm_requested.emit()


func _poll_xr_input(delta: float) -> void:
	var trigger_now := right_hand.get_float(&"trigger") > 0.55
	if trigger_now and not xr_trigger_down:
		_begin_grab(_raycast_from(right_hand), right_hand.global_position)
	elif not trigger_now and xr_trigger_down:
		release_grab()
	xr_trigger_down = trigger_now

	var grip_now := right_hand.get_float(&"grip") > 0.62
	if grip_now and not xr_grip_down:
		_push_from(right_hand)
	xr_grip_down = grip_now

	var anchor_now := left_hand.get_float(&"trigger") > 0.62
	if anchor_now and not xr_anchor_down:
		var hit := _raycast_from(left_hand)
		if not hit.is_empty() and hit["collider"] is ThoughtProp:
			anchor_requested.emit(hit["collider"] as ThoughtProp)
	xr_anchor_down = anchor_now

	var skip_now := left_hand.is_button_pressed(&"primary_click")
	if skip_now and not xr_skip_down:
		skip_requested.emit()
	xr_skip_down = skip_now

	if is_instance_valid(grabbed_thought):
		var distance_axis := right_hand.get_vector2(&"primary").y
		if absf(distance_axis) > 0.18:
			grab_distance = clampf(grab_distance + distance_axis * delta * 2.2, 0.45, 9.5)


func _poll_xr_menu_input() -> void:
	vr_menu.update_pointer(right_hand.global_position, -right_hand.global_transform.basis.z)
	var start_now := right_hand.get_float(&"trigger") > 0.55
	if start_now and not xr_trigger_down:
		vr_menu.press_hovered()
	xr_trigger_down = start_now

	var controls_now := left_hand.is_button_pressed(&"primary_click")
	if controls_now and not xr_skip_down:
		vr_menu.toggle_controls()
		menu_controls_requested.emit()
	xr_skip_down = controls_now

func _begin_grab(hit: Dictionary, source_position: Vector3) -> void:
	if not hit.is_empty() and hit["collider"] is Area3D and (hit["collider"] as Area3D).is_in_group("guide_hitbox"):
		guide_hit.emit(source_position)
		return
	if hit.is_empty() or not hit["collider"] is ThoughtProp:
		return
	var thought := hit["collider"] as ThoughtProp
	if thought.anchored:
		thought.set_anchor(false)
	grabbed_thought = thought
	grab_distance = clampf(source_position.distance_to(thought.global_position), 0.45, 9.5)
	thought.set_grab_highlight(true)


func _push_from(source: Node3D) -> void:
	var thought := grabbed_thought
	if not is_instance_valid(thought):
		var hit := _raycast_from(source)
		if hit.is_empty() or not hit["collider"] is ThoughtProp:
			return
		thought = hit["collider"] as ThoughtProp
	if thought.freeze:
		return
	thought.apply_central_impulse(-source.global_transform.basis.z * thought.mass * 4.2)


func _raycast_from(source: Node3D) -> Dictionary:
	if not is_instance_valid(source) or not source.is_inside_tree():
		return {}
	var ray_from := source.global_position
	var ray_to := ray_from + (-source.global_transform.basis.z * 22.0)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 6)
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _build_desktop_rig() -> void:
	desktop_yaw = Node3D.new()
	desktop_yaw.name = "DesktopYaw"
	desktop_yaw.position = Vector3(0.0, 0.75, 4.25)
	add_child(desktop_yaw)
	desktop_pitch = Node3D.new()
	desktop_pitch.name = "DesktopPitch"
	desktop_yaw.add_child(desktop_pitch)
	desktop_camera = Camera3D.new()
	desktop_camera.name = "DesktopCamera"
	desktop_camera.fov = 82.0
	desktop_camera.near = 0.05
	desktop_camera.current = true
	desktop_pitch.add_child(desktop_camera)


func _build_xr_rig() -> void:
	xr_origin = XROrigin3D.new()
	xr_origin.name = "XROrigin"
	xr_origin.position = Vector3(0.0, -4.82, 4.25)
	xr_origin.current = true
	add_child(xr_origin)
	xr_camera = XRCamera3D.new()
	xr_camera.name = "Head"
	xr_camera.current = false
	xr_camera.near = 0.05
	xr_origin.add_child(xr_camera)
	_build_xr_fade()
	_build_vr_menu()
	_build_vr_objective()
	left_hand = _create_xr_hand(&"left_hand", "LeftHand", GameColors.FLOAT)
	right_hand = _create_xr_hand(&"right_hand", "RightHand", GameColors.PAD)
	xr_origin.add_child(left_hand)
	xr_origin.add_child(right_hand)

	wrist_label = Label3D.new()
	wrist_label.name = "ThoughtCompass"
	wrist_label.position = Vector3(0.0, 0.095, 0.025)
	wrist_label.font_size = 44
	wrist_label.pixel_size = 0.00045
	wrist_label.modulate = GameColors.PAD
	wrist_label.outline_modulate = GameColors.DARK
	wrist_label.outline_size = 7
	wrist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrist_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	wrist_label.no_depth_test = true
	wrist_label.text = "SANITY DRIFT"
	left_hand.add_child(wrist_label)

	xr_pointer = MeshInstance3D.new()
	xr_pointer.name = "RemoteGrabRay"
	var pointer_mesh := CylinderMesh.new()
	pointer_mesh.top_radius = 0.006
	pointer_mesh.bottom_radius = 0.006
	pointer_mesh.height = 8.0
	xr_pointer.mesh = pointer_mesh
	xr_pointer.position = Vector3(0.0, 0.0, -4.0)
	xr_pointer.rotation_degrees.x = 90.0
	xr_pointer.material_override = GameColors.material(Color(0.55, 1.0, 0.93, 0.72), 3.0, true)
	right_hand.add_child(xr_pointer)


func _build_vr_menu() -> void:
	vr_menu = VRMenu.new()
	vr_menu.name = "VRStartMenu"
	vr_menu.position = Vector3(0.0, 0.04, -1.28)
	vr_menu.visible = false
	vr_menu.start_requested.connect(func() -> void: menu_start_requested.emit())
	xr_camera.add_child(vr_menu)


func _build_vr_objective() -> void:
	vr_objective = VRObjectivePanel.new()
	vr_objective.name = "VRObjective"
	vr_objective.position = Vector3(-0.43, 0.28, -1.05)
	vr_objective.rotation_degrees.y = 10.0
	vr_objective.visible = false
	xr_camera.add_child(vr_objective)


func _create_xr_hand(tracker_name: StringName, node_name: String, color: Color) -> XRController3D:
	var hand := XRController3D.new()
	hand.name = node_name
	hand.tracker = tracker_name
	hand.pose = &"aim"
	hand.show_when_tracked = true
	var visual := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.045
	capsule.height = 0.18
	visual.mesh = capsule
	visual.rotation_degrees.x = 90.0
	visual.position.z = -0.06
	visual.material_override = GameColors.material(color, 1.1)
	hand.add_child(visual)
	return hand


func _build_xr_fade() -> void:
	xr_fade = MeshInstance3D.new()
	xr_fade.name = "ComfortFade"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	xr_fade.mesh = quad
	xr_fade.position = Vector3(0.0, 0.0, -0.11)
	xr_fade_material = StandardMaterial3D.new()
	xr_fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	xr_fade_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xr_fade_material.no_depth_test = true
	xr_fade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	xr_fade_material.albedo_color = Color(0.38, 0.32, 0.66, 0.0)
	xr_fade_material.render_priority = 127
	xr_fade.material_override = xr_fade_material
	xr_camera.add_child(xr_fade)


func _set_xr_fade_alpha(value: float) -> void:
	if not is_instance_valid(xr_fade_material):
		return
	var fade_color := xr_fade_material.albedo_color
	fade_color.a = value if xr_enabled else 0.0
	xr_fade_material.albedo_color = fade_color
