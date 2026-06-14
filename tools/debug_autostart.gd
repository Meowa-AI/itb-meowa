extends SceneTree


func _initialize() -> void:
	var game: Game = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	_run(game)


func _run(game: Game) -> void:
	for i in 120:
		await process_frame
	print("DBG| current_scene=", game._current.get_class(), " script=", game._current.get_script().resource_path)
	quit(0)
