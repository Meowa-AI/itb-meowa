extends SceneTree
## Autoplay bot: plays a full run through the REAL UI — synthesized mouse
## clicks on board tiles, real HUD buttons, real animation playback.
## Decisions come from a greedy evaluation on cloned core states.
## Run: Godot --path . --resolution 1280x720 -s tools/autoplay.gd
## Logs to stdout (AP| prefix), screenshots to /tmp/itb_autoplay.

const OUT := "/tmp/itb_autoplay"
const MAX_TURNS_PER_BATTLE := 30
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
	_press_text("START RUN")
	await _frames(20)

	var missions_played := 0
	while missions_played < 12:  # hard cap
		var node: Node = game._current
		if node is Battle:
			missions_played += 1
			await _play_battle(node)
		elif node is ShopScreen:
			await _do_shop(node)
		elif node is EndScreen:
			break
		else:
			await _frames(10)

	var end := game._current
	if end is EndScreen:
		_log("run_result: " + end.headline + " | " + end.detail.replace("\n", " / "))
		await _shot("final_screen")
	else:
		_log("run_result: UNEXPECTED scene %s" % [end])
	_log("done")
	quit(0)


# ---------- battle ----------

func _play_battle(b: Battle) -> void:
	await _idle(b)
	var mid: String = b.state.mission.id
	_log("%s begin: %s obj=%s grid=%d" % [mid, b.state.mission.title, b.state.mission.objective, b.state.grid_power])
	await _shot(mid + "_start")
	var turn := 0
	while is_instance_valid(b) and b.is_inside_tree() and not b.finished and turn < MAX_TURNS_PER_BATTLE:
		turn += 1
		await _play_turn(b)
		if not is_instance_valid(b) or not b.is_inside_tree() or b.finished:
			break
		_press_btn(b.hud._btn_end)
		await _idle(b)
	if is_instance_valid(b) and b.is_inside_tree():
		_log("%s end: outcome=%s grid=%d turn=%d" % [mid, TurnEngine.check_outcome(b.state), b.state.grid_power, b.state.turn])
		await _shot(mid + "_end")
	# wait for the scene swap (battle_finished fires after a 1.6s banner)
	var guard := 0
	while is_instance_valid(b) and b.is_inside_tree() and guard < 400:
		await process_frame
		guard += 1
	await _frames(20)


func _play_turn(b: Battle) -> void:
	for mech_id in b.state.mechs().map(func(m): return m.id):
		if not is_instance_valid(b) or not b.is_inside_tree() or b.finished:
			return
		var mech: BUnit = b.state.unit_by_id(mech_id)
		if mech == null or not mech.alive or mech.acted:
			continue
		var plan := _best_action(b.state, mech)
		await _execute_plan(b, mech, plan)
		await _idle(b)


func _best_action(s: BattleState, mech: BUnit) -> Dictionary:
	var threatened := {}
	var dangerous := {}  # vek id -> true when its telegraph threatens a building/mech
	for v in s.vek():
		for t in Telegraph.threatened_tiles(s, v):
			threatened[t] = true
			if (s.buildings.has(t) and s.buildings[t]["hp"] > 0) or (s.unit_at(t) != null and s.unit_at(t).team == "mech"):
				dangerous[v.id] = true
	var spawn_tiles := {}
	for sp in s.pending_spawns:
		spawn_tiles[sp["pos"]] = true

	var tiles: Array = [mech.pos]
	tiles.append_array(Actions.legal_moves(s, mech))
	var best := {"move": mech.pos, "target": Vector2i(-1, -1), "repair": false, "score": -999999}
	for tile in tiles:
		var pos_score := 0
		if spawn_tiles.has(tile) and mech.hp > 2:
			pos_score += 350  # block a spawn, but not on our last legs
		if threatened.has(tile):
			pos_score -= 700
		pos_score -= _dist_to_nearest_vek(s, tile) * 10
		# Option A: just reposition
		if pos_score > best["score"]:
			best = {"move": tile, "target": Vector2i(-1, -1), "repair": false, "score": pos_score}
		# Option B: reposition + repair
		if mech.hp < mech.max_hp:
			var heal_score: int = pos_score + (mech.max_hp - mech.hp) * 60
			if heal_score > best["score"]:
				best = {"move": tile, "target": Vector2i(-1, -1), "repair": true, "score": heal_score}
		# Option C: move + attack
		var sim := s.clone()
		var sm := sim.unit_by_id(mech.id)
		sm.pos = tile
		sm.moved = tile != mech.pos
		for t in Actions.legal_targets(sim, sm):
			var sim2 := sim.clone()
			var r := Actions.do_attack(sim2, sim2.unit_by_id(mech.id), t["target"])
			if not r["ok"]:
				continue
			var score: int = pos_score + _score_events(sim2, r["events"], mech.id, dangerous)
			if score > best["score"]:
				best = {"move": tile, "target": t["target"], "repair": false, "score": score}
	return best


func _score_events(sim: BattleState, events: Array, my_id: int, dangerous: Dictionary) -> int:
	var score := 0
	for ev in events:
		match ev["type"]:
			"unit_damaged":
				var u: BUnit = sim.unit_by_id(ev["unit_id"])
				if u == null:
					continue
				if u.team == "vek":
					score += 80 * ev["amount"]
					if Defs.unit(u.def_id).is_boss:
						score += 60 * ev["amount"]  # focus the boss down
					if dangerous.has(u.id):
						score += 250  # disrupting an attack on a building/mech
				else:
					score -= 120 * ev["amount"]
			"unit_pushed":
				var u: BUnit = sim.unit_by_id(ev["unit_id"])
				if u != null and u.team == "vek" and dangerous.has(u.id) and ev["from"] != ev["to"]:
					score += 200  # displacement redirects its telegraph
			"unit_died":
				var u: BUnit = sim.unit_by_id(ev["unit_id"])
				if u == null:
					continue
				if u.team == "vek":
					score += 500 if not Defs.unit(u.def_id).is_boss else 1500
					if dangerous.has(u.id):
						score += 400
				else:
					score -= 2000 if u.id == my_id else 1500
			"building_damaged":
				score -= 600 * ev["amount"]
			"mission_failed":
				score -= 3000
	return score


func _execute_plan(b: Battle, mech: BUnit, plan: Dictionary) -> void:
	_log("  %s t%d %s: move %s->%s atk %s (score %d)" % [
		b.state.mission.id, b.state.turn, mech.def_id, mech.pos, plan["move"], plan["target"], plan["score"]])
	# Reset the controller FSM first: a leftover ATTACK mode would turn our
	# select click into a friendly-fire attack if the mech stands in range.
	b._deselect()
	await _frames(2)
	# Select (retry — clicks are dropped while playback is busy)
	for attempt in 4:
		_click_cell(b, mech.pos)
		await _idle(b)
		if b.selected == mech:
			break
		await _frames(10)
	if b.selected != mech:
		_log("    BUG? could not select %s at %s" % [mech.def_id, mech.pos])
		return
	if plan["move"] != mech.pos:
		if b.mode != Battle.Mode.MOVE:
			_press_btn(b.hud._btn_move)
			await _frames(2)
		for attempt in 3:
			_click_cell(b, plan["move"])
			await _idle(b)
			if mech.pos == plan["move"]:
				break
			await _frames(10)
		if mech.pos != plan["move"]:
			_log("    move did not land (pos=%s) — replanning skipped" % [mech.pos])
	if plan["target"] != Vector2i(-1, -1):
		if not is_instance_valid(b) or b.finished:
			return
		if b.mode != Battle.Mode.ATTACK:
			_press_btn(b.hud._btn_attack)
			await _frames(2)
		for attempt in 3:
			_click_cell(b, plan["target"])
			await _idle(b)
			if mech.acted or b.finished or not is_instance_valid(b):
				break
			await _frames(10)
	elif plan["repair"]:
		if not is_instance_valid(b) or b.finished:
			return
		_press_btn(b.hud._btn_repair)
		await _idle(b)


# ---------- shop ----------

func _do_shop(shop: ShopScreen) -> void:
	_log("shop: rep=%d grid=%d" % [shop.run.reputation, shop.run.grid_power])
	# Greedy priorities: shore up the grid when low, weapons, damage, hp
	var wishes: Array = []
	while shop.run.grid_power + wishes.size() < 7 and wishes.size() < 3:
		wishes.append("grid_up")
	wishes.append_array(["cluster_shells", "grappling_hook", "dmg_up", "grid_up", "hp_up", "move_up", "dmg_up", "hp_up"])
	for wish in wishes:
		if shop.run.can_buy(wish):
			var item: Dictionary = shop.run.shop_item(wish)
			_press_text_prefix(shop, item["name"])
			await _frames(3)
			if item["needs_target"]:
				var target_idx := 0 if wish != "dmg_up" else 0  # prime
				shop._pick_popup.id_pressed.emit(target_idx)
				shop._pick_popup.hide()
				await _frames(3)
			_log("  bought %s (rep left %d)" % [wish, shop.run.reputation])
	await _shot("shop_m%d" % shop.run.mission_index)
	_press_text("NEXT MISSION ▶")
	await _frames(20)


# ---------- ui plumbing ----------

func _click_cell(b: Battle, cell: Vector2i) -> void:
	var pos: Vector2 = b.board.position + Iso.to_screen(cell) * b.board.scale
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	Input.parse_input_event(down)
	var up := down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _press_btn(btn: Button) -> void:
	if is_instance_valid(btn) and not btn.disabled:
		btn.pressed.emit()


func _press_text(text: String) -> void:
	var btn := _find_button(root, text, false)
	if btn != null:
		btn.pressed.emit()
	else:
		_log("button_not_found: " + text)


func _press_text_prefix(node: Node, prefix: String) -> void:
	var btn := _find_button(node, prefix, true)
	if btn != null and not btn.disabled:
		btn.pressed.emit()


func _find_button(node: Node, text: String, prefix: bool) -> Button:
	if node is Button and (node.text.begins_with(text) if prefix else node.text == text):
		return node
	for c in node.get_children():
		var r := _find_button(c, text, prefix)
		if r != null:
			return r
	return null


func _idle(b: Battle) -> void:
	await _frames(3)
	var guard := 0
	while guard < 1200:
		if not is_instance_valid(b) or not b.is_inside_tree():
			return
		if not b.board.busy:
			break
		await process_frame
		guard += 1
	await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	shot_idx += 1
	root.get_texture().get_image().save_png("%s/%02d_%s.png" % [OUT, shot_idx, name])


func _log(msg: String) -> void:
	print("AP| ", msg)


func _dist_to_nearest_vek(s: BattleState, tile: Vector2i) -> int:
	var best := 99
	for v in s.vek():
		best = mini(best, absi(v.pos.x - tile.x) + absi(v.pos.y - tile.y))
	return best
