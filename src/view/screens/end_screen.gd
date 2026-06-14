class_name EndScreen
extends Control
## Shared game-over / victory screen, styled with the pixel HUD kit.

signal back_to_title

var headline: String = ""
var detail: String = ""
var color: Color = Color.WHITE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self)

	# Tinted wash so victory reads warm-green and defeat reads red.
	var wash := ColorRect.new()
	wash.color = Color(color, 0.06)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var head := UiKit.label(headline, 56, color)
	head.add_theme_constant_override("shadow_offset_x", 3)
	head.add_theme_constant_override("shadow_offset_y", 3)
	head.custom_minimum_size = Vector2(1280, 0)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 170)
	add_child(head)

	var panel_scale := 1.5
	var panel_w := UiKit.panel_size("05_mission_card_blank.png", panel_scale)
	var panel := UiKit.panel("05_mission_card_blank.png", Vector2(640.0 - panel_w.x / 2.0, 290), panel_scale)
	var det := UiKit.label(detail, 16)
	det.set_anchors_preset(Control.PRESET_FULL_RECT)
	det.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	det.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(det)
	add_child(panel)

	var btn := UiKit.panel_button("02_grid_power_panel_blank.png", Vector2(640.0 - UiKit.panel_size("02_grid_power_panel_blank.png").x / 2.0, 560), "BACK TO TITLE", 15)
	var holder := btn.get_parent() as Control
	add_child(holder)
	btn.pressed.connect(func(): back_to_title.emit())

	# Entrance: headline punches in, panel and button follow.
	head.scale = Vector2(1.4, 1.4)
	head.pivot_offset = Vector2(640, 28)
	head.modulate.a = 0.0
	panel.modulate.a = 0.0
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(head, "modulate:a", 1.0, 0.3)
	tw.tween_property(head, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.4).set_delay(0.25)
	tw.tween_property(holder, "modulate:a", 1.0, 0.4).set_delay(0.45)
