class_name FlowGenerator
extends RefCounted

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const SolverScript = preload("res://src/core/solver.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const DifficultyScript = preload("res://src/core/difficulty.gd")

var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func generate_chain(piece_count: int, board_size: Vector2i = Vector2i(8, 8)) -> Dictionary:
	assert(piece_count > 0)
	assert(board_size.x >= 3 and board_size.y >= 3)

	var pieces: Array = []
	var solution: Array[String] = []
	var occupied: Dictionary = {}
	var row := clamp(board_size.y / 2, 1, board_size.y - 2)

	for i in range(piece_count):
		var id := String.chr(65 + (i % 26)) + ("" if i < 26 else str(i / 26))
		var x := min(i, board_size.x - 2)
		var y := row
		if i > 0:
			y = clamp(row - (i % 2), 0, board_size.y - 1)
		var cell := Vector2i(x, y)
		while occupied.has(_cell_key(cell)):
			cell = Vector2i(rng.randi_range(0, board_size.x - 1), rng.randi_range(0, board_size.y - 1))
		occupied[_cell_key(cell)] = true

		var direction := Vector2i.RIGHT
		if i == piece_count - 1:
			direction = Vector2i.UP if cell.y > 0 else Vector2i.DOWN
		pieces.append(PieceScript.new(id, [cell], direction))
		solution.push_front(id)

	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var validator = ValidatorScript.new()
	var validation := validator.validate(board)

	if not validation.valid:
		return _generate_simple(piece_count, board_size)

	return {
		"board": board,
		"known_solution": validation.solution,
		"difficulty": DifficultyScript.new().estimate(board, validation.solution),
	}

func _generate_simple(piece_count: int, board_size: Vector2i) -> Dictionary:
	var pieces: Array = []
	for i in range(piece_count):
		var id := "P%d" % i
		var cell := Vector2i(i % board_size.x, i % board_size.y)
		var direction := Vector2i.RIGHT if cell.x < board_size.x - 1 else Vector2i.LEFT
		pieces.append(PieceScript.new(id, [cell], direction))
	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var solution := SolverScript.new().solve(board)
	return {
		"board": board,
		"known_solution": solution,
		"difficulty": DifficultyScript.new().estimate(board, solution),
	}

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
