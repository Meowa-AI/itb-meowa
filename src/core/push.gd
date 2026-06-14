class_name Push
extends RefCounted
## Damage and displacement rules. All funcs mutate the state and return events.


static func damage_tile(s: BattleState, pos: Vector2i, amount: int) -> Array:
	## Damage whatever occupies pos: unit, building, or mountain.
	if amount <= 0 or not s.in_bounds(pos):
		return []
	var u := s.unit_at(pos)
	if u != null:
		return damage_unit(s, u, amount)
	if s.buildings.has(pos) and s.buildings[pos]["hp"] > 0:
		return _damage_building(s, pos, amount)
	if s.terrain[pos] == "mountain":
		return _damage_mountain(s, pos)
	return []


static func damage_unit(s: BattleState, u: BUnit, amount: int) -> Array:
	u.hp -= amount
	var evs := [Ev.ev("unit_damaged", {"unit_id": u.id, "amount": amount, "hp": u.hp})]
	if u.hp <= 0:
		evs.append_array(kill_unit(s, u, "damage"))
	return evs


static func kill_unit(s: BattleState, u: BUnit, cause: String) -> Array:
	u.alive = false
	u.hp = 0
	u.intent = {}
	return [Ev.ev("unit_died", {"unit_id": u.id, "pos": u.pos, "cause": cause})]


static func displace(s: BattleState, pos: Vector2i, dir: Vector2i) -> Array:
	## Push the unit at pos one tile in dir (cardinal). No-op if tile is empty.
	var u := s.unit_at(pos)
	if u == null:
		return []
	var dest := pos + dir
	var evs: Array = []
	# Map edge: blocked, bump damage
	if not s.in_bounds(dest):
		evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": pos}))
		evs.append_array(damage_unit(s, u, 1))
		return evs
	# Occupied by another unit: both take 1, no move
	var other := s.unit_at(dest)
	if other != null:
		evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": pos}))
		evs.append_array(damage_unit(s, u, 1))
		evs.append_array(damage_unit(s, other, 1))
		return evs
	# Building: 1 dmg each side, no move
	if s.buildings.has(dest) and s.buildings[dest]["hp"] > 0:
		evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": pos}))
		evs.append_array(damage_unit(s, u, 1))
		evs.append_array(_damage_building(s, dest, 1))
		return evs
	match s.terrain[dest]:
		"mountain":
			evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": pos}))
			evs.append_array(damage_unit(s, u, 1))
			evs.append_array(_damage_mountain(s, dest))
		"water":
			u.pos = dest
			evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": dest}))
			if not u.flying:
				evs.append_array(kill_unit(s, u, "water"))
		"chasm":
			u.pos = dest
			evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": dest}))
			if not u.flying:
				evs.append_array(kill_unit(s, u, "chasm"))
		_:
			u.pos = dest
			evs.append(Ev.ev("unit_pushed", {"unit_id": u.id, "from": pos, "to": dest}))
	return evs


static func _damage_building(s: BattleState, pos: Vector2i, amount: int) -> Array:
	var b: Dictionary = s.buildings[pos]
	var lost: int = mini(amount, b["hp"])
	b["hp"] -= lost
	s.grid_power = maxi(0, s.grid_power - lost)
	var evs := [
		Ev.ev("building_damaged", {"pos": pos, "amount": lost, "hp": b["hp"]}),
		Ev.ev("grid_power_changed", {"amount": -lost, "value": s.grid_power}),
	]
	if b["hp"] <= 0:
		s.terrain[pos] = "rubble"
		evs.append(Ev.ev("building_destroyed", {"pos": pos}))
	return evs


static func _damage_mountain(s: BattleState, pos: Vector2i) -> Array:
	## Mountains take 1 damage per hit regardless of amount.
	s.mountain_hp[pos] -= 1
	if s.mountain_hp[pos] <= 0:
		s.terrain[pos] = "rubble"
		s.mountain_hp.erase(pos)
		return [Ev.ev("mountain_damaged", {"pos": pos, "hp": 0})]
	return [Ev.ev("mountain_damaged", {"pos": pos, "hp": s.mountain_hp[pos]})]
