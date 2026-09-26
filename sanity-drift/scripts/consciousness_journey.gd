class_name ConsciousnessJourney
extends Node3D

# The player never moves. Streaks and rings travel toward the stationary
# camera, creating a comfortable impression of flying through thought-space.

var speed := 12.0
var travelers: Array[Node3D] = []


func _ready() -> void:
	_build_star_tunnel()
	_build_rings()


func _process(delta: float) -> void:
	for traveler in travelers:
		if not is_instance_valid(traveler):
			continue
		traveler.position.z += speed * delta
		if traveler.position.z > 5.4:
			traveler.position.z -= 42.0
	rotate_z(delta * 0.035)


func _build_star_tunnel() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91027
	var colors := [GameColors.FLOAT, GameColors.PAD, GameColors.DANGER, Color("b8b4ff"), Color.WHITE]
	for index in range(92):
		var streak := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(rng.randf_range(0.025, 0.085), rng.randf_range(0.025, 0.085), rng.randf_range(0.8, 3.8))
		streak.mesh = mesh
		var color: Color = colors[index % colors.size()]
		streak.material_override = GameColors.material(Color(color, rng.randf_range(0.55, 0.95)), rng.randf_range(2.0, 5.0), true)
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(1.2, 8.5)
		streak.position = Vector3(cos(angle) * radius, sin(angle) * radius, rng.randf_range(-38.0, 3.0))
		add_child(streak)
		travelers.append(streak)


func _build_rings() -> void:
	for index in range(7):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 4.6 + index * 0.12
		torus.outer_radius = 4.66 + index * 0.12
		ring.mesh = torus
		ring.rotation_degrees.x = 90.0
		ring.position = Vector3(0.0, 0.0, -5.0 - index * 6.0)
		var color := GameColors.FLOAT.lerp(GameColors.DANGER, float(index) / 6.0)
		ring.material_override = GameColors.material(Color(color, 0.28), 2.4, true)
		add_child(ring)
		travelers.append(ring)
