extends Node3D
## Visual circuit connecting the two live Library plates through a door relay.

const COMPLETION_DURATION := 0.48
const ACTIVE_ENERGY := 5.2

var plate_i: PressurePad
var plate_ii: PressurePad
var point_i := Vector3.ZERO
var point_ii := Vector3.ZERO
var relay_point := Vector3(0.0, 0.48, -5.42)
var material_i: StandardMaterial3D
var material_ii: StandardMaterial3D
var relay_material: StandardMaterial3D
var spark_i: MeshInstance3D
var spark_ii: MeshInstance3D
var completion_pulse: MeshInstance3D
var pulse_light: OmniLight3D
var energy_i := 0.0
var energy_ii := 0.0
var animation_time := 0.0
var completion_active := false
var completion_elapsed := 0.0


func configure(first_plate: PressurePad, second_plate: PressurePad) -> void:
	plate_i = first_plate
	plate_ii = second_plate
	point_i = plate_i.position - plate_i.gravity_direction * 0.30
	point_ii = plate_ii.position - plate_ii.gravity_direction * 0.30
	material_i = GameColors.material(Color(0.25, 0.95, 0.88, 0.18), 0.18, true)
	material_ii = GameColors.material(Color(1.0, 0.74, 0.26, 0.18), 0.18, true)
	relay_material = GameColors.material(Color(0.66, 0.58, 1.0, 0.36), 0.35, true)
	_add_beam(point_i, relay_point, material_i, "PlateIHalf")
	_add_beam(point_ii, relay_point, material_ii, "PlateIIHalf")
	_add_relay()
	spark_i = _add_orb("PlateISpark", Color("62ead7"), 0.075)
	spark_ii = _add_orb("PlateIISpark", Color("ffd36e"), 0.075)
	completion_pulse = _add_orb("CompletionPulse", Color("e9a7ff"), 0.15)
	completion_pulse.visible = false
	pulse_light = OmniLight3D.new()
	pulse_light.name = "CompletionPulseLight"
	pulse_light.light_color = Color("df7dff")
	pulse_light.light_energy = 0.0
	pulse_light.omni_range = 2.8
	pulse_light.shadow_enabled = false
	add_child(pulse_light)
	set_process(true)
	_apply_visuals()


func play_completion_pulse() -> void:
	if completion_active:
		return
	completion_active = true
	completion_elapsed = 0.0
	energy_i = 1.0
	energy_ii = 1.0
	spark_i.visible = false
	spark_ii.visible = false
	completion_pulse.visible = true
	completion_pulse.position = point_i
	pulse_light.position = point_i
	pulse_light.light_energy = 4.8
	_apply_visuals()


func _process(delta: float) -> void:
	animation_time += delta
	if completion_active:
		completion_elapsed = minf(completion_elapsed + delta, COMPLETION_DURATION)
		var progress := completion_elapsed / COMPLETION_DURATION
		completion_pulse.position = _completion_position(progress)
		pulse_light.position = completion_pulse.position
		pulse_light.light_energy = 3.6 + sin(progress * PI) * 3.2
		var pulse_scale := 1.0 + sin(progress * PI) * 1.25
		completion_pulse.scale = Vector3.ONE * pulse_scale
		_apply_visuals()
		return
	var target_i := 1.0 if is_instance_valid(plate_i) and plate_i.latched else 0.0
	var target_ii := 1.0 if is_instance_valid(plate_ii) and plate_ii.latched else 0.0
	energy_i = move_toward(energy_i, target_i, delta * 7.0)
	energy_ii = move_toward(energy_ii, target_ii, delta * 7.0)
	spark_i.visible = energy_i > 0.05
	spark_ii.visible = energy_ii > 0.05
	if spark_i.visible:
		spark_i.position = point_i.lerp(relay_point, fmod(animation_time * 0.72, 1.0))
	if spark_ii.visible:
		spark_ii.position = point_ii.lerp(relay_point, fmod(animation_time * 0.72 + 0.5, 1.0))
	_apply_visuals()


func _apply_visuals() -> void:
	_set_line_energy(material_i, Color("62ead7"), energy_i)
	_set_line_energy(material_ii, Color("ffd36e"), energy_ii)
	var relay_energy := maxf(energy_i, energy_ii)
	if completion_active:
		relay_energy = 1.0 + sin(clampf(completion_elapsed / COMPLETION_DURATION, 0.0, 1.0) * PI) * 1.8
	relay_material.albedo_color = Color(0.68, 0.60, 1.0, 0.28 + minf(relay_energy, 1.0) * 0.62)
	relay_material.emission = Color("b6a5ff")
	relay_material.emission_energy_multiplier = 0.35 + relay_energy * 4.2


func _set_line_energy(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = Color(color, 0.13 + energy * 0.78)
	material.emission = color
	material.emission_energy_multiplier = 0.16 + energy * ACTIVE_ENERGY


func _completion_position(progress: float) -> Vector3:
	if progress < 0.5:
		return point_i.lerp(relay_point, progress * 2.0)
	return relay_point.lerp(point_ii, (progress - 0.5) * 2.0)


func _add_beam(from: Vector3, to: Vector3, material: Material, node_name: String) -> void:
	var direction := to - from
	var beam := MeshInstance3D.new()
	beam.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.032
	mesh.bottom_radius = 0.032
	mesh.height = direction.length()
	mesh.radial_segments = 8
	beam.mesh = mesh
	beam.material_override = material
	beam.position = (from + to) * 0.5
	beam.quaternion = Quaternion(Vector3.UP, direction.normalized())
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _add_relay() -> void:
	var relay := MeshInstance3D.new()
	relay.name = "DoorRelay"
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	relay.mesh = mesh
	relay.material_override = relay_material
	relay.position = relay_point
	relay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(relay)
	for ring_rotation in [Vector3.ZERO, Vector3(90.0, 0.0, 0.0)]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.24
		torus.outer_radius = 0.29
		ring.mesh = torus
		ring.material_override = relay_material
		ring.position = relay_point
		ring.rotation_degrees = ring_rotation
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


func _add_orb(node_name: String, color: Color, radius: float) -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	orb.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	orb.mesh = mesh
	orb.material_override = GameColors.material(Color(color, 0.96), 8.0, true)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	return orb
