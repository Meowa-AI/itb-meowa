class_name MissionDef
extends RefCounted
## Static mission definition.
## map_rows: 8 strings of 8 chars —
##   . plain, ~ water, M mountain, X chasm,
##   B building (2 hp), b building (1 hp), O objective structure (3 hp)
## spawn_schedule entries: {turn, id, pos} — tile telegraphed on `turn`,
## resolves at the start of the enemy phase of turn+1.

var id: String
var title: String
var objective: String  # "kill_all" | "survive" | "protect"
var survive_turns: int = 0
var map_rows: Array[String] = []
var mech_spawns: Array[Vector2i] = []
var initial_vek: Array = []  # [{id: String, pos: Vector2i}]
var spawn_schedule: Array = []  # [{turn: int, id: String, pos: Vector2i}]


func _init(p: Dictionary) -> void:
	for k in p:
		set(k, p[k])
