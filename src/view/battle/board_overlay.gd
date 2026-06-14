class_name BoardOverlay
extends Node2D
## Draws all tactical overlays from board state each frame it's dirtied:
## hover/selection highlights, move range, attack targets, vek telegraph
## lines, pending spawn markers, and attack preview ghosts.

var board: BoardView


func _diamond(center: Vector2) -> PackedVector2Array:
	var w := Iso.TILE_W / 2.0
	var h := Iso.TILE_H / 2.0
	return PackedVector2Array([
		center + Vector2(0, -h), center + Vector2(w, 0),
		center + Vector2(0, h), center + Vector2(-w, 0),
	])


func _fill(cell: Vector2i, color: Color) -> void:
	draw_colored_polygon(_diamond(Iso.to_screen(cell)), color)


func _outline(cell: Vector2i, color: Color, width: float = 2.0) -> void:
	var pts := _diamond(Iso.to_screen(cell))
	pts.append(pts[0])
	draw_polyline(pts, color, width)


func _draw() -> void:
	if board == null or board.state == null:
		return
	var s: BattleState = board.state
	if board.show_grid:
		_draw_lattice()
	for cell in board.move_overlay:
		_fill(cell, Color(0.4, 0.7, 1.0, 0.35))
		_outline(cell, Color(0.5, 0.8, 1.0, 0.6), 1.0)
	for t in board.target_overlay:
		_fill(t, Color(1.0, 0.5, 0.2, 0.3))
		_outline(t, Color(1.0, 0.55, 0.25, 0.8), 1.0)
	if board.selected_cell != Vector2i(-1, -1):
		_outline(board.selected_cell, Color(1.0, 0.9, 0.4), 2.0)
	# Vek telegraphs: dashed line + threatened tile marks
	for vek in s.vek():
		if vek.intent.is_empty():
			continue
		var origin := Iso.to_screen(vek.pos)
		for tile in Telegraph.threatened_tiles(s, vek):
			_outline(tile, Color(0.9, 0.2, 0.2, 0.9), 2.0)
			_dashed_line(origin + Vector2(0, -10), Iso.to_screen(tile), Color(0.9, 0.25, 0.2, 0.8))
	# Pending spawns
	for sp in s.pending_spawns:
		_outline(sp["pos"], Color(1.0, 0.8, 0.3, 0.9), 2.0)
		_draw_spawn_arrow(Iso.to_screen(sp["pos"]))
	# Hover
	var hc := board.hover_cell()
	if s.in_bounds(hc):
		_outline(hc, Color(1, 1, 1, 0.5), 1.0)
	# Attack preview ghosts
	for ev in board.preview_events:
		match ev["type"]:
			"unit_damaged":
				var u: BUnit = s.unit_by_id(ev["unit_id"])
				if u != null:
					_preview_text(Iso.to_screen(u.pos) + Vector2(10, -44), "-%d" % ev["amount"], Color(1, 0.5, 0.4))
			"unit_died":
				_preview_text(Iso.to_screen(ev["pos"]) + Vector2(10, -58), "✖", Color(1, 0.3, 0.3))
			"unit_pushed":
				if ev["from"] != ev["to"]:
					_arrow(Iso.to_screen(ev["from"]), Iso.to_screen(ev["to"]), Color(1, 0.9, 0.4))
			"building_damaged":
				_preview_text(Iso.to_screen(ev["pos"]) + Vector2(10, -44), "-%d" % ev["amount"], Color(1, 0.75, 0.3))


func _draw_lattice() -> void:
	## Debug grid (toggle with G): the exact iso lattice the tiles must sit on.
	var n := BattleState.SIZE
	var col := Color(1, 0.2, 1, 0.9)
	for i in n + 1:
		draw_line(_corner(i, 0), _corner(i, n), col, 1.0)
		draw_line(_corner(0, i), _corner(n, i), col, 1.0)


func _corner(i: int, j: int) -> Vector2:
	## Lattice node (i, j): the TOP vertex of cell (i, j).
	return Vector2((i - j) * Iso.TILE_W / 2.0, (i + j) * Iso.TILE_H / 2.0 - Iso.TILE_H / 2.0)


func _dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := to - from
	var len := dir.length()
	if len < 1.0:
		return
	dir = dir / len
	var t := 0.0
	while t < len:
		var seg_end: float = minf(t + 6.0, len)
		draw_line(from + dir * t, from + dir * seg_end, color, 2.0)
		t += 11.0


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 2.5)
	var dir := (to - from).normalized()
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		to, to - dir * 8 + side * 5, to - dir * 8 - side * 5,
	]), color)


func _draw_spawn_arrow(center: Vector2) -> void:
	var c := Color(1.0, 0.8, 0.3, 0.95)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -8), center + Vector2(6, 2), center + Vector2(-6, 2),
	]), c)


func _preview_text(at: Vector2, text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
