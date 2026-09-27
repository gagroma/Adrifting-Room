class_name ThoughtProp
extends RigidBody3D

var thought_kind := "memory"
var display_name := "THOUGHT"
var directional_gravity_multiplier := 1.0
var anchored := false
var false_warning_active := false
var false_warning_time_left := 0.0
var false_warning_total := 5.0
var warning_pulse_time := 0.0
var grab_highlighted := false
var base_color := GameColors.FLOAT
var base_emission := 0.6

var shape_mesh: MeshInstance3D
var anchor_mark: Node3D
var danger_label: Label3D


func configure(kind: String) -> void:
	thought_kind = kind
	collision_layer = 2
	collision_mask = 1 | 2
	gravity_scale = 0.0
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.35
	angular_damp = 0.5
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	_build_shape()
	_build_anchor_mark()
	set_process(false)


func _process(delta: float) -> void:
	if not false_warning_active or not is_instance_valid(shape_mesh):
		return
	warning_pulse_time += delta
	var urgency := 1.0 - clampf(false_warning_time_left / false_warning_total, 0.0, 1.0)
	var interval := lerpf(0.52, 0.12, urgency)
	var flash_on := fmod(warning_pulse_time, interval) < interval * 0.52
	var material := shape_mesh.material_override as StandardMaterial3D
	material.albedo_color = GameColors.DANGER if flash_on else base_color.darkened(0.35)
	material.emission = GameColors.DANGER if flash_on else base_color
	material.emission_energy_multiplier = 7.0 if flash_on else 0.45
	if is_instance_valid(danger_label):
		danger_label.text = "FALSE MEMORY\n%d" % maxi(1, int(ceil(false_warning_time_left)))
		danger_label.modulate = Color.WHITE if flash_on else GameColors.DANGER


func apply_directional_gravity(direction: Vector3) -> void:
	if freeze:
		return
	apply_central_force(direction * 9.8 * mass * directional_gravity_multiplier)
	linear_velocity = linear_velocity.limit_length(15.0)


func set_grab_highlight(active: bool) -> void:
	grab_highlighted = active
	if not is_instance_valid(shape_mesh):
		return
	if false_warning_active:
		return
	var shape_material := shape_mesh.material_override as StandardMaterial3D
	shape_material.emission_energy_multiplier = 3.2 if active else 0.6


func is_false_memory() -> bool:
	return thought_kind == "false_memory"


func start_false_warning(duration: float) -> void:
	if not is_false_memory():
		return
	false_warning_total = duration
	false_warning_time_left = duration
	false_warning_active = true
	warning_pulse_time = 0.0
	if is_instance_valid(danger_label):
		danger_label.visible = true
	set_process(true)


func update_false_warning(time_left: float) -> void:
	false_warning_time_left = maxf(time_left, 0.0)


func cancel_false_warning() -> void:
	false_warning_active = false
	false_warning_time_left = 0.0
	set_process(false)
	if is_instance_valid(danger_label):
		danger_label.visible = false
	if is_instance_valid(shape_mesh):
		var material := shape_mesh.material_override as StandardMaterial3D
		material.albedo_color = base_color
		material.emission = base_color
		material.emission_energy_multiplier = 3.2 if grab_highlighted else base_emission


func set_anchor(active: bool) -> void:
	anchored = active
	freeze = active
	if is_instance_valid(anchor_mark):
		anchor_mark.visible = active


func release_anchor() -> void:
	if anchored:
		set_anchor(false)


func _build_shape() -> void:
	shape_mesh = MeshInstance3D.new()
	shape_mesh.name = "Shape"
	var collision := CollisionShape3D.new()
	var color := GameColors.FLOAT
	var physics := PhysicsMaterial.new()
	physics.friction = 0.72

	match thought_kind:
		"memory":
			mass = 8.0
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.15, 0.82, 0.72)
			shape_mesh.mesh = mesh
			var shape := BoxShape3D.new()
			shape.size = mesh.size
			collision.shape = shape
			color = Color("68d7c4")
			physics.bounce = 0.02
			display_name = "MEMORY · 8 kg"
		"false_memory":
			mass = 8.0
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.15, 0.82, 0.72)
			shape_mesh.mesh = mesh
			var shape := BoxShape3D.new()
			shape.size = mesh.size
			collision.shape = shape
			color = Color("68d7c4")
			physics.bounce = 0.02
			display_name = "MEMORY · 8 kg"
		"anxiety":
			mass = 1.2
			var mesh := SphereMesh.new()
			mesh.radius = 0.48
			mesh.height = 0.96
			shape_mesh.mesh = mesh
			var shape := SphereShape3D.new()
			shape.radius = 0.48
			collision.shape = shape
			color = GameColors.DANGER
			physics.bounce = 0.9
			physics.friction = 0.18
			display_name = "ANXIETY · BOUNCY"
		"joy":
			mass = 0.8
			directional_gravity_multiplier = -0.45
			var mesh := SphereMesh.new()
			mesh.radius = 0.5
			mesh.height = 1.0
			shape_mesh.mesh = mesh
			var shape := SphereShape3D.new()
			shape.radius = 0.5
			collision.shape = shape
			color = GameColors.PAD
			physics.bounce = 0.25
			physics.friction = 0.35
			display_name = "JOY · FALLS IN REVERSE"

	physics_material_override = physics
	base_color = color
	base_emission = 0.6
	shape_mesh.material_override = GameColors.material(color, base_emission)
	add_child(shape_mesh)
	add_child(collision)
	if is_false_memory():
		_build_false_memory_warning()


func _build_false_memory_warning() -> void:
	danger_label = Label3D.new()
	danger_label.text = "FALSE MEMORY"
	danger_label.font_size = 34
	danger_label.modulate = GameColors.DANGER
	danger_label.outline_modulate = GameColors.DARK
	danger_label.outline_size = 8
	danger_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	danger_label.no_depth_test = true
	danger_label.position = Vector3(0.0, 0.78, 0.0)
	danger_label.visible = false
	add_child(danger_label)


func _build_anchor_mark() -> void:
	anchor_mark = Node3D.new()
	anchor_mark.name = "AnchorMark"
	anchor_mark.visible = false
	var mark_material := GameColors.material(Color.WHITE, 4.0, true)
	for rotation_value in [Vector3.ZERO, Vector3(0, 0, 90), Vector3(90, 0, 0)]:
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(1.48, 0.045, 0.045)
		bar.mesh = bar_mesh
		bar.rotation_degrees = rotation_value
		bar.material_override = mark_material
		anchor_mark.add_child(bar)
	add_child(anchor_mark)
