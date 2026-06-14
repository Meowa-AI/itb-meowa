extends GutTest


const GENERATED_TILE_PATHS := [
	"res://assets/tiles/generated/grass_a.png",
	"res://assets/tiles/generated/grass_b.png",
	"res://assets/tiles/generated/water_a.png",
	"res://assets/tiles/generated/water_b.png",
	"res://assets/tiles/generated/house_a.png",
	"res://assets/tiles/generated/house_b.png",
	"res://assets/tiles/generated/rock_a.png",
	"res://assets/tiles/generated/rock_b.png",
	"res://assets/tiles/generated/rubble_a.png",
	"res://assets/tiles/generated/rubble_b.png",
]


func test_generated_iso_tiles_exist():
	for path in GENERATED_TILE_PATHS:
		assert_true(ResourceLoader.exists(path), path)


func test_board_view_uses_generated_tile_sets():
	var ground := BoardView.GROUND_TEXTURES
	var objects := BoardView.OBJECT_TEXTURES
	assert_eq(ground["plain"], load("res://assets/tiles/generated/grass_a.png"))
	assert_eq(ground["plain_alt"], load("res://assets/tiles/generated/grass_b.png"))
	assert_eq(ground["water"], load("res://assets/tiles/generated/water_a.png"))
	assert_eq(ground["water_alt"], load("res://assets/tiles/generated/water_b.png"))
	assert_eq(ground["rubble"], load("res://assets/tiles/generated/rubble_a.png"))
	assert_eq(objects["building"], load("res://assets/tiles/generated/house_a.png"))
	assert_eq(objects["building_alt"], load("res://assets/tiles/generated/house_b.png"))
	assert_eq(objects["mountain"], load("res://assets/tiles/generated/rock_a.png"))
	assert_eq(objects["mountain_damaged"], load("res://assets/tiles/generated/rock_b.png"))


func test_generated_tiles_render_on_logical_grid_center():
	assert_eq(BoardView.TILE_SPRITE_OFFSET, Vector2.ZERO)
