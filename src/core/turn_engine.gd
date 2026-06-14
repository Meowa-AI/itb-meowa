class_name TurnEngine
extends RefCounted
## Orchestrates the battle loop. The view calls start_battle once, then
## end_player_turn after each player turn, replaying the returned events.


static func start_battle(s: BattleState) -> Array:
	## Initial enemy telegraphs (no attacks on turn 1).
	return EnemyAI.set_intents(s)


static func end_player_turn(s: BattleState) -> Array:
	## Full enemy phase: execute intents → spawns → move & telegraph.
	var evs: Array = []
	# 1. Vek execute last turn's telegraphed attacks
	evs.append_array(Telegraph.execute_all(s))
	evs.append_array(_apply_protect_failure(s))
	# 2. Spawn resolution, then telegraph this turn's scheduled tiles
	evs.append_array(_resolve_spawns(s))
	# 3. Survive missions complete after the enemy phase of turn N
	if s.mission.objective == "survive" and s.turn >= s.mission.survive_turns:
		s.survive_completed = true
	# 4. Remaining vek move and telegraph (skip if battle is decided)
	if check_outcome(s) == "":
		evs.append_array(EnemyAI.set_intents(s))
	# 5. Reset mech turn flags, advance turn
	for m in s.mechs():
		m.moved = false
		m.acted = false
	s.turn += 1
	var outcome := check_outcome(s)
	if outcome == "won":
		evs.append(Ev.ev("mission_won"))
	elif outcome == "lost_grid":
		evs.append(Ev.ev("mission_failed", {"reason": "grid"}))
	elif outcome == "lost_mechs":
		evs.append(Ev.ev("mission_failed", {"reason": "mechs"}))
	return evs


static func check_outcome(s: BattleState) -> String:
	## "" while the battle continues.
	if s.grid_power <= 0:
		return "lost_grid"
	if s.mechs().is_empty():
		return "lost_mechs"
	if s.protect_failed:
		return "failed_protect"
	match s.mission.objective:
		"survive":
			if s.survive_completed:
				return "won"
		_:  # kill_all and protect both end by clearing the vek out
			if s.vek().is_empty() and s.pending_spawns.is_empty() and s.spawn_queue.is_empty():
				return "won"
	return ""


static func apply_protect_failure(s: BattleState) -> Array:
	## Public for the view: call after player actions too (friendly fire).
	return _apply_protect_failure(s)


static func _apply_protect_failure(s: BattleState) -> Array:
	if s.protect_failed or s.mission.objective != "protect":
		return []
	for pos in s.buildings:
		var b: Dictionary = s.buildings[pos]
		if b["objective"] and b["hp"] <= 0:
			s.protect_failed = true
			s.grid_power = maxi(0, s.grid_power - 2)
			return [
				Ev.ev("grid_power_changed", {"amount": -2, "value": s.grid_power}),
				Ev.ev("mission_failed", {"reason": "protect"}),
			]
	return []


static func _resolve_spawns(s: BattleState) -> Array:
	var evs: Array = []
	var still_pending: Array = []
	for sp in s.pending_spawns:
		var blocker := s.unit_at(sp["pos"])
		if blocker != null:
			evs.append(Ev.ev("spawn_blocked", {"pos": sp["pos"], "blocker_id": blocker.id}))
			evs.append_array(Push.damage_unit(s, blocker, 1))
			still_pending.append(sp)  # retries next turn
		else:
			var u: BUnit = s.spawn_unit(sp["def_id"], sp["pos"])
			evs.append(Ev.ev("vek_spawned", {"unit_id": u.id, "def_id": u.def_id, "pos": u.pos}))
	s.pending_spawns = still_pending
	var remaining: Array = []
	for entry in s.spawn_queue:
		if entry["turn"] == s.turn:
			s.pending_spawns.append({"def_id": entry["id"], "pos": entry["pos"]})
			evs.append(Ev.ev("spawn_telegraphed", {"pos": entry["pos"], "def_id": entry["id"]}))
		else:
			remaining.append(entry)
	s.spawn_queue = remaining
	return evs
