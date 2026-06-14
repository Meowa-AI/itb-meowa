class_name Hud
extends CanvasLayer
## Battle HUD: grid power, turn/phase, objectives, unit card, action buttons.
## Pure presentation — emits button signals, reads state via update_from().

signal move_pressed
signal attack_pressed
signal repair_pressed
signal undo_pressed
signal end_turn_pressed

const UI_ASSET_DIR := "res://assets/ui/generated_hud_pixel_meowa/game_ready_fit/"
const BUTTON_ASSET_DIR := "res://assets/ui/generated_hud_pixel_meowa/raw/"
const ICON_ASSET_DIR := "res://assets/ui/generated_hud_pixel_meowa/icons_mapped/"

const SCREEN := Vector2(1280, 720)
const MARGIN := 12.0
const BUTTON_HEIGHT := 52.0
const BUTTON_GAP := 12.0
const BUTTON_Y := 640.0

# Opaque-pixel bounds of each art file inside its padded canvas (measured from
# the PNGs). Panels are aligned by their visible frame, not the canvas.
const ART_TRIM := {
	"02_grid_power_panel_blank.png": Rect2(84, 0, 211, 76),
	"04_turn_phase_panel_blank.png": Rect2(36, 0, 393, 87),
	"05_mission_card_blank.png": Rect2(0, 15, 328, 133),
	"15_selected_unit_card_blank.png": Rect2(29, 0, 256, 146),
	"35_button_command_wide_blank.png": Rect2(4, 4, 342, 156),
	"36_button_attack_wide_blank.png": Rect2(4, 4, 412, 152),
	"37_button_blue_wide_blank.png": Rect2(4, 4, 434, 200),
	"38_button_system_wide_blank.png": Rect2(4, 4, 265, 119),
	"39_button_end_turn_wide_blank.png": Rect2(4, 4, 458, 211),
}

const COLOR_TEXT := Color(0.88, 0.95, 1.0)
const COLOR_DIM := Color(0.55, 0.66, 0.78)
const COLOR_ACCENT := Color(0.45, 0.95, 0.75)
const COLOR_WARN := Color(1.0, 0.62, 0.3)
const COLOR_DANGER := Color(1.0, 0.42, 0.38)

var _power_pips: HBoxContainer
var _power_value: Label
var _phase_label: Label
var _turn_label: Label
var _phase_mech_icon: TextureRect
var _phase_vek_icon: TextureRect
var _mission_id_label: Label
var _mission_title_label: Label
var _objective_label: Label
var _remaining_label: Label
var _unit_card: Control
var _unit_portrait: TextureRect
var _unit_name: Label
var _hp_pips: HBoxContainer
var _hp_value: Label
var _move_value: Label
var _damage_value: Label
var _weapon_label: Label
var _btn_move: Button
var _btn_attack: Button
var _btn_repair: Button
var _btn_undo: Button
var _btn_end: Button
var _banner: Label
var _drag_roots: Array[Control] = []
var _layout_editor: HudLayoutEditor


static func ui_asset_path(file_name: String) -> String:
	return UI_ASSET_DIR + file_name


static func button_asset_path(file_name: String) -> String:
	return BUTTON_ASSET_DIR + file_name


static func icon_asset_path(file_name: String) -> String:
	return ICON_ASSET_DIR + file_name


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_power_panel(root)
	_build_phase_panel(root)
	_build_mission_panel(root)
	_build_unit_card(root)
	_build_action_buttons(root)
	_build_banner(root)
	_build_layout_editor(root)


func _build_layout_editor(root: Control) -> void:
	HudLayoutEditor.apply_saved(_drag_roots, root)
	_layout_editor = HudLayoutEditor.new()
	root.add_child(_layout_editor)
	_layout_editor.setup(_drag_roots)

	var edit_btn := Button.new()
	edit_btn.text = "EDIT UI"
	edit_btn.add_theme_font_size_override("font_size", 10)
	edit_btn.position = Vector2(236, 16)
	edit_btn.focus_mode = Control.FOCUS_NONE
	edit_btn.modulate = Color(1, 1, 1, 0.55)
	edit_btn.pressed.connect(func(): _layout_editor.toggle())
	root.add_child(edit_btn)


func _tag_drag_root(c: Control, id: String) -> void:
	c.set_meta("hud_drag_id", id)
	_drag_roots.append(c)


# --- panel construction -----------------------------------------------------


func _build_power_panel(root: Control) -> void:
	var panel := _image_panel("02_grid_power_panel_blank.png", Vector2(MARGIN, 10))
	var title := _label("GRID POWER", 10)
	title.modulate = COLOR_DIM
	title.position = Vector2(18, 12)
	title.size = Vector2(120, 14)
	panel.add_child(title)

	_power_value = _label("", 11)
	_power_value.position = Vector2(125, 11)
	_power_value.size = Vector2(68, 15)
	_power_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(_power_value)

	_power_pips = HBoxContainer.new()
	_power_pips.add_theme_constant_override("separation", 2)
	_power_pips.position = Vector2(17, 34)
	_power_pips.size = Vector2(178, 16)
	panel.add_child(_power_pips)
	_tag_drag_root(panel, "power_panel")
	root.add_child(panel)


func _build_phase_panel(root: Control) -> void:
	var panel := _image_panel("04_turn_phase_panel_blank.png", Vector2.ZERO)
	panel.position.x = (SCREEN.x - panel.size.x) / 2.0 - _trim("04_turn_phase_panel_blank.png").position.x
	panel.position.y = 8
	# _image_panel children are laid out in visible-box coordinates already.
	var visible_w := _trim("04_turn_phase_panel_blank.png").size.x

	# The art has a small slot at each end (centers measured at x=35 / x=358):
	# shield = player side, vek bug = enemy side; the active one is lit.
	_phase_mech_icon = _asset_rect("30_icon_shield.png", Vector2(23, 26), Vector2(24, 24), ICON_ASSET_DIR, "hud_icon_asset")
	panel.add_child(_phase_mech_icon)
	_phase_vek_icon = _asset_rect("34_icon_vek_bug.png", Vector2(visible_w - 47, 26), Vector2(24, 24), ICON_ASSET_DIR, "hud_icon_asset")
	panel.add_child(_phase_vek_icon)

	_phase_label = _label("PLAYER PHASE", 17)
	_phase_label.position = Vector2(66, 13)
	_phase_label.size = Vector2(visible_w - 132, 24)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_phase_label)

	_turn_label = _label("TURN 01", 11)
	_turn_label.modulate = COLOR_DIM
	_turn_label.position = Vector2(66, 40)
	_turn_label.size = Vector2(visible_w - 132, 15)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_turn_label)
	_tag_drag_root(panel, "phase_panel")
	root.add_child(panel)


func _build_mission_panel(root: Control) -> void:
	var trim := _trim("05_mission_card_blank.png")
	var panel := _image_panel("05_mission_card_blank.png", Vector2(SCREEN.x - MARGIN - trim.size.x, 10))

	_mission_id_label = _label("", 10)
	_mission_id_label.modulate = COLOR_DIM
	_mission_id_label.position = Vector2(20, 14)
	_mission_id_label.size = Vector2(200, 14)
	panel.add_child(_mission_id_label)

	_mission_title_label = _label("", 15)
	_mission_title_label.position = Vector2(20, 29)
	_mission_title_label.size = Vector2(288, 20)
	panel.add_child(_mission_title_label)

	panel.add_child(_asset_rect("31_icon_objective_diamond.png", Vector2(20, 60), Vector2(16, 16), ICON_ASSET_DIR, "hud_icon_asset"))
	_objective_label = _label("", 12)
	_objective_label.position = Vector2(42, 60)
	_objective_label.size = Vector2(250, 17)
	panel.add_child(_objective_label)

	_remaining_label = _label("", 12)
	_remaining_label.modulate = COLOR_WARN
	_remaining_label.position = Vector2(42, 82)
	_remaining_label.size = Vector2(220, 17)
	panel.add_child(_remaining_label)

	panel.add_child(_asset_rect("34_icon_vek_bug.png", Vector2(trim.size.x - 40, 80), Vector2(20, 20), ICON_ASSET_DIR, "hud_icon_asset"))
	_tag_drag_root(panel, "mission_panel")
	root.add_child(panel)


# Compartments of 15_selected_unit_card_blank.png, in visible-box coordinates
# (measured from the art): portrait box, main stat box, top-right tab, small
# bottom-left box, and the bottom strip. All children must stay inside one box.
const CARD_PORTRAIT_BOX := Rect2(17, 24, 69, 77)
const CARD_MAIN_BOX := Rect2(90, 22, 149, 77)
const CARD_TAB_BOX := Rect2(179, 5, 70, 25)
const CARD_WEAPON_ICON_BOX := Rect2(17, 105, 69, 22)
const CARD_WEAPON_STRIP := Rect2(90, 103, 149, 24)


func _build_unit_card(root: Control) -> void:
	var trim := _trim("15_selected_unit_card_blank.png")
	_unit_card = _image_panel("15_selected_unit_card_blank.png", Vector2(MARGIN, SCREEN.y - MARGIN - trim.size.y))

	# Portrait box: per-unit sprite, swapped in update_from().
	_unit_portrait = _asset_rect("11_mech_portrait_tile.png", CARD_PORTRAIT_BOX.position + Vector2(2, 2), CARD_PORTRAIT_BOX.size - Vector2(4, 4), UI_ASSET_DIR, "hud_fit_asset")
	_unit_card.add_child(_unit_portrait)

	# Top-right tab: weapon damage at a glance.
	_unit_card.add_child(_asset_rect("25_icon_attack_swords.png", Vector2(CARD_TAB_BOX.position.x + 6, CARD_TAB_BOX.position.y + 4), Vector2(16, 16), ICON_ASSET_DIR, "hud_icon_asset"))
	_damage_value = _label("", 11)
	_damage_value.position = Vector2(CARD_TAB_BOX.position.x + 26, CARD_TAB_BOX.position.y)
	_damage_value.size = Vector2(CARD_TAB_BOX.size.x - 32, CARD_TAB_BOX.size.y)
	_damage_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unit_card.add_child(_damage_value)

	# Main box: name / HP / MOVE rows.
	var mx := CARD_MAIN_BOX.position.x + 6
	var mw := CARD_MAIN_BOX.size.x - 12
	_unit_name = _label("", 13)
	_unit_name.position = Vector2(mx, CARD_MAIN_BOX.position.y + 6)
	_unit_name.size = Vector2(mw, 18)
	_unit_name.clip_text = true
	_unit_card.add_child(_unit_name)

	var hp_title := _label("HP", 10)
	hp_title.modulate = COLOR_DIM
	hp_title.position = Vector2(mx, CARD_MAIN_BOX.position.y + 31)
	hp_title.size = Vector2(22, 14)
	_unit_card.add_child(hp_title)

	_hp_pips = HBoxContainer.new()
	_hp_pips.add_theme_constant_override("separation", 2)
	_hp_pips.position = Vector2(mx + 26, CARD_MAIN_BOX.position.y + 30)
	_hp_pips.size = Vector2(80, 14)
	_unit_card.add_child(_hp_pips)

	_hp_value = _label("", 10)
	_hp_value.position = Vector2(mx + mw - 34, CARD_MAIN_BOX.position.y + 31)
	_hp_value.size = Vector2(34, 14)
	_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_unit_card.add_child(_hp_value)

	var move_title := _label("MOVE", 10)
	move_title.modulate = COLOR_DIM
	move_title.position = Vector2(mx, CARD_MAIN_BOX.position.y + 52)
	move_title.size = Vector2(40, 14)
	_unit_card.add_child(move_title)

	_unit_card.add_child(_asset_rect("24_icon_move_arrows.png", Vector2(mx + 44, CARD_MAIN_BOX.position.y + 51), Vector2(14, 14), ICON_ASSET_DIR, "hud_icon_asset"))
	_move_value = _label("", 11)
	_move_value.position = Vector2(mx + 62, CARD_MAIN_BOX.position.y + 51)
	_move_value.size = Vector2(40, 15)
	_unit_card.add_child(_move_value)

	# Bottom row: weapon icon in its own small box, weapon name in the strip.
	_unit_card.add_child(_asset_rect("33_icon_weapon_gun.png", CARD_WEAPON_ICON_BOX.get_center() - Vector2(9, 9), Vector2(18, 18), ICON_ASSET_DIR, "hud_icon_asset"))
	_weapon_label = _label("", 11)
	_weapon_label.position = Vector2(CARD_WEAPON_STRIP.position.x + 6, CARD_WEAPON_STRIP.position.y)
	_weapon_label.size = Vector2(CARD_WEAPON_STRIP.size.x - 12, CARD_WEAPON_STRIP.size.y)
	_weapon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_weapon_label.clip_text = true
	_unit_card.add_child(_weapon_label)

	_tag_drag_root(_unit_card, "unit_card")
	root.add_child(_unit_card)
	_unit_card.visible = false


func _build_action_buttons(root: Control) -> void:
	var command_group: Array = [
		["35_button_command_wide_blank.png", "MOVE", "24_icon_move_arrows.png", "Q"],
		["36_button_attack_wide_blank.png", "ATTACK", "25_icon_attack_swords.png", "W"],
		["37_button_blue_wide_blank.png", "REPAIR", "26_icon_repair_plus.png", "E"],
	]
	var group_w := 0.0
	for spec in command_group:
		group_w += _button_width(spec[0])
	group_w += BUTTON_GAP * (command_group.size() - 1)

	var x := (SCREEN.x - group_w) / 2.0
	var buttons: Array[Button] = []
	for spec in command_group:
		var w := _button_width(spec[0])
		buttons.append(_image_button(root, spec[0], Vector2(x, BUTTON_Y), spec[1], spec[2], spec[3]))
		x += w + BUTTON_GAP
	_btn_move = buttons[0]
	_btn_attack = buttons[1]
	_btn_repair = buttons[2]
	_btn_move.pressed.connect(func(): move_pressed.emit())
	_btn_attack.pressed.connect(func(): attack_pressed.emit())
	_btn_repair.pressed.connect(func(): repair_pressed.emit())

	var end_w := _button_width("39_button_end_turn_wide_blank.png")
	var undo_w := _button_width("38_button_system_wide_blank.png")
	var end_x := SCREEN.x - MARGIN - end_w
	var undo_x := end_x - BUTTON_GAP - undo_w
	_btn_undo = _image_button(root, "38_button_system_wide_blank.png", Vector2(undo_x, BUTTON_Y), "UNDO", "27_icon_undo_arrow.png", "Z")
	_btn_end = _image_button(root, "39_button_end_turn_wide_blank.png", Vector2(end_x, BUTTON_Y), "END TURN", "29_icon_play_triangle.png", "X")
	_btn_undo.pressed.connect(func(): undo_pressed.emit())
	_btn_end.pressed.connect(func(): end_turn_pressed.emit())
	_tag_drag_root(_btn_move.get_parent(), "btn_move")
	_tag_drag_root(_btn_attack.get_parent(), "btn_attack")
	_tag_drag_root(_btn_repair.get_parent(), "btn_repair")
	_tag_drag_root(_btn_undo.get_parent(), "btn_undo")
	_tag_drag_root(_btn_end.get_parent(), "btn_end")


func _build_banner(root: Control) -> void:
	_banner = _label("", 28)
	_banner.position = Vector2(0, 320)
	_banner.custom_minimum_size = Vector2(SCREEN.x, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.visible = false
	root.add_child(_banner)


# --- widget helpers ---------------------------------------------------------


func _trim(file_name: String) -> Rect2:
	return ART_TRIM[file_name]


func _texture_from_dir(asset_dir: String, file_name: String) -> Texture2D:
	return load(asset_dir + file_name) as Texture2D


## Battle sprite of the unit if one exists, otherwise the generic portrait.
func _unit_portrait_texture(def_id: String) -> Texture2D:
	var sprite_path := "res://assets/sprites/%s.png" % def_id
	if ResourceLoader.exists(sprite_path):
		return load(sprite_path) as Texture2D
	return _texture_from_dir(UI_ASSET_DIR, "11_mech_portrait_tile.png")


func _asset_rect(file_name: String, pos: Vector2, rect_size: Vector2, asset_dir: String = UI_ASSET_DIR, meta_name: String = "hud_fit_asset") -> TextureRect:
	var r := TextureRect.new()
	r.texture = _texture_from_dir(asset_dir, file_name)
	# expand_mode must be set before size: with the default KEEP_SIZE the
	# texture's native size acts as minimum size and overrides rect_size.
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.custom_minimum_size = rect_size
	r.size = rect_size
	r.set_meta(meta_name, true)
	return r


## Panel positioned by its visible frame: `visible_pos` is where the opaque
## art lands on screen, and children are laid out in visible-box coordinates.
func _image_panel(file_name: String, visible_pos: Vector2) -> Control:
	var tex := _texture_from_dir(UI_ASSET_DIR, file_name)
	var trim := _trim(file_name)
	var p := Control.new()
	p.position = visible_pos
	p.custom_minimum_size = trim.size
	p.size = trim.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_asset_rect(file_name, -trim.position, tex.get_size()))
	return p


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.08, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func _button_width(frame_file: String) -> float:
	var trim := _trim(frame_file)
	return roundf(BUTTON_HEIGHT * trim.size.x / trim.size.y)


func _image_button(root: Control, frame_file: String, pos: Vector2, text: String, icon_file: String, hotkey: String) -> Button:
	var trim := _trim(frame_file)
	var w := _button_width(frame_file)
	var rect_size := Vector2(w, BUTTON_HEIGHT)
	var holder := Control.new()
	holder.position = pos
	holder.custom_minimum_size = rect_size
	holder.size = rect_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("hud_button_holder", true)
	root.add_child(holder)

	# Scale the padded canvas so the opaque frame fills the holder exactly.
	var scale := BUTTON_HEIGHT / trim.size.y
	var tex := _texture_from_dir(BUTTON_ASSET_DIR, frame_file)
	holder.add_child(_asset_rect(frame_file, -trim.position * scale, tex.get_size() * scale, BUTTON_ASSET_DIR, "hud_button_frame_asset"))

	holder.add_child(_asset_rect(icon_file, Vector2(13, (BUTTON_HEIGHT - 20.0) / 2.0), Vector2(20, 20), ICON_ASSET_DIR, "hud_icon_asset"))

	var label := _label(text, 12)
	label.position = Vector2(36, 0)
	label.size = Vector2(rect_size.x - 44, BUTTON_HEIGHT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(label)

	# Hotkey hint: small keycap centered under the button.
	holder.add_child(_asset_rect("20_button_keycap_blank.png", Vector2((w - 20.0) / 2.0, BUTTON_HEIGHT + 4.0), Vector2(20, 20), UI_ASSET_DIR, "hud_fit_asset"))
	var key_label := _label(hotkey, 9)
	key_label.modulate = COLOR_DIM
	key_label.position = Vector2((w - 20.0) / 2.0, BUTTON_HEIGHT + 4.0)
	key_label.size = Vector2(20, 20)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(key_label)

	var b := Button.new()
	b.text = ""
	b.flat = true
	b.custom_minimum_size = rect_size
	b.size = rect_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(style_name, empty)
	b.pressed.connect(Audio.click)
	b.mouse_entered.connect(func(): _set_button_visual(b, true, b.button_pressed))
	b.mouse_exited.connect(func(): _set_button_visual(b, false, false))
	b.button_down.connect(func(): _set_button_visual(b, true, true))
	b.button_up.connect(func(): _set_button_visual(b, b.is_hovered(), false))
	holder.add_child(b)
	return b


func _set_button_visual(button: Button, hovered: bool, pressed: bool) -> void:
	if button.disabled:
		return
	var holder := button.get_parent() as Control
	if holder == null:
		return
	if pressed:
		holder.modulate = Color(0.78, 0.85, 0.92)
	elif hovered:
		holder.modulate = Color(1.18, 1.18, 1.25)
	else:
		holder.modulate = Color.WHITE


func _set_image_button_disabled(button: Button, disabled: bool) -> void:
	button.disabled = disabled
	var holder := button.get_parent() as Control
	if holder != null:
		holder.modulate = Color(0.42, 0.48, 0.55, 0.72) if disabled else Color.WHITE


func _press_if_enabled(button: Button) -> void:
	if not button.disabled:
		Audio.click()
		match button:
			_btn_move:
				move_pressed.emit()
			_btn_attack:
				attack_pressed.emit()
			_btn_repair:
				repair_pressed.emit()
			_btn_undo:
				undo_pressed.emit()
			_btn_end:
				end_turn_pressed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F2:
		_layout_editor.toggle()
		return
	if _layout_editor.visible:
		return
	match key.keycode:
		KEY_Q:
			_press_if_enabled(_btn_move)
		KEY_W:
			_press_if_enabled(_btn_attack)
		KEY_E:
			_press_if_enabled(_btn_repair)
		KEY_Z:
			_press_if_enabled(_btn_undo)
		KEY_X:
			_press_if_enabled(_btn_end)


func _rebuild_pips(box: HBoxContainer, full: int, total: int, pip_size: Vector2, full_file: String, empty_file: String) -> void:
	for c in box.get_children():
		c.queue_free()
	for i in total:
		var pip := _asset_rect(full_file if i < full else empty_file, Vector2.ZERO, pip_size)
		pip.custom_minimum_size = pip_size
		box.add_child(pip)


# --- state -> view ----------------------------------------------------------


func update_from(s: BattleState, selected: BUnit, busy: bool) -> void:
	_rebuild_pips(_power_pips, s.grid_power, RunState.MAX_GRID, Vector2(16, 16), "13_power_slot_full_framed.png", "14_power_slot_empty_framed.png")
	_power_value.text = "%d / %d" % [s.grid_power, RunState.MAX_GRID]

	_phase_label.text = "RESOLVING..." if busy else "PLAYER PHASE"
	_phase_label.modulate = COLOR_WARN if busy else COLOR_TEXT
	_phase_mech_icon.modulate = Color(1, 1, 1, 0.35) if busy else Color.WHITE
	_phase_vek_icon.modulate = Color.WHITE if busy else Color(1, 1, 1, 0.35)
	_turn_label.text = "TURN %02d" % s.turn

	var m := s.mission
	var mission_num := m.id.lstrip("Mm")
	_mission_id_label.text = "MISSION %02d" % (int(mission_num) if mission_num.is_valid_int() else 0)
	_mission_title_label.text = m.title.to_upper()
	match m.objective:
		"kill_all":
			_objective_label.text = "Destroy all vek"
			_remaining_label.text = "Remaining: %d" % (s.vek().size() + s.pending_spawns.size() + s.spawn_queue.size())
			_remaining_label.modulate = COLOR_WARN
		"survive":
			_objective_label.text = "Survive %d turns" % m.survive_turns
			_remaining_label.text = "Progress: %d / %d" % [mini(s.turn - 1, m.survive_turns), m.survive_turns]
			_remaining_label.modulate = COLOR_WARN
		"protect":
			_objective_label.text = "Protect the generator"
			_remaining_label.text = "FAILED" if s.protect_failed else "Generator online"
			_remaining_label.modulate = COLOR_DANGER if s.protect_failed else COLOR_ACCENT

	if selected != null:
		_unit_card.visible = true
		var w := selected.weapon()
		_unit_portrait.texture = _unit_portrait_texture(selected.def_id)
		_unit_name.text = Defs.unit(selected.def_id).display_name.to_upper()
		_rebuild_pips(_hp_pips, selected.hp, selected.max_hp, Vector2(13, 13), "21_pip_full_round.png", "22_pip_empty_round.png")
		_hp_value.text = "%d/%d" % [selected.hp, selected.max_hp]
		_move_value.text = "%d" % selected.move
		_damage_value.text = "%d DMG" % (w.damage + selected.weapon_damage_bonus)
		var push_text := ""
		if w.push > 0:
			push_text = ", push"
		elif w.push < 0:
			push_text = ", pull"
		_weapon_label.text = "%s%s" % [w.display_name, push_text]
		_set_image_button_disabled(_btn_move, busy or selected.moved or selected.acted)
		_set_image_button_disabled(_btn_attack, busy or selected.acted)
		_set_image_button_disabled(_btn_repair, busy or selected.acted or selected.hp >= selected.max_hp)
	else:
		_unit_card.visible = _layout_editor != null and _layout_editor.visible
		_set_image_button_disabled(_btn_move, true)
		_set_image_button_disabled(_btn_attack, true)
		_set_image_button_disabled(_btn_repair, true)
	_set_image_button_disabled(_btn_undo, busy)
	_set_image_button_disabled(_btn_end, busy)


func show_banner(text: String, color: Color = Color.WHITE) -> void:
	_banner.text = text
	_banner.modulate = Color(color, 0.0)
	_banner.visible = true
	_banner.pivot_offset = Vector2(SCREEN.x / 2.0, 20)
	_banner.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_banner, "modulate:a", 1.0, 0.22)
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_banner() -> void:
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _banner.visible = false)
