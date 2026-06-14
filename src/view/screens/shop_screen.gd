class_name ShopScreen
extends Control
## Between-mission shop: spend reputation on upgrades and weapons.
## Styled with the Meowa pixel HUD kit to match the battle scene.

signal next_mission

const ITEM_ICONS := {
	"grid_up": "23_icon_lightning.png",
	"hp_up": "extra_icon_defense_hex.png",
	"dmg_up": "25_icon_attack_swords.png",
	"move_up": "24_icon_move_arrows.png",
	"grappling_hook": "32_icon_push_force.png",
	"cluster_shells": "33_icon_weapon_gun.png",
}
const CARD_ART := "05_mission_card_blank.png"
const SQUAD_ART := "15_selected_unit_card_blank.png"

var run: RunState
var _rep_value: Label
var _cards_root: Control
var _squad_root: Control
var _picking_item: String = ""
var _pick_popup: PopupMenu


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.backdrop(self)

	var header := UiKit.panel("04_turn_phase_panel_blank.png", Vector2((1280.0 - UiKit.panel_size("04_turn_phase_panel_blank.png").x) / 2.0, 14))
	var title := UiKit.label("MISSION COMPLETE", 17)
	title.position = Vector2(40, 13)
	title.size = Vector2(313, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var subtitle := UiKit.label("CHOOSE UPGRADES", 11, UiKit.COLOR_DIM)
	subtitle.position = Vector2(40, 40)
	subtitle.size = Vector2(313, 15)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(subtitle)
	add_child(header)

	var rep_panel := UiKit.panel("02_grid_power_panel_blank.png", Vector2(1232.0 - UiKit.panel_size("02_grid_power_panel_blank.png").x, 14))
	var rep_title := UiKit.label("REPUTATION", 10, UiKit.COLOR_DIM)
	rep_title.position = Vector2(18, 12)
	rep_title.size = Vector2(120, 14)
	rep_panel.add_child(rep_title)
	_rep_value = UiKit.label("", 16, UiKit.COLOR_GOLD)
	_rep_value.position = Vector2(18, 30)
	_rep_value.size = Vector2(175, 24)
	rep_panel.add_child(_rep_value)
	add_child(rep_panel)

	_cards_root = Control.new()
	_cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards_root)

	var squad_heading := UiKit.label("SQUAD", 13, UiKit.COLOR_DIM)
	squad_heading.position = Vector2(976, 96)
	add_child(squad_heading)
	_squad_root = Control.new()
	_squad_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_squad_root)

	_pick_popup = PopupMenu.new()
	add_child(_pick_popup)
	_pick_popup.id_pressed.connect(_on_mech_picked)

	var next_btn := UiKit.panel_button("02_grid_power_panel_blank.png", Vector2(1232.0 - UiKit.panel_size("02_grid_power_panel_blank.png").x, 626), "NEXT MISSION ▶", 14)
	add_child(next_btn.get_parent())
	next_btn.pressed.connect(func(): next_mission.emit())

	_rebuild()


func _rebuild() -> void:
	_rep_value.text = "★ %d" % run.reputation

	for c in _cards_root.get_children():
		c.queue_free()
	var card_size := UiKit.panel_size(CARD_ART)
	for i in RunState.SHOP.size():
		var item: Dictionary = RunState.SHOP[i]
		var col := i % 2
		var row := i / 2
		var pos := Vector2(48 + col * (card_size.x + 16), 120 + row * (card_size.y + 16))
		_cards_root.add_child(_build_card(item, pos))

	for c in _squad_root.get_children():
		c.queue_free()
	var squad_size := UiKit.panel_size(SQUAD_ART)
	for i in run.squad.size():
		_squad_root.add_child(_build_squad_card(run.squad[i], Vector2(976, 120 + i * (squad_size.y + 14))))


func _build_card(item: Dictionary, pos: Vector2) -> Control:
	var holder := UiKit.panel(CARD_ART, pos)
	var already: bool = item["id"] in run.purchased and RunState.WEAPON_OWNERS.has(item["id"])

	holder.add_child(UiKit.asset_rect("20_button_keycap_blank.png", Vector2(18, 18), Vector2(44, 44)))
	holder.add_child(UiKit.asset_rect(ITEM_ICONS.get(item["id"], "31_icon_objective_diamond.png"), Vector2(28, 28), Vector2(24, 24), UiKit.ICON_DIR))

	var title := UiKit.label(str(item["name"]).to_upper(), 14)
	title.position = Vector2(76, 20)
	title.size = Vector2(230, 18)
	holder.add_child(title)

	var cost := UiKit.label("PURCHASED" if already else "★ %d" % item["cost"], 12, UiKit.COLOR_ACCENT if already else UiKit.COLOR_GOLD)
	cost.position = Vector2(76, 42)
	cost.size = Vector2(160, 16)
	holder.add_child(cost)

	var desc := UiKit.label(str(item["desc"]), 11, UiKit.COLOR_DIM)
	desc.position = Vector2(20, 74)
	desc.size = Vector2(288, 46)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(desc)

	var b := UiKit.flat_button(holder.size)
	holder.add_child(b)
	UiKit.attach_feedback(b, holder)
	UiKit.set_disabled(b, holder, already or not run.can_buy(item["id"]))
	var item_id: String = item["id"]
	b.pressed.connect(func(): _on_item(item_id))
	return holder


func _build_squad_card(entry: Dictionary, pos: Vector2) -> Control:
	var holder := UiKit.panel(SQUAD_ART, pos)
	var w: WeaponDef = Defs.weapon(entry["weapon_id"])

	holder.add_child(UiKit.asset_rect("11_mech_portrait_tile.png", Vector2(16, 18), Vector2(64, 64)))

	var name_label := UiKit.label(Defs.unit(entry["def_id"]).display_name.to_upper(), 13)
	name_label.position = Vector2(94, 18)
	name_label.size = Vector2(150, 17)
	holder.add_child(name_label)

	var stats := UiKit.label("HP %d    MOVE %d" % [entry["max_hp"], entry["move"]], 11, UiKit.COLOR_DIM)
	stats.position = Vector2(94, 44)
	stats.size = Vector2(150, 15)
	holder.add_child(stats)

	holder.add_child(UiKit.asset_rect("33_icon_weapon_gun.png", Vector2(18, 108), Vector2(18, 18), UiKit.ICON_DIR))
	var weapon := UiKit.label("%s — %d dmg" % [w.display_name, w.damage + entry["weapon_damage_bonus"]], 11)
	weapon.position = Vector2(42, 108)
	weapon.size = Vector2(200, 15)
	holder.add_child(weapon)
	return holder


func _on_item(item_id: String) -> void:
	if run.shop_item(item_id)["needs_target"]:
		_picking_item = item_id
		_pick_popup.clear()
		for i in run.squad.size():
			_pick_popup.add_item(Defs.unit(run.squad[i]["def_id"]).display_name, i)
		_pick_popup.popup(Rect2i(Vector2i(get_global_mouse_position()), Vector2i(0, 0)))
	else:
		run.buy(item_id)
		_rebuild()


func _on_mech_picked(idx: int) -> void:
	run.buy(_picking_item, run.squad[idx]["def_id"])
	_rebuild()
