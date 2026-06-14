class_name Ev
extends RefCounted
## Event constructor. Events are plain Dictionaries with a "type" key.
## Types used by the core:
##   unit_moved {unit_id, from, to, path}
##   unit_pushed {unit_id, from, to}        (to == from means blocked)
##   unit_damaged {unit_id, amount, hp}
##   unit_healed {unit_id, amount, hp}
##   unit_died {unit_id, pos, cause}        cause: "damage"|"water"|"chasm"
##   building_damaged {pos, amount, hp}
##   building_destroyed {pos}
##   mountain_damaged {pos, hp}             hp 0 means it became rubble
##   attack_fired {unit_id, weapon_id, origin, target}
##   vek_spawned {unit_id, def_id, pos}
##   spawn_blocked {pos, blocker_id}
##   spawn_telegraphed {pos, def_id}
##   telegraph_set {unit_id, weapon_id, tiles}   tiles the attack threatens
##   grid_power_changed {amount, value}
##   mission_won {}
##   mission_failed {reason}                reason: "protect"|"grid"|"mechs"


static func ev(type: String, data: Dictionary = {}) -> Dictionary:
	var d := data.duplicate()
	d["type"] = type
	return d
