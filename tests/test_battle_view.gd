extends GutTest


func test_battle_scales_board_without_scaling_hud() -> void:
	var battle := Battle.new()
	battle.state = Fixtures.blank_state()
	battle._create_board()
	battle._create_hud()
	autofree(battle)

	assert_eq(battle.board.scale, Vector2(2, 2))
	assert_eq(battle.hud.scale, Vector2.ONE)


func test_left_mouse_drag_pans_board() -> void:
	var battle := Battle.new()
	battle.state = Fixtures.blank_state()
	battle._create_board()
	autofree(battle)

	var start := battle.board.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(320, 260)
	battle._unhandled_input(press)

	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(344, 244)
	drag.relative = Vector2(24, -16)
	battle._unhandled_input(drag)

	assert_eq(battle.board.position, start + Vector2(24, -16))

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(344, 244)
	battle._unhandled_input(release)

	var after_release := battle.board.position
	var ignored_drag := InputEventMouseMotion.new()
	ignored_drag.position = Vector2(360, 244)
	ignored_drag.relative = Vector2(16, 0)
	battle._unhandled_input(ignored_drag)

	assert_eq(battle.board.position, after_release)


func test_board_click_ignores_drag_release() -> void:
	var board := BoardView.new()
	add_child_autofree(board)
	board.setup(Fixtures.blank_state())

	var clicked: Array[Vector2i] = []
	board.tile_clicked.connect(func(cell: Vector2i) -> void: clicked.append(cell))

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Iso.to_screen(Vector2i(3, 3))
	board._unhandled_input(press)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = press.position + Vector2(16, 0)
	board._unhandled_input(release)

	assert_eq(clicked.size(), 0)
