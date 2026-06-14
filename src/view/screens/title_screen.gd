class_name TitleScreen
extends Control
## Title: background art, game name, start button, drifting embers.

signal start_run


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/title_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Embers rising from the burning skyline.
	var embers := CPUParticles2D.new()
	embers.position = Vector2(640, 560)
	embers.amount = 40
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(660, 60)
	embers.direction = Vector2(0, -1)
	embers.spread = 14.0
	embers.gravity = Vector2(6, -14)
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 52.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.4
	embers.color = Color(1.0, 0.62, 0.25, 0.7)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	embers.color_ramp = ramp
	add_child(embers)

	var title := UiKit.label("INTO THE BREACH", 64)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.custom_minimum_size = Vector2(1280, 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 90)
	add_child(title)

	var sub := UiKit.label("— demo —", 20)
	sub.modulate = Color(1, 1, 1, 0.7)
	sub.custom_minimum_size = Vector2(1280, 0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 180)
	add_child(sub)

	# CTA: the chunky end-turn button frame from the kit, play icon + text.
	const CTA := "39_button_end_turn_wide_blank.png"
	var cta_size := UiKit.panel_size(CTA)
	var btn := UiKit.panel_button(CTA, Vector2(640.0 - cta_size.x / 2.0, 474), "START RUN", 28, 1.0, UiKit.RAW_DIR)
	var holder := btn.get_parent() as Control
	holder.add_child(UiKit.asset_rect("29_icon_play_triangle.png", Vector2(cta_size.x / 2.0 - 126, cta_size.y / 2.0 - 16), Vector2(32, 32), UiKit.ICON_DIR))
	add_child(holder)
	btn.pressed.connect(func(): start_run.emit())

	# Entrance: title drops in, button fades up.
	title.modulate.a = 0.0
	title.position.y = 60
	sub.modulate.a = 0.0
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "position:y", 90.0, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(sub, "modulate:a", 0.7, 0.5).set_delay(0.25)
	tw.tween_property(holder, "modulate:a", 1.0, 0.4).set_delay(0.45)
