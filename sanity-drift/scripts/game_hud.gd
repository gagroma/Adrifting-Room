class_name GameHud
extends CanvasLayer

signal start_pressed
signal tutorial_pressed
signal restart_pressed
signal calm_changed(enabled: bool)

var ui_root: Control
var title_panel: Control
var controls_panel: Control
var finish_panel: Control
var room_label: Label
var phase_label: Label
var timer_label: Label
var compass_label: Label
var progress_label: Label
var anchors_label: Label
var hint_label: Label
var calm_label: Label
var finish_stats: Label
var guide_panel: PanelContainer
var guide_label: Label
var vignette_material: ShaderMaterial
var transition_overlay: ColorRect
var transition_material: ShaderMaterial

var default_help := "MOUSE — look   LMB — grab   RMB — push\nI — anchor   WHEEL — distance   P — skip drift\nK — guide hint   L — restart   O — comfort mode"


func _ready() -> void:
	layer = 10
	_build_hud()
	_build_title_panel()
	_build_controls_panel()
	_build_finish_panel()
	_build_transition_overlay()


func show_title() -> void:
	title_panel.visible = true
	controls_panel.visible = false
	finish_panel.visible = false
	_set_game_hud_visible(false)


func show_game() -> void:
	title_panel.visible = false
	controls_panel.visible = false
	finish_panel.visible = false
	_set_game_hud_visible(true)


func show_journey() -> void:
	title_panel.visible = false
	controls_panel.visible = false
	finish_panel.visible = false
	_set_game_hud_visible(false)


func show_finish(stats_text: String) -> void:
	_set_game_hud_visible(false)
	title_panel.visible = false
	controls_panel.visible = false
	finish_panel.visible = true
	finish_stats.text = stats_text


func update_status(room_name: String, room_subtitle: String, phase_text: String, phase_color: Color, seconds: int, next_direction: String, active_plates: int, total_plates: int, anchors: int, calm_mode: bool) -> void:
	room_label.text = "%s\n%s" % [room_name, room_subtitle]
	phase_label.text = phase_text
	phase_label.add_theme_color_override("font_color", phase_color)
	timer_label.text = "%02d" % seconds
	compass_label.text = "NEXT FALL: %s" % next_direction
	progress_label.text = "PLATES  %d / %d" % [active_plates, total_plates]
	anchors_label.text = "ANCHORS  %d" % anchors if anchors > 0 else ""
	calm_label.text = "COMFORT MODE" if calm_mode else ""


func set_interaction_text(text: String) -> void:
	hint_label.text = text if not text.is_empty() else default_help


func set_guide_dialogue(text: String) -> void:
	guide_label.text = text
	guide_panel.visible = not text.is_empty()


func set_vignette_strength(strength: float) -> void:
	vignette_material.set_shader_parameter("strength", strength)


func transition_out(duration := 1.25) -> Tween:
	transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_method(_set_transition_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func transition_in(duration := 0.9) -> Tween:
	transition_overlay.visible = true
	var tween := create_tween()
	tween.tween_method(_set_transition_progress, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void: transition_overlay.visible = false)
	return tween


func get_transition_progress() -> float:
	return float(transition_material.get_shader_parameter("progress"))


func _build_hud() -> void:
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	room_label = _label(24, Color.WHITE)
	room_label.position = Vector2(34, 30)
	room_label.size = Vector2(500, 70)
	ui_root.add_child(room_label)
	phase_label = _label(20, GameColors.FLOAT)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	phase_label.position = Vector2(-240, 25)
	phase_label.size = Vector2(480, 34)
	ui_root.add_child(phase_label)
	timer_label = _label(54, Color.WHITE)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.position = Vector2(-110, 58)
	timer_label.size = Vector2(220, 68)
	ui_root.add_child(timer_label)
	compass_label = _label(18, GameColors.PAD)
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_label.position = Vector2(-240, 128)
	compass_label.size = Vector2(480, 34)
	ui_root.add_child(compass_label)
	progress_label = _label(18, GameColors.MIST)
	progress_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	progress_label.position = Vector2(34, -106)
	progress_label.size = Vector2(500, 34)
	ui_root.add_child(progress_label)
	anchors_label = _label(17, GameColors.FLOAT)
	anchors_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	anchors_label.position = Vector2(34, -72)
	anchors_label.size = Vector2(420, 30)
	ui_root.add_child(anchors_label)
	hint_label = _label(15, Color(0.88, 0.87, 1.0, 0.86))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.position = Vector2(-520, -126)
	hint_label.size = Vector2(486, 92)
	hint_label.text = default_help
	ui_root.add_child(hint_label)

	guide_panel = PanelContainer.new()
	guide_panel.name = "GuideDialogue"
	guide_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	guide_panel.position = Vector2(-310, -190)
	guide_panel.size = Vector2(620, 90)
	guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var guide_style := StyleBoxFlat.new()
	guide_style.bg_color = Color(0.035, 0.035, 0.105, 0.88)
	guide_style.border_color = GameColors.FLOAT
	guide_style.set_border_width_all(2)
	guide_style.set_corner_radius_all(12)
	guide_style.content_margin_left = 20
	guide_style.content_margin_right = 20
	guide_style.content_margin_top = 11
	guide_style.content_margin_bottom = 11
	guide_panel.add_theme_stylebox_override("panel", guide_style)
	guide_label = _label(19, Color.WHITE)
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guide_panel.add_child(guide_label)
	guide_panel.visible = false
	ui_root.add_child(guide_panel)
	calm_label = _label(14, GameColors.FLOAT)
	calm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	calm_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	calm_label.position = Vector2(-330, 30)
	calm_label.size = Vector2(296, 30)
	ui_root.add_child(calm_label)

	var crosshair := _label(25, Color(0.92, 0.91, 1.0, 0.84))
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-20, -20)
	crosshair.size = Vector2(40, 40)
	ui_root.add_child(crosshair)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform float strength : hint_range(0.0, 1.0) = 0.0; void fragment(){ float d=length((UV-vec2(0.5))*vec2(1.15,1.0)); float a=smoothstep(0.28,0.73,d)*strength; COLOR=vec4(0.025,0.018,0.075,a); }"
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = shader
	vignette.material = vignette_material
	ui_root.add_child(vignette)


func _build_title_panel() -> void:
	title_panel = ColorRect.new()
	title_panel.color = Color(0.025, 0.02, 0.09, 0.96)
	title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(title_panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 9)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-330, -320)
	content.size = Vector2(660, 640)
	title_panel.add_child(content)
	var eyebrow := _label(16, GameColors.FLOAT)
	eyebrow.text = "A PHYSICS PUZZLE"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title := _label(74, Color.WHITE)
	title.text = "SANITY DRIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 88
	content.add_child(title)
	var subtitle := _label(20, Color(0.82, 0.80, 0.96))
	subtitle.text = "You stay still. Gravity does not."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	var description := _label(17, Color(0.74, 0.73, 0.90))
	description.text = "Arrange thoughts in zero gravity.\nRead where they will fall next.\nLight every plate and escape the dream."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.custom_minimum_size.y = 82
	content.add_child(description)
	var start := Button.new()
	start.text = "ENTER THE DREAM"
	start.custom_minimum_size = Vector2(300, 52)
	start.add_theme_font_size_override("font_size", 19)
	start.pressed.connect(func() -> void: start_pressed.emit())
	content.add_child(start)
	var tutorial := Button.new()
	tutorial.name = "TutorialButton"
	tutorial.text = "TUTORIAL"
	tutorial.custom_minimum_size = Vector2(300, 48)
	tutorial.add_theme_font_size_override("font_size", 18)
	tutorial.pressed.connect(func() -> void: tutorial_pressed.emit())
	content.add_child(tutorial)
	var controls := Button.new()
	controls.name = "VRControlsButton"
	controls.text = "VR CONTROLS"
	controls.custom_minimum_size = Vector2(300, 46)
	controls.add_theme_font_size_override("font_size", 17)
	controls.pressed.connect(show_vr_controls)
	content.add_child(controls)
	var calm := CheckButton.new()
	calm.text = "Comfort mode"
	calm.tooltip_text = "Stops background dust and softens the vignette"
	calm.toggled.connect(func(enabled: bool) -> void: calm_changed.emit(enabled))
	content.add_child(calm)
	var enter_hint := _label(14, Color(0.57, 0.56, 0.74))
	enter_hint.text = "ENTER / RIGHT TRIGGER — start    LEFT STICK CLICK — VR controls"
	enter_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(enter_hint)


func _build_controls_panel() -> void:
	controls_panel = ColorRect.new()
	controls_panel.name = "VRControlsPanel"
	controls_panel.color = Color(0.025, 0.02, 0.09, 0.985)
	controls_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls_panel.visible = false
	ui_root.add_child(controls_panel)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 13)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-390, -300)
	content.size = Vector2(780, 600)
	controls_panel.add_child(content)

	var eyebrow := _label(15, GameColors.FLOAT)
	eyebrow.text = "OPENXR · STANDING OR SEATED"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title := _label(48, Color.WHITE)
	title.text = "VR CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 70
	content.add_child(title)
	var intro := _label(17, Color(0.78, 0.77, 0.94))
	intro.text = "Stay in place. Point at a thought with your right hand."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(intro)

	var guide := _label(19, Color(0.94, 0.93, 1.0))
	guide.text = "RIGHT HAND\nTrigger — remote grab · release — throw\nPoint at robot + trigger — playful bump\nGrip — push the highlighted thought\nThumbstick up / down — change grab distance\n\nLEFT HAND\nTrigger — anchor a thought until the next fall\nThumbstick click — end the Drift phase early\nWrist display — timer, next gravity, plates and anchors"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	guide.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	guide.custom_minimum_size = Vector2(680, 300)
	content.add_child(guide)

	var start := Button.new()
	start.text = "ENTER THE DREAM"
	start.custom_minimum_size = Vector2(320, 50)
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(func() -> void: start_pressed.emit())
	content.add_child(start)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(220, 42)
	back.pressed.connect(show_title)
	content.add_child(back)


func show_vr_controls() -> void:
	title_panel.visible = false
	finish_panel.visible = false
	controls_panel.visible = true
	_set_game_hud_visible(false)


func toggle_vr_controls() -> void:
	if controls_panel.visible:
		show_title()
	else:
		show_vr_controls()


func _build_finish_panel() -> void:
	finish_panel = ColorRect.new()
	finish_panel.color = Color(0.95, 0.93, 1.0, 0.96)
	finish_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	finish_panel.visible = false
	ui_root.add_child(finish_panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-320, -180)
	content.size = Vector2(640, 360)
	finish_panel.add_child(content)
	var small := _label(16, GameColors.DEPTH)
	small.text = "AWAKENING"
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(small)
	var title := _label(56, GameColors.NIGHT)
	title.text = "YOUR THOUGHTS ARE IN PLACE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.y = 136
	content.add_child(title)
	finish_stats = _label(20, GameColors.DEPTH)
	finish_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(finish_stats)
	var again := Button.new()
	again.text = "DREAM AGAIN"
	again.custom_minimum_size = Vector2(300, 52)
	again.add_theme_font_size_override("font_size", 18)
	again.pressed.connect(func() -> void: restart_pressed.emit())
	content.add_child(again)


func _build_transition_overlay() -> void:
	transition_overlay = ColorRect.new()
	transition_overlay.name = "ConsciousnessTransition"
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap; uniform float progress : hint_range(0.0, 1.0) = 0.0; void fragment(){ vec2 p=UV-vec2(0.5); float radius=length(p); float angle=progress*progress*1.45*(1.0-radius); float c=cos(angle); float s=sin(angle); vec2 warped=mat2(vec2(c,-s),vec2(s,c))*p; warped*=1.0-progress*0.12; vec2 uv=clamp(warped+vec2(0.5),vec2(0.002),vec2(0.998)); vec3 scene=textureLod(screen_texture,uv,progress*6.0).rgb; vec3 mist=vec3(0.76,0.73,0.98); scene=mix(scene,mist,smoothstep(0.15,1.0,progress)*0.88); float edge=smoothstep(0.15,0.78,radius)*progress*0.35; COLOR=vec4(mix(scene,vec3(0.10,0.07,0.25),edge),smoothstep(0.0,0.82,progress)*0.985); }"
	transition_material = ShaderMaterial.new()
	transition_material.shader = shader
	transition_material.set_shader_parameter("progress", 0.0)
	transition_overlay.material = transition_material
	transition_overlay.visible = false
	ui_root.add_child(transition_overlay)


func _set_transition_progress(value: float) -> void:
	transition_material.set_shader_parameter("progress", value)


func _set_game_hud_visible(value: bool) -> void:
	for control in [room_label, phase_label, timer_label, compass_label, progress_label, anchors_label, hint_label, calm_label]:
		control.visible = value


func _label(font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result
