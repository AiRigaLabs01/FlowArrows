extends SceneTree

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const SolverScript = preload("res://src/core/solver.gd")
const DependencySolverScript = preload("res://src/core/dependency_solver.gd")

const CASE_COUNT := 1200

var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 0xF10A2026
	for case_index in range(CASE_COUNT):
		var board = _random_small_board(case_index)
		var dfs_solution: Array[String] = SolverScript.new().solve(board)
		var graph_solution: Array[String] = DependencySolverScript.new().solve(board)
		var dfs_solvable: bool = board.is_solved() or not dfs_solution.is_empty()
		var graph_solvable: bool = board.is_solved() or not graph_solution.is_empty()
		assert(dfs_solvable == graph_solvable, "Solver disagreement in case %d: DFS=%s graph=%s" % [case_index, dfs_solution, graph_solution])
		if graph_solvable:
			assert(_is_valid_solution(board, graph_solution), "Dependency solver returned invalid sequence in case %d" % case_index)
	print("Dependency solver equivalence passed: %d deterministic random boards" % CASE_COUNT)
	quit()

func _random_small_board(case_index: int):
	var width: int = rng.randi_range(3, 6)
	var height: int = rng.randi_range(3, 6)
	var target_count: int = rng.randi_range(1, mini(7, width * height))
	var occupied: Dictionary = {}
	var pieces: Array = []

	for i in range(target_count):
		var cells: Array[Vector2i] = _random_path(width, height, occupied)
		if cells.is_empty():
			continue
		for cell in cells:
			occupied[_key(cell)] = true
		var direction: Vector2i = _random_direction()
		pieces.append(PieceScript.new("C%d_%d" % [case_index, i], cells, direction))

	return BoardScript.new(width, height, pieces)

func _random_path(width: int, height: int, occupied: Dictionary) -> Array[Vector2i]:
	for _attempt in range(20):
		var start := Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
		if occupied.has(_key(start)):
			continue
		var path: Array[Vector2i] = [start]
		var target_length: int = rng.randi_range(1, 4)
		while path.size() < target_length:
			var candidates: Array[Vector2i] = []
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = path[-1] + direction
				if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
					continue
				if occupied.has(_key(next)) or next in path:
					continue
				candidates.append(next)
			if candidates.is_empty():
				break
			path.append(candidates[rng.randi_range(0, candidates.size() - 1)])
		return path
	return []

func _random_direction() -> Vector2i:
	var directions := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	return directions[rng.randi_range(0, directions.size() - 1)]

func _is_valid_solution(initial_board, solution: Array[String]) -> bool:
	var state = initial_board.copy()
	for piece_id in solution:
		if not state.can_exit(piece_id):
			return false
		if not state.remove_piece(piece_id):
			return false
	return state.is_solved()

func _key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
