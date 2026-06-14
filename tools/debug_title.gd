extends SceneTree


func _initialize() -> void:
	var t := TitleScreen.new()
	root.add_child(t)
	await process_frame
	await process_frame
	var bg: TextureRect = t.get_child(0)
	print("DBG| title size=", t.size, " bg size=", bg.size, " tex=", bg.texture, " visible=", bg.visible and t.visible)
	quit(0)
