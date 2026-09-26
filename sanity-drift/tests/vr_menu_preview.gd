extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.current = true
	camera.near = 0.05
	world.add_child(camera)
	var menu := VRMenu.new()
	menu.position = Vector3(0.0, 0.0, -1.28)
	world.add_child(menu)
	await process_frame
	menu.update_pointer(Vector3(0.0, -0.03, 0.0), Vector3.FORWARD)
