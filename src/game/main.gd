extends Node2D

const CELL_SIZE := 120.0
const BOARD_ORIGIN := Vector2(120, 420)

var board: BoardState
var piece_nodes: Dictionary = {}
var status_label: Label

func _ready() -> void:
	_build_demo_board()
	_build_ui()
	_render_board()

func _build_demo_board() -> void:
	var a := FlowPiece.new("A", [Vector2i(0, 1)], Vector2i.RIGHT)
	var b := FlowPiece.new("B", [Vector2i(2, 1)], Vector2i.UP)
	var c := FlowPiece.new("C", [Vector2i(1, 2)], Vector2i.LEFT)
	board = BoardState.new(4, 4, [a, b, c])

func _build_ui() -> void:
	var title := Label.new()
	title.text = "FlowArrows — prototype"
	title.position = Vector2(80, 100)
	title.add_theme_font_size_override("font_size", 42)
	add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(80, 180)
	status_label.add_theme_font_size_override("font_size", 28)
	add_child(status_label)
	_update_status()

func _render_board() -> void:
	for child in get_children():
		if child.has_meta("piece_id"):
			child.queue_free()
	piece_nodes.clear()

	for piece_id in board.pieces:
		var piece: FlowPiece = board.pieces[piece_id]
		var button := Button.new()
		button.set_meta("piece_id", piece_id)
		button.text = "%s  %s" % [piece_id, _arrow_for(piece.direction)]
		button.position = BOARD_ORIGIN + Vector2(piece.cells[0].x, piece.cells[0].y) * CELL_SIZE
		button.size = Vector2(CELL_SIZE - 12.0, CELL_SIZE - 12.0)
		button.add_theme_font_size_override("font_size", 34)
		button.disabled = not board.can_exit(piece_id)
		button.pressed.connect(_on_piece_pressed.bind(piece_id, button))
		add_child(button)
		piece_nodes[piece_id] = button

func _on_piece_pressed(piece_id: String, button: Button) -> void:
	if not board.can_exit(piece_id):
		return
	var piece: FlowPiece = board.pieces[piece_id]
	button.disabled = true
	var target := button.position + Vector2(piece.direction) * 900.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(button, "position", target, 0.35)
	tween.tween_callback(_finish_remove.bind(piece_id, button))

func _finish_remove(piece_id: String, button: Button) -> void:
	board.remove_piece(piece_id)
	button.queue_free()
	_update_status()
	if board.is_solved():
		status_label.text = "Solved!"
	else:
		_render_board()

func _update_status() -> void:
	var legal := board.legal_moves()
	status_label.text = "Available: %s" % [", ".join(legal)]

func _arrow_for(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "↑"
	if direction == Vector2i.DOWN:
		return "↓"
	if direction == Vector2i.LEFT:
		return "←"
	return "→"
