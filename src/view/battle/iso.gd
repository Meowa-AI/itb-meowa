class_name Iso
extends RefCounted
## Isometric projection: logical (x, y) grid cells <-> screen pixels.
## Screen origin (0,0) is the center of cell (0,0); 2:1 diamonds.

const TILE_W := 128
const TILE_H := 64
const Z_STRIDE := 10


static func to_screen(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_W / 2.0,
		(cell.x + cell.y) * TILE_H / 2.0
	)


static func to_cell(screen: Vector2) -> Vector2i:
	var fx := screen.x / (TILE_W / 2.0)
	var fy := screen.y / (TILE_H / 2.0)
	return Vector2i(
		int(round((fx + fy) / 2.0)),
		int(round((fy - fx) / 2.0))
	)


static func sort_z(cell: Vector2i) -> int:
	return (cell.x + cell.y) * Z_STRIDE + cell.y
