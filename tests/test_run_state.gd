extends GutTest


func _won_battle(r: RunState, end_power: int) -> BattleState:
	var s := r.start_battle()
	s.grid_power = end_power
	return s


func test_initial_state():
	var r := RunState.new()
	assert_eq(r.mission_index, 0)
	assert_eq(r.grid_power, 8)
	assert_eq(r.reputation, 0)
	assert_eq(r.squad.size(), 3)
	assert_eq(r.squad[0]["def_id"], "prime")
	assert_eq(r.current_mission().id, "m1")


func test_win_grants_rep_and_advances():
	var r := RunState.new()
	r.finish_battle(_won_battle(r, 7), "won", true)
	assert_eq(r.reputation, 4)  # 3 + 1 bonus
	assert_eq(r.mission_index, 1)
	assert_eq(r.grid_power, 7)
	assert_false(r.game_over)


func test_win_without_bonus():
	var r := RunState.new()
	r.finish_battle(_won_battle(r, 5), "won", false)
	assert_eq(r.reputation, 3)
	assert_eq(r.grid_power, 5)  # battle losses persist


func test_protect_failure_advances_without_rep():
	var r := RunState.new()
	r.finish_battle(_won_battle(r, 4), "failed_protect", false)
	assert_eq(r.reputation, 0)
	assert_eq(r.mission_index, 1)
	assert_false(r.game_over)


func test_losses_end_run():
	var r := RunState.new()
	r.finish_battle(_won_battle(r, 0), "lost_grid", false)
	assert_true(r.game_over)
	var r2 := RunState.new()
	r2.finish_battle(_won_battle(r2, 3), "lost_mechs", false)
	assert_true(r2.game_over)


func test_victory_after_seven_wins():
	var r := RunState.new()
	for i in 7:
		r.finish_battle(_won_battle(r, 7), "won", false)
	assert_true(r.victory)


func test_buy_hp_upgrade():
	var r := RunState.new()
	r.reputation = 5
	assert_true(r.can_buy("hp_up"))
	assert_true(r.buy("hp_up", "prime"))
	assert_eq(r.reputation, 3)
	assert_eq(r.squad[0]["max_hp"], 6)


func test_buy_refused_when_poor():
	var r := RunState.new()
	r.reputation = 1
	assert_false(r.can_buy("dmg_up"))
	assert_false(r.buy("dmg_up", "prime"))
	assert_eq(r.reputation, 1)


func test_buy_grid_power_repeatable_capped():
	var r := RunState.new()
	r.reputation = 20
	r.grid_power = 8
	assert_true(r.buy("grid_up"))
	assert_true(r.buy("grid_up"))
	assert_eq(r.grid_power, 10)
	assert_false(r.can_buy("grid_up"))  # capped
	assert_eq(r.reputation, 16)
	r.grid_power = 3
	assert_true(r.can_buy("grid_up"))


func test_buy_weapon_swaps_and_is_one_time():
	var r := RunState.new()
	r.reputation = 8
	assert_true(r.buy("grappling_hook"))
	assert_eq(r.squad[2]["weapon_id"], "grappling_hook")  # science
	assert_false(r.can_buy("grappling_hook"))  # already purchased
	assert_true(r.buy("cluster_shells"))
	assert_eq(r.squad[1]["weapon_id"], "cluster_shells")  # artillery
	assert_eq(r.reputation, 0)


func test_upgrades_reach_next_battle():
	var r := RunState.new()
	r.reputation = 9
	r.buy("hp_up", "prime")
	r.buy("move_up", "science")
	r.buy("dmg_up", "prime")
	var s := r.start_battle()
	var prime: BUnit = s.mechs()[0]
	assert_eq(prime.max_hp, 6)
	assert_eq(prime.weapon_damage_bonus, 1)
	var science: BUnit = s.mechs()[2]
	assert_eq(science.move, 5)


func test_battle_uses_current_grid_power():
	var r := RunState.new()
	r.finish_battle(_won_battle(r, 4), "won", false)
	var s := r.start_battle()
	assert_eq(s.grid_power, 4)
	assert_eq(s.mission.id, "m2")
