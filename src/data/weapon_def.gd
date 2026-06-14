class_name WeaponDef
extends RefCounted
## Static weapon definition. kind: "melee" | "projectile" | "artillery"

var id: String
var display_name: String
var kind: String
var damage: int = 0
var push: int = 0  # +1 push away from attacker, -1 pull toward, 0 none
var splash_adjacent: bool = false  # damage the 4 tiles around impact
var push_adjacent: bool = false  # push the 4 tiles around impact outward
var sweep: bool = false  # boss: hits all 4 tiles adjacent to the attacker


func _init(p: Dictionary) -> void:
	for k in p:
		set(k, p[k])
