extends Node2D

const FlowPiece = preload("res://src/core/piece.gd")
const BoardState = preload("res://src/core/board_state.gd")
const FlowSolver = preload("res://src/core/solver.gd")
const FlowGenerator = preload("res://src/core/generator.gd")

const CELL_SIZE := 120.0
const BOARD_ORIGIN := Vector2(120, 420)
const EXIT_DISTANCE := 1100.0
const START_PIECES := 5

var board
var initial_board
var piece_nodes: Dictionary = {}
var status_label: Label
var level_label: Label
var moves_label: Label
var hint_label: Label
var new_level_button: Button
var restart_button: Button
var hint_button: Button
var generator := FlowGenerator.new()
var level_number := 1
var moves := 0
var input_locked := false

func _ready() -> void:
	_build_ui()
	_start_new_level()

func _build_ui() -> void:
	var title := Label.new()
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
	moves = 0
	hint_label.text = ""
	var piece_count := min(START_PIECES + int((level_number - 1) / 2), 9)
	var generated: Dictionary = generator.generate_chain(piece_count, Vector2i(7, 7))
	board = generated["board"]
	initial_board = board.copy()
	_render_board()
	_update_status()

func _restart_level() -> void:
	if input_locked:
		return
	board = initial_board.copy()
	moves = 0
	hint_label.text = ""
	_render_board()
	_update_status()

func _next_level() -> void:
	if input_locked:
		return
	level_number += 1
	_start_new_level()

func _render_board() -> void:
	for child in get_children():
		if child.has_meta("piece_id"):
			child.queue_free()
	piece_nodes.clear()

	for piece_id in board.pieces:
		var piece = board.pieces[piece_id]
		var button := Button.new()
		button.set_meta("piece_id", piece_id)
		button.text = "%s  %s" % [piece_id, _arrow_for(piece.direction)]
		button.position = BOARD_ORIGIN + Vector2(piece.cells[0].x, piece.cells[0].y) * CELL_SIZE
		button.size = Vector2(CELL_SIZE - 12.0, CELL_SIZE - 12.0)
		button.add_theme_font_size_override("font_size", 34)
		button.disabled = input_locked or not board.can_exit(piece_id)
		button.pressed.connect(_on_piece_pressed.bind(piece_id, button))
		add_child(button)
		piece_nodes[piece_id] = button

func _on_piece_pressed(piece_id: String, button: Button) -> void:
	if input_locked or not board.can_exit(piece_id):
		return
	input_locked = true
	var piece = board.pieces[piece_id]
	button.disabled = true
	var target := button.position + Vector2(piece.direction) * EXIT_DISTANCE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(button, "position", target, 0.32)
	tween.tween_callback(_finish_remove.bind(piece_id, button))

func _finish_remove(piece_id: String, button: Button) -> void:
	board.remove_piece(piece_id)
	moves += 1
	button.queue_free()
	input_locked = false
	hint_label.text = ""
	if board.is_solved():
		_render_board()
		_update_status()
		status_label.text = "Solved! Tap New level"
	else:
		_render_board()
		_update_status()

func _show_hint() -> void:
	if input_locked or board.is_solved():
		return
	var solution: Array[String] = FlowSolver.new().solve(board)
	if solution.is_empty():
		hint_label.text = "No solution found"
		return
	var suggested := solution[0]
	hint_label.text = "Try: %s %s" % [suggested, _arrow_for(board.pieces[suggested].direction)]

func _update_status() -> void:
	level_label.text = "Level %d · %d pieces left" % [level_number, board.pieces.size()]
	moves_label.text = "Moves: %d" % moves
	var legal: Array[String] = board.legal_moves()
	if board.is_solved():
		status_label.text = "Solved!"
	else:
		status_label.text = "Available moves: %d" % legal.size()

func _arrow_for(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "↑"
	if direction == Vector2i.DOWN:
		return "↓"
	if direction == Vector2i.LEFT:
		return "←"
	return "→"
