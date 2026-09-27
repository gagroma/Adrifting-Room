extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var kitchen := RoomCatalog.all_rooms()[1]
	var light_data := (kitchen["pads"] as Array)[1] as Dictionary
	var hard_kitchen := RoomCatalog.hard_rooms()[1]
	var hard_light_data := (hard_kitchen["pads"] as Array)[3] as Dictionary
	_check(is_equal_approx(float(light_data["maximum_mass"]), 1.0), "normal kitchen LIGHT plate has a maximum mass")
	_check(is_equal_approx(float(hard_light_data["maximum_mass"]), 1.0), "hard kitchen LIGHT plate has a maximum mass")

	var plate := PressurePad.new()
	plate.configure(light_data, RoomBuilder.ROOM_HALF)
	root.add_child(plate)

	var memory := ThoughtProp.new()
	memory.configure("memory")
	root.add_child(memory)
	var anxiety := ThoughtProp.new()
	anxiety.configure("anxiety")
	root.add_child(anxiety)
	var joy := ThoughtProp.new()
	joy.configure("joy")
	root.add_child(joy)
	var thoughts: Array[ThoughtProp] = [memory, anxiety, joy]
	for thought in thoughts:
		thought.global_position = Vector3.ZERO

	memory.global_position = plate.global_position - Vector3.UP * 0.62
	plate.update_contact(0.3, Vector3.UP, thoughts)
	_check(not plate.latched, "LIGHT rejects an 8 kg memory")
	memory.global_position = Vector3.ZERO

	anxiety.global_position = plate.global_position - Vector3.UP * 0.62
	plate.update_contact(0.3, Vector3.UP, thoughts)
	_check(not plate.latched, "LIGHT rejects 1.2 kg anxiety")
	anxiety.global_position = Vector3.ZERO

	joy.global_position = plate.global_position - Vector3.UP * 0.62
	plate.update_contact(0.3, Vector3.UP, thoughts)
	_check(plate.latched, "LIGHT accepts 0.8 kg Joy")

	if failures.is_empty():
		print("SANITY_DRIFT_PRESSURE_PAD_TEST: PASS")
		quit(0)
		return
	for failure in failures:
		push_error("SANITY_DRIFT_PRESSURE_PAD_TEST: " + failure)
	quit(1)
