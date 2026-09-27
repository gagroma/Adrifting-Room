class_name VRMenu
extends Node3D

signal start_requested
signal tutorial_requested
signal main_menu_requested
signal resume_requested
signal restart_requested
signal quit_requested

const VIEW_SIZE := Vector2i(1000, 700)
const PANEL_SIZE := Vector2(1.60, 1.12)

var menu_viewport: SubViewport
var start_page: Control
var controls_page: Control
var finish_page: Control
var pause_page: Control
var start_button: Button
var tutorial_button: Button
var controls_button: Button
var back_button: Button
var replay_button: Button
var finish_menu_button: Button
var resume_button: Button
var pause_restart_button: Button
var pause_menu_button: Button
var quit_button: Button
var finish_eyebrow: Label
var finish_title: Label
var finish_subtitle: Label
var cursor: ColorRect
var hovered_button: Button


func _ready() -> void:
	_build_viewport()
	_build_surface()
	show_start_page()


func update_pointer(ray_origin: Vector3, ray_direction: Vector3) -> void:
	if not visible or not is_inside_tree():
		return
	var local_origin := to_local(ray_origin)
	var local_direction := global_transform.basis.inverse() * ray_direction.normalized()
	if absf(local_direction.z) < 0.0001:
		_clear_hover()
		return
	var distance := -local_origin.z / local_direction.z
	if distance <= 0.0:
		_clear_hover()
		return
	var hit := local_origin + local_direction * distance
	if absf(hit.x) > PANEL_SIZE.x * 0.5 or absf(hit.y) > PANEL_SIZE.y * 0.5:
		_clear_hover()
		return
	var pointer_position := Vector2(
		(hit.x / PANEL_SIZE.x + 0.5) * VIEW_SIZE.x,
		(0.5 - hit.y / PANEL_SIZE.y) * VIEW_SIZE.y
	)
	cursor.position = pointer_position - cursor.size * 0.5
	cursor.visible = true
	var next_hover: Button
	for button in [start_button, tutorial_button, controls_button, back_button, replay_button, finish_menu_button, resume_button, pause_restart_button, pause_menu_button, quit_button]:
		if not is_instance_valid(button):
			continue
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pointer_position):
			next_hover = button
			break
	_set_hovered_button(next_hover)


func press_hovered() -> void:
	if hovered_button == start_button:
		start_requested.emit()
	elif hovered_button == tutorial_button:
		tutorial_requested.emit()
	elif hovered_button == controls_button:
		show_controls_page()
	elif hovered_button == back_button:
		show_start_page()
	elif hovered_button == replay_button:
		start_requested.emit()
	elif hovered_button == finish_menu_button:
		main_menu_requested.emit()
	elif hovered_button == resume_button:
		resume_requested.emit()
	elif hovered_button == pause_restart_button:
		restart_requested.emit()
	elif hovered_button == pause_menu_button:
		main_menu_requested.emit()
	elif hovered_button == quit_button:
		quit_requested.emit()


func toggle_controls() -> void:
	if controls_page.visible:
		show_start_page()
	else:
		show_controls_page()


func show_start_page() -> void:
	start_page.visible = true
	controls_page.visible = false
	finish_page.visible = false
	pause_page.visible = false
	_clear_hover()


func show_controls_page() -> void:
	start_page.visible = false
	controls_page.visible = true
	finish_page.visible = false
	pause_page.visible = false
	_clear_hover()


func show_finish_page(loss := false) -> void:
	start_page.visible = false
	controls_page.visible = false
	finish_page.visible = true
	pause_page.visible = false
	if loss:
		finish_eyebrow.text = "FALSE MEMORY ACCEPTED"
		finish_eyebrow.add_theme_color_override("font_color", GameColors.DANGER)
		finish_title.text = "THE DREAM\nCOLLAPSED"
		finish_subtitle.text = "The room was destroyed · pull the flashing memory away within 5 seconds"
		replay_button.text = "RETRY ROOM"
	else:
		finish_eyebrow.text = "AWAKENING"
		finish_eyebrow.add_theme_color_override("font_color", GameColors.FLOAT)
		finish_title.text = "YOUR THOUGHTS\nARE IN PLACE"
		finish_subtitle.text = "All dream layers complete"
		replay_button.text = "DREAM AGAIN"
	_clear_hover()


func show_pause_page() -> void:
	start_page.visible = false
	controls_page.visible = false
	finish_page.visible = false
	pause_page.visible = true
	_clear_hover()


func _build_viewport() -> void:
	menu_viewport = SubViewport.new()
	menu_viewport.name = "MenuViewport"
	menu_viewport.size = VIEW_SIZE
	menu_viewport.transparent_bg = true
	menu_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(menu_viewport)

	var backdrop := Panel.new()
	backdrop.position = Vector2.ZERO
	backdrop.size = VIEW_SIZE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_style := StyleBoxFlat.new()
	backdrop_style.bg_color = Color("11102d")
	backdrop_style.border_color = GameColors.FLOAT
	backdrop_style.set_border_width_all(7)
	backdrop_style.corner_radius_top_left = 28
	backdrop_style.corner_radius_top_right = 28
	backdrop_style.corner_radius_bottom_left = 28
	backdrop_style.corner_radius_bottom_right = 28
	backdrop.add_theme_stylebox_override("panel", backdrop_style)
	menu_viewport.add_child(backdrop)

	start_page = Control.new()
	start_page.position = Vector2.ZERO
	start_page.size = VIEW_SIZE
	menu_viewport.add_child(start_page)
	_build_start_page()

	controls_page = Control.new()
	controls_page.position = Vector2.ZERO
	controls_page.size = VIEW_SIZE
	menu_viewport.add_child(controls_page)
	_build_controls_page()

	finish_page = Control.new()
	finish_page.position = Vector2.ZERO
	finish_page.size = VIEW_SIZE
	menu_viewport.add_child(finish_page)
	_build_finish_page()

	pause_page = Control.new()
	pause_page.position = Vector2.ZERO
	pause_page.size = VIEW_SIZE
	menu_viewport.add_child(pause_page)
	_build_pause_page()

	cursor = ColorRect.new()
	cursor.name = "AimCursor"
	cursor.size = Vector2(18, 18)
	cursor.color = GameColors.PAD
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.visible = false
	menu_viewport.add_child(cursor)


func _build_surface() -> void:
	var surface := MeshInstance3D.new()
	surface.name = "MenuSurface"
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	surface.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = menu_viewport.get_texture()
	material.render_priority = 120
	surface.material_override = material
	add_child(surface)


func _build_start_page() -> void:
	var eyebrow := _label("A PHYSICS PUZZLE", 24, GameColors.FLOAT)
	eyebrow.position = Vector2(100, 72)
	eyebrow.size = Vector2(800, 36)
	start_page.add_child(eyebrow)

	var title := _label("SANITY DRIFT", 82, Color.WHITE)
	title.position = Vector2(80, 110)
	title.size = Vector2(840, 112)
	start_page.add_child(title)

	var subtitle := _label("You stay still. Gravity does not.", 28, Color("cac6ec"))
	subtitle.position = Vector2(100, 230)
	subtitle.size = Vector2(800, 44)
	start_page.add_child(subtitle)

	start_button = _button("ENTER THE DREAM", Vector2(190, 290), Vector2(620, 88))
	start_page.add_child(start_button)
	tutorial_button = _button("TUTORIAL", Vector2(190, 390), Vector2(620, 72))
	start_page.add_child(tutorial_button)
	var campaign := _label("6 LEVEL CAMPAIGN · NORMAL → HARD", 24, GameColors.PAD)
	campaign.position = Vector2(100, 480)
	campaign.size = Vector2(800, 40)
	start_page.add_child(campaign)
	controls_button = _button("VR CONTROLS", Vector2(190, 535), Vector2(620, 62))
	start_page.add_child(controls_button)

	var hint := _label("Right trigger: select · left ≡ button: pause", 22, Color("8f8ab6"))
	hint.position = Vector2(100, 620)
	hint.size = Vector2(800, 34)
	start_page.add_child(hint)


func _build_controls_page() -> void:
	var title := _label("VR CONTROLS", 56, GameColors.FLOAT)
	title.position = Vector2(100, 55)
	title.size = Vector2(800, 76)
	controls_page.add_child(title)

	var guide := _label(
		"RIGHT HAND\nTrigger  —  grab / release\nPoint at robot + trigger  —  playful bump\nGrip  —  push the highlighted thought\nThumbstick / trackpad up or down  —  grab distance\n\nLEFT HAND\nTrigger or grip  —  anchor until the next fall\nThumbstick / trackpad click or X  —  skip the Drift phase\n≡ Menu button  —  pause / resume",
		28, Color.WHITE
	)
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide.position = Vector2(165, 145)
	guide.size = Vector2(700, 350)
	controls_page.add_child(guide)

	back_button = _button("BACK", Vector2(290, 535), Vector2(420, 82))
	controls_page.add_child(back_button)


func _build_finish_page() -> void:
	finish_eyebrow = _label("AWAKENING", 24, GameColors.FLOAT)
	finish_eyebrow.position = Vector2(100, 82)
	finish_eyebrow.size = Vector2(800, 42)
	finish_page.add_child(finish_eyebrow)

	finish_title = _label("YOUR THOUGHTS\nARE IN PLACE", 62, Color.WHITE)
	finish_title.position = Vector2(100, 132)
	finish_title.size = Vector2(800, 180)
	finish_page.add_child(finish_title)

	finish_subtitle = _label("All dream layers complete", 27, Color("cac6ec"))
	finish_subtitle.position = Vector2(80, 315)
	finish_subtitle.size = Vector2(840, 66)
	finish_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	finish_page.add_child(finish_subtitle)

	replay_button = _button("DREAM AGAIN", Vector2(190, 400), Vector2(620, 82))
	finish_page.add_child(replay_button)
	finish_menu_button = _button("MAIN MENU", Vector2(190, 510), Vector2(620, 76))
	finish_page.add_child(finish_menu_button)


func _build_pause_page() -> void:
	var eyebrow := _label("DREAM SUSPENDED", 24, GameColors.FLOAT)
	eyebrow.position = Vector2(100, 65)
	eyebrow.size = Vector2(800, 40)
	pause_page.add_child(eyebrow)
	var title := _label("PAUSED", 74, Color.WHITE)
	title.position = Vector2(100, 105)
	title.size = Vector2(800, 100)
	pause_page.add_child(title)
	var hint := _label("Use the right controller to choose", 24, Color("cac6ec"))
	hint.position = Vector2(100, 200)
	hint.size = Vector2(800, 42)
	pause_page.add_child(hint)
	resume_button = _button("CONTINUE", Vector2(190, 260), Vector2(620, 72))
	pause_page.add_child(resume_button)
	pause_restart_button = _button("RESTART LEVEL", Vector2(190, 345), Vector2(620, 72))
	pause_page.add_child(pause_restart_button)
	pause_menu_button = _button("MAIN MENU", Vector2(190, 430), Vector2(620, 72))
	pause_page.add_child(pause_menu_button)
	quit_button = _button("EXIT GAME", Vector2(190, 515), Vector2(620, 72))
	pause_page.add_child(quit_button)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_size_override("font_size", 30)
	button.focus_mode = Control.FOCUS_NONE
	_apply_button_style(button, false)
	return button


func _apply_button_style(button: Button, hovered: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameColors.FLOAT if hovered else Color("262150")
	style.border_color = Color.WHITE if hovered else Color("5a548d")
	style.set_border_width_all(4 if hovered else 2)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override("font_color", GameColors.DARK if hovered else Color.WHITE)


func _set_hovered_button(button: Button) -> void:
	if hovered_button == button:
		return
	if is_instance_valid(hovered_button):
		_apply_button_style(hovered_button, false)
	hovered_button = button
	if is_instance_valid(hovered_button):
		_apply_button_style(hovered_button, true)


func _clear_hover() -> void:
	cursor.visible = false
	_set_hovered_button(null)
