class_name GuideRobot
extends Node3D

signal dialogue_changed(text: String)

const MODEL := preload("res://Robot.fbx")
const VOICE_1 := preload("res://sfx/robot-sound1.wav")
const VOICE_2 := preload("res://sfx/robot-sound2.wav")
const HIT_SOUND := preload("res://sfx/robot-hit.wav")
const FLOOR_Y := -4.95
const WALK_SPEED := 1.25
# The imported robot's visor faces +Z (the black head mesh is on that side).

enum MotionState { GUIDING, DRIFTING, LANDING, RETURNING }

var model: Node3D
var animation_controller: GuideAnimationController
var speech: Label3D
var hitbox: Area3D
var voice_player: AudioStreamPlayer3D
var hit_player: AudioStreamPlayer3D
var head_mesh: MeshInstance3D
var head_rest: Transform3D
var viewer: Node3D
var destination := Vector3.ZERO
var hit_return_position := Vector3.ZERO
var motion_state := MotionState.GUIDING
var drift_velocity := Vector3.ZERO
var drift_time := 0.0
var voice_variant := 0
var dialogue_queue: Array[Dictionary] = []
var dialogue_remaining := 0.0
var room_number := 0
var room_data: Dictionary = {}


func _ready() -> void:
	model = MODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * 0.48
	add_child(model)
	head_mesh = model.get_node("RobotArmature/Skeleton3D/Head2/Head2") as MeshInstance3D
	head_rest = head_mesh.transform
	animation_controller = GuideAnimationController.new()
	animation_controller.name = "AnimationController"
	add_child(animation_controller)
	animation_controller.configure(model.get_node("AnimationPlayer") as AnimationPlayer)

	speech = Label3D.new()
	speech.name = "Speech"
	speech.position = Vector3(0.0, 2.25, 0.0)
	speech.font_size = 64
	speech.pixel_size = 0.004
	speech.width = 920.0
	speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech.outline_size = 14
	speech.modulate = Color.WHITE
	speech.outline_modulate = GameColors.DARK
	speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	speech.no_depth_test = true
	speech.visible = false
	add_child(speech)

	hitbox = Area3D.new()
	hitbox.name = "GuideHitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.add_to_group("guide_hitbox")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.68
	capsule.height = 2.15
	shape.shape = capsule
	shape.position.y = 0.98
	hitbox.add_child(shape)
	add_child(hitbox)

	voice_player = AudioStreamPlayer3D.new()
	voice_player.name = "Voice"
	voice_player.unit_size = 2.0
	voice_player.max_distance = 20.0
	add_child(voice_player)
	hit_player = AudioStreamPlayer3D.new()
	hit_player.name = "HitSound"
	hit_player.stream = HIT_SOUND
	hit_player.unit_size = 2.0
	hit_player.max_distance = 20.0
	add_child(hit_player)
	set_process(false)


func enter_room(data: Dictionary, index: int, camera: Node3D) -> void:
	room_number = index
	room_data = data
	viewer = camera
	visible = true
	position = Vector3(2.2, FLOOR_Y, camera.global_position.z - 4.45)
	destination = Vector3(1.4, FLOOR_Y, camera.global_position.z - 5.45)
	motion_state = MotionState.GUIDING
	model.rotation = Vector3.ZERO
	head_mesh.transform = head_rest
	rotation.y = 0.0
	animation_controller.set_moving(true)
	set_process(true)
	dialogue_queue.clear()
	queue_line("I am your guide. Follow me!", "wave", 3.2)
	if data.has("guide_lines"):
		var hard_lines: Array = data["guide_lines"]
		for line_index in range(hard_lines.size()):
			var emotion := "yes" if line_index % 2 == 0 else "thumbsup"
			queue_line(str(hard_lines[line_index]), emotion, 6.0)
		return
	match index:
		0:
			queue_line("You stay at the center. Use the trigger or mouse to grab the Memory.", "yes", 5.5)
			queue_line("Place it over the glowing plate. The next fall pulls it down.", "thumbsup", 5.0)
		1:
			queue_line("Heavy thoughts fall down. Light thoughts can rise up.", "wave", 4.7)
			queue_line("Watch NEXT FALL, then place each thought near its matching plate.", "yes", 5.2)
		2:
			queue_line("This room has two plates. The sequence shows which way gravity turns.", "wave", 5.0)
			queue_line("Anchor a thought to hold it in place until the next fall.", "thumbsup", 5.0)


func enter_tutorial(data: Dictionary, camera: Node3D) -> void:
	enter_room(data, -1, camera)
	dialogue_queue.clear()
	queue_line("Welcome to training. I will wait while you try every action.", "wave", 4.5)
	queue_line("First, aim at the floating Memory and grab it with right trigger or the left mouse button.", "yes", 6.0)


func set_objective(text: String) -> void:
	room_data["objective"] = text


func leave_room() -> void:
	set_process(false)
	visible = false
	dialogue_queue.clear()
	dialogue_remaining = 0.0
	speech.visible = false
	head_mesh.transform = head_rest
	voice_player.stop()
	hit_player.stop()
	dialogue_changed.emit("")


func queue_line(text: String, emotion := "yes", duration := 4.0) -> void:
	dialogue_queue.append({"text": text, "emotion": emotion, "duration": duration})


func say_now(text: String, emotion := "yes", duration := 4.0) -> void:
	if motion_state != MotionState.GUIDING:
		return
	dialogue_queue.clear()
	_show_line(text, emotion, duration)


func remind_objective() -> void:
	if room_data.is_empty():
		return
	say_now(str(room_data["objective"]), "thumbsup", 5.5)


func on_warning(direction: String) -> void:
	move_to(Vector3(2.35, FLOOR_Y, -1.05))
	if dialogue_remaining > 1.5:
		return
	say_now("Gravity shifts soon: %s. Check the highlighted plates!" % direction, "wave", 4.5)


func on_drift() -> void:
	move_to(Vector3(1.4, FLOOR_Y, -1.2))


func on_plate_activated(active: int, total: int) -> void:
	if active >= total:
		say_now("Every plate is lit. Great work!", "thumbsup", 3.5)
	else:
		say_now("Nice! %d of %d plates lit. Keep going." % [active, total], "thumbsup", 3.5)


func on_failed_cycle() -> void:
	say_now("Try placing a thought nearer the target before the next fall.", "no", 4.7)
	queue_line(str(room_data["objective"]), "yes", 4.5)


func celebrate() -> void:
	say_now("We did it! On to the next dream layer.", "dance", 4.0)


func move_to(target: Vector3) -> void:
	destination = target
	if motion_state == MotionState.GUIDING:
		animation_controller.set_moving(position.distance_to(destination) > 0.04)


func take_hit(source_position: Vector3) -> void:
	if not visible or motion_state != MotionState.GUIDING:
		return
	motion_state = MotionState.DRIFTING
	hit_return_position = position
	drift_time = 1.3
	var away := global_position - source_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3.RIGHT
	drift_velocity = away.normalized() * 2.8 + Vector3.UP * 2.3
	animation_controller.set_moving(false)
	animation_controller.gesture("jump")
	dialogue_queue.clear()
	dialogue_remaining = 0.0
	speech.visible = false
	head_mesh.transform = head_rest
	dialogue_changed.emit("")
	voice_player.stop()
	hit_player.stop()
	hit_player.play()


func _process(delta: float) -> void:
	if motion_state == MotionState.DRIFTING:
		position += drift_velocity * delta
		position.x = clampf(position.x, -4.5, 4.5)
		position.y = clampf(position.y, FLOOR_Y, FLOOR_Y + 1.35)
		position.z = clampf(position.z, -4.5, 3.0)
		drift_velocity *= exp(-1.4 * delta)
		model.rotation.z += delta * 2.8
		drift_time -= delta
		if drift_time <= 0.0:
			motion_state = MotionState.LANDING
		return
	if motion_state == MotionState.LANDING:
		position.y = move_toward(position.y, FLOOR_Y, delta * 2.0)
		model.rotation.z = lerp_angle(model.rotation.z, 0.0, minf(1.0, delta * 5.0))
		if absf(position.y - FLOOR_Y) < 0.02:
			position.y = FLOOR_Y
			model.rotation.z = 0.0
			motion_state = MotionState.RETURNING
			animation_controller.set_moving(true)
		return
	if motion_state == MotionState.RETURNING:
		var to_return := hit_return_position - position
		model.rotation.y = lerp_angle(model.rotation.y, atan2(to_return.x, to_return.z), minf(1.0, delta * 6.0))
		position = position.move_toward(hit_return_position, WALK_SPEED * 2.0 * delta)
		animation_controller.set_moving(true)
		if position.distance_to(hit_return_position) < 0.05:
			position = hit_return_position
			destination = hit_return_position
			model.rotation.z = 0.0
			motion_state = MotionState.GUIDING
			animation_controller.set_moving(false)
			say_now("All systems stable. Back to the puzzle!", "thumbsup", 3.5)
			queue_line(str(room_data["objective"]), "yes", 4.5)
		return
	var horizontal := destination - position
	horizontal.y = 0.0
	if horizontal.length() > 0.04:
		var step := minf(WALK_SPEED * delta, horizontal.length())
		position += horizontal.normalized() * step
		model.rotation.y = lerp_angle(model.rotation.y, atan2(horizontal.x, horizontal.z), delta * 6.0)
		animation_controller.set_moving(true)
	else:
		animation_controller.set_moving(false)
		if is_instance_valid(viewer):
			var to_viewer := viewer.global_position - global_position
			model.rotation.y = lerp_angle(model.rotation.y, atan2(to_viewer.x, to_viewer.z), minf(1.0, delta * 4.0))
	if dialogue_remaining > 0.0:
		dialogue_remaining -= delta
		if dialogue_remaining <= 0.0:
			speech.visible = false
			dialogue_changed.emit("")
	if dialogue_remaining <= 0.0 and not dialogue_queue.is_empty() and not animation_controller.moving:
		var next_line: Dictionary = dialogue_queue.pop_front()
		_show_line(str(next_line["text"]), str(next_line["emotion"]), float(next_line["duration"]))
	_update_head_look(delta)


func _show_line(text: String, emotion: String, duration: float) -> void:
	speech.text = text
	speech.visible = true
	dialogue_remaining = duration
	dialogue_changed.emit(text)
	voice_player.stop()
	voice_player.stream = VOICE_1 if voice_variant % 2 == 0 else VOICE_2
	voice_variant += 1
	voice_player.play()
	animation_controller.gesture(emotion)


func _update_head_look(delta: float) -> void:
	if not is_instance_valid(viewer):
		return
	var target_basis := head_rest.basis
	if dialogue_remaining > 0.0 and speech.visible:
		var parent_node := head_mesh.get_parent() as Node3D
		var target_local := parent_node.to_local(viewer.global_position) - head_rest.origin
		if target_local.length_squared() > 0.01:
			var yaw := clampf(atan2(target_local.x, target_local.z), -0.8, 0.8)
			var pitch := clampf(-atan2(target_local.y, Vector2(target_local.x, target_local.z).length()), -0.85, 0.6)
			target_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * head_rest.basis
	var current_rotation := head_mesh.transform.basis.get_rotation_quaternion()
	var target_rotation := target_basis.get_rotation_quaternion()
	head_mesh.transform.basis = Basis(current_rotation.slerp(target_rotation, minf(1.0, delta * 7.0)))
