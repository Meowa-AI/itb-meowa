class_name BattleState
extends RefCounted
## Full battle state: terrain, buildings, units, grid power, spawn queue.
## Pure logic — the view never mutates this directly.

const SIZE := 8

var terrain: Dictionary = {}  # Vector2i -> "plain"|"water"|"mountain"|"rubble"|"chasm"
var mountain_hp: Dictionary = {}  # Vector2i -> int
var buildings: Dictionary = {}  # Vector2i -> {hp, max_hp, objective: bool}
var units: Array = []  # of BUnit (alive and dead)
var grid_power: int = 7
var turn: int = 1
var pending_spawns: Array = []  # [{def_id, pos: Vector2i}] resolving next enemy phase
var spawn_queue: Array = []  # remaining schedule entries {turn, id, pos}
var mission: MissionDef
var next_unit_id: int = 1
# Outcome flags
var protect_failed: bool = false
var survive_completed: bool = false


static func from_mission(m: MissionDef, power: int, squad_overrides: Array) -> BattleState:
	var s := BattleState.new()
	s.mission = m
	s.grid_power = power
	s.spawn_queue = m.spawn_schedule.duplicate(true)
	for y in SIZE:
		for x in SIZE:
			var p := Vector2i(x, y)
			var c := m.map_rows[y][x]
			match c:
				"~":
					s.terrain[p] = "water"
				"M":
					s.terrain[p] = "mountain"
					s.mountain_hp[p] = 2
				"X":
					s.terrain[p] = "chasm"
				"B":
					s.terrain[p] = "plain"
					s.buildings[p] = {"hp": 2, "max_hp": 2, "objective": false}
				"b":
					s.terrain[p] = "plain"
					s.buildings[p] = {"hp": 1, "max_hp": 1, "objective": false}
				"O":
					s.terrain[p] = "plain"
					s.buildings[p] = {"hp": 4, "max_hp": 4, "objective": true}
				_:
					s.terrain[p] = "plain"
	var squad := squad_overrides
	if squad.is_empty():
		squad = []
		for def_id in ["prime", "artillery", "science"]:
			var d: UnitDef = Defs.unit(def_id)
			squad.append({
				"def_id": def_id, "max_hp": d.max_hp, "move": d.move,
				"weapon_id": d.weapon_id, "weapon_damage_bonus": 0,
			})
	for i in m.mech_spawns.size():
		var entry: Dictionary = squad[i]
		var d: UnitDef = Defs.unit(entry["def_id"])
		var u := s._make_unit(d, m.mech_spawns[i])
		u.max_hp = entry["max_hp"]
		u.hp = u.max_hp
		u.move = entry["move"]
		u.weapon_id = entry["weapon_id"]
		u.weapon_damage_bonus = entry["weapon_damage_bonus"]
	for v in m.initial_vek:
		s._make_unit(Defs.unit(v["id"]), v["pos"])
	return s


func _make_unit(d: UnitDef, p: Vector2i) -> BUnit:
	var u := BUnit.new()
	u.id = next_unit_id
	next_unit_id += 1
	u.def_id = d.id
	u.team = d.team
	u.pos = p
	u.max_hp = d.max_hp
	u.hp = d.max_hp
	u.move = d.move
	u.flying = d.flying
	u.weapon_id = d.weapon_id
	units.append(u)
	return u


func spawn_unit(def_id: String, p: Vector2i) -> BUnit:
	return _make_unit(Defs.unit(def_id), p)


func unit_by_id(uid: int) -> BUnit:
	for u in units:
		if u.id == uid:
			return u
	return null


func unit_at(p: Vector2i) -> BUnit:
	for u in units:
		if u.alive and u.pos == p:
			return u
	return null


func mechs() -> Array:
	return units.filter(func(u): return u.team == "mech" and u.alive)


func vek() -> Array:
	return units.filter(func(u): return u.team == "vek" and u.alive)


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < SIZE and p.y >= 0 and p.y < SIZE


func is_walkable(p: Vector2i, u: BUnit) -> bool:
	## May `u` legally occupy tile p (ignoring other units)?
	if not in_bounds(p):
		return false
	if buildings.has(p) and buildings[p]["hp"] > 0:
		return false
	match terrain[p]:
		"mountain":
			return false
		"chasm":
			return false  # nothing may END on a chasm (flying could hover but disallow for simplicity)
		"water":
			return u.flying
		_:
			return true


func snapshot() -> Dictionary:
	return {
		"terrain": terrain.duplicate(),
		"mountain_hp": mountain_hp.duplicate(),
		"buildings": buildings.duplicate(true),
		"units": units.map(func(u): return u.to_dict()),
		"grid_power": grid_power,
		"turn": turn,
		"pending_spawns": pending_spawns.duplicate(true),
		"spawn_queue": spawn_queue.duplicate(true),
		"next_unit_id": next_unit_id,
		"protect_failed": protect_failed,
		"survive_completed": survive_completed,
	}


func restore(snap: Dictionary) -> void:
	terrain = snap["terrain"].duplicate()
	mountain_hp = snap["mountain_hp"].duplicate()
	buildings = snap["buildings"].duplicate(true)
	units = snap["units"].map(func(d): return BUnit.from_dict(d))
	grid_power = snap["grid_power"]
	turn = snap["turn"]
	pending_spawns = snap["pending_spawns"].duplicate(true)
	spawn_queue = snap["spawn_queue"].duplicate(true)
	next_unit_id = snap["next_unit_id"]
	protect_failed = snap["protect_failed"]
	survive_completed = snap["survive_completed"]


func clone() -> BattleState:
	var c := BattleState.new()
	c.mission = mission
	c.restore(snapshot())
	return c
