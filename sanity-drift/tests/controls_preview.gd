extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	game.set("audio_enabled", false)
	root.add_child(game)
	await process_frame
	(game.get("hud") as GameHud).show_vr_controls()
