extends GutTest

const RIGHT := Vector2i(1, 0)
const LEFT := Vector2i(-1, 0)
const DOWN := Vector2i(0, 1)


func _set_intent(vek: BUnit, weapon_id: String, target: Vector2i, dir: Vector2i) -> void:
	vek.intent = {"weapon_id": weapon_id, "target": target, "dir": dir}


func test_melee_intent_follows_pushed_vek():
	# Vek at (3,3) telegraphs melee to the right -> threatens (4,3).
	# Push the vek down: origin moves with it, attack now hits (4,4).
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	_set_intent(bug, "scorpion_pincer", Vector2i(4, 3), RIGHT)
	var victim := Fixtures.add(s, "prime", Vector2i(4, 4))
	Push.displace(s, Vector2i(3, 3), DOWN)
	var evs := Telegraph.execute_all(s)
	assert_eq(victim.hp, 2)  # pincer 2 dmg landed on (4,4)
	assert_true("attack_fired" in evs.map(func(e): return e["type"]))


func test_artillery_intent_stays_on_tile():
	# Scarab aims at absolute tile; pushing the scarab does not move the impact.
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "scarab", Vector2i(3, 3))
	_set_intent(bug, "scarab_arc", Vector2i(3, 6), DOWN)
	var victim := Fixtures.add(s, "prime", Vector2i(3, 6))
	Push.displace(s, Vector2i(3, 3), RIGHT)
	Telegraph.execute_all(s)
	assert_eq(victim.hp, 3)


func test_victim_moved_attack_hits_tile_anyway():
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	_set_intent(bug, "scorpion_pincer", Vector2i(4, 3), RIGHT)
	var mech := Fixtures.add(s, "prime", Vector2i(4, 3))
	mech.pos = Vector2i(4, 4)  # mech stepped away
	var other := Fixtures.add(s, "firefly", Vector2i(4, 3))  # another vek now there
	Telegraph.execute_all(s)
	assert_eq(mech.hp, 4)    # untouched
	assert_eq(other.hp, 1)   # friendly fire — hits whatever is on the tile


func test_projectile_intent_fires_from_current_pos():
	# Firefly telegraphs a shot to the right; pull it left — the projectile
	# still flies right from its NEW position and hits the first blocker.
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "firefly", Vector2i(3, 3))
	_set_intent(bug, "firefly_shot", Vector2i(6, 3), RIGHT)
	var mech := Fixtures.add(s, "prime", Vector2i(5, 3))
	Push.displace(s, Vector2i(3, 3), LEFT)
	Telegraph.execute_all(s)
	assert_eq(mech.hp, 3)  # still first in line


func test_dead_vek_does_not_attack():
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	_set_intent(bug, "scorpion_pincer", Vector2i(4, 3), RIGHT)
	var mech := Fixtures.add(s, "prime", Vector2i(4, 3))
	Push.damage_unit(s, bug, 99)
	Telegraph.execute_all(s)
	assert_eq(mech.hp, 4)


func test_leader_sweep_hits_all_adjacent():
	var s := Fixtures.blank_state()
	var boss := Fixtures.add(s, "hornet_leader", Vector2i(3, 3))
	_set_intent(boss, "leader_sweep", Vector2i(3, 3), RIGHT)
	var a := Fixtures.add(s, "prime", Vector2i(4, 3))
	var b := Fixtures.add(s, "science", Vector2i(3, 2))
	Telegraph.execute_all(s)
	assert_eq(a.hp, 2)
	assert_eq(b.hp, 0)
	assert_false(b.alive)


func test_threatened_tiles_for_view():
	var s := Fixtures.blank_state()
	var bug := Fixtures.add(s, "scorpion", Vector2i(3, 3))
	_set_intent(bug, "scorpion_pincer", Vector2i(4, 3), RIGHT)
	assert_eq(Telegraph.threatened_tiles(s, bug), [Vector2i(4, 3)])
	var boss := Fixtures.add(s, "hornet_leader", Vector2i(6, 6))
	_set_intent(boss, "leader_sweep", Vector2i(6, 6), RIGHT)
	assert_eq(Telegraph.threatened_tiles(s, boss).size(), 4)
