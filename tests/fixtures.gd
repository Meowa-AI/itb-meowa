class_name Fixtures
extends RefCounted
## Test helpers: hand-built battle states.


static func blank_state() -> BattleState:
	## 8x8 all-plain board, no units, grid power 7.
	var s := BattleState.new()
	for y in BattleState.SIZE:
		for x in BattleState.SIZE:
			s.terrain[Vector2i(x, y)] = "plain"
	return s


static func add(s: BattleState, def_id: String, pos: Vector2i) -> BUnit:
	return s.spawn_unit(def_id, pos)


static func set_terrain(s: BattleState, pos: Vector2i, kind: String) -> void:
	s.terrain[pos] = kind
	if kind == "mountain":
		s.mountain_hp[pos] = 2


static func add_building(s: BattleState, pos: Vector2i, hp: int = 2, objective: bool = false) -> void:
	s.buildings[pos] = {"hp": hp, "max_hp": hp, "objective": objective}
