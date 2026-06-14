class_name HudLayoutEditor
extends Control
## Debug overlay for tuning the HUD layout in the running game (incl. web).
## Toggle with F2 or the EDIT UI button. A Godot-style sidebar lists the HUD
## node tree; select any node there (or click a panel) and drag it — or nudge
## with arrow keys (Shift = 10 px). Offsets are keyed by stable node path and
## persist to user://hud_layout.json (IndexedDB on web); COPY JSON exports
## them for hardcoding back into hud.gd.

const SAVE_PATH := "user://hud_layout.json"
## Baked layout: part of the project (committed, shipped in the pck). BAKE
## merges the session's offsets into it — directly on desktop, via the dev
## server's /api/bake-layout endpoint on web.
const BAKED_PATH := "res://assets/ui/hud_layout.json"
## Version history of every bake/restore (Figma-style: append-only, restores
## are recorded as new versions). Written by the dev server on web, directly
## on desktop dev runs. Committed to git alongside the baked layout.
const HISTORY_PATH := "res://assets/ui/hud_layout_history.json"
const HISTORY_CAP := 100
const COLOR_EDIT := Color(0.45, 0.95, 0.75)
const COLOR_SELECT := Color(1.0, 0.8, 0.3)
const SIDEBAR_W := 300.0

## Baked offsets currently reflected in the nodes' hud_base_pos metas; needed
## to live-apply a restored version as a delta without restarting.
static var _baked_now: Dictionary = {}

var _roots: Array[Control] = []
var _ui_root: Control
var _prev_visible := {}
var _selected: Control = null
var _drag: Control = null
var _drag_start_mouse := Vector2.ZERO
var _drag_start_pos := Vector2.ZERO
var _tree: Tree
var _tree_items := {}
var _info: Label
var _status: Label
var _bake_dialog: ConfirmationDialog
var _bake_request: HTTPRequest
var _pending_bake := {}
var _history_dialog: AcceptDialog
var _history_list: VBoxContainer
var _history_versions: Array = []
var _history_request: HTTPRequest
var _restore_request: HTTPRequest


## Anonymous HUD nodes get auto names (@Label@33) that differ every launch.
## Rename each drag root to its drag id and every descendant Control to
## "<Class><sibling-index>" so node paths are stable across runs and usable
## as persistence keys.
static func assign_stable_names(roots: Array[Control]) -> void:
	for r in roots:
		r.name = str(r.get_meta("hud_drag_id"))
		_name_children(r)


static func _name_children(parent: Control) -> void:
	var counts := {}
	for c in parent.get_children():
		if not (c is Control):
			continue
		var cls := c.get_class()
		var i: int = counts.get(cls, 0)
		counts[cls] = i + 1
		c.name = "%s%d" % [cls, i]
		_name_children(c)


## Renames the subtree, then applies the baked project layout (rebasing, so it
## becomes the default) and the local user offsets on top. Skipped in headless
## runs so GUT tests always see the pristine code layout.
static func apply_saved(roots: Array[Control], ui_root: Control) -> void:
	assign_stable_names(roots)
	for r in roots:
		r.set_meta("hud_base_pos", r.position)
	_baked_now = _load_json(BAKED_PATH)
	if DisplayServer.get_name() == "headless":
		return
	_apply_offsets(_baked_now, ui_root, true)
	_apply_offsets(_load_json(SAVE_PATH), ui_root, false)


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func _apply_offsets(data: Dictionary, ui_root: Control, rebase: bool) -> void:
	for key in data:
		var off: Variant = data[key]
		var node := ui_root.get_node_or_null(NodePath(str(key))) as Control
		if node == null or not (off is Array) or (off as Array).size() != 2:
			continue
		if not node.has_meta("hud_base_pos"):
			node.set_meta("hud_base_pos", node.position)
		node.position = (node.get_meta("hud_base_pos") as Vector2) + Vector2(float(off[0]), float(off[1]))
		if rebase:
			node.set_meta("hud_base_pos", node.position)


func setup(roots: Array[Control]) -> void:
	_roots = roots
	_ui_root = get_parent() as Control


func _ready() -> void:
	position = Vector2.ZERO
	size = Hud.SCREEN
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_toolbar()
	_build_sidebar()


func toggle() -> void:
	if visible:
		_deactivate()
	else:
		_activate()


func _activate() -> void:
	visible = true
	_status.text = ""
	_prev_visible.clear()
	for r in _roots:
		_prev_visible[r] = r.visible
		r.visible = true
	_rebuild_tree()
	_select(null)


func _deactivate() -> void:
	visible = false
	_drag = null
	_selected = null
	for r in _roots:
		if _prev_visible.has(r):
			r.visible = _prev_visible[r]


# --- sidebar ------------------------------------------------------------------


func _build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(16, 104)
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	for spec in [["DONE (F2)", toggle], ["RESET ALL (R)", _reset], ["COPY JSON (C)", _copy_json], ["BAKE 固化", _confirm_bake], ["HISTORY 历史", _show_history]]:
		var b := Button.new()
		b.text = spec[0]
		b.add_theme_font_size_override("font_size", 11)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		bar.add_child(b)
	var hint := Label.new()
	hint.text = "侧边栏选节点 → 拖拽或方向键微调（Shift=10px）"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.7)
	bar.add_child(hint)

	_status = Label.new()
	_status.position = Vector2(16, 136)
	_status.size = Vector2(700, 18)
	_status.add_theme_font_size_override("font_size", 12)
	add_child(_status)

	_bake_dialog = ConfirmationDialog.new()
	_bake_dialog.title = "固化布局"
	_bake_dialog.dialog_text = "把当前布局合并进项目文件 assets/ui/hud_layout.json？\n固化后将成为所有设备的默认布局（web 会自动重新导出）。"
	_bake_dialog.ok_button_text = "固化"
	_bake_dialog.confirmed.connect(_bake)
	add_child(_bake_dialog)

	_bake_request = HTTPRequest.new()
	_bake_request.request_completed.connect(_on_bake_response)
	add_child(_bake_request)

	_history_dialog = AcceptDialog.new()
	_history_dialog.title = "布局版本历史"
	_history_dialog.ok_button_text = "关闭"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 380)
	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_history_list)
	_history_dialog.add_child(scroll)
	add_child(_history_dialog)

	_history_request = HTTPRequest.new()
	_history_request.request_completed.connect(_on_history_response)
	add_child(_history_request)

	_restore_request = HTTPRequest.new()
	_restore_request.request_completed.connect(_on_restore_response)
	add_child(_restore_request)


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(size.x - SIDEBAR_W, 0)
	panel.size = Vector2(SIDEBAR_W, size.y)
	panel.modulate = Color(1, 1, 1, 0.94)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	_tree = Tree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.focus_mode = Control.FOCUS_NONE  # keep arrow keys free for nudging
	_tree.add_theme_font_size_override("font_size", 11)
	_tree.item_selected.connect(_on_tree_selected)
	vbox.add_child(_tree)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 10)
	_info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_info.custom_minimum_size = Vector2(0, 56)
	vbox.add_child(_info)


func _rebuild_tree() -> void:
	_tree.clear()
	_tree_items.clear()
	var root_item := _tree.create_item()
	root_item.set_text(0, "HUD")
	root_item.set_selectable(0, false)
	for r in _roots:
		_add_tree_node(r, root_item)


func _add_tree_node(node: Control, parent_item: TreeItem) -> void:
	var item := _tree.create_item(parent_item)
	item.set_text(0, _describe(node))
	item.set_metadata(0, node)
	_tree_items[node] = item
	if node.get_parent() is Container:
		item.set_custom_color(0, Color(0.7, 0.55, 0.55))
		item.set_tooltip_text(0, "由容器自动排列，拖动无效")
	for c in node.get_children():
		if c is Control and not (c is HudLayoutEditor):
			_add_tree_node(c, item)


func _describe(node: Control) -> String:
	var label := String(node.name)
	if node is Label and (node as Label).text != "":
		label += ' "%s"' % (node as Label).text.left(14)
	elif node is TextureRect and (node as TextureRect).texture != null:
		label += " [%s]" % (node as TextureRect).texture.resource_path.get_file().left(24)
	return label


func _on_tree_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		_select(null, false)
	else:
		_select(item.get_metadata(0) as Control, false)


func _select(node: Control, sync_tree: bool = true) -> void:
	_selected = node
	if sync_tree and node != null and _tree_items.has(node):
		(_tree_items[node] as TreeItem).select(0)
		_tree.scroll_to_item(_tree_items[node])
	_update_info()
	queue_redraw()


func _update_info() -> void:
	if _selected == null:
		_info.text = "未选中节点"
		return
	var base: Vector2 = _selected.get_meta("hud_base_pos", _selected.position)
	var off := _selected.position - base
	_info.text = "%s\npos: %d,%d  offset: %d,%d" % [_path_of(_selected), _selected.position.x, _selected.position.y, off.x, off.y]


func _path_of(node: Control) -> String:
	return str(_ui_root.get_path_to(node))


# --- input --------------------------------------------------------------------


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_begin_drag(mb.position)
		elif _drag != null:
			_drag = null
			_save()
		accept_event()
		queue_redraw()
	var mm := event as InputEventMouseMotion
	if mm != null and _drag != null:
		_drag.position = (_drag_start_pos + mm.position - _drag_start_mouse).round()
		_update_info()
		queue_redraw()


## Press inside the selected node drags it; pressing another top-level block
## selects that block; empty space still drags the selection (so nodes hidden
## under the sidebar can be moved after picking them in the tree).
func _begin_drag(p: Vector2) -> void:
	var hit := _root_at(p)
	if _selected != null and (_selected.get_global_rect().has_point(p) or hit == null):
		_start_drag(_selected, p)
	elif hit != null:
		_select(hit)
		_start_drag(hit, p)


func _start_drag(node: Control, mouse: Vector2) -> void:
	if not node.has_meta("hud_base_pos"):
		node.set_meta("hud_base_pos", node.position)
	_drag = node
	_drag_start_mouse = mouse
	_drag_start_pos = node.position


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var step := 10.0 if key.shift_pressed else 1.0
	match key.keycode:
		KEY_ESCAPE:
			toggle()
		KEY_R:
			_reset()
		KEY_C:
			_copy_json()
		KEY_LEFT:
			_nudge(Vector2(-step, 0))
		KEY_RIGHT:
			_nudge(Vector2(step, 0))
		KEY_UP:
			_nudge(Vector2(0, -step))
		KEY_DOWN:
			_nudge(Vector2(0, step))


func _nudge(delta: Vector2) -> void:
	if _selected == null:
		return
	if not _selected.has_meta("hud_base_pos"):
		_selected.set_meta("hud_base_pos", _selected.position)
	_selected.position += delta
	_save()
	_update_info()
	queue_redraw()


func _root_at(p: Vector2) -> Control:
	for i in range(_roots.size() - 1, -1, -1):
		if Rect2(_roots[i].position, _roots[i].size).has_point(p):
			return _roots[i]
	return null


# --- persistence ----------------------------------------------------------------


func _moved_nodes(parent: Control, out: Array) -> void:
	for c in parent.get_children():
		if c is Control:
			if c.has_meta("hud_base_pos") and (c as Control).position != (c.get_meta("hud_base_pos") as Vector2):
				out.append(c)
			_moved_nodes(c, out)


func _offsets() -> Dictionary:
	var moved: Array = []
	for r in _roots:
		if r.position != (r.get_meta("hud_base_pos") as Vector2):
			moved.append(r)
		_moved_nodes(r, moved)
	var d := {}
	for n: Control in moved:
		var off: Vector2 = n.position - (n.get_meta("hud_base_pos") as Vector2)
		d[_path_of(n)] = [off.x, off.y]
	return d


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_offsets()))


func _restore_subtree(parent: Control) -> void:
	for c in parent.get_children():
		if c is Control:
			if c.has_meta("hud_base_pos"):
				(c as Control).position = c.get_meta("hud_base_pos")
			_restore_subtree(c)


func _reset() -> void:
	for r in _roots:
		r.position = r.get_meta("hud_base_pos")
		_restore_subtree(r)
	_save()
	_update_info()
	queue_redraw()


func _copy_json() -> void:
	var s := JSON.stringify(_offsets())
	DisplayServer.clipboard_set(s)
	print("HUD layout offsets: ", s)
	_toast("已复制: " + s, true)


# --- bake -----------------------------------------------------------------------


func _confirm_bake() -> void:
	_bake_dialog.popup_centered()


## Merge baked + session offsets and persist them into the project. On web the
## dev server writes the file (and re-exports); on desktop dev runs res:// is
## the project directory, so write it directly.
func _bake() -> void:
	var merged := _load_json(BAKED_PATH)
	var user := _offsets()
	for k in user:
		var b: Array = merged.get(k, [0.0, 0.0])
		merged[k] = [float(b[0]) + float(user[k][0]), float(b[1]) + float(user[k][1])]
	var clean := {}
	for k in merged:
		if float(merged[k][0]) != 0.0 or float(merged[k][1]) != 0.0:
			clean[k] = merged[k]
	var body := JSON.stringify(clean)

	if OS.has_feature("web"):
		_pending_bake = clean
		var err := _bake_request.request(_origin() + "/api/bake-layout", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body)
		if err != OK:
			_toast("固化请求发送失败 (%d)" % err, false)
		else:
			_toast("固化中…", true)
	else:
		var f := FileAccess.open(BAKED_PATH, FileAccess.WRITE)
		if f == null:
			_toast("无法写入 %s（导出版不支持，请在网页或源码运行中固化）" % BAKED_PATH, false)
			return
		f.store_string(body)
		f.close()
		_append_history_local(clean)
		_finish_bake(clean, "已固化到 assets/ui/hud_layout.json（历史 v%d）" % (_load_json(HISTORY_PATH).get("versions", []) as Array).size())


func _on_bake_response(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_finish_bake(_pending_bake, "已固化到项目，web 正在重新导出，约半分钟后刷新页面即为默认布局")
	else:
		_toast("固化失败 (HTTP %d)——确认页面是由 tools/serve_web.sh 提供的" % code, false)


## Baked positions are the new defaults: rebase everything and clear the local
## offset file so nothing is applied twice.
func _finish_bake(baked: Dictionary, msg: String) -> void:
	HudLayoutEditor._baked_now = baked
	for r in _roots:
		r.set_meta("hud_base_pos", r.position)
		_rebase_subtree(r)
	_save()
	_update_info()
	_toast(msg, true)


func _rebase_subtree(parent: Control) -> void:
	for c in parent.get_children():
		if c is Control:
			if c.has_meta("hud_base_pos"):
				c.set_meta("hud_base_pos", (c as Control).position)
			_rebase_subtree(c)


func _toast(msg: String, ok: bool = true) -> void:
	_status.text = msg
	_status.modulate = Color(0.6, 1.0, 0.7) if ok else Color(1.0, 0.55, 0.5)


# --- version history --------------------------------------------------------------


func _origin() -> String:
	return str(JavaScriptBridge.eval("window.location.origin", true))


func _show_history() -> void:
	if OS.has_feature("web"):
		var err := _history_request.request(_origin() + "/api/layout-history")
		if err != OK:
			_toast("历史加载失败 (%d)" % err, false)
	else:
		_populate_history(_load_json(HISTORY_PATH))
		_history_dialog.popup_centered()


func _on_history_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_toast("历史加载失败 (HTTP %d)——确认页面由 tools/serve_web.sh 提供" % code, false)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	_populate_history(data if data is Dictionary else {})
	_history_dialog.popup_centered()


func _populate_history(data: Dictionary) -> void:
	for c in _history_list.get_children():
		c.queue_free()
	_history_versions = data.get("versions", [])
	if _history_versions.is_empty():
		var empty := Label.new()
		empty.text = "还没有任何固化版本"
		_history_list.add_child(empty)
		return
	for i in range(_history_versions.size() - 1, -1, -1):
		_history_list.add_child(_history_row(i))


func _history_row(i: int) -> Control:
	var v: Dictionary = _history_versions[i]
	var layout: Dictionary = v.get("layout", {})
	var prev: Dictionary = (_history_versions[i - 1] as Dictionary).get("layout", {}) if i > 0 else {}
	var is_current := i == _history_versions.size() - 1

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text := "v%d  %s  ·  %d 项偏移  ·  Δ%d" % [i + 1, v.get("ts", "?"), layout.size(), _diff_count(layout, prev)]
	if v.has("restored_from"):
		text += "  ·  回退自 v%d" % (int(v["restored_from"]) + 1)
	var label := Label.new()
	label.text = text + ("  （当前）" if is_current else "")
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	if not is_current:
		var btn := Button.new()
		btn.text = "回退"
		btn.add_theme_font_size_override("font_size", 11)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_restore_version.bind(i))
		row.add_child(btn)
	return row


func _diff_count(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for k in a:
		if not b.has(k) or str(b[k]) != str(a[k]):
			n += 1
	for k in b:
		if not a.has(k):
			n += 1
	return n


func _restore_version(i: int) -> void:
	if OS.has_feature("web"):
		var err := _restore_request.request(_origin() + "/api/restore-layout", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify({"index": i}))
		if err != OK:
			_toast("回退请求发送失败 (%d)" % err, false)
		else:
			_toast("回退中…", true)
	else:
		var layout: Dictionary = (_history_versions[i] as Dictionary).get("layout", {})
		var f := FileAccess.open(BAKED_PATH, FileAccess.WRITE)
		if f == null:
			_toast("无法写入 " + BAKED_PATH, false)
			return
		f.store_string(JSON.stringify(layout))
		f.close()
		_append_history_local(layout, i)
		_finish_restore(layout)


func _on_restore_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_toast("回退失败 (HTTP %d)" % code, false)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and (data as Dictionary).get("layout") is Dictionary:
		_finish_restore((data as Dictionary)["layout"])
	else:
		_toast("回退响应异常", false)


func _finish_restore(layout: Dictionary) -> void:
	_apply_baked_live(layout)
	_history_dialog.hide()
	_toast("已回退并实时应用；web 正在重新导出，刷新后此版本即为默认布局")


## Shift bases and positions by (new - old) baked offsets so the restored
## version shows immediately while unbaked local edits stay on top.
func _apply_baked_live(new_baked: Dictionary) -> void:
	var keys := {}
	for k in HudLayoutEditor._baked_now:
		keys[k] = true
	for k in new_baked:
		keys[k] = true
	for k in keys:
		var node := _ui_root.get_node_or_null(NodePath(str(k))) as Control
		if node == null:
			continue
		var o: Array = HudLayoutEditor._baked_now.get(k, [0.0, 0.0])
		var n: Array = new_baked.get(k, [0.0, 0.0])
		var delta := Vector2(float(n[0]) - float(o[0]), float(n[1]) - float(o[1]))
		if delta == Vector2.ZERO:
			continue
		if not node.has_meta("hud_base_pos"):
			node.set_meta("hud_base_pos", node.position)
		node.set_meta("hud_base_pos", (node.get_meta("hud_base_pos") as Vector2) + delta)
		node.position += delta
	HudLayoutEditor._baked_now = new_baked
	_update_info()
	queue_redraw()


func _append_history_local(layout: Dictionary, restored_from: int = -1) -> void:
	var data := _load_json(HISTORY_PATH)
	var versions: Array = data.get("versions", [])
	if restored_from < 0 and not versions.is_empty() and str((versions[-1] as Dictionary).get("layout")) == str(layout):
		return
	var entry := {"ts": Time.get_datetime_string_from_system(false, true), "layout": layout}
	if restored_from >= 0:
		entry["restored_from"] = restored_from
	versions.append(entry)
	if versions.size() > HISTORY_CAP:
		versions = versions.slice(versions.size() - HISTORY_CAP)
	var f := FileAccess.open(HISTORY_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"versions": versions}, " "))
		f.close()


# --- drawing --------------------------------------------------------------------


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for r in _roots:
		var rect := Rect2(r.position, r.size)
		draw_rect(rect, Color(COLOR_EDIT, 0.04), true)
		draw_rect(rect, Color(COLOR_EDIT, 0.5), false, 1.0)
		draw_string(font, rect.position + Vector2(2, -3), str(r.get_meta("hud_drag_id")), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(COLOR_EDIT, 0.9))
	if _selected != null:
		var rect := _selected.get_global_rect()
		draw_rect(rect, Color(COLOR_SELECT, 0.12), true)
		draw_rect(rect, COLOR_SELECT, false, 2.0)
		draw_string(font, rect.position + Vector2(0, rect.size.y + 12), "%s (%d, %d)" % [_selected.name, _selected.position.x, _selected.position.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_SELECT)
