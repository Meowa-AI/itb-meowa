extends GutTest

const UNIT_IDS := ["prime", "artillery", "science", "hornet", "firefly", "scorpion", "scarab", "hornet_leader"]
const ANIMATION_NAMES := ["idle", "attack", "hit"]


func test_every_unit_has_all_animation_sheets() -> void:
	for unit_id in UNIT_IDS:
		for animation_name in ANIMATION_NAMES:
			var path := "res://assets/sprites/animations/%s/%s.png" % [unit_id, animation_name]
			assert_true(ResourceLoader.exists(path), "%s has %s sheet" % [unit_id, animation_name])


func test_unit_sprite_starts_idle_and_exposes_action_animations() -> void:
	var s := Fixtures.blank_state()
	var u := Fixtures.add(s, "prime", Vector2i(3, 3))
	var us := UnitSprite.new()
	add_child_autofree(us)

	us.setup(u)
	assert_eq(us.current_animation(), "idle")

	us.play_attack()
	assert_eq(us.current_animation(), "attack")

	us.play_hit()
	assert_eq(us.current_animation(), "hit")
