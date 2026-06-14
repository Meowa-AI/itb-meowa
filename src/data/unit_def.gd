class_name UnitDef
extends RefCounted
## Static unit definition for mechs and vek.

var id: String
var display_name: String
var team: String  # "mech" | "vek"
var max_hp: int
var move: int
var flying: bool = false
var weapon_id: String = ""
var is_boss: bool = false


func _init(p: Dictionary) -> void:
	for k in p:
		set(k, p[k])
