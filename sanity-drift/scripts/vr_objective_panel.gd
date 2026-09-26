class_name VRObjectivePanel
extends Node3D

const VIEW_SIZE := Vector2i(760, 460)
const PANEL_SIZE := Vector2(0.72, 0.435)

var panel_viewport: SubViewport
var room_label: Label
var objective_label: Label
var phase_label: Label
var timer_label: Label
var gravity_label: Label
var progress_label: Label


func _ready() -> void:
	_build_viewport()
	_build_surface()


func update_status(room_name: String, objective: String, phase_text: String, phase_color: Color, seconds: int, next_direction: String, active_plates: int, total_plates: int, anchors: int) -> void:
	room_label.text = room_name
	objective_label.text = objective
	phase_label.text = phase_text
	phase_label.add_theme_color_override("font_color", phase_color)
	timer_label.text = "%02d" % seconds
	gravity_label.text = "NEXT FALL  ·  %s" % next_direction
	progress_label.text = "PLATES  %d / %d" % [active_plates, total_plates]
	if anchors > 0:
		progress_label.text += "     ANCHORS  %d" % anchors


func _build_viewport() -> void:
	panel_viewport = SubViewport.new()
	panel_viewport.name = "ObjectiveViewport"
	panel_viewport.size = VIEW_SIZE
	panel_viewport.transparent_bg = true
	panel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(panel_viewport)

	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = VIEW_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.04, 0.13, 0.94)
	panel_style.border_color = Color(0.36, 0.95, 0.90, 0.94)
	panel_style.set_border_width_all(5)
	panel_style.corner_radius_top_left = 24
	panel_style.corner_radius_top_right = 24
	panel_style.corner_radius_bottom_left = 24
	panel_style.corner_radius_bottom_right = 24
	panel.add_theme_stylebox_override("panel", panel_style)
	panel_viewport.add_child(panel)

	var marker := ColorRect.new()
	marker.position = Vector2(36, 44)
	marker.size = Vector2(8, 76)
	marker.color = GameColors.FLOAT
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_viewport.add_child(marker)

	var eyebrow := _label("CURRENT PUZZLE", 20, GameColors.FLOAT)
	eyebrow.position = Vector2(68, 35)
	eyebrow.size = Vector2(430, 30)
	panel_viewport.add_child(eyebrow)

	room_label = _label("BEDROOM", 38, Color.WHITE)
	room_label.position = Vector2(68, 66)
	room_label.size = Vector2(430, 56)
	panel_viewport.add_child(room_label)

	objective_label = _label("Guide the Memory onto the 8 kg plate.", 27, Color("d8d5f4"))
	objective_label.position = Vector2(40, 142)
	objective_label.size = Vector2(680, 92)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel_viewport.add_child(objective_label)

	var separator := ColorRect.new()
	separator.position = Vector2(40, 252)
	separator.size = Vector2(680, 2)
	separator.color = Color(0.40, 0.38, 0.65, 0.62)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_viewport.add_child(separator)

	phase_label = _label("DRIFT · ARRANGE THOUGHTS", 21, GameColors.FLOAT)
	phase_label.position = Vector2(40, 276)
	phase_label.size = Vector2(500, 38)
	panel_viewport.add_child(phase_label)

	timer_label = _label("22", 48, Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.position = Vector2(570, 264)
	timer_label.size = Vector2(150, 62)
	panel_viewport.add_child(timer_label)

	gravity_label = _label("NEXT FALL  ·  DOWN", 23, GameColors.PAD)
	gravity_label.position = Vector2(40, 334)
	gravity_label.size = Vector2(420, 40)
	panel_viewport.add_child(gravity_label)

	progress_label = _label("PLATES  0 / 1", 23, Color("d8d5f4"))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.position = Vector2(380, 334)
	progress_label.size = Vector2(340, 40)
	panel_viewport.add_child(progress_label)

	var hint := _label("Arrange the thoughts before gravity returns", 18, Color("8f8ab6"))
	hint.position = Vector2(40, 393)
	hint.size = Vector2(680, 30)
	panel_viewport.add_child(hint)


func _build_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "ObjectiveSurface"
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	surface.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = panel_viewport.get_texture()
	material.render_priority = 119
	surface.material_override = material
	add_child(surface)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
