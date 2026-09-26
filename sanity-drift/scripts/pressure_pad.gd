class_name PressurePad
extends Node3D

signal activated(pad: PressurePad)

var gravity_direction := Vector3.DOWN
var required_mass := 1.0
var plate_size := Vector2(2.25, 2.25)
var latched := false
var dwell_time := 0.0

var plate_material: StandardMaterial3D
var plate_label: Label3D


func configure(data: Dictionary, room_half: Vector3) -> void:
	gravity_direction = data["direction"]
	required_mass = float(data["threshold"])
	position = _wall_point(gravity_direction, float(data["u"]), float(data["v"]), room_half)
	_build_visual(str(data["label"]))


func update_contact(delta: float, current_gravity: Vector3, thoughts: Array[ThoughtProp]) -> void:
	if latched:
		return
	if gravity_direction.dot(current_gravity) < 0.98:
		dwell_time = 0.0
		return

	var mass_on_plate := 0.0
	for thought in thoughts:
		if not is_instance_valid(thought):
			continue
		var offset := thought.global_position - global_position
		var distance := offset.dot(-gravity_direction)
		var axes := _surface_axes()
		if distance >= 0.0 and distance <= 1.25 and absf(offset.dot(axes[0])) <= plate_size.x * 0.52 and absf(offset.dot(axes[1])) <= plate_size.y * 0.52:
			mass_on_plate += thought.mass

	if mass_on_plate >= required_mass:
		dwell_time += delta
		if dwell_time >= 0.22:
			_latch()
	else:
		dwell_time = 0.0


func show_as_next(next_direction: Vector3) -> void:
	if latched:
		return
	if gravity_direction.dot(next_direction) > 0.98:
		plate_material.albedo_color = GameColors.PAD.darkened(0.08)
		plate_material.emission = GameColors.PAD
		plate_material.emission_energy_multiplier = 2.7
	else:
		plate_material.albedo_color = GameColors.PAD.darkened(0.48)
		plate_material.emission = GameColors.PAD.darkened(0.4)
		plate_material.emission_energy_multiplier = 0.55


func _latch() -> void:
	latched = true
	plate_material.albedo_color = GameColors.PAD
	plate_material.emission = GameColors.PAD
	plate_material.emission_energy_multiplier = 4.5
	plate_label.modulate = Color.WHITE
	plate_label.text = "READY"
	activated.emit(self)


func _build_visual(label_text: String) -> void:
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	if abs(gravity_direction.x) > 0.5:
		box.size = Vector3(0.10, plate_size.x, plate_size.y)
	elif abs(gravity_direction.y) > 0.5:
		box.size = Vector3(plate_size.x, 0.10, plate_size.y)
	else:
		box.size = Vector3(plate_size.x, plate_size.y, 0.10)
	visual.mesh = box
	visual.position = -gravity_direction * 0.13
	plate_material = GameColors.material(GameColors.PAD.darkened(0.35), 1.0)
	visual.material_override = plate_material
	add_child(visual)

	plate_label = Label3D.new()
	plate_label.text = label_text
	plate_label.font_size = 44
	plate_label.modulate = GameColors.PAD
	plate_label.outline_modulate = GameColors.DARK
	plate_label.outline_size = 9
	plate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate_label.no_depth_test = true
	plate_label.position = -gravity_direction * 0.29
	add_child(plate_label)


func _surface_axes() -> Array[Vector3]:
	if abs(gravity_direction.x) > 0.5:
		return [Vector3.UP, Vector3.FORWARD]
	if abs(gravity_direction.y) > 0.5:
		return [Vector3.RIGHT, Vector3.FORWARD]
	return [Vector3.RIGHT, Vector3.UP]


static func _wall_point(direction: Vector3, u: float, v: float, room_half: Vector3) -> Vector3:
	if abs(direction.x) > 0.5:
		return Vector3(sign(direction.x) * room_half.x, u, v)
	if abs(direction.y) > 0.5:
		return Vector3(u, sign(direction.y) * room_half.y, v)
	return Vector3(u, v, sign(direction.z) * room_half.z)
