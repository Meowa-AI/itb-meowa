extends SceneTree
## Screenshot helper for static screens (title / shop / end) after their
## entrance animations settle. Saves to /tmp/itb_screens.
## Run: godot --path . --resolution 1280x720 -s tools/screen_check.gd

const OUT := "/tmp/itb_screens"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run()


func _run() -> void:
	var post_fx := PostFx.new()
	root.add_child(post_fx)

	var title := TitleScreen.new()
	await _capture(title, "title")

	var run_state := RunState.new()
	run_state.reputation = 5
	var shop := ShopScreen.new()
	shop.run = run_state
	await _capture(shop, "shop")

	var end := EndScreen.new()
	end.headline = "GAME OVER"
	end.detail = "The power grid failed.\nMissions cleared: 1 of 7"
	end.color = Color(1, 0.45, 0.4)
	await _capture(end, "game_over")

	var win := EndScreen.new()
	win.headline = "VICTORY"
	win.detail = "All 7 missions complete.\nThe vek are driven back — this timeline is saved."
	win.color = Color(0.55, 1, 0.65)
	await _capture(win, "victory")

	quit(0)


func _capture(screen: Control, name: String) -> void:
	root.add_child(screen)
	screen.size = root.get_visible_rect().size
	# Entrance tweens are time-based and headless rendering is uncapped,
	# so wait wall-clock time rather than frames.
	await create_timer(1.6).timeout
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
	screen.queue_free()
	await process_frame
