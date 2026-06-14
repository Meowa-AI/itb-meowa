class_name Game
extends Node
## Root flow controller: Title → Battle → Shop → ... → Victory / Game Over.

var run: RunState
var _current: Node


func _ready() -> void:
	add_child(Audio.new())
	add_child(PostFx.new())
	_show_title()


func _swap(scene: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = scene
	add_child(scene)
	if scene is Control:
		# Parent is a plain Node, so anchors have nothing to fill — size explicitly.
		scene.size = get_viewport().get_visible_rect().size


func _show_title() -> void:
	run = RunState.new()
	var title := TitleScreen.new()
	title.start_run.connect(_start_battle)
	_swap(title)


func _start_battle() -> void:
	Audio.click()
	Audio.bgm(true)
	var battle := Battle.new()
	battle.run = run
	battle.battle_finished.connect(_on_battle_finished)
	_swap(battle)


func _on_battle_finished(outcome: String, bonus: bool) -> void:
	Audio.bgm(false)
	run.finish_battle(_current.state, outcome, bonus)
	if run.victory:
		_show_end("VICTORY", "All %d missions complete.\nThe vek are driven back — this timeline is saved." % Defs.missions().size(), Color(0.55, 1, 0.65))
	elif run.game_over:
		var why := "The power grid failed." if outcome == "lost_grid" else "Your squad was destroyed."
		_show_end("GAME OVER", "%s\nMissions cleared: %d of %d" % [why, run.mission_index, Defs.missions().size()], Color(1, 0.45, 0.4))
	else:
		_show_shop()


func _show_shop() -> void:
	var shop := ShopScreen.new()
	shop.run = run
	shop.next_mission.connect(_start_battle)
	_swap(shop)


func _show_end(headline: String, detail: String, color: Color) -> void:
	var end := EndScreen.new()
	end.headline = headline
	end.detail = detail
	end.color = color
	end.back_to_title.connect(_show_title)
	_swap(end)
