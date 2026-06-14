class_name RunState
extends RefCounted
## Campaign state across the 7-mission run: grid power, reputation,
## squad upgrades, shop. Mechs repair fully between missions; grid
## power never recovers.

const MAX_GRID := 10

const SHOP := [
	{"id": "grid_up", "name": "+1 Grid Power", "cost": 2, "needs_target": false, "desc": "Restore 1 grid power (max %d)" % MAX_GRID},
	{"id": "hp_up", "name": "+2 Mech HP", "cost": 2, "needs_target": true, "desc": "Pick a mech: +2 max HP"},
	{"id": "dmg_up", "name": "+1 Weapon Damage", "cost": 3, "needs_target": true, "desc": "Pick a mech: weapon deals +1 damage"},
	{"id": "move_up", "name": "+1 Movement", "cost": 2, "needs_target": true, "desc": "Pick a mech: +1 move range"},
	{"id": "grappling_hook", "name": "Grappling Hook", "cost": 4, "needs_target": false, "desc": "Science: long-range pull, 0 dmg"},
	{"id": "cluster_shells", "name": "Cluster Shells", "cost": 4, "needs_target": false, "desc": "Artillery: hits 4 adjacent, no push"},
]
const WEAPON_OWNERS := {"grappling_hook": "science", "cluster_shells": "artillery"}

var mission_index: int = 0
var grid_power: int = 8
var reputation: int = 0
var squad: Array = []
var purchased: Array = []
var game_over: bool = false
var victory: bool = false


func _init() -> void:
	for def_id in ["prime", "artillery", "science"]:
		var d: UnitDef = Defs.unit(def_id)
		squad.append({
			"def_id": def_id, "max_hp": d.max_hp, "move": d.move,
			"weapon_id": d.weapon_id, "weapon_damage_bonus": 0,
		})


func current_mission() -> MissionDef:
	return Defs.missions()[mission_index]


func start_battle() -> BattleState:
	return BattleState.from_mission(current_mission(), grid_power, squad)


func finish_battle(s: BattleState, outcome: String, bonus_kept_grid: bool) -> void:
	grid_power = s.grid_power
	match outcome:
		"won":
			reputation += 4 if bonus_kept_grid else 3
			_advance()
		"failed_protect":
			_advance()
		_:
			game_over = true


func _advance() -> void:
	mission_index += 1
	if mission_index >= Defs.missions().size():
		victory = true


func shop_item(item_id: String) -> Dictionary:
	for item in SHOP:
		if item["id"] == item_id:
			return item
	return {}


func can_buy(item_id: String) -> bool:
	var item := shop_item(item_id)
	if item.is_empty() or item_id in purchased and WEAPON_OWNERS.has(item_id):
		return false
	if item_id == "grid_up" and grid_power >= MAX_GRID:
		return false
	return reputation >= item["cost"]


func buy(item_id: String, mech_def_id: String = "") -> bool:
	if not can_buy(item_id):
		return false
	var item := shop_item(item_id)
	if item_id == "grid_up":
		grid_power = mini(grid_power + 1, MAX_GRID)
	elif item["needs_target"]:
		var entry := _squad_entry(mech_def_id)
		if entry.is_empty():
			return false
		match item_id:
			"hp_up":
				entry["max_hp"] += 2
			"dmg_up":
				entry["weapon_damage_bonus"] += 1
			"move_up":
				entry["move"] += 1
	else:
		var owner := _squad_entry(WEAPON_OWNERS[item_id])
		owner["weapon_id"] = item_id
	reputation -= item["cost"]
	purchased.append(item_id)
	return true


func _squad_entry(def_id: String) -> Dictionary:
	for entry in squad:
		if entry["def_id"] == def_id:
			return entry
	return {}
