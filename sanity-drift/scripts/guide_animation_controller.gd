class_name GuideAnimationController
extends Node

## Maps gameplay states to the clips supplied by Robot.fbx.

signal gesture_finished

var player: AnimationPlayer
var clips: Dictionary = {}
var moving := false
var gesturing := false
var pending_gesture := ""
var active_gesture := ""


func configure(animation_player: AnimationPlayer) -> void:
	player = animation_player
	for clip_name in player.get_animation_list():
		var short_name := String(clip_name).get_slice("|", 1).trim_prefix("Robot_").to_lower()
		clips[short_name] = clip_name
	player.animation_finished.connect(_on_animation_finished)
	_play_base()


func set_moving(value: bool) -> void:
	if moving == value:
		return
	moving = value
	if moving:
		if gesturing:
			pending_gesture = active_gesture
		gesturing = false
		_play_base()
	elif not pending_gesture.is_empty():
		var gesture_name := pending_gesture
		pending_gesture = ""
		gesture(gesture_name)
	elif not gesturing:
		_play_base()


func gesture(emotion: String) -> void:
	var key := emotion.to_lower()
	if not clips.has(key):
		return
	if moving:
		pending_gesture = key
		return
	gesturing = true
	active_gesture = key
	player.play(clips[key], 0.18)


func _on_animation_finished(_clip: StringName) -> void:
	if gesturing:
		gesturing = false
		active_gesture = ""
		gesture_finished.emit()
		_play_base()
	elif not player.is_playing():
		_play_base()


func _play_base() -> void:
	if player == null:
		return
	var key := "walking" if moving else "idle"
	if clips.has(key):
		player.play(clips[key], 0.2)
