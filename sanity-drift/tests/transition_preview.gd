extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://main.tscn") as PackedScene).instantiate()
	game.set("audio_enabled", false)
	root.add_child(game)
	await process_frame
	game.call("_start_game")
	await create_timer(0.25).timeout
	game.set("room_transitioning", true)
	var builder := game.get("room_builder") as RoomBuilder
	var hud := game.get("hud") as GameHud
	var player := game.get("player") as PlayerController
	builder.disintegrate_room(0.55)
	hud.transition_out(0.55)
	player.transition_out(0.55)
	await create_timer(0.60).timeout
	builder.clear_room()
	hud.show_journey()
	var journey := ConsciousnessJourney.new()
	game.add_child(journey)
	hud.transition_in(0.32)
	player.transition_in(0.32)
	await create_timer(0.85).timeout
	hud.transition_out(0.38)
	player.transition_out(0.38)
	await create_timer(0.42).timeout
	journey.queue_free()
	builder.build_room((game.get("rooms") as Array)[1])
	hud.show_game()
	hud.transition_in(0.8)
	player.transition_in(0.8)
