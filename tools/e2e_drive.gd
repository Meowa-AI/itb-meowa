extends SceneTree
## E2E driver: runs the real game, synthesizes mouse input, saves screenshots
## to /tmp/itb_verify for inspection.
## Run: Godot --path . --resolution 1280x720 -s tools/e2e_drive.gd

const OUT := "/tmp/itb_verify"
var game: Game
var shot_idx := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_run()


func _run() -> void:
	await _frames(10)
	await _shot("title")

	# Start run
	_click_control_text("START RUN")
	await _frames(30)
	await _shot("m1_battle_start")

	var battle: Battle = game._current
	assert(battle != null, "battle scene active")
	var state: BattleState = battle.state

	# Select the first mech (wait out the initial telegraph playback first)
	await _wait_playback(battle)
	var mech: BUnit = state.mechs()[0]
	_click_cell(battle, mech.pos)
	await _frames(8)
	_log("selected_after_click: %s" % (battle.selected != null))
	_log("mode_after_click: %s" % battle.mode)
	await _shot("m1_mech_selected_move_range")

	# Move it one legal tile
	var moves := Actions.legal_moves(state, mech)
	moves.sort_custom(func(a, b): return str(a) < str(b))
	_click_cell(battle, moves[0])
	await _wait_playback(battle)
	await _shot("m1_after_move")

	# Attack mode: select a target if any, else just screenshot overlays
	if not battle.board.target_overlay.is_empty():
		_hover_cell(battle, battle.board.target_overlay[0])
		await _frames(8)
		await _shot("m1_attack_preview")
		_click_cell(battle, battle.board.target_overlay[0])
		await _wait_playback(battle)
		await _shot("m1_after_attack")

	# Undo: board must return to turn start
	var before_undo := str(state.snapshot())
	_press(battle.hud._btn_undo)
	await _frames(8)
	await _shot("m1_after_undo")
	var after_undo := str(state.snapshot())
	_log("undo_changed_state: %s" % (before_undo != after_undo))
	_log("undo_matches_turn_snapshot: %s" % (after_undo == str(battle.turn_snapshot)))

	# End turn → enemy phase animations + new telegraphs
	_press(battle.hud._btn_end)
	await _wait_playback(battle)
	await _frames(10)
	await _shot("m1_after_enemy_phase")

	# Fast-forward the rest of mission 1 via direct core play (UI already shown);
	# simulate a player who kills everything: clear vek through the engine.
	for v in state.vek():
		Push.damage_unit(state, v, 99)
	state.pending_spawns = []
	state.spawn_queue = []
	battle.board.refresh()
	await battle._play_and_check([])
	await _frames(20)
	await _shot("shop_after_m1")

	# Shop: buy +2 HP for prime if affordable
	var shop: ShopScreen = game._current
	if shop is ShopScreen:
		_log("shop_reached: true, rep=%d" % game.run.reputation)
		shop.run.buy("hp_up", "prime")
		shop._rebuild()
		await _frames(5)
		await _shot("shop_bought_hp")
		_click_control_text("NEXT MISSION ▶")
		await _frames(30)
		await _shot("m2_battle_start")
	else:
		_log("shop_reached: false")

	# Force a game over via grid loss in mission 2
	var b2: Battle = game._current
	if b2 is Battle:
		b2.state.grid_power = 0
		await b2._play_and_check([])
		await _frames(20)
		await _shot("game_over")
	_log("done")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_playback(battle: Battle) -> void:
	await _frames(5)
	var guard := 0
	while battle.board.busy and guard < 600:
		await process_frame
		guard += 1
	await _frames(10)


func _shot(name: String) -> void:
	await _frames(2)
	var img := root.get_texture().get_image()
	shot_idx += 1
	img.save_png("%s/%02d_%s.png" % [OUT, shot_idx, name])


func _log(msg: String) -> void:
	print("E2E| ", msg)


func _click_at(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _hover_at(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	Input.parse_input_event(mv)


func _cell_to_window(battle: Battle, cell: Vector2i) -> Vector2:
	return battle.board.position + Iso.to_screen(cell) * battle.board.scale


func _click_cell(battle: Battle, cell: Vector2i) -> void:
	_click_at(_cell_to_window(battle, cell))


func _hover_cell(battle: Battle, cell: Vector2i) -> void:
	_hover_at(_cell_to_window(battle, cell))


func _press(btn: Button) -> void:
	btn.pressed.emit()


func _click_control_text(text: String) -> void:
	var found := _find_button(root, text)
	if found != null:
		found.pressed.emit()
	else:
		_log("button_not_found: " + text)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
