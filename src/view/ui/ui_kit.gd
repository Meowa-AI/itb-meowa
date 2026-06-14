class_name UiKit
extends Object
## Shared pixel-UI construction helpers for full screens (shop, title, end).
## Same Meowa asset kit and trim-compensation approach as the battle Hud.

const ASSET_DIR := "res://assets/ui/generated_hud_pixel_meowa/game_ready_fit/"
const RAW_DIR := "res://assets/ui/generated_hud_pixel_meowa/raw/"
const ICON_DIR := "res://assets/ui/generated_hud_pixel_meowa/icons_mapped/"
const BACKDROP_SHADER := preload("res://src/view/fx/backdrop.gdshader")

const COLOR_TEXT := Color(0.88, 0.95, 1.0)
const COLOR_DIM := Color(0.55, 0.66, 0.78)
const COLOR_GOLD := Color(1.0, 0.85, 0.4)
const COLOR_ACCENT := Color(0.45, 0.95, 0.75)

# Opaque-pixel bounds inside each padded canvas (measured from the PNGs).
const ART_TRIM := {
	"02_grid_power_panel_blank.png": Rect2(84, 0, 211, 76),
	"04_turn_phase_panel_blank.png": Rect2(36, 0, 393, 87),
	"05_mission_card_blank.png": Rect2(0, 15, 328, 133),
	"15_selected_unit_card_blank.png": Rect2(29, 0, 256, 146),
	"20_button_keycap_blank.png": Rect2(0, 7, 71, 69),
	"39_button_end_turn_wide_blank.png": Rect2(4, 4, 458, 211),  # in RAW_DIR
}


static func backdrop(parent: Control) -> void:
	## Full-screen gradient-glow background, same look as the battle scene.
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	rect.material = mat
	parent.add_child(rect)


static func label(text: String, size: int, color: Color = COLOR_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func asset_rect(file_name: String, pos: Vector2, rect_size: Vector2, asset_dir: String = ASSET_DIR) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(asset_dir + file_name) as Texture2D
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.custom_minimum_size = rect_size
	r.size = rect_size
	return r


static func panel(file_name: String, visible_pos: Vector2, panel_scale: float = 1.0, asset_dir: String = ASSET_DIR) -> Control:
	## Positioned by the visible art frame; children use visible-box coords.
	var tex := load(asset_dir + file_name) as Texture2D
	var trim: Rect2 = ART_TRIM[file_name]
	var p := Control.new()
	p.position = visible_pos
	p.custom_minimum_size = trim.size * panel_scale
	p.size = trim.size * panel_scale
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(asset_rect(file_name, -trim.position * panel_scale, tex.get_size() * panel_scale, asset_dir))
	return p


static func panel_size(file_name: String, panel_scale: float = 1.0) -> Vector2:
	return (ART_TRIM[file_name] as Rect2).size * panel_scale


static func panel_button(file_name: String, visible_pos: Vector2, text: String, font_size: int, panel_scale: float = 1.0, asset_dir: String = ASSET_DIR) -> Button:
	## A kit panel acting as a button, with hover/press feedback. The Button
	## renders the text itself so tooling can find it by Button.text.
	var holder := panel(file_name, visible_pos, panel_scale, asset_dir)
	var b := flat_button(holder.size)
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(color_name, COLOR_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(COLOR_TEXT, 0.5))
	b.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.9))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	holder.add_child(b)
	attach_feedback(b, holder)
	return b


static func flat_button(rect_size: Vector2) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = rect_size
	b.size = rect_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(style_name, empty)
	b.pressed.connect(Audio.click)
	return b


static func attach_feedback(b: Button, holder: Control) -> void:
	b.mouse_entered.connect(func(): _visual(b, holder, true, b.button_pressed))
	b.mouse_exited.connect(func(): _visual(b, holder, false, false))
	b.button_down.connect(func(): _visual(b, holder, true, true))
	b.button_up.connect(func(): _visual(b, holder, b.is_hovered(), false))


static func set_disabled(b: Button, holder: Control, disabled: bool) -> void:
	b.disabled = disabled
	holder.modulate = Color(0.42, 0.48, 0.55, 0.72) if disabled else Color.WHITE


static func _visual(b: Button, holder: Control, hovered: bool, pressed: bool) -> void:
	if b.disabled:
		return
	if pressed:
		holder.modulate = Color(0.78, 0.85, 0.92)
	elif hovered:
		holder.modulate = Color(1.18, 1.18, 1.25)
	else:
		holder.modulate = Color.WHITE
