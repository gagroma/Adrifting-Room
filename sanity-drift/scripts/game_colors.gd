class_name GameColors
extends RefCounted

const NIGHT := Color("1f1b4b")
const DEPTH := Color("2d2870")
const MIST := Color("ece8f8")
const FLOAT := Color("62d9c6")
const PAD := Color("f7c873")
const DANGER := Color("e88fb6")
const DARK := Color("0c0a22")


static func material(color: Color, emission_strength := 0.0, transparent := false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	result.metallic = 0.08
	if emission_strength > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission_strength
	if transparent or color.a < 0.999:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return result


static func direction_name(direction: Vector3) -> String:
	if direction == Vector3.DOWN:
		return "DOWN  ↓"
	if direction == Vector3.UP:
		return "UP  ↑"
	if direction == Vector3.RIGHT:
		return "RIGHT  →"
	if direction == Vector3.LEFT:
		return "LEFT  ←"
	if direction == Vector3.FORWARD:
		return "FAR WALL  ↗"
	return "NEAR WALL  ↙"
