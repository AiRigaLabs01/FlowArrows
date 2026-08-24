class_name FlowGenerator
extends RefCounted

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const SolverScript = preload("res://src/core/solver.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const DifficultyScript = preload("res://src/core/difficulty.gd")

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func generate_chain(piece_count: int, board_size: Vector2i = Vector2i(8, 8)) -> Dictionary:
	assert(piece_count > 0)
	assert(board_size.x >= 3 and board_size.y >= 3)

	for _attempt in range(40):
		var generated := _try_generate_multicell(piece_count, board_size)
		if not generated.is_empty():
			return generated
	return _generate_simple(piece_count, board_size)

func _try_generate_multicell(piece_count: int, board_size: Vector2i) -> Dictionary:
	var pieces: Array = []
	var occupied: Dictionary = {}

	for i in range(piece_count):
		var id: String = String.chr(65 + (i % 26)) + ("" if i < 26 else str(i / 26))
		var cells: Array[Vector2i] = _build_path(board_size, occupied)
		if cells.is_empty():
			return {}
		for cell: Vector2i in cells:
			occupied[_cell_key(cell)] = true
		var direction: Vector2i = _exit_direction(cells, board_size)
		pieces.append(PieceScript.new(id, cells, direction))

	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var validation: Dictionary = ValidatorScript.new().validate(board)
	if not validation["valid"]:
		return {}
	var solution: Array[String] = validation["solution"]
	return {
		"board": board,
		"known_solution": solution,
		"difficulty": DifficultyScript.new().estimate(board, solution),
	}

func _build_path(board_size: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	var target_length: int = rng.randi_range(2, 4)
	for _attempt in range(24):
		var start := Vector2i(rng.randi_range(0, board_size.x - 1), rng.randi_range(0, board_size.y - 1))
		if occupied.has(_cell_key(start)):
			continue
		var path: Array[Vector2i] = [start]
		while path.size() < target_length:
			var candidates: Array[Vector2i] = []
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = path[-1] + direction
				if _inside(next, board_size) and not occupied.has(_cell_key(next)) and next not in path:
					candidates.append(next)
			if candidates.is_empty():
				break
			path.append(candidates[rng.randi_range(0, candidates.size() - 1)])
		if path.size() >= 2:
			return path
	return []

func _exit_direction(cells: Array[Vector2i], board_size: Vector2i) -> Vector2i:
	var head: Vector2i = cells[-1]
	var previous: Vector2i = cells[-2]
	var forward: Vector2i = head - previous
	if forward in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		return forward
	var distances := {
		Vector2i.LEFT: head.x,
		Vector2i.RIGHT: board_size.x - 1 - head.x,
		Vector2i.UP: head.y,
		Vector2i.DOWN: board_size.y - 1 - head.y,
	}
	var best := Vector2i.RIGHT
	var best_distance: int = 1 << 30
	for direction in distances:
		var distance: int = distances[direction]
		if distance < best_distance:
			best_distance = distance
			best = direction
	return best

func _generate_simple(piece_count: int, board_size: Vector2i) -> Dictionary:
	var pieces: Array = []
	for i in range(piece_count):
		var id: String = "P%d" % i
		var cell: Vector2i = Vector2i(i % board_size.x, i % board_size.y)
		var direction: Vector2i = Vector2i.RIGHT if cell.x < board_size.x - 1 else Vector2i.LEFT
		pieces.append(PieceScript.new(id, [cell], direction))
	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var solution: Array[String] = SolverScript.new().solve(board)
	return {
		"board": board,
		"known_solution": solution,
		"difficulty": DifficultyScript.new().estimate(board, solution),
	}

func _inside(cell: Vector2i, board_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size.x and cell.y >= 0 and cell.y < board_size.y

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
