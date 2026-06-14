class_name Battle
extends Node2D
## Battle scene controller: owns the BattleState, wires board + HUD,
## runs the input FSM, and reports the outcome upward.

signal battle_finished(outcome: String, bonus_kept_grid: bool)

enum Mode { IDLE, MOVE, ATTACK }

const BOARD_START_POSITION := Vector2(640, 150)
const BOARD_SCALE := Vector2(2, 2)

var run: RunState
var state: BattleState
var board: BoardView
var hud: Hud
var turn_snapshot: Dictionary
var start_power: int
var selected: BUnit = null
var mode: Mode = Mode.IDLE
var finished := false
var _dragging_board := false


func _ready() -> void:
	if run == null:  # standalone scene launch (debugging)
		run = RunState.new()
	state = run.start_battle()
	start_power = state.grid_power

	add_child(BattleBackdrop.new())
	_create_board()
	_create_hud()


	var evs := TurnEngine.start_battle(state)
	await board.play_events(evs)
	turn_snapshot = state.snapshot()
	hud.show_banner("%s — %s" % [state.mission.id.to_upper(), state.mission.title])
	get_tree().create_timer(1.4).timeout.connect(hud.hide_banner)
	_refresh_hud()


func _create_board() -> void:
	board = BoardView.new()
	board.position = BOARD_START_POSITION
	board.scale = BOARD_SCALE
	add_child(board)
	board.setup(state)
	board.tile_clicked.connect(_on_tile_clicked)
	board.tile_hovered.connect(_on_tile_hovered)
	board.playback_done.connect(_refresh_hud)
	board.event_played.connect(Audio.play_for_event)


func _create_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.move_pressed.connect(func(): _set_mode(Mode.MOVE))
	hud.attack_pressed.connect(func(): _set_mode(Mode.ATTACK))
	hud.repair_pressed.connect(_on_repair)
	hud.undo_pressed.connect(_on_undo)
	hud.end_turn_pressed.connect(_on_end_turn)


func _unhandled_input(event: InputEvent) -> void:
	if board == null:
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging_board = button.pressed
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging_board:
		board.position = (board.position + motion.relative).round()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _refresh_hud() -> void:
	if selected != null and (not selected.alive):
		selected = null
	hud.update_from(state, selected, board.busy)


func _set_mode(m: Mode) -> void:
	if selected == null or board.busy:
		return
	mode = m
	board.preview_events = []
	match m:
		Mode.MOVE:
			board.move_overlay = Actions.legal_moves(state, selected)
			board.target_overlay = []
		Mode.ATTACK:
			board.move_overlay = []
			board.target_overlay = Actions.legal_targets(state, selected).map(func(t): return t["target"])
		Mode.IDLE:
			board.move_overlay = []
			board.target_overlay = []
	board.redraw_overlays()


func _select(u: BUnit) -> void:
	selected = u
	board.selected_cell = u.pos
	# Default affordance: show move range if the mech can still move
	if not u.moved and not u.acted:
		_set_mode(Mode.MOVE)
	elif not u.acted:
		_set_mode(Mode.ATTACK)
	else:
		_set_mode(Mode.IDLE)
	_refresh_hud()


func _deselect() -> void:
	selected = null
	mode = Mode.IDLE
	board.clear_overlays()
	_refresh_hud()


func _on_tile_clicked(cell: Vector2i) -> void:
	if board.busy or finished:
		return
	var u := state.unit_at(cell)
	match mode:
		Mode.MOVE:
			if cell in board.move_overlay:
				var r := Actions.do_move(state, selected, cell)
				if r["ok"]:
					await _play_and_check(r["events"])
					if selected != null:
						board.selected_cell = selected.pos
						_set_mode(Mode.ATTACK if not selected.acted else Mode.IDLE)
				return
			_click_select_or_clear(u)
		Mode.ATTACK:
			if cell in board.target_overlay:
				var r := Actions.do_attack(state, selected, cell)
				if r["ok"]:
					var evs: Array = r["events"]
					evs.append_array(TurnEngine.apply_protect_failure(state))
					await _play_and_check(evs)
					_deselect()
				return
			_click_select_or_clear(u)
		Mode.IDLE:
			_click_select_or_clear(u)


func _click_select_or_clear(u: BUnit) -> void:
	if u != null and u.team == "mech":
		_select(u)
	else:
		_deselect()


func _on_tile_hovered(cell: Vector2i) -> void:
	if mode == Mode.ATTACK and selected != null and not board.busy:
		if cell in board.target_overlay:
			board.preview_events = Preview.preview_attack(state, selected, cell)
		else:
			board.preview_events = []
		board.redraw_overlays()


func _on_repair() -> void:
	if selected == null or board.busy:
		return
	var r := Actions.do_repair(state, selected)
	if r["ok"]:
		await _play_and_check(r["events"])
		_deselect()


func _on_undo() -> void:
	if board.busy or finished:
		return
	state.restore(turn_snapshot)
	selected = null
	mode = Mode.IDLE
	board.clear_overlays()
	board.refresh()
	_refresh_hud()


func _on_end_turn() -> void:
	if board.busy or finished:
		return
	_deselect()
	var evs := TurnEngine.end_player_turn(state)
	await _play_and_check(evs)
	turn_snapshot = state.snapshot()


func _play_and_check(events: Array) -> void:
	await board.play_events(events)
	_refresh_hud()
	var outcome := TurnEngine.check_outcome(state)
	if outcome != "" and not finished:
		finished = true
		var bonus := state.grid_power >= start_power
		match outcome:
			"won":
				hud.show_banner("MISSION COMPLETE", Color(0.5, 1, 0.6))
			"failed_protect":
				hud.show_banner("OBJECTIVE LOST", Color(1, 0.7, 0.3))
			_:
				hud.show_banner("DEFEAT", Color(1, 0.4, 0.35))
		await get_tree().create_timer(1.6).timeout
		battle_finished.emit(outcome, bonus)
