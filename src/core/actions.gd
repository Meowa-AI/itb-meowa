class_name Actions
extends RefCounted
## Player-facing actions and shared weapon resolution.
## All do_* funcs return {ok: bool, events: Array, reason: String}.

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "events": [], "reason": reason}


static func _ok(events: Array) -> Dictionary:
	return {"ok": true, "events": events, "reason": ""}


static func legal_moves(s: BattleState, u: BUnit) -> Array:
	## BFS within u.move. Units block pathing; flying passes over terrain
	## hazards but not units/mountains/buildings; may not end on chasm.
	var frontier := [u.pos]
	var dist := {u.pos: 0}
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if dist[cur] >= u.move:
			continue
		for d in DIRS:
			var nxt: Vector2i = cur + d
			if dist.has(nxt) or not s.in_bounds(nxt):
				continue
			if s.unit_at(nxt) != null:
				continue
			# Passability while moving through:
			if s.buildings.has(nxt) and s.buildings[nxt]["hp"] > 0:
				continue
			if s.terrain[nxt] == "mountain":
				continue
			if not u.flying and s.terrain[nxt] in ["water", "chasm"]:
				continue
			dist[nxt] = dist[cur] + 1
			frontier.append(nxt)
	var result: Array = []
	for p in dist:
		if p != u.pos and s.is_walkable(p, u):
			result.append(p)
	return result


static func legal_targets(s: BattleState, u: BUnit) -> Array:
	## Tiles u's weapon may target right now: [{target, dir}].
	var w := u.weapon()
	var result: Array = []
	match w.kind:
		"melee":
			for d in DIRS:
				var p: Vector2i = u.pos + d
				if s.in_bounds(p):
					result.append({"target": p, "dir": d})
		"projectile":
			for d in DIRS:
				var p: Vector2i = u.pos + d
				while s.in_bounds(p):
					if _blocks_projectile(s, p):
						result.append({"target": p, "dir": d})
						break
					p += d
		"artillery":
			for d in DIRS:
				var p: Vector2i = u.pos + d * 2
				while s.in_bounds(p):
					result.append({"target": p, "dir": d})
					p += d
	return result


static func _blocks_projectile(s: BattleState, p: Vector2i) -> bool:
	if s.unit_at(p) != null:
		return true
	if s.buildings.has(p) and s.buildings[p]["hp"] > 0:
		return true
	return s.terrain[p] == "mountain"


static func do_move(s: BattleState, u: BUnit, to: Vector2i) -> Dictionary:
	if u.moved:
		return _fail("already moved")
	if u.acted:
		return _fail("already acted")
	if not (to in legal_moves(s, u)):
		return _fail("illegal destination")
	var from := u.pos
	u.pos = to
	u.moved = true
	return _ok([Ev.ev("unit_moved", {"unit_id": u.id, "from": from, "to": to})])


static func do_attack(s: BattleState, u: BUnit, target: Vector2i) -> Dictionary:
	if u.acted:
		return _fail("already acted")
	var dir := Vector2i.ZERO
	var found := false
	for t in legal_targets(s, u):
		if t["target"] == target:
			dir = t["dir"]
			found = true
			break
	if not found:
		return _fail("illegal target")
	u.acted = true
	var evs: Array = [Ev.ev("attack_fired", {"unit_id": u.id, "weapon_id": u.weapon_id, "origin": u.pos, "target": target})]
	evs.append_array(resolve_weapon(s, u.pos, u.weapon(), target, dir, u.weapon_damage_bonus))
	return _ok(evs)


static func do_repair(s: BattleState, u: BUnit) -> Dictionary:
	if u.acted:
		return _fail("already acted")
	if u.hp >= u.max_hp:
		return _fail("full hp")
	u.acted = true
	u.hp += 1
	return _ok([Ev.ev("unit_healed", {"unit_id": u.id, "amount": 1, "hp": u.hp})])


static func resolve_weapon(s: BattleState, origin: Vector2i, w: WeaponDef, target: Vector2i, dir: Vector2i, dmg_bonus: int) -> Array:
	## Shared by mechs and vek. Impact damage first, then displacement (ItB order).
	var evs: Array = []
	var dmg := w.damage + dmg_bonus
	evs.append_array(Push.damage_tile(s, target, dmg))
	if w.splash_adjacent:
		for d in DIRS:
			evs.append_array(Push.damage_tile(s, target + d, dmg))
	if w.push != 0:
		var push_dir := dir if w.push > 0 else -dir
		evs.append_array(Push.displace(s, target, push_dir))
	if w.push_adjacent:
		for d in DIRS:
			evs.append_array(Push.displace(s, target + d, d))
	return evs
