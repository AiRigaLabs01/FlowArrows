class_name FlowGenerator
extends RefCounted

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const DependencySolverScript = preload("res://src/core/dependency_solver.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const DifficultyScript = preload("res://src/core/difficulty.gd")

const MAX_GENERATION_ATTEMPTS := 16
const CANDIDATES_PER_PIECE := 128
const DIFFICULTY_CANDIDATES := 5

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

	var target_score: int = _target_difficulty_score(piece_count, complexity)
	var target_density: float = _target_board_density(complexity)
	var best: Dictionary = {}
	var best_distance: float = INF

	# Construct several proven-solvable boards and select by both mathematical
	# difficulty and visual occupancy. Sparse boards are intentionally penalized.
	for _sample in range(DIFFICULTY_CANDIDATES):
		for _attempt in range(MAX_GENERATION_ATTEMPTS):
			var generated := _generate_reverse_solvable(piece_count, board_size, complexity)
			if generated.is_empty():
				continue
			var score: int = int(generated["difficulty"]["score"])
			var density: float = float(generated["difficulty"]["board_density"])
			var score_distance := float(absi(score - target_score))
			var density_penalty := maxf(0.0, target_density - density) * 900.0
			var distance := score_distance + density_penalty
			if best.is_empty() or distance < best_distance:
				best = generated
				best_distance = distance
			break

	if not best.is_empty():
		best["target_difficulty_score"] = target_score
		best["target_board_density"] = target_density
		return best
	return _generate_safe_multicell_fallback(piece_count, board_size)

func _target_difficulty_score(piece_count: int, complexity: int) -> int:
	var level_term: int = maxi(complexity - 1, 0)
	return piece_count * 5 + 70 + level_term * 24 + int(pow(float(level_term), 1.25) * 5.0)

func _target_board_density(complexity: int) -> float:
	# The reference look is intentionally crowded. Keep a little breathing room so
	# solvable exit corridors still exist, but push later boards close to full.
	return minf(0.82 + float(maxi(complexity - 1, 0)) * 0.008, 0.92)

func _generate_reverse_solvable(piece_count: int, board_size: Vector2i, complexity: int) -> Dictionary:
	var pieces: Array = []
	var occupied: Dictionary = {}
	var insertion_order: Array[String] = []

	for i in range(piece_count):
		var accepted = null
		for _candidate in range(CANDIDATES_PER_PIECE):
			var cells: Array[Vector2i] = _build_path(board_size, occupied, complexity)
			if cells.is_empty():
				continue
			var direction: Vector2i = _exit_direction(cells, board_size)
			var id := _piece_id(i)
			var candidate = PieceScript.new(id, cells, direction)
			var trial_pieces: Array = pieces.duplicate()
			trial_pieces.append(candidate)
			var trial_board = BoardScript.new(board_size.x, board_size.y, trial_pieces)
			if not trial_board.can_exit(id):
				continue
			accepted = candidate
			break

		if accepted == null:
			return {}
		pieces.append(accepted)
		insertion_order.append(accepted.id)
		for cell: Vector2i in accepted.cells:
			occupied[_cell_key(cell)] = true

	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var known_solution: Array[String] = []
	for i in range(insertion_order.size() - 1, -1, -1):
		known_solution.append(insertion_order[i])

	var graph_solution: Array[String] = DependencySolverScript.new().solve(board)
	if graph_solution.size() != piece_count:
		return {}

	return {
		"board": board,
		"known_solution": known_solution,
		"difficulty": DifficultyScript.new().estimate(board, graph_solution),
	}

func _build_path(board_size: Vector2i, occupied: Dictionary, complexity: int) -> Array[Vector2i]:
	# Long threads are the default, not the exception. Level 1 already contains
	# substantial paths; later levels add both length and bends.
	var min_length: int = mini(6 + int((complexity - 1) / 6), 9)
	var max_length: int = mini(14 + int((complexity - 1) / 2), 20)
	var spread: int = maxi(max_length - min_length, 1)
	# Squaring the random value biases the result toward max_length.
	var target_length: int = max_length - int(pow(rng.randf(), 2.0) * float(spread))
	var desired_turns: int = mini(2 + int((complexity - 1) / 3), 7)
	var minimum_accepted_length: int = maxi(min_length, int(ceil(float(target_length) * 0.75)))

	for _attempt in range(96):
		var start := _choose_empty_start(board_size, occupied)
		if start.x < 0:
			return []
		var path: Array[Vector2i] = [start]
		var previous_direction := Vector2i.ZERO
		var turns := 0
		while path.size() < target_length:
			var candidates: Array[Vector2i] = []
			var turning_candidates: Array[Vector2i] = []
			var straight_candidates: Array[Vector2i] = []
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = path[-1] + direction
				if not _inside(next, board_size) or occupied.has(_cell_key(next)) or next in path:
					continue
				candidates.append(next)
				if previous_direction != Vector2i.ZERO and direction != previous_direction and direction != -previous_direction:
					turning_candidates.append(next)
				elif previous_direction == Vector2i.ZERO or direction == previous_direction:
					straight_candidates.append(next)
			if candidates.is_empty():
				break

			var next_cell: Vector2i
			if turns < desired_turns and not turning_candidates.is_empty():
				next_cell = turning_candidates[rng.randi_range(0, turning_candidates.size() - 1)]
			elif not straight_candidates.is_empty() and rng.randf() < 0.70:
				next_cell = straight_candidates[rng.randi_range(0, straight_candidates.size() - 1)]
			else:
				# Prefer cells near existing geometry once the mandatory bends exist;
				# this closes visible holes without permitting overlap.
				next_cell = _choose_dense_candidate(candidates, occupied)

			var direction: Vector2i = next_cell - path[-1]
			if previous_direction != Vector2i.ZERO and direction != previous_direction:
				turns += 1
			previous_direction = direction
			path.append(next_cell)

		if path.size() >= minimum_accepted_length and turns >= mini(desired_turns, path.size() - 2):
			return path
	return []

func _choose_empty_start(board_size: Vector2i, occupied: Dictionary) -> Vector2i:
	# Sample several empty cells and prefer one adjacent to existing threads. This
	# packs new paths into gaps instead of scattering starts uniformly.
	var best := Vector2i(-1, -1)
	var best_score := -1
	for _i in range(28):
		var cell := Vector2i(rng.randi_range(0, board_size.x - 1), rng.randi_range(0, board_size.y - 1))
		if occupied.has(_cell_key(cell)):
			continue
		var score := _occupied_neighbor_count(cell, occupied)
		if score > best_score:
			best = cell
			best_score = score
	if best.x >= 0:
		return best
	for y in range(board_size.y):
		for x in range(board_size.x):
			var cell := Vector2i(x, y)
			if not occupied.has(_cell_key(cell)):
				return cell
	return Vector2i(-1, -1)

func _choose_dense_candidate(candidates: Array[Vector2i], occupied: Dictionary) -> Vector2i:
	var best_score := -1
	var best: Array[Vector2i] = []
	for cell in candidates:
		var score := _occupied_neighbor_count(cell, occupied)
		if score > best_score:
			best_score = score
			best = [cell]
		elif score == best_score:
			best.append(cell)
	return best[rng.randi_range(0, best.size() - 1)]

func _occupied_neighbor_count(cell: Vector2i, occupied: Dictionary) -> int:
	var count := 0
	for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if occupied.has(_cell_key(cell + direction)):
			count += 1
	return count

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

func _piece_id(index: int) -> String:
	return "P%d" % index

func _generate_safe_multicell_fallback(piece_count: int, board_size: Vector2i) -> Dictionary:
	var pieces: Array = []
	var slots: Array = []
	for x in range(2, board_size.x - 2):
		slots.append([[Vector2i(x, 1), Vector2i(x, 0)], Vector2i.UP])
		slots.append([[Vector2i(x, board_size.y - 2), Vector2i(x, board_size.y - 1)], Vector2i.DOWN])
	for y in range(2, board_size.y - 2):
		slots.append([[Vector2i(1, y), Vector2i(0, y)], Vector2i.LEFT])
		slots.append([[Vector2i(board_size.x - 2, y), Vector2i(board_size.x - 1, y)], Vector2i.RIGHT])
	piece_count = mini(piece_count, slots.size())
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	for i in range(piece_count):
		var cells: Array[Vector2i] = []
		for cell in slots[i][0]:
			cells.append(cell)
		pieces.append(PieceScript.new("F%d" % i, cells, slots[i][1]))
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
