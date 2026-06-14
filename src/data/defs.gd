class_name Defs
extends RefCounted
## Static content registry: all weapons, units, and missions in the demo.

static var _weapons: Dictionary = {}
static var _units: Dictionary = {}
static var _missions: Array = []


static func weapon(id: String) -> WeaponDef:
	_build()
	return _weapons.get(id)


static func unit(id: String) -> UnitDef:
	_build()
	return _units.get(id)


static func missions() -> Array:
	_build()
	return _missions


static func _build() -> void:
	if not _weapons.is_empty():
		return
	for w in [
		# Mech weapons
		{"id": "titan_fist", "display_name": "Titan Fist", "kind": "melee", "damage": 2, "push": 1},
		{"id": "arc_shot", "display_name": "Arc Shot", "kind": "artillery", "damage": 1, "push_adjacent": true},
		{"id": "force_beam", "display_name": "Force Beam", "kind": "projectile", "damage": 1, "push": -1},
		# Shop weapons
		{"id": "grappling_hook", "display_name": "Grappling Hook", "kind": "projectile", "damage": 0, "push": -1},
		{"id": "cluster_shells", "display_name": "Cluster Shells", "kind": "artillery", "damage": 1, "splash_adjacent": true},
		# Vek weapons
		{"id": "stinger", "display_name": "Stinger", "kind": "melee", "damage": 1},
		{"id": "firefly_shot", "display_name": "Spit Glob", "kind": "projectile", "damage": 1},
		{"id": "scorpion_pincer", "display_name": "Pincer", "kind": "melee", "damage": 2},
		{"id": "scarab_arc", "display_name": "Lobbed Goo", "kind": "artillery", "damage": 1},
		{"id": "leader_sweep", "display_name": "Wing Sweep", "kind": "melee", "damage": 2, "sweep": true},
	]:
		_weapons[w["id"]] = WeaponDef.new(w)

	for u in [
		{"id": "prime", "display_name": "Prime Mech", "team": "mech", "max_hp": 4, "move": 3, "weapon_id": "titan_fist"},
		{"id": "artillery", "display_name": "Artillery Mech", "team": "mech", "max_hp": 3, "move": 2, "weapon_id": "arc_shot"},
		{"id": "science", "display_name": "Science Mech", "team": "mech", "max_hp": 2, "move": 4, "weapon_id": "force_beam"},
		{"id": "hornet", "display_name": "Hornet", "team": "vek", "max_hp": 2, "move": 4, "flying": true, "weapon_id": "stinger"},
		{"id": "firefly", "display_name": "Firefly", "team": "vek", "max_hp": 3, "move": 3, "weapon_id": "firefly_shot"},
		{"id": "scorpion", "display_name": "Scorpion", "team": "vek", "max_hp": 5, "move": 2, "weapon_id": "scorpion_pincer"},
		{"id": "scarab", "display_name": "Scarab", "team": "vek", "max_hp": 3, "move": 2, "weapon_id": "scarab_arc"},
		{"id": "hornet_leader", "display_name": "Hornet Leader", "team": "vek", "max_hp": 9, "move": 4, "flying": true, "weapon_id": "leader_sweep", "is_boss": true},
	]:
		_units[u["id"]] = UnitDef.new(u)

	_missions = [
		MissionDef.new({
			"id": "m1", "title": "First Contact", "objective": "kill_all",
			"map_rows": Array([
				"..B.....",
				"....M...",
				".B....~.",
				"......~.",
				"...M....",
				"......B.",
				"........",
				"........",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(1, 6), Vector2i(3, 6), Vector2i(5, 6)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "hornet", "pos": Vector2i(3, 1)},
				{"id": "hornet", "pos": Vector2i(5, 2)},
				{"id": "firefly", "pos": Vector2i(2, 3)},
			],
		}),
		MissionDef.new({
			"id": "m2", "title": "Tidal Front", "objective": "kill_all",
			"map_rows": Array([
				"~~......",
				"~....B..",
				"...M....",
				".B......",
				"......M.",
				"..~~....",
				"........",
				"....B...",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "hornet", "pos": Vector2i(1, 2)},
				{"id": "hornet", "pos": Vector2i(6, 1)},
				{"id": "firefly", "pos": Vector2i(5, 3)},
				{"id": "firefly", "pos": Vector2i(3, 4)},
			],
			"spawn_schedule": [
				{"turn": 1, "id": "hornet", "pos": Vector2i(0, 4)},
			],
		}),
		MissionDef.new({
			"id": "m3", "title": "Hold the Line", "objective": "survive", "survive_turns": 5,
			"map_rows": Array([
				"...M....",
				"B......B",
				"........",
				"..~.....",
				"........",
				"M.......",
				"........",
				"...B....",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 4), Vector2i(4, 4), Vector2i(6, 4)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "hornet", "pos": Vector2i(1, 1)},
				{"id": "firefly", "pos": Vector2i(6, 2)},
				{"id": "scorpion", "pos": Vector2i(4, 0)},
			],
			"spawn_schedule": [
				{"turn": 1, "id": "hornet", "pos": Vector2i(0, 7)},
				{"turn": 1, "id": "firefly", "pos": Vector2i(7, 6)},
				{"turn": 2, "id": "hornet", "pos": Vector2i(7, 2)},
				{"turn": 2, "id": "scorpion", "pos": Vector2i(0, 3)},
				{"turn": 3, "id": "hornet", "pos": Vector2i(4, 7)},
				{"turn": 4, "id": "firefly", "pos": Vector2i(0, 0)},
			],
		}),
		MissionDef.new({
			"id": "m4", "title": "Guard the Generator", "objective": "protect",
			"map_rows": Array([
				"........",
				"...O....",
				".B...B..",
				"........",
				"....M...",
				".~......",
				"........",
				"......~~",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 6), Vector2i(4, 6), Vector2i(5, 6)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "scorpion", "pos": Vector2i(7, 5)},
				{"id": "hornet", "pos": Vector2i(1, 4)},
			],
			"spawn_schedule": [
				{"turn": 2, "id": "hornet", "pos": Vector2i(7, 3)},
				{"turn": 3, "id": "scorpion", "pos": Vector2i(0, 2)},
				{"turn": 4, "id": "firefly", "pos": Vector2i(7, 5)},
			],
		}),
		MissionDef.new({
			"id": "m5", "title": "Broken Ridge", "objective": "kill_all",
			"map_rows": Array([
				"..M.....",
				"......B.",
				".B......",
				"....X...",
				"...XX...",
				"........",
				"M.......",
				".....B..",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "scorpion", "pos": Vector2i(3, 2)},
				{"id": "scarab", "pos": Vector2i(6, 0)},
				{"id": "firefly", "pos": Vector2i(1, 1)},
				{"id": "hornet", "pos": Vector2i(6, 4)},
			],
			"spawn_schedule": [
				{"turn": 1, "id": "scorpion", "pos": Vector2i(7, 2)},
				{"turn": 2, "id": "scarab", "pos": Vector2i(0, 4)},
				{"turn": 3, "id": "hornet", "pos": Vector2i(4, 7)},
			],
		}),
		MissionDef.new({
			"id": "m6", "title": "Last Light", "objective": "survive", "survive_turns": 6,
			"map_rows": Array([
				".B....B.",
				"........",
				"...M....",
				"~.......",
				"......~.",
				"..B.....",
				"........",
				"....M...",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 6), Vector2i(4, 6), Vector2i(6, 6)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "scorpion", "pos": Vector2i(2, 1)},
				{"id": "scarab", "pos": Vector2i(6, 1)},
				{"id": "hornet", "pos": Vector2i(4, 3)},
			],
			"spawn_schedule": [
				{"turn": 1, "id": "hornet", "pos": Vector2i(0, 1)},
				{"turn": 1, "id": "firefly", "pos": Vector2i(7, 5)},
				{"turn": 2, "id": "scorpion", "pos": Vector2i(0, 5)},
				{"turn": 3, "id": "scarab", "pos": Vector2i(7, 2)},
				{"turn": 4, "id": "hornet", "pos": Vector2i(3, 1)},
				{"turn": 5, "id": "firefly", "pos": Vector2i(5, 4)},
			],
		}),
		MissionDef.new({
			"id": "m7", "title": "The Nest", "objective": "kill_all",
			"map_rows": Array([
				"...XX...",
				".B......",
				"........",
				"M......M",
				"........",
				"......B.",
				"..~.....",
				"........",
			], TYPE_STRING, "", null),
			"mech_spawns": Array([Vector2i(2, 7), Vector2i(4, 7), Vector2i(6, 7)], TYPE_VECTOR2I, "", null),
			"initial_vek": [
				{"id": "hornet_leader", "pos": Vector2i(4, 1)},
				{"id": "hornet", "pos": Vector2i(2, 2)},
				{"id": "hornet", "pos": Vector2i(6, 2)},
			],
			"spawn_schedule": [
				{"turn": 2, "id": "firefly", "pos": Vector2i(0, 4)},
				{"turn": 3, "id": "scorpion", "pos": Vector2i(7, 4)},
			],
		}),
	]
