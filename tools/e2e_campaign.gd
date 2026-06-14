extends SceneTree
## Campaign E2E: pushes a run through all 7 missions exercising the real
## battle controllers and screen flow. Battles are resolved through core
## calls (UI interaction is covered by e2e_drive.gd); screen transitions,
## objective logic, shop purchases, and end screens are verified for real.
## Run: Godot --path . --resolution 1280x720 -s tools/e2e_campaign.gd

const OUT := "/tmp/itb_campaign"
var game: Game
var shot_idx := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_run()


func _run() -> void:
	await _frames(10)
	_find_button(root, "START RUN").pressed.emit()
	await _frames(20)

	# --- M1, M2: kill-all missions, clear them ---
	for i in 2:
		await _win_kill_all("m%d" % (i + 1))
		await _shop_and_continue(i == 0)

	# --- M3: survive 5 turns by ending turns (mechs healed each turn) ---
	var b: Battle = game._current
	await _until_battle_done_or_idle(b)
	_log("m3_objective: " + b.state.mission.objective)
	var m3_state := b.state
	var guard := 0
	while is_instance_valid(b) and b.is_inside_tree() and TurnEngine.check_outcome(m3_state) == "" and guard < 12:
		for m in m3_state.mechs():
			m.hp = m.max_hp
		b._on_end_turn()
		await _until_battle_done_or_idle(b)
		guard += 1
	_log("m3_outcome: " + TurnEngine.check_outcome(m3_state))
	await _shot("m3_survive_result")
	await _wait_for_shop()
	await _shop_and_continue(false)

	# --- M4: protect mission — destroy the objective, expect failure + continue ---
	b = game._current
	await _until_battle_done_or_idle(b)
	_log("m4_objective: " + b.state.mission.objective)
	b.state.grid_power = 7  # top up so the -5 (3 hp + 2 penalty) doesn't zero the grid
	var grid_before: int = b.state.grid_power
	for pos in b.state.buildings:
		if b.state.buildings[pos]["objective"]:
			var evs := Push.damage_tile(b.state, pos, 9)
			evs.append_array(TurnEngine.apply_protect_failure(b.state))
			await b._play_and_check(evs)
	_log("m4_grid_drop: %d" % (grid_before - b.state.grid_power))
	await _shot("m4_objective_lost")
	await _wait_for_shop()
	_log("m4_run_continues: %s" % (game._current is ShopScreen))
	await _shop_and_continue(false)

	# --- M5: kill-all ---
	await _win_kill_all("m5")
	await _shop_and_continue(false)

	# --- M6: survive 6 — jump the clock then end turn ---
	b = game._current
	await _until_battle_done_or_idle(b)
	var m6_state := b.state
	m6_state.turn = m6_state.mission.survive_turns
	m6_state.grid_power = 7  # keep the run alive through the final enemy phase
	for m in m6_state.mechs():
		m.hp = m.max_hp
	b._on_end_turn()
	await _until_battle_done_or_idle(b)
	_log("m6_outcome: " + TurnEngine.check_outcome(m6_state))
	await _wait_for_shop()
	await _shop_and_continue(false)

	# --- M7: boss kill-all → victory ---
	b = game._current
	_log("m7_has_boss: %s" % (b.state.vek().any(func(v): return Defs.unit(v.def_id).is_boss)))
	await _shot("m7_boss_battle")
	await _win_kill_all("m7")
	await _frames(30)
	_log("victory_screen: %s" % (game._current is EndScreen))
	await _shot("victory")
	_log("done")
	quit(0)


func _win_kill_all(tag: String) -> void:
	var b: Battle = game._current
	assert(b is Battle, "expected battle for " + tag)
	await _until_battle_done_or_idle(b)
	for v in b.state.vek():
		Push.damage_unit(b.state, v, 99)
	b.state.pending_spawns = []
	b.state.spawn_queue = []
	b.board.refresh()
	await b._play_and_check([])
	await _frames(10)


func _shop_and_continue(buy_weapons: bool) -> void:
	await _wait_for_shop()
	var shop: ShopScreen = game._current
	assert(shop is ShopScreen, "expected shop")
	if buy_weapons:
		shop.run.reputation = 10
		var ok1 := shop.run.buy("cluster_shells")
		var ok2 := shop.run.buy("hp_up", "prime")
		shop._rebuild()
		_log("bought_cluster_and_hp: %s %s" % [ok1, ok2])
		await _frames(5)
		await _shot("shop_purchases")
	_find_button(shop, "NEXT MISSION ▶").pressed.emit()
	await _frames(20)
	var b: Battle = game._current
	if b is Battle and game.run.purchased.has("cluster_shells"):
		_log("m_next_artillery_weapon: " + b.state.mechs()[1].weapon_id)


func _wait_for_shop() -> void:
	var guard := 0
	while not (game._current is ShopScreen) and not (game._current is EndScreen) and guard < 1200:
		await process_frame
		guard += 1
	await _frames(5)


func _until_battle_done_or_idle(b: Battle) -> void:
	var guard := 0
	while guard < 1200:
		if not is_instance_valid(b) or not b.is_inside_tree():
			break
		if not b.board.busy and not b.finished:
			break
		await process_frame
		guard += 1
	await _frames(5)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	shot_idx += 1
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [OUT, shot_idx, name])


func _log(msg: String) -> void:
	print("E2E| ", msg)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
