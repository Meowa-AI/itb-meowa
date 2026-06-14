extends GutTest


func _collect_texture_rects(n: Node, out: Array) -> void:
	if n is TextureRect:
		out.append(n)
	for c in n.get_children():
		_collect_texture_rects(c, out)


func _collect_button_holders(n: Node, out: Array) -> void:
	if n is Control and n.has_meta("hud_button_holder"):
		out.append(n)
	for c in n.get_children():
		_collect_button_holders(c, out)


func test_hud_uses_fit_ui_assets_and_keep_aspect() -> void:
	assert_true(Hud.ui_asset_path("35_button_command_wide_blank.png").contains("/game_ready_fit/"))
	assert_false(Hud.ui_asset_path("35_button_command_wide_blank.png").contains("/game_ready_exact/"))
	assert_true(ResourceLoader.exists(Hud.ui_asset_path("35_button_command_wide_blank.png")))
	assert_true(Hud.icon_asset_path("24_icon_move_arrows.png").contains("/icons_mapped/"))
	assert_true(ResourceLoader.exists(Hud.icon_asset_path("24_icon_move_arrows.png")))

	var hud := Hud.new()
	add_child_autofree(hud)
	await get_tree().process_frame

	var texture_rects := []
	_collect_texture_rects(hud, texture_rects)
	var fit_asset_count := 0
	for rect: TextureRect in texture_rects:
		if rect.has_meta("hud_fit_asset"):
			fit_asset_count += 1
			assert_eq(rect.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
			assert_eq(rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
		if rect.has_meta("hud_icon_asset"):
			assert_eq(rect.texture.get_size(), Vector2(32, 32))
			assert_eq(rect.expand_mode, TextureRect.EXPAND_IGNORE_SIZE)
			assert_eq(rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	assert_gt(fit_asset_count, 0)

	var button_holders := []
	_collect_button_holders(hud, button_holders)
	assert_eq(button_holders.size(), 5)
	var first_height := (button_holders[0] as Control).size.y
	var first_y := (button_holders[0] as Control).position.y
	for holder: Control in button_holders:
		assert_eq(holder.size.y, first_height)
		assert_eq(holder.position.y, first_y)
