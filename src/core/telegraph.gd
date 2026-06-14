class_name Telegraph
extends RefCounted
## Vek attack intents. An intent is {weapon_id, target: Vector2i, dir: Vector2i}
## fixed at telegraph time. Execution recomputes from the vek's CURRENT
## position — pushing a vek moves its attack with it (melee/projectile),
## while artillery stays aimed at the absolute target tile.


static func threatened_tiles(s: BattleState, vek: BUnit) -> Array:
	## Tiles this vek's intent currently threatens (for display and AI).
	if vek.intent.is_empty():
		return []
	var w: WeaponDef = Defs.weapon(vek.intent["weapon_id"])
	var dir: Vector2i = vek.intent["dir"]
	if w.sweep:
		return Actions.DIRS.map(func(d): return vek.pos + d)
	match w.kind:
		"melee":
			return [vek.pos + dir]
		"projectile":
			var hit := _projectile_hit(s, vek, dir)
			return [hit] if hit != Vector2i(-1, -1) else []
		"artillery":
			return [vek.intent["target"]]
	return []


static func execute_all(s: BattleState) -> Array:
	## Resolve every living vek's intent in unit-id order; clears intents.
	var evs: Array = []
	var attackers := s.vek().filter(func(u): return not u.intent.is_empty())
	attackers.sort_custom(func(a, b): return a.id < b.id)
	for vek in attackers:
		if not vek.alive:  # may die mid-phase (e.g. pushed by friendly fire)
			continue
		evs.append_array(_execute_one(s, vek))
	for u in s.units:
		u.intent = {}
	return evs


static func _execute_one(s: BattleState, vek: BUnit) -> Array:
	var w: WeaponDef = Defs.weapon(vek.intent["weapon_id"])
	var dir: Vector2i = vek.intent["dir"]
	var evs: Array = []
	if w.sweep:
		evs.append(Ev.ev("attack_fired", {"unit_id": vek.id, "weapon_id": w.id, "origin": vek.pos, "target": vek.pos}))
		for d in Actions.DIRS:
			evs.append_array(Push.damage_tile(s, vek.pos + d, w.damage))
		return evs
	var target := Vector2i(-1, -1)
	match w.kind:
		"melee":
			target = vek.pos + dir
		"projectile":
			target = _projectile_hit(s, vek, dir)
		"artillery":
			target = vek.intent["target"]
	if target == Vector2i(-1, -1) or not s.in_bounds(target):
		return evs  # projectile flew off the map
	evs.append(Ev.ev("attack_fired", {"unit_id": vek.id, "weapon_id": w.id, "origin": vek.pos, "target": target}))
	evs.append_array(Actions.resolve_weapon(s, vek.pos, w, target, dir, 0))
	return evs


static func _projectile_hit(s: BattleState, vek: BUnit, dir: Vector2i) -> Vector2i:
	var p := vek.pos + dir
	while s.in_bounds(p):
		if Actions._blocks_projectile(s, p):
			return p
		p += dir
	return Vector2i(-1, -1)
