class_name BoardView
extends Node2D
## Renders a BattleState isometrically and plays back core Events as
## animations. Never mutates game state; emits input signals upward.

signal tile_clicked(cell: Vector2i)
signal tile_hovered(cell: Vector2i)
signal event_played(ev: Dictionary)
signal playback_done

const GROUND_TEXTURES := {
	"plain": preload("res://assets/tiles/generated/grass_a.png"),
	"plain_alt": preload("res://assets/tiles/generated/grass_b.png"),
	"water": preload("res://assets/tiles/generated/water_a.png"),
	"water_alt": preload("res://assets/tiles/generated/water_b.png"),
	"rubble": preload("res://assets/tiles/generated/rubble_a.png"),
	"rubble_alt": preload("res://assets/tiles/generated/rubble_b.png"),
	"chasm": preload("res://assets/tiles/generated/water_b.png"),
}
const OBJECT_TEXTURES := {
	"mountain": preload("res://assets/tiles/generated/rock_a.png"),
	"mountain_damaged": preload("res://assets/tiles/generated/rock_b.png"),
	"building": preload("res://assets/tiles/generated/house_a.png"),
	"building_alt": preload("res://assets/tiles/generated/house_b.png"),
	"building_damaged": preload("res://assets/tiles/generated/house_b.png"),
	"objective": preload("res://assets/tiles/generated/house_b.png"),
}
const STEP := 0.18  # seconds per animated event
const WATER_SHADER := preload("res://src/view/fx/water.gdshader")
# z layers: tiles 0..147, overlays above map blocks, units/effects/popups above overlays.
const Z_OVERLAY := 180
const Z_UNITS := 200
const Z_EFFECTS := 260
const Z_POPUPS := 300
const TILE_SPRITE_OFFSET := Vector2.ZERO
const CLICK_DRAG_THRESHOLD := 6.0

var state: BattleState
var busy := false  # true while playing back events
var _water_material: ShaderMaterial

var show_grid := false

var _tiles: Node2D
var _overlay: BoardOverlay
var _units_layer: Node2D
var _popups: Node2D
var _tile_sprites: Dictionary = {}  # Vector2i -> Sprite2D
var _unit_sprites: Dictionary = {}  # unit_id -> UnitSprite
var _hover_cell := Vector2i(-1, -1)
var _left_button_down := false
var _left_press_screen_position := Vector2.ZERO

# Overlay inputs (set by the controller)
var move_overlay: Array = []
var target_overlay: Array = []
var selected_cell := Vector2i(-1, -1)
var preview_events: Array = []


func setup(s: BattleState) -> void:
	state = s
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER
	_tiles = Node2D.new()
	add_child(_tiles)
	_overlay = BoardOverlay.new()
	_overlay.board = self
	_overlay.z_index = Z_OVERLAY
	add_child(_overlay)
	_units_layer = Node2D.new()
	_units_layer.z_index = Z_UNITS
	add_child(_units_layer)
	_popups = Node2D.new()
	_popups.z_index = Z_POPUPS
	add_child(_popups)
	for y in BattleState.SIZE:
		for x in BattleState.SIZE:
			var cell := Vector2i(x, y)
			var sp := Sprite2D.new()
			sp.position = Iso.to_screen(cell)
			sp.offset = TILE_SPRITE_OFFSET
			sp.z_index = Iso.sort_z(cell)
			_tiles.add_child(sp)
			_tile_sprites[cell] = sp
	for u in state.units:
		_add_unit_sprite(u)
	refresh()


func _add_unit_sprite(u: BUnit) -> UnitSprite:
	var us := UnitSprite.new()
	us.setup(u)
	_units_layer.add_child(us)
	_unit_sprites[u.id] = us
	return us


func refresh() -> void:
	## Hard re-sync of every visual to the state (after undo or playback).
	for cell in _tile_sprites:
		_refresh_cell(cell)
	for u in state.units:
		if not _unit_sprites.has(u.id):
			_add_unit_sprite(u)
		_unit_sprites[u.id].sync_to(u)
	_overlay.queue_redraw()


func _refresh_cell(cell: Vector2i) -> void:
	var sp: Sprite2D = _tile_sprites.get(cell)
	if sp != null:
		sp.texture = _tile_texture_for(cell)
		var kind: String = state.terrain[cell]
		var is_water: bool = (kind == "water" or kind == "chasm") and not state.buildings.has(cell)
		sp.material = _water_material if is_water else null


func _tile_texture_for(cell: Vector2i) -> Texture2D:
	if state.buildings.has(cell):
		var b: Dictionary = state.buildings[cell]
		if b["hp"] > 0:
			if b["objective"]:
				return OBJECT_TEXTURES["objective"]
			if b["hp"] < b["max_hp"]:
				return OBJECT_TEXTURES["building_damaged"]
			return OBJECT_TEXTURES["building_alt"] if _alternate(cell) else OBJECT_TEXTURES["building"]

	var kind: String = state.terrain[cell]
	match kind:
		"mountain":
			var hurt: bool = state.mountain_hp.get(cell, 2) <= 1
			return OBJECT_TEXTURES["mountain_damaged"] if hurt else OBJECT_TEXTURES["mountain"]
		"water":
			return GROUND_TEXTURES["water_alt"] if _alternate(cell) else GROUND_TEXTURES["water"]
		"rubble":
			return GROUND_TEXTURES["rubble_alt"] if _alternate(cell) else GROUND_TEXTURES["rubble"]
		"chasm":
			return GROUND_TEXTURES["chasm"]
		_:
			return GROUND_TEXTURES["plain_alt"] if _alternate(cell) else GROUND_TEXTURES["plain"]


func _alternate(cell: Vector2i) -> bool:
	return (cell.x + cell.y) % 2 == 1


func clear_overlays() -> void:
	move_overlay = []
	target_overlay = []
	selected_cell = Vector2i(-1, -1)
	preview_events = []
	_overlay.queue_redraw()


func redraw_overlays() -> void:
	_overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		show_grid = not show_grid
		_overlay.queue_redraw()
		return
	if busy:
		return
	if event is InputEventMouseMotion:
		var cell := Iso.to_cell(make_input_local(event).position)
		if cell != _hover_cell:
			_hover_cell = cell
			_overlay.queue_redraw()
			if state.in_bounds(cell):
				tile_hovered.emit(cell)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_button_down = true
			_left_press_screen_position = event.position
		else:
			if _left_button_down and event.position.distance_to(_left_press_screen_position) <= CLICK_DRAG_THRESHOLD:
				var cell := Iso.to_cell(make_input_local(event).position)
				if state.in_bounds(cell):
					tile_clicked.emit(cell)
			_left_button_down = false


func hover_cell() -> Vector2i:
	return _hover_cell


func play_events(events: Array) -> void:
	busy = true
	clear_overlays()
	for ev in events:
		await _play_one(ev)
		event_played.emit(ev)
	refresh()
	busy = false
	playback_done.emit()


func _play_one(ev: Dictionary) -> void:
	match ev["type"]:
		"unit_moved", "unit_pushed":
			var us: UnitSprite = _unit_sprites.get(ev["unit_id"])
			if us == null:
				return
			if ev["from"] == ev["to"]:  # blocked push: bump
				var dir: Vector2 = Vector2(8, 4)
				var tw := create_tween()
				tw.tween_property(us, "position", Iso.to_screen(ev["from"]) + dir, STEP / 2)
				tw.tween_property(us, "position", Iso.to_screen(ev["from"]), STEP / 2)
				await tw.finished
			else:
				var tw := create_tween()
				tw.tween_property(us, "position", Iso.to_screen(ev["to"]), STEP)
				await tw.finished
				us.z_index = Iso.sort_z(ev["to"])
		"unit_damaged":
			var us: UnitSprite = _unit_sprites.get(ev["unit_id"])
			if us != null:
				us.play_hit()
				us.flash(Color(1, 0.3, 0.3))
				Fx.impact(self, us.position + Vector2(0, -20), Z_EFFECTS)
				Fx.shake(self, 3.0)
				us.hp = ev["hp"]
				us.queue_redraw()
				_popup(us.position, "-%d" % ev["amount"], Color(1, 0.45, 0.4))
			await _wait(STEP)
		"unit_healed":
			var us: UnitSprite = _unit_sprites.get(ev["unit_id"])
			if us != null:
				us.flash(Color(0.4, 1, 0.4))
				Fx.heal_burst(self, us.position + Vector2(0, -24), Z_EFFECTS)
				us.hp = ev["hp"]
				us.queue_redraw()
				_popup(us.position, "+%d" % ev["amount"], Color(0.5, 1, 0.5))
			await _wait(STEP)
		"unit_died":
			var us: UnitSprite = _unit_sprites.get(ev["unit_id"])
			if us != null:
				Fx.death(self, us.position + Vector2(0, -20), Z_EFFECTS, us.team)
				Fx.shake(self, 5.0)
				var tw := create_tween()
				tw.tween_property(us, "modulate:a", 0.0, STEP * 1.5)
				await tw.finished
				us.visible = false
				us.modulate.a = 1.0
		"building_damaged":
			_refresh_cell(ev["pos"])
			var bs: Sprite2D = _tile_sprites.get(ev["pos"])
			if bs != null:
				var orig := bs.position
				var tw := create_tween()
				tw.tween_property(bs, "position", orig + Vector2(3, 0), 0.04)
				tw.tween_property(bs, "position", orig - Vector2(3, 0), 0.04)
				tw.tween_property(bs, "position", orig, 0.04)
				await tw.finished
				Fx.debris(self, bs.position + Vector2(0, -10), Z_EFFECTS, false)
				_popup(bs.position, "-%d" % ev["amount"], Color(1, 0.7, 0.3))
			await _wait(STEP)
		"building_destroyed":
			_refresh_cell(ev["pos"])
			Fx.debris(self, Iso.to_screen(ev["pos"]) + Vector2(0, -10), Z_EFFECTS, true)
			Fx.shake(self, 5.0)
			await _wait(STEP)
		"mountain_damaged":
			_refresh_cell(ev["pos"])
			Fx.debris(self, Iso.to_screen(ev["pos"]) + Vector2(0, -14), Z_EFFECTS, false)
			await _wait(STEP / 2)
		"attack_fired":
			var us: UnitSprite = _unit_sprites.get(ev["unit_id"])
			if us != null:
				us.play_attack()
			await _flash_attack(ev["origin"], ev["target"])
		"vek_spawned":
			var u: BUnit = state.unit_by_id(ev["unit_id"])
			if u != null and not _unit_sprites.has(u.id):
				var us := _add_unit_sprite(u)
				us.scale = Vector2(0.1, 0.1)
				us.position = Iso.to_screen(ev["pos"])
				var tw := create_tween()
				tw.tween_property(us, "scale", Vector2.ONE, STEP)
				await tw.finished
		"spawn_blocked":
			_popup(Iso.to_screen(ev["pos"]), "BLOCKED", Color(1, 0.85, 0.4))
			await _wait(STEP)
		"spawn_telegraphed", "telegraph_set", "grid_power_changed":
			pass  # redrawn from state after playback / handled by HUD
		"mission_won", "mission_failed":
			pass  # the controller reacts after playback
		_:
			pass


func _flash_attack(origin: Vector2i, target: Vector2i) -> void:
	var from := Iso.to_screen(origin) + Vector2(0, -16)
	var to := Iso.to_screen(target)
	Fx.muzzle(self, from, to, Z_EFFECTS)
	# Layered beam: wide soft glow under a hot core, faded out by tween.
	var glow := Line2D.new()
	glow.points = [from, to]
	glow.width = 9
	glow.default_color = Color(1, 0.45, 0.2, 0.35)
	glow.z_index = Z_EFFECTS
	add_child(glow)
	var core := Line2D.new()
	core.points = [from, to]
	core.width = 3
	core.default_color = Color(1, 0.85, 0.55, 0.95)
	core.z_index = Z_EFFECTS
	add_child(core)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(glow, "modulate:a", 0.0, STEP)
	tw.tween_property(core, "modulate:a", 0.0, STEP)
	await _wait(STEP)
	glow.queue_free()
	core.queue_free()


func _popup(at: Vector2, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at + Vector2(-16, -58)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 15)
	label.scale = Vector2(0.4, 0.4)
	label.pivot_offset = Vector2(16, 10)
	_popups.add_child(label)
	# Pop in, hang, then drift up and fade.
	var tw := create_tween()
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2.ONE, 0.08)
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 22, 0.6).set_delay(0.1)
	tw.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout
