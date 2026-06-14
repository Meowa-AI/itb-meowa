extends SceneTree
## Renders mission 1 with the debug lattice enabled and saves screenshots.
## Run: Godot --path . --resolution 1280x720 -s tools/grid_check.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/itb_grid")
	var game: Game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_run(game)


func _run(game: Game) -> void:
	await _frames(10)
	_find_button(root, "START RUN").pressed.emit()
	await _frames(40)
	var battle: Battle = game._current
	while battle.board.busy:
		await process_frame
	battle.board.show_grid = true
	battle.board.redraw_overlays()
	await _frames(5)
	root.get_texture().get_image().save_png("/tmp/itb_grid/grid_on.png")
	battle.board.show_grid = false
	battle.board.redraw_overlays()
	await _frames(5)
	root.get_texture().get_image().save_png("/tmp/itb_grid/grid_off.png")
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var r := _find_button(c, text)
		if r != null:
			return r
	return null
