class_name ThoughtProp
extends RigidBody3D

var thought_kind := "memory"
var display_name := "THOUGHT"
var directional_gravity_multiplier := 1.0
var anchored := false

var shape_mesh: MeshInstance3D
var anchor_mark: Node3D


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


func apply_directional_gravity(direction: Vector3) -> void:
	if freeze:
		return
	apply_central_force(direction * 9.8 * mass * directional_gravity_multiplier)
	linear_velocity = linear_velocity.limit_length(15.0)


func set_grab_highlight(active: bool) -> void:
	if not is_instance_valid(shape_mesh):
		return
	var shape_material := shape_mesh.material_override as StandardMaterial3D
	shape_material.emission_energy_multiplier = 3.2 if active else 0.6


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
	shape_mesh.material_override = GameColors.material(color, 0.6)
	add_child(shape_mesh)
	add_child(collision)


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
