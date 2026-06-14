extends GutTest


func test_roundtrip_all_cells():
	for y in 8:
		for x in 8:
			var c := Vector2i(x, y)
			assert_eq(Iso.to_cell(Iso.to_screen(c)), c)


func test_neighbor_screen_offsets():
	var o := Iso.to_screen(Vector2i(3, 3))
	# +x goes right-down in iso space
	assert_eq(Iso.to_screen(Vector2i(4, 3)) - o, Vector2(Iso.TILE_W / 2.0, Iso.TILE_H / 2.0))
	# +y goes left-down
	assert_eq(Iso.to_screen(Vector2i(3, 4)) - o, Vector2(-Iso.TILE_W / 2.0, Iso.TILE_H / 2.0))


func test_large_isometric_tile_spacing():
	assert_eq(Iso.TILE_W, 128)
	assert_eq(Iso.TILE_H, 64)
	assert_eq(Iso.to_screen(Vector2i(1, 0)), Vector2(64, 32))
	assert_eq(Iso.to_screen(Vector2i(0, 1)), Vector2(-64, 32))


func test_to_cell_tolerates_click_offsets():
	# Clicks near a tile center resolve to that tile.
	var center := Iso.to_screen(Vector2i(5, 2))
	assert_eq(Iso.to_cell(center + Vector2(10, 4)), Vector2i(5, 2))
	assert_eq(Iso.to_cell(center + Vector2(-10, -4)), Vector2i(5, 2))
