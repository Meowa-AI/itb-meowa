class_name EnemyAI
extends RefCounted
## Deterministic vek AI: move each vek to the position whose best attack
## scores highest, then set its intent. RNG-free — ties break on a
## state-derived hash so undo/redo replays identically.


static func set_intents(s: BattleState) -> Array:
	var evs: Array = []
	var bugs := s.vek()
	bugs.sort_custom(func(a, b): return a.id < b.id)
	for vek in bugs:
		evs.append_array(_act_one(s, vek))
	return evs


static func _act_one(s: BattleState, vek: BUnit) -> Array:
	var w := vek.weapon()
	var move_tiles: Array = [vek.pos]
	move_tiles.append_array(Actions.legal_moves(s, vek))
	var spawn_tiles := {}
	for sp in s.pending_spawns:
		spawn_tiles[sp["pos"]] = true
	var best_score := -1000000
	var best: Dictionary = {}
	for tile in move_tiles:
		var move_penalty := 0
		if spawn_tiles.has(tile):
			move_penalty -= 500  # don't squat on emerging allies if avoidable
		for cand in _candidate_attacks(s, vek, tile, w):
			var score: int = cand["score"] * 100 + move_penalty - _dist_to_nearest_mech(s, tile)
			var tie: int = hash("%d|%d|%s|%s" % [s.turn, vek.id, tile, cand["target"]]) % 97
			score = score * 100 + tie
			if score > best_score:
				best_score = score
				best = {"tile": tile, "target": cand["target"], "dir": cand["dir"]}
	var evs: Array = []
	if best.is_empty():
		return evs
	if best["tile"] != vek.pos:
		var from: Vector2i = vek.pos
		vek.pos = best["tile"]
		evs.append(Ev.ev("unit_moved", {"unit_id": vek.id, "from": from, "to": vek.pos}))
	vek.intent = {"weapon_id": w.id, "target": best["target"], "dir": best["dir"]}
	evs.append(Ev.ev("telegraph_set", {
		"unit_id": vek.id, "weapon_id": w.id,
		"tiles": Telegraph.threatened_tiles(s, vek),
	}))
	return evs


static func _candidate_attacks(s: BattleState, vek: BUnit, tile: Vector2i, w: WeaponDef) -> Array:
	## Possible attacks from `tile`: [{target, dir, score}].
	var out: Array = []
	if w.sweep:
		var score := 0
		for d in Actions.DIRS:
			score += _score_tile(s, tile + d, vek)
		out.append({"target": tile, "dir": Vector2i(1, 0), "score": score})
		return out
	match w.kind:
		"melee":
			for d in Actions.DIRS:
				var p: Vector2i = tile + d
				if s.in_bounds(p):
					out.append({"target": p, "dir": d, "score": _score_tile(s, p, vek)})
		"projectile":
			for d in Actions.DIRS:
				var p: Vector2i = tile + d
				var hit := Vector2i(-1, -1)
				while s.in_bounds(p):
					# the vek itself never blocks its own shot; ignore `tile`
					if p != tile and _blocks(s, p):
						hit = p
						break
					p += d
				if hit == Vector2i(-1, -1):
					out.append({"target": tile + d, "dir": d, "score": -1})
				else:
					out.append({"target": hit, "dir": d, "score": _score_tile(s, hit, vek)})
		"artillery":
			for d in Actions.DIRS:
				var p: Vector2i = tile + d * 2
				while s.in_bounds(p):
					out.append({"target": p, "dir": d, "score": _score_tile(s, p, vek)})
					p += d
	return out


static func _blocks(s: BattleState, p: Vector2i) -> bool:
	if s.unit_at(p) != null:
		return true
	if s.buildings.has(p) and s.buildings[p]["hp"] > 0:
		return true
	return s.terrain[p] == "mountain"


static func _score_tile(s: BattleState, p: Vector2i, vek: BUnit) -> int:
	if not s.in_bounds(p):
		return 0
	var u := s.unit_at(p)
	if u != null and u != vek:
		return 3 if u.team == "mech" else -2
	if s.buildings.has(p) and s.buildings[p]["hp"] > 0:
		return 4 if s.buildings[p]["objective"] else 2
	return 0


static func _dist_to_nearest_mech(s: BattleState, tile: Vector2i) -> int:
	var best := 99
	for m in s.mechs():
		var d: int = absi(m.pos.x - tile.x) + absi(m.pos.y - tile.y)
		best = mini(best, d)
	return best
