class_name BUnit
extends RefCounted
## A unit on the battle grid (mech or vek). Pure data, no scene-tree deps.

var id: int
var def_id: String
var team: String  # "mech" | "vek"
var pos: Vector2i
var hp: int
var max_hp: int
var move: int
var flying: bool = false
var weapon_id: String = ""
var weapon_damage_bonus: int = 0
var alive: bool = true
# Per-turn flags (player units)
var moved: bool = false
var acted: bool = false
# Vek intent: {} or {weapon_id, target: Vector2i, dir: Vector2i}
var intent: Dictionary = {}


func weapon() -> WeaponDef:
	return Defs.weapon(weapon_id)


func attack_damage() -> int:
	return weapon().damage + weapon_damage_bonus


func to_dict() -> Dictionary:
	return {
		"id": id, "def_id": def_id, "team": team, "pos": pos,
		"hp": hp, "max_hp": max_hp, "move": move, "flying": flying,
		"weapon_id": weapon_id, "weapon_damage_bonus": weapon_damage_bonus,
		"alive": alive, "moved": moved, "acted": acted,
		"intent": intent.duplicate(),
	}


static func from_dict(d: Dictionary) -> BUnit:
	var u := BUnit.new()
	for k in d:
		if k == "intent":
			u.intent = d[k].duplicate()
		else:
			u.set(k, d[k])
	return u
