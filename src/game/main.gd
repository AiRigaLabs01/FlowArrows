extends Node2D

const BoardState = preload("res://src/core/board_state.gd")
const FlowSolver = preload("res://src/core/solver.gd")
const FlowGenerator = preload("res://src/core/generator.gd")
const PieceView = preload("res://src/game/piece_view.gd")

const CELL_SIZE := 105.0
const BOARD_ORIGIN := Vector2(120, 420)
const START_PIECES := 8
const START_BOARD_SIZE := Vector2i(8, 8)
const MAX_LIVES := 3

var board
var initial_board
var piece_nodes: Dictionary = {}
var failed_piece_ids: Dictionary = {}
var status_label: Label
var level_label: Label
var moves_label: Label
var lives_label: Label
var hint_label: Label
var new_level_button: Button
var restart_button: Button
var hint_button: Button
var generator = FlowGenerator.new()
var level_number: int = 1
var moves: int = 0
var lives: int = MAX_LIVES
var input_locked: bool = false
var game_over: bool = false

func _ready() -> void:
	_build_ui()
	_start_new_level()

func _build_ui() -> void:
	var title: Label = Label.new()
	title.text = "FlowArrows"
	title.position = Vector2(80, 70)
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)

	level_label = Label.new()
	level_label.position = Vector2(80, 145)
	level_label.add_theme_font_size_override("font_size", 28)
	add_child(level_label)

	moves_label = Label.new()
	moves_label.position = Vector2(760, 145)
	moves_label.add_theme_font_size_override("font_size", 28)
	add_child(moves_label)

	status_label = Label.new()
	status_label.position = Vector2(80, 205)
	status_label.add_theme_font_size_override("font_size", 30)
	add_child(status_label)

	lives_label = Label.new()
	lives_label.position = Vector2(760, 205)
	lives_label.add_theme_font_size_override("font_size", 28)
	add_child(lives_label)

	hint_label = Label.new()
	hint_label.position = Vector2(80, 265)
	hint_label.add_theme_font_size_override("font_size", 24)
	add_child(hint_label)

	restart_button = Button.new()
	restart_button.text = "Restart"
	restart_button.position = Vector2(80, 1540)
	restart_button.size = Vector2(260, 90)
	restart_button.add_theme_font_size_override("font_size", 28)
	restart_button.pressed.connect(_restart_level)
	add_child(restart_button)

	hint_button = Button.new()
	hint_button.text = "Hint"
	hint_button.position = Vector2(410, 1540)
	hint_button.size = Vector2(260, 90)
	hint_button.add_theme_font_size_override("font_size", 28)
	hint_button.pressed.connect(_show_hint)
	add_child(hint_button)

	new_level_button = Button.new()
	new_level_button.text = "New level"
	new_level_button.position = Vector2(740, 1540)
	new_level_button.size = Vector2(260, 90)
	new_level_button.add_theme_font_size_override("font_size", 28)
	new_level_button.pressed.connect(_next_level)
	add_child(new_level_button)

func _start_new_level() -> void:
	input_locked = false
	game_over = false
	moves = 0
	lives = MAX_LIVES
	failed_piece_ids.clear()
	hint_label.text = ""
	var piece_count: int = mini(START_PIECES + int((level_number - 1) / 2), 12)
	var generated: Dictionary = generator.generate_chain(piece_count, START_BOARD_SIZE, level_number)
	board = generated["board"]
	initial_board = board.copy()
	_render_board()
	_update_status()

func _restart_level() -> void:
	if input_locked:
		return
	board = initial_board.copy()
	moves = 0
	lives = MAX_LIVES
	game_over = false
	failed_piece_ids.clear()
	hint_label.text = ""
	_render_board()
	_update_status()

func _next_level() -> void:
	if input_locked or game_over:
		return
	level_number += 1
	_start_new_level()

func _render_board() -> void:
	for node in piece_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	piece_nodes.clear()

	for piece_id in board.pieces:
		var piece = board.pieces[piece_id]
		var view = PieceView.new()
		view.set_meta("piece_id", piece_id)
		view.position = BOARD_ORIGIN + Vector2(piece.cells[0]) * CELL_SIZE
		view.setup(piece_id, piece.cells, piece.direction, CELL_SIZE)
		view.set_failed(failed_piece_ids.has(piece_id))
		view.set_enabled(not input_locked and not game_over)
		view.pressed.connect(_on_piece_pressed)
		add_child(view)
		piece_nodes[piece_id] = view

func _on_piece_pressed(piece_id: String, view) -> void:
	if input_locked or game_over:
		return
	if board.can_exit(piece_id):
		_start_exit_animation(piece_id, view)
	else:
		_start_failed_animation(piece_id, view)

func _start_exit_animation(piece_id: String, view) -> void:
	var steps: int = board.exit_steps(piece_id)
	if steps <= 0:
		return
	input_locked = true
	_set_piece_input_enabled(false)
	var duration: float = maxf(0.28, float(steps) * 0.085)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(view, "exit_progress", float(steps), duration)
	tween.tween_callback(_finish_remove.bind(piece_id, view))

func _start_failed_animation(piece_id: String, view) -> void:
	var first_failure := not failed_piece_ids.has(piece_id)
	if first_failure:
		failed_piece_ids[piece_id] = true
		lives -= 1
		view.set_failed(true)
	_update_status()

	input_locked = true
	_set_piece_input_enabled(false)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(view, "impact_offset", CELL_SIZE * 0.18, 0.10).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, "impact_offset", 0.0, 0.16).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_failed_animation.bind(view))

func _finish_failed_animation(view) -> void:
	if is_instance_valid(view):
		view.impact_offset = 0.0
	input_locked = false
	if lives <= 0:
		game_over = true
		_set_piece_input_enabled(false)
		_update_status()
		return
	_set_piece_input_enabled(true)
	_update_status()

func _finish_remove(piece_id: String, view) -> void:
	board.remove_piece(piece_id)
	moves += 1
	failed_piece_ids.erase(piece_id)
	piece_nodes.erase(piece_id)
	view.queue_free()
	hint_label.text = ""
	_render_board()
	_update_status()

	if board.is_solved():
		input_locked = false
		_set_piece_input_enabled(false)
		status_label.text = "Solved! Tap New level"
		return

	var automatic_piece_id := _next_open_failed_piece()
	if automatic_piece_id != "" and piece_nodes.has(automatic_piece_id):
		_start_exit_animation(automatic_piece_id, piece_nodes[automatic_piece_id])
		return

	input_locked = false
	_set_piece_input_enabled(true)
	_update_status()

func _next_open_failed_piece() -> String:
	var ids := failed_piece_ids.keys()
	ids.sort()
	for piece_id in ids:
		var id := String(piece_id)
		if board.pieces.has(id) and board.can_exit(id):
			return id
	return ""

func _show_hint() -> void:
	if input_locked or game_over or board.is_solved():
		return
	for node in piece_nodes.values():
		node.set_hint(false)
	var solution: Array[String] = FlowSolver.new().solve(board)
	if solution.is_empty():
		hint_label.text = "No solution found"
		return
	var suggested: String = solution[0]
	hint_label.text = "Suggested move highlighted"
	if piece_nodes.has(suggested):
		piece_nodes[suggested].set_hint(true)

func _set_piece_input_enabled(value: bool) -> void:
	for piece_id in piece_nodes:
		piece_nodes[piece_id].set_enabled(value and not game_over)

func _update_status() -> void:
	level_label.text = "Level %d · %d pieces left" % [level_number, board.pieces.size()]
	moves_label.text = "Moves: %d" % moves
	lives_label.text = "Lives: %d/%d" % [lives, MAX_LIVES]
	new_level_button.disabled = game_over
	hint_button.disabled = game_over
	if game_over:
		status_label.text = "Game over · Restart"
	elif board.is_solved():
		status_label.text = "Solved!"
	else:
		status_label.text = "Choose a thread"
