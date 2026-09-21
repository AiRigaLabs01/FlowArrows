class_name FlowGenerator
extends RefCounted

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const DependencySolverScript = preload("res://src/core/dependency_solver.gd")
const DifficultyScript = preload("res://src/core/difficulty.gd")

const MAX_GENERATION_ATTEMPTS := 4
const DIFFICULTY_CANDIDATES := 2
const EXIT_SEED_SAMPLES := 72
const PATH_BUILD_ATTEMPTS := 18
const LOCAL_BACKTRACK_LIMIT := 48
const LOCAL_BACKTRACK_MIN := 2
const LOCAL_BACKTRACK_MAX := 5

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
	var attempts_total := 0
	var max_pieces_placed := 0
	var max_occupied_cells := 0
	var best_average_length := 0.0
	var best_max_length := 0
	var max_backtracks := 0
	var last_reason := "no valid candidate"
	var graph_failures := 0

	for _sample in range(DIFFICULTY_CANDIDATES):
		for _attempt in range(MAX_GENERATION_ATTEMPTS):
			attempts_total += 1
			var generated := _generate_reverse_solvable(piece_count, board_size, complexity, target_density)
			if bool(generated.get("generation_failed", false)):
				var diag: Dictionary = generated.get("diagnostics", {})
				var placed := int(diag.get("pieces_placed", 0))
				var occupied_cells := int(diag.get("occupied_cells", 0))
				if placed > max_pieces_placed or (placed == max_pieces_placed and occupied_cells > max_occupied_cells):
					max_pieces_placed = placed
					max_occupied_cells = occupied_cells
					best_average_length = float(diag.get("average_thread_length", 0.0))
					best_max_length = int(diag.get("max_thread_length", 0))
				max_backtracks = maxi(max_backtracks, int(diag.get("backtracks", 0)))
				last_reason = String(diag.get("reason", last_reason))
				if last_reason == "dependency verification failed":
					graph_failures += 1
				continue
			var score: int = int(generated["difficulty"]["score"])
			var density: float = float(generated["difficulty"]["board_density"])
			var score_distance := float(absi(score - target_score))
			var density_penalty := absf(target_density - density) * 700.0
			var distance := score_distance + density_penalty
			if best.is_empty() or distance < best_distance:
				best = generated
				best_distance = distance
			break

	if not best.is_empty():
		best["target_difficulty_score"] = target_score
		best["target_board_density"] = target_density
		return best

	var board_cells := board_size.x * board_size.y
	return {
		"generation_failed": true,
		"diagnostics": {
			"reason": last_reason,
			"attempts": attempts_total,
			"requested_pieces": piece_count,
			"max_pieces_placed": max_pieces_placed,
			"max_occupied_cells": max_occupied_cells,
			"max_density": 0.0 if board_cells <= 0 else float(max_occupied_cells) / float(board_cells),
			"average_thread_length": best_average_length,
			"max_thread_length": best_max_length,
			"target_density": target_density,
			"target_score": target_score,
			"board_size": "%dx%d" % [board_size.x, board_size.y],
			"graph_failures": graph_failures,
			"backtracks": max_backtracks,
		}
	}

func _target_difficulty_score(piece_count: int, complexity: int) -> int:
	var level_term: int = maxi(complexity - 1, 0)
	return piece_count * 5 + 70 + level_term * 24 + int(pow(float(level_term), 1.25) * 5.0)

func _target_board_density(complexity: int) -> float:
	return minf(0.84 + float(maxi(complexity - 1, 0)) * 0.006, 0.91)

func _generate_reverse_solvable(piece_count: int, board_size: Vector2i, complexity: int, target_density: float) -> Dictionary:
	var pieces: Array = []
	var occupied: Dictionary = {}
	var insertion_order: Array[String] = []
	var target_occupied_cells: int = mini(int(round(float(board_size.x * board_size.y) * target_density)), board_size.x * board_size.y - 4)
	var i := 0
	var backtracks := 0
	var max_pieces_reached := 0
	var max_occupied_reached := 0
	var best_average_length := 0.0
	var best_max_length := 0

	# Dense generation tends to fail only near the end. Instead of throwing away a
	# good 40+ piece partial board, rewind a few recent threads and explore a new
	# local geometry. This is bounded backtracking, not a visual fallback.
	while i < piece_count:
		if i > max_pieces_reached or (i == max_pieces_reached and occupied.size() > max_occupied_reached):
			max_pieces_reached = i
			max_occupied_reached = occupied.size()
			var length_stats := _thread_length_stats(pieces)
			best_average_length = float(length_stats["average"])
			best_max_length = int(length_stats["max"])
		var remaining_pieces: int = piece_count - i
		var remaining_target_cells: int = maxi(target_occupied_cells - occupied.size(), remaining_pieces * 3)
		var ideal_length: int = maxi(3, int(round(float(remaining_target_cells) / float(remaining_pieces))))
		var accepted = null

		for _candidate in range(PATH_BUILD_ATTEMPTS):
			var built: Dictionary = _build_exit_aware_path(board_size, occupied, complexity, ideal_length)
			if built.is_empty():
				continue
			var cells: Array[Vector2i] = built["cells"]
			var direction: Vector2i = built["direction"]
			var id := _piece_id(i)
			accepted = PieceScript.new(id, cells, direction)
			break

		if accepted == null:
			if i >= LOCAL_BACKTRACK_MIN and backtracks < LOCAL_BACKTRACK_LIMIT:
				var rewind: int = mini(rng.randi_range(LOCAL_BACKTRACK_MIN, LOCAL_BACKTRACK_MAX), i)
				for _r in range(rewind):
					var removed = pieces.pop_back()
					insertion_order.pop_back()
					for cell: Vector2i in removed.cells:
						occupied.erase(_cell_key(cell))
				i -= rewind
				backtracks += 1
				continue
			return {
				"generation_failed": true,
				"diagnostics": {
					"reason": "no exit-aware path after local backtracking near piece %d" % i,
					"pieces_placed": max_pieces_reached,
					"occupied_cells": max_occupied_reached,
					"average_thread_length": best_average_length,
					"max_thread_length": best_max_length,
					"backtracks": backtracks,
				}
			}

		pieces.append(accepted)
		insertion_order.append(accepted.id)
		for cell: Vector2i in accepted.cells:
			occupied[_cell_key(cell)] = true
		i += 1

	if pieces.size() > max_pieces_reached or (pieces.size() == max_pieces_reached and occupied.size() > max_occupied_reached):
		max_pieces_reached = pieces.size()
		max_occupied_reached = occupied.size()
		var final_length_stats := _thread_length_stats(pieces)
		best_average_length = float(final_length_stats["average"])
		best_max_length = int(final_length_stats["max"])
	var board = BoardScript.new(board_size.x, board_size.y, pieces)
	var known_solution: Array[String] = []
	for solution_index in range(insertion_order.size() - 1, -1, -1):
		known_solution.append(insertion_order[solution_index])

	var graph_solution: Array[String] = DependencySolverScript.new().solve(board)
	if graph_solution.size() != piece_count:
		return {
			"generation_failed": true,
			"diagnostics": {
				"reason": "dependency verification failed",
				"pieces_placed": pieces.size(),
				"occupied_cells": occupied.size(),
				"average_thread_length": _thread_length_stats(pieces)["average"],
				"max_thread_length": _thread_length_stats(pieces)["max"],
				"backtracks": backtracks,
			}
		}

	var final_stats := _thread_length_stats(pieces)
	return {
		"board": board,
		"known_solution": known_solution,
		"difficulty": DifficultyScript.new().estimate(board, graph_solution),
		"generation_backtracks": backtracks,
		"average_thread_length": final_stats["average"],
		"max_thread_length": final_stats["max"],
	}

func _build_exit_aware_path(board_size: Vector2i, occupied: Dictionary, complexity: int, ideal_length: int) -> Dictionary:
	var seed: Dictionary = _choose_exit_seed(board_size, occupied)
	if seed.is_empty():
		return {}
	var head: Vector2i = seed["head"]
	var exit_direction: Vector2i = seed["direction"]
	var first_tail: Vector2i = head - exit_direction
	if not _inside(first_tail, board_size):
		return {}
	if occupied.has(_cell_key(first_tail)):
		return {}

	var min_length: int = maxi(5, ideal_length - 4)
	var max_length: int = mini(20, maxi(min_length, ideal_length + 5 + int((complexity - 1) / 4)))
	var target_length: int = clampi(ideal_length + rng.randi_range(-2, 4), min_length, max_length)
	var desired_turns: int = mini(2 + int((complexity - 1) / 3), 7)

	var head_to_tail: Array[Vector2i] = [head, first_tail]
	var path_keys: Dictionary = {
		_cell_key(head): true,
		_cell_key(first_tail): true,
	}
	var previous_direction: Vector2i = first_tail - head
	var turns := 0

	while head_to_tail.size() < target_length:
		var current: Vector2i = head_to_tail[-1]
		var candidates: Array[Vector2i] = []
		var straight: Array[Vector2i] = []
		var turning: Array[Vector2i] = []
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := current + direction
			var key := _cell_key(next)
			if not _inside(next, board_size) or occupied.has(key) or path_keys.has(key):
				continue
			candidates.append(next)
			if direction == previous_direction:
				straight.append(next)
			elif direction != -previous_direction:
				turning.append(next)
		if candidates.is_empty():
			break

		var next_cell: Vector2i
		if turns < desired_turns and not turning.is_empty():
			next_cell = _choose_growth_candidate(turning, board_size, occupied, path_keys)
		elif not straight.is_empty() and rng.randf() < 0.62:
			next_cell = _choose_growth_candidate(straight, board_size, occupied, path_keys)
		else:
			next_cell = _choose_growth_candidate(candidates, board_size, occupied, path_keys)

		var direction := next_cell - current
		if direction != previous_direction:
			turns += 1
		previous_direction = direction
		head_to_tail.append(next_cell)
		path_keys[_cell_key(next_cell)] = true

	var minimum_accepted_length: int = maxi(5, int(round(float(target_length) * 0.70)))
	if head_to_tail.size() < minimum_accepted_length:
		return {}

	var cells: Array[Vector2i] = head_to_tail.duplicate()
	cells.reverse()
	return {
		"cells": cells,
		"direction": exit_direction,
	}

func _choose_exit_seed(board_size: Vector2i, occupied: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1000000.0
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var occupancy_ratio := float(occupied.size()) / float(board_size.x * board_size.y)

	for _sample in range(EXIT_SEED_SAMPLES):
		var head := Vector2i(rng.randi_range(0, board_size.x - 1), rng.randi_range(0, board_size.y - 1))
		if occupied.has(_cell_key(head)):
			continue
		for direction: Vector2i in directions:
			var first_tail := head - direction
			if not _inside(first_tail, board_size) or occupied.has(_cell_key(first_tail)):
				continue
			var ray_steps: int = _clear_exit_ray_steps(head, direction, board_size, occupied)
			if ray_steps < 0:
				continue
			# Early in generation, interior heads are desirable. Near saturation, shorter
			# clear rays are more valuable because they keep placement options alive.
			var ray_weight := 5.0 if occupancy_ratio < 0.55 else -2.0
			var score := float(ray_steps) * ray_weight + float(_occupied_neighbor_count(head, occupied) * 3)
			score += rng.randf() * 3.0
			if score > best_score:
				best_score = score
				best = {"head": head, "direction": direction}

	if not best.is_empty():
		return best

	for y in range(board_size.y):
		for x in range(board_size.x):
			var head := Vector2i(x, y)
			if occupied.has(_cell_key(head)):
				continue
			for direction: Vector2i in directions:
				var first_tail := head - direction
				if not _inside(first_tail, board_size) or occupied.has(_cell_key(first_tail)):
					continue
				if _clear_exit_ray_steps(head, direction, board_size, occupied) >= 0:
					return {"head": head, "direction": direction}
	return {}

func _clear_exit_ray_steps(head: Vector2i, direction: Vector2i, board_size: Vector2i, occupied: Dictionary) -> int:
	var cursor := head + direction
	var steps := 0
	while _inside(cursor, board_size):
		if occupied.has(_cell_key(cursor)):
			return -1
		steps += 1
		cursor += direction
	return steps

func _choose_growth_candidate(candidates: Array[Vector2i], board_size: Vector2i, occupied: Dictionary, path_keys: Dictionary) -> Vector2i:
	var best_score := -1000000
	var best: Array[Vector2i] = []
	for cell: Vector2i in candidates:
		var free_neighbors := 0
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := cell + direction
			var key := _cell_key(neighbor)
			if _inside(neighbor, board_size) and not occupied.has(key) and not path_keys.has(key):
				free_neighbors += 1
		var score := _occupied_neighbor_count(cell, occupied) * 3 + free_neighbors * 2 + rng.randi_range(0, 2)
		if score > best_score:
			best_score = score
			best = [cell]
		elif score == best_score:
			best.append(cell)
	return best[rng.randi_range(0, best.size() - 1)]

func _occupied_neighbor_count(cell: Vector2i, occupied: Dictionary) -> int:
	var count := 0
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if occupied.has(_cell_key(cell + direction)):
			count += 1
	return count

func _thread_length_stats(pieces: Array) -> Dictionary:
	if pieces.is_empty():
		return {"average": 0.0, "max": 0}
	var total := 0
	var maximum := 0
	for piece in pieces:
		var length: int = piece.cells.size()
		total += length
		maximum = maxi(maximum, length)
	return {
		"average": float(total) / float(pieces.size()),
		"max": maximum,
	}

func _piece_id(index: int) -> String:
	return "P%d" % index

func _inside(cell: Vector2i, board_size: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size.x and cell.y >= 0 and cell.y < board_size.y

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
