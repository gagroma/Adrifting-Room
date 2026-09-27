extends Node3D
## Room-space anticipation and impact, shared by desktop and both XR eyes.

const IMPACT_SECONDS := 0.48

var room_half := Vector3.ZERO
var direction := Vector3.DOWN
var warning_duration := 5.0
var warning_left := 0.0
var warning_active := false
var impact_left := 0.0
var calm_mode := false
var lamp: OmniLight3D
var lamp_energy := 0.0
var lamp_color := Color.WHITE
var dust: Node3D
var dust_rest: Array[Transform3D] = []
var furniture: Array[Node3D] = []
var furniture_rest: Array[Transform3D] = []
var wave_material: ShaderMaterial
var surfaces: Node3D
var flash: OmniLight3D


func configure(half_size: Vector3, room_lamp: OmniLight3D, room_dust: Node3D, decor: Array[Node3D]) -> void:
	room_half = half_size
	lamp = room_lamp
	lamp_energy = lamp.light_energy
	lamp_color = lamp.light_color
	dust = room_dust
	for mote in dust.get_children():
		dust_rest.append((mote as Node3D).transform)
	furniture = decor.duplicate()
	for piece in furniture:
		furniture_rest.append(piece.transform)
	_build_wave()
	flash = OmniLight3D.new()
	flash.name = "ShiftFlash"
	flash.omni_range = 16.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	add_child(flash)
	reset()


func begin_warning(next_direction: Vector3, duration: float) -> void:
	reset()
	direction = next_direction.normalized()
	warning_duration = maxf(duration, 0.001)
	warning_left = warning_duration
	warning_active = true
	wave_material.set_shader_parameter("shift_direction", direction)
	wave_material.set_shader_parameter("shift_color", _direction_color())
	surfaces.visible = true
	_apply_frame()


func update_warning(seconds_left: float) -> void:
	warning_left = maxf(seconds_left, 0.0)


func trigger_impact(fall_direction: Vector3) -> void:
	direction = fall_direction.normalized()
	warning_active = false
	impact_left = IMPACT_SECONDS
	wave_material.set_shader_parameter("shift_direction", direction)
	wave_material.set_shader_parameter("shift_color", _direction_color())
	flash.light_color = _direction_color()
	surfaces.visible = true
	_restore_furniture()
	_apply_frame()


func set_calm_mode(value: bool) -> void:
	calm_mode = value
	_apply_frame()


func reset() -> void:
	warning_active = false
	impact_left = 0.0
	_restore_furniture()
	if is_instance_valid(lamp):
		lamp.light_energy = lamp_energy
		lamp.light_color = lamp_color
	if is_instance_valid(dust):
		for index in range(dust_rest.size()):
			(dust.get_child(index) as Node3D).transform = dust_rest[index]
	if is_instance_valid(surfaces):
		surfaces.visible = false
	if is_instance_valid(flash):
		flash.light_energy = 0.0
	set_process(false)


func _process(delta: float) -> void:
	if impact_left > 0.0:
		impact_left = maxf(impact_left - delta, 0.0)
		if impact_left <= 0.0:
			reset()
			return
	_apply_frame()


func _apply_frame() -> void:
	if not warning_active and impact_left <= 0.0:
		return
	set_process(true)
	var age := warning_duration - warning_left
	var progress := clampf(age / warning_duration, 0.0, 1.0)
	var impact := impact_left / IMPACT_SECONDS
	var strength := 0.2 if calm_mode else 1.0
	var extent := room_half.dot(direction.abs()) - 0.04
	# Two sweeps, both travelling toward the coming gravity wall.
	var wave_progress := fmod(progress * 2.0, 1.0)
	var wave_position := lerpf(-extent, extent, wave_progress)
	if not warning_active:
		wave_position = extent
	wave_material.set_shader_parameter("wave_position", wave_position)
	wave_material.set_shader_parameter("strength", strength * (0.32 + progress * 0.3) if warning_active else 0.0)
	wave_material.set_shader_parameter("impact", impact * impact * strength)
	# Slow, smooth light dips; comfort mode keeps the room light steady.
	var dip := pow(0.5 + 0.5 * sin(age * TAU * 1.4), 6.0)
	lamp.light_energy = lamp_energy * (1.0 - dip * 0.38) if warning_active and not calm_mode else lamp_energy
	flash.light_energy = impact * impact * 3.0 * strength
	var tremble := clampf(1.0 - warning_left, 0.0, 1.0) if warning_active and not calm_mode else 0.0
	for index in range(furniture.size()):
		var piece := furniture[index]
		piece.transform = furniture_rest[index]
		# All pieces share one displacement, so furniture assemblies stay intact.
		piece.position += direction * sin(age * 49.0) * 0.018 * tremble
	var pull := (0.15 + progress * 0.85) if warning_active else impact
	var local_direction := dust.basis.inverse() * direction
	var alignment := Quaternion(Vector3.UP, local_direction.normalized())
	for index in range(dust_rest.size()):
		var mote := dust.get_child(index) as Node3D
		var rest := dust_rest[index]
		mote.position = rest.origin + local_direction * pull * 0.28
		mote.basis = Basis(alignment) * Basis.from_scale(Vector3(0.75, 1.0 + 7.0 * pull, 0.75))


func _restore_furniture() -> void:
	for index in range(furniture.size()):
		if is_instance_valid(furniture[index]):
			furniture[index].transform = furniture_rest[index]


func _direction_color() -> Color:
	if absf(direction.y) > 0.5:
		return GameColors.PAD if direction.y < 0.0 else GameColors.FLOAT
	if absf(direction.x) > 0.5:
		return Color("a39bff")
	return GameColors.DANGER


func _build_wave() -> void:
	surfaces = Node3D.new()
	surfaces.name = "WallWave"
	add_child(surfaces)
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 shift_direction = vec3(0.0, -1.0, 0.0);
uniform vec4 shift_color : source_color = vec4(0.4, 0.9, 0.8, 1.0);
uniform float wave_position = 0.0;
uniform float strength = 0.0;
uniform float impact = 0.0;
varying vec3 room_position;
void vertex() {
    room_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float distance_to_wave = abs(dot(room_position, shift_direction) - wave_position);
    float band = 1.0 - smoothstep(0.05, 0.85, distance_to_wave);
    ALBEDO = shift_color.rgb;
    ALPHA = band * strength + impact * 0.16;
}
"""
	wave_material = ShaderMaterial.new()
	wave_material.shader = shader
	for normal in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var surface := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(room_half.x, room_half.y) * 2.0
		if absf(normal.x) > 0.5:
			quad.size = Vector2(room_half.z, room_half.y) * 2.0
		elif absf(normal.y) > 0.5:
			quad.size = Vector2(room_half.x, room_half.z) * 2.0
		surface.mesh = quad
		surface.material_override = wave_material
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface.position = normal * (room_half - Vector3.ONE * 0.035)
		surface.quaternion = Quaternion(Vector3.BACK, normal)
		surfaces.add_child(surface)
