class_name FlowGenerator
extends RefCounted

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const DependencySolverScript = preload("res://src/core/dependency_solver.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const DifficultyScript = preload("res://src/core/difficulty.gd")

const MAX_GENERATION_ATTEMPTS := 24

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func generate_chain(piece_count: int, board_size: Vector2i = Vector2i(8, 8), complexity: int = 1) -> Dictionary:
	assert(piece_count > 0)
	assert(board_size.x >= 3 and board_size.y >= 3)
	complexity = maxi(complexity, 1)

	for _attempt in range(MAX_GENERATION_ATTEMPTS):
		var generated := _try_generate_multicell(piece_count, board_size, complexity)
		if not generated.is_empty():
			return generated
	# Never degrade to one-cell dots: use a guaranteed-solvable visible fallback.
	return _generate_safe_multicell_fallback(piece_count, board_size)

func _try_generate_multicell(piece_count: int, board_size: Vector2i, complexity: int) -> Dictionary:
	var pieces: Array = []
	var occupied: Dictionary = {}

	for i in range(piece_count):
		var id: String = String.chr(65 + (i % 26)) + ("" if i < 26 else str(i / 26))
		var cells: Array[Vector2i] = _build_path(board_size, occupied, complexity)
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

func _build_path(board_size: Vector2i, occupied: Dictionary, complexity: int) -> Array[Vector2i]:
	var min_length: int = mini(2 + int((complexity - 1) / 4), 4)
	var max_length: int = mini(4 + int((complexity - 1) / 2), 7)
	var target_length: int = rng.randi_range(min_length, max_length)
	var desired_turns: int = mini(int((complexity - 1) / 2), 3)

	for _attempt in range(36):
		var start := Vector2i(rng.randi_range(0, board_size.x - 1), rng.randi_range(0, board_size.y - 1))
		if occupied.has(_cell_key(start)):
			continue
		var path: Array[Vector2i] = [start]
		var previous_direction := Vector2i.ZERO
		var turns := 0
		while path.size() < target_length:
			var candidates: Array[Vector2i] = []
			var turning_candidates: Array[Vector2i] = []
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = path[-1] + direction
				if not _inside(next, board_size) or occupied.has(_cell_key(next)) or next in path:
					continue
				candidates.append(next)
				if previous_direction != Vector2i.ZERO and direction != previous_direction and direction != -previous_direction:
					turning_candidates.append(next)
			if candidates.is_empty():
				break
			var next_cell: Vector2i
			if turns < desired_turns and not turning_candidates.is_empty():
				next_cell = turning_candidates[rng.randi_range(0, turning_candidates.size() - 1)]
			else:
				next_cell = candidates[rng.randi_range(0, candidates.size() - 1)]
			var direction: Vector2i = next_cell - path[-1]
			if previous_direction != Vector2i.ZERO and direction != previous_direction:
				turns += 1
			previous_direction = direction
			path.append(next_cell)
		if path.size() >= min_length and (desired_turns == 0 or turns >= mini(desired_turns, path.size() - 2)):
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

func _generate_safe_multicell_fallback(piece_count: int, board_size: Vector2i) -> Dictionary:
	var pieces: Array = []
	var slots: Array = []

	# Straight two-cell threads whose heads sit on the border and point outward.
	# They are all immediately removable, so the fallback is mathematically solvable
	# while still looking like actual threads instead of isolated arrowhead dots.
	for x in range(2, board_size.x - 2):
		slots.append([[Vector2i(x, 1), Vector2i(x, 0)], Vector2i.UP])
		slots.append([[Vector2i(x, board_size.y - 2), Vector2i(x, board_size.y - 1)], Vector2i.DOWN])
	for y in range(2, board_size.y - 2):
		slots.append([[Vector2i(1, y), Vector2i(0, y)], Vector2i.LEFT])
		slots.append([[Vector2i(board_size.x - 2, y), Vector2i(board_size.x - 1, y)], Vector2i.RIGHT])

	if slots.size() < piece_count:
		# This should not happen for our production board sizes, but keep a safe bound.
		piece_count = slots.size()

	# Shuffle so fallback threads are distributed around all four sides.
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp

	for i in range(piece_count):
		var id := "F%d" % i
		var cells: Array[Vector2i] = []
		for cell in slots[i][0]:
			cells.append(cell)
		var direction: Vector2i = slots[i][1]
		pieces.append(PieceScript.new(id, cells, direction))

	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var solution: Array[String] = DependencySolverScript.new().solve(board)
	return {
		"board": board,
		"known_solution": solution,
		"difficulty": DifficultyScript.new().estimate(board, solution),
	}

func _inside(cell: Vector2i, board_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size.x and cell.y >= 0 and cell.y < board_size.y

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
