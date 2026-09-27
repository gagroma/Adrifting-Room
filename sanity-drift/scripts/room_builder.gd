class_name RoomBuilder
extends Node3D

signal plate_activated(index: int)
signal false_thought_accepted(thought: ThoughtProp, plate: PressurePad)

const ROOM_HALF := Vector3(6.0, 5.0, 6.0)
const GravityShiftFX := preload("res://scripts/gravity_shift_fx.gd")
const LibraryPlateLink := preload("res://scripts/library_plate_link.gd")

var thoughts: Array[ThoughtProp] = []
var plates: Array[PressurePad] = []
var door_mesh: MeshInstance3D
var door_light: OmniLight3D
var drift_visual: Node3D
var calm_mode := false
var shift_fx: Node3D
var room_lamp: OmniLight3D
var shift_furniture: Array[Node3D] = []
var plate_link: Node3D


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if is_instance_valid(drift_visual) and not calm_mode and (not is_instance_valid(shift_fx) or not shift_fx.is_processing()):
		drift_visual.rotate_y(delta * 0.025)
		drift_visual.rotate_z(delta * 0.009)


func build_room(room_data: Dictionary) -> void:
	clear_room()
	_build_shell(room_data["accent"])
	_build_theme_geometry(str(room_data.get("theme", "dream")), room_data["accent"])
	_build_platform()
	_build_door(room_data["accent"])
	_build_dust()
	for thought_data in room_data["props"]:
		_spawn_thought(thought_data["kind"], thought_data["position"])
	for plate_data in room_data["pads"]:
		_spawn_plate(plate_data)
	if bool(room_data.get("simultaneous_plates", false)) and plates.size() >= 2:
		plate_link = LibraryPlateLink.new()
		plate_link.name = "LibraryPlateLink"
		add_child(plate_link)
		plate_link.configure(plates[0], plates[1])
	shift_fx = GravityShiftFX.new()
	shift_fx.name = "GravityShiftFX"
	add_child(shift_fx)
	shift_fx.configure(ROOM_HALF, room_lamp, drift_visual, shift_furniture)
	set_calm_mode(calm_mode)


func clear_room() -> void:
	reset_shift_effects()
	shift_fx = null
	plate_link = null
	shift_furniture.clear()
	for child in get_children():
		child.free()
	thoughts.clear()
	plates.clear()
	door_mesh = null
	door_light = null
	drift_visual = null
	room_lamp = null


func begin_shift_warning(direction: Vector3, duration: float) -> void:
	if is_instance_valid(shift_fx):
		shift_fx.begin_warning(direction, duration)


func update_shift_warning(seconds_left: float) -> void:
	if is_instance_valid(shift_fx):
		shift_fx.update_warning(seconds_left)


func play_shift_impact(direction: Vector3) -> void:
	if is_instance_valid(shift_fx):
		shift_fx.trigger_impact(direction)


func reset_shift_effects() -> void:
	if is_instance_valid(shift_fx):
		shift_fx.reset()


func play_plate_link_completion() -> float:
	if not is_instance_valid(plate_link):
		return 0.0
	plate_link.play_completion_pulse()
	return LibraryPlateLink.COMPLETION_DURATION


func apply_gravity(direction: Vector3, grabbed_thought: ThoughtProp) -> void:
	for thought in thoughts:
		if not is_instance_valid(thought) or thought == grabbed_thought:
			continue
		thought.apply_directional_gravity(direction)


func update_plates(delta: float, current_gravity: Vector3) -> void:
	for plate in plates:
		plate.update_contact(delta, current_gravity, thoughts)


func highlight_next_plates(direction: Vector3) -> void:
	for plate in plates:
		plate.show_as_next(direction)


func release_all_anchors() -> void:
	for thought in thoughts:
		thought.release_anchor()


func can_anchor_on_active_plate(thought: ThoughtProp, current_gravity: Vector3) -> bool:
	for plate in plates:
		if plate.can_anchor_thought(thought, current_gravity):
			return true
	return false


func all_plates_active() -> bool:
	for plate in plates:
		if not plate.latched:
			return false
	return true


func active_plate_count() -> int:
	var count := 0
	for plate in plates:
		if plate.latched:
			count += 1
	return count


func open_door() -> Tween:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(door_mesh, "position:y", 3.8, 1.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(door_light, "light_energy", 8.0, 1.0)
	return tween


func disintegrate_room(duration := 1.25) -> Tween:
	reset_shift_effects()
	# Break the current dream layer into simple fragments and push every room
	# element away from the player. The next room is built after this tween.
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	for thought in thoughts:
		thought.freeze = true
		thought.linear_velocity = Vector3.ZERO
		thought.angular_velocity = Vector3.ZERO

	_spawn_transition_fragments(rng, duration)
	var tween := create_tween()
	tween.set_parallel(true)
	for child in get_children():
		if not child is Node3D:
			continue
		var piece := child as Node3D
		if piece.is_in_group("transition_fragments"):
			continue
		if piece is CollisionObject3D:
			(piece as CollisionObject3D).collision_layer = 0
			(piece as CollisionObject3D).collision_mask = 0
			for piece_child in piece.get_children():
				if piece_child is CollisionShape3D:
					(piece_child as CollisionShape3D).set_deferred("disabled", true)
		var outward := piece.position.normalized()
		if outward.length_squared() < 0.05:
			outward = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var target := piece.position + outward * rng.randf_range(3.0, 7.0)
		target += Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
		var target_rotation := piece.rotation + Vector3(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
		tween.tween_property(piece, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(piece, "rotation", target_rotation, duration)
		tween.tween_property(piece, "scale", Vector3.ONE * 0.04, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	return tween


func explode_room(origin: Vector3, duration := 1.35) -> Tween:
	var blast := MeshInstance3D.new()
	blast.name = "FalseMemoryBlast"
	blast.add_to_group("transition_fragments")
	var blast_mesh := SphereMesh.new()
	blast_mesh.radius = 0.34
	blast_mesh.height = 0.68
	blast.mesh = blast_mesh
	blast.position = to_local(origin)
	var blast_material := GameColors.material(Color(1.0, 0.08, 0.04, 0.88), 12.0, true)
	blast.material_override = blast_material
	add_child(blast)

	var flash := OmniLight3D.new()
	flash.name = "ExplosionLight"
	flash.add_to_group("transition_fragments")
	flash.position = to_local(origin)
	flash.light_color = Color("ff351f")
	flash.light_energy = 18.0
	flash.omni_range = 14.0
	add_child(flash)

	var blast_tween := create_tween()
	blast_tween.set_parallel(true)
	blast_tween.tween_property(blast, "scale", Vector3.ONE * 34.0, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	blast_tween.tween_property(blast_material, "albedo_color:a", 0.0, duration)
	blast_tween.tween_property(flash, "light_energy", 0.0, duration * 0.72)
	disintegrate_room(duration)
	return blast_tween


func show_awakening_message() -> void:
	var message := Label3D.new()
	message.text = "AWAKENING\nEvery thought is in place"
	message.font_size = 72
	message.modulate = Color.WHITE
	message.outline_modulate = GameColors.NIGHT
	message.outline_size = 12
	message.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	message.no_depth_test = true
	message.position = Vector3(0.0, 0.4, -4.9)
	add_child(message)


func set_calm_mode(value: bool) -> void:
	calm_mode = value
	if is_instance_valid(shift_fx):
		shift_fx.set_calm_mode(value)
	if is_instance_valid(drift_visual):
		drift_visual.visible = not value


func _spawn_thought(kind: String, spawn_position: Vector3) -> void:
	var thought := ThoughtProp.new()
	thought.configure(kind)
	thought.position = spawn_position
	add_child(thought)
	thought.linear_velocity = Vector3(randf_range(-0.35, 0.35), randf_range(-0.25, 0.25), randf_range(-0.3, 0.3))
	thought.angular_velocity = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
	thoughts.append(thought)


func _spawn_plate(data: Dictionary) -> void:
	var plate := PressurePad.new()
	plate.configure(data, ROOM_HALF)
	var plate_index := plates.size()
	plate.activated.connect(_on_plate_activated.bind(plate_index))
	plate.false_thought_accepted.connect(_on_false_thought_accepted)
	add_child(plate)
	plates.append(plate)


func _on_plate_activated(_plate: PressurePad, index: int) -> void:
	plate_activated.emit(index)


func _on_false_thought_accepted(thought: ThoughtProp, plate: PressurePad) -> void:
	false_thought_accepted.emit(thought, plate)


func _build_shell(accent: Color) -> void:
	var night_tint := GameColors.NIGHT.lerp(accent, 0.08)
	var depth_tint := GameColors.DEPTH.lerp(accent, 0.06)
	_add_wall(Vector3(0, -ROOM_HALF.y - 0.1, 0), Vector3(ROOM_HALF.x * 2.0, 0.2, ROOM_HALF.z * 2.0), night_tint.lightened(0.08))
	_add_wall(Vector3(0, ROOM_HALF.y + 0.1, 0), Vector3(ROOM_HALF.x * 2.0, 0.2, ROOM_HALF.z * 2.0), night_tint.darkened(0.06))
	_add_wall(Vector3(-ROOM_HALF.x - 0.1, 0, 0), Vector3(0.2, ROOM_HALF.y * 2.0, ROOM_HALF.z * 2.0), depth_tint.darkened(0.10))
	_add_wall(Vector3(ROOM_HALF.x + 0.1, 0, 0), Vector3(0.2, ROOM_HALF.y * 2.0, ROOM_HALF.z * 2.0), depth_tint.darkened(0.02))
	_add_wall(Vector3(0, 0, -ROOM_HALF.z - 0.1), Vector3(ROOM_HALF.x * 2.0, ROOM_HALF.y * 2.0, 0.2), night_tint.lightened(0.03))
	_add_wall(Vector3(0, 0, ROOM_HALF.z + 0.1), Vector3(ROOM_HALF.x * 2.0, ROOM_HALF.y * 2.0, 0.2), GameColors.DARK)

	var edge_material := GameColors.material(Color(accent, 0.55), 2.0, true)
	for x in [-ROOM_HALF.x, ROOM_HALF.x]:
		for y in [-ROOM_HALF.y, ROOM_HALF.y]:
			_add_visual_box(Vector3(x, y, 0), Vector3(0.035, 0.035, ROOM_HALF.z * 2.0), edge_material)
	for x in [-ROOM_HALF.x, ROOM_HALF.x]:
		for z in [-ROOM_HALF.z, ROOM_HALF.z]:
			_add_visual_box(Vector3(x, 0, z), Vector3(0.035, ROOM_HALF.y * 2.0, 0.035), edge_material)
	for y in [-ROOM_HALF.y, ROOM_HALF.y]:
		for z in [-ROOM_HALF.z, ROOM_HALF.z]:
			_add_visual_box(Vector3(0, y, z), Vector3(ROOM_HALF.x * 2.0, 0.035, 0.035), edge_material)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.4, 1.0)
	lamp.light_color = accent
	lamp.light_energy = 3.2
	lamp.omni_range = 10.0
	lamp.shadow_enabled = true
	add_child(lamp)
	room_lamp = lamp


func _build_theme_geometry(theme: String, accent: Color) -> void:
	match theme:
		"bedroom":
			_build_bedroom(accent)
		"kitchen":
			_build_kitchen(accent)
		"library":
			_build_library(accent)


func _build_bedroom(accent: Color) -> void:
	# A low bed, bedside table and moonlit window create a soft horizontal room.
	_add_decor_box(Vector3(-3.7, -4.48, -3.35), Vector3(3.2, 0.42, 4.4), GameColors.DEPTH.lightened(0.12))
	_add_decor_box(Vector3(-3.7, -4.18, -3.35), Vector3(2.9, 0.34, 4.0), GameColors.MIST.darkened(0.08), 0.16)
	_add_decor_box(Vector3(-3.7, -2.85, -5.48), Vector3(3.25, 2.4, 0.24), GameColors.DEPTH.lightened(0.20))
	_add_decor_box(Vector3(3.7, -4.25, 1.5), Vector3(1.25, 1.3, 1.25), GameColors.DEPTH.lightened(0.18))
	_add_decor_cylinder(Vector3(3.7, -3.2, 1.5), 0.12, 1.0, accent, 1.4)
	_add_decor_sphere(Vector3(3.7, -2.55, 1.5), 0.48, Color("ffdba0"), 2.8)

	var window_color := Color("86a8ff")
	_add_decor_box(Vector3(-3.75, 1.25, -5.73), Vector3(3.1, 3.9, 0.10), GameColors.DARK.lightened(0.08))
	_add_decor_box(Vector3(-3.75, 1.25, -5.64), Vector3(2.72, 3.5, 0.06), Color(0.12, 0.16, 0.40, 0.72), 0.8, true)
	_add_decor_box(Vector3(-3.75, 1.25, -5.53), Vector3(0.08, 3.5, 0.08), window_color, 2.2)
	_add_decor_box(Vector3(-3.75, 1.25, -5.53), Vector3(2.72, 0.08, 0.08), window_color, 2.2)
	_add_decor_sphere(Vector3(-4.35, 1.65, -5.42), 0.52, Color("d8ddff"), 3.0)


func _build_kitchen(accent: Color) -> void:
	# Strong checker rhythm, counters and cupboards make this room immediately read as a kitchen.
	for x in range(-5, 6, 2):
		for z in range(-5, 6, 2):
			var alternate := int((x + z) / 2)
			var tile_color := GameColors.MIST.darkened(0.28) if alternate % 2 == 0 else GameColors.DEPTH.lightened(0.08)
			_add_decor_box(Vector3(float(x), -4.86, float(z)), Vector3(1.82, 0.025, 1.82), tile_color, 0.08)

	_add_decor_box(Vector3(-5.35, -3.75, -0.3), Vector3(1.05, 2.15, 8.7), Color("554c86"))
	_add_decor_box(Vector3(5.35, -3.75, -0.3), Vector3(1.05, 2.15, 8.7), Color("554c86"))
	_add_decor_box(Vector3(-5.15, -2.55, -0.3), Vector3(1.4, 0.22, 8.9), GameColors.MIST.darkened(0.10), 0.2)
	_add_decor_box(Vector3(5.15, -2.55, -0.3), Vector3(1.4, 0.22, 8.9), GameColors.MIST.darkened(0.10), 0.2)
	for x in [-4.2, 4.2]:
		for y in [0.0, 2.2]:
			_add_decor_box(Vector3(x, y, -5.72), Vector3(2.2, 1.75, 0.22), Color("6c619c"))
			_add_decor_box(Vector3(x, y, -5.56), Vector3(0.055, 1.42, 0.06), accent, 1.3)
	for x in [-2.8, 0.0, 2.8]:
		_add_decor_cylinder(Vector3(x, 3.6, -0.2), 0.06, 2.6, accent, 1.8)
		_add_decor_sphere(Vector3(x, 2.15, -0.2), 0.34, Color("ffe8aa"), 3.2)


func _build_library(accent: Color) -> void:
	# Tall shelves and many colored book spines emphasize vertical planning.
	for z in [-3.6, 0.0, 3.6]:
		_add_decor_box(Vector3(-5.72, 0.0, z), Vector3(0.28, 8.4, 2.8), Color("3b326d"))
		for y in [-3.2, -1.6, 0.0, 1.6, 3.2]:
			_add_decor_box(Vector3(-5.48, y, z), Vector3(0.18, 0.10, 2.55), accent.darkened(0.18), 0.5)
		for book_index in range(6):
			var book_color: Color = [GameColors.DANGER, GameColors.FLOAT, GameColors.PAD][book_index % 3]
			_add_decor_box(Vector3(-5.38, -3.55 + book_index * 1.25, z - 0.85 + (book_index % 3) * 0.75), Vector3(0.24, 0.82, 0.34), book_color, 0.45)
	for x in [-4.1, 4.1]:
		_add_decor_box(Vector3(x, 0.0, -5.72), Vector3(2.6, 8.5, 0.28), Color("3b326d"))
		for y in [-3.1, -1.5, 0.1, 1.7, 3.3]:
			_add_decor_box(Vector3(x, y, -5.50), Vector3(2.35, 0.11, 0.18), accent.darkened(0.2), 0.5)
	_add_decor_cylinder(Vector3(0.0, -1.75, -3.8), 0.72, 6.2, GameColors.DEPTH.lightened(0.14), 0.2)
	_add_decor_sphere(Vector3(0.0, 1.7, -3.8), 0.55, accent, 3.0)


func _add_decor_box(box_position: Vector3, size: Vector3, color: Color, emission := 0.0, transparent := false) -> void:
	var body := StaticBody3D.new()
	body.position = box_position
	body.collision_layer = 1
	body.collision_mask = 2
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = GameColors.material(color, emission, transparent)
	body.add_child(visual)
	# The shell already owns the floor collision. Every raised decoration gets
	# its own collider so drifting thoughts cannot pass through furniture.
	if box_position.y > -4.8:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	add_child(body)
	# Floor tiles stay still; only theme furniture participates in the tremble.
	if box_position.y > -4.8:
		shift_furniture.append(body)


func _add_decor_sphere(sphere_position: Vector3, radius: float, color: Color, emission := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = sphere_position
	body.collision_layer = 1
	body.collision_mask = 2
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	visual.mesh = mesh
	visual.material_override = GameColors.material(color, emission)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	shift_furniture.append(body)


func _add_decor_cylinder(cylinder_position: Vector3, radius: float, height: float, color: Color, emission := 0.0) -> void:
	var body := StaticBody3D.new()
	body.position = cylinder_position
	body.collision_layer = 1
	body.collision_mask = 2
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	visual.mesh = mesh
	visual.material_override = GameColors.material(color, emission)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	shift_furniture.append(body)


func _add_wall(wall_position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = wall_position
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = GameColors.material(color)
	body.add_child(visual)
	add_child(body)


func _add_visual_box(box_position: Vector3, size: Vector3, box_material: Material) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.position = box_position
	visual.material_override = box_material
	add_child(visual)


func _build_platform() -> void:
	var visual := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.8
	cylinder.bottom_radius = 1.05
	cylinder.height = 0.18
	visual.mesh = cylinder
	visual.position = Vector3(0, -4.78, 4.25)
	visual.material_override = GameColors.material(GameColors.MIST.darkened(0.25), 0.2)
	add_child(visual)


func _build_door(accent: Color) -> void:
	var frame_material := GameColors.material(accent, 2.6, true)
	_add_visual_box(Vector3(-1.45, -1.0, -5.78), Vector3(0.12, 4.8, 0.18), frame_material)
	_add_visual_box(Vector3(1.45, -1.0, -5.78), Vector3(0.12, 4.8, 0.18), frame_material)
	_add_visual_box(Vector3(0, 1.4, -5.78), Vector3(3.0, 0.12, 0.18), frame_material)
	door_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.65, 4.5, 0.15)
	door_mesh.mesh = box
	door_mesh.position = Vector3(0, -1.0, -5.72)
	door_mesh.material_override = GameColors.material(GameColors.DARK.lightened(0.04))
	add_child(door_mesh)
	door_light = OmniLight3D.new()
	door_light.position = Vector3(0, 0.0, -5.1)
	door_light.light_color = accent
	door_light.light_energy = 0.0
	door_light.omni_range = 5.0
	add_child(door_light)


func _build_dust() -> void:
	drift_visual = Node3D.new()
	drift_visual.name = "DriftingDust"
	add_child(drift_visual)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var dust_material := GameColors.material(Color(0.65, 0.82, 1.0, 0.5), 1.8, true)
	for index in range(34):
		var mote := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.018, 0.045)
		sphere.height = sphere.radius * 2.0
		mote.mesh = sphere
		mote.material_override = dust_material
		mote.position = Vector3(rng.randf_range(-5.4, 5.4), rng.randf_range(-4.4, 4.4), rng.randf_range(-5.4, 3.4))
		drift_visual.add_child(mote)


func _spawn_transition_fragments(rng: RandomNumberGenerator, duration: float) -> void:
	var fragment_material := GameColors.material(Color(0.72, 0.95, 1.0, 0.78), 3.2, true)
	for index in range(42):
		var fragment := MeshInstance3D.new()
		var fragment_mesh := BoxMesh.new()
		fragment_mesh.size = Vector3.ONE * rng.randf_range(0.04, 0.16)
		fragment.mesh = fragment_mesh
		fragment.material_override = fragment_material
		fragment.add_to_group("transition_fragments")
		fragment.position = Vector3(rng.randf_range(-5.5, 5.5), rng.randf_range(-4.5, 4.5), rng.randf_range(-5.5, 3.5))
		add_child(fragment)
		var direction := fragment.position.normalized()
		if direction.length_squared() < 0.05:
			direction = Vector3.UP
		var target := fragment.position + direction * rng.randf_range(3.0, 8.0)
		var fragment_tween := create_tween()
		fragment_tween.set_parallel(true)
		fragment_tween.tween_property(fragment, "position", target, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		fragment_tween.tween_property(fragment, "rotation", Vector3(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0)), duration)
		fragment_tween.tween_property(fragment, "scale", Vector3.ONE * 0.01, duration)
