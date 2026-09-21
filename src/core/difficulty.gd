class_name DifficultyEstimator
extends RefCounted

const DependencySolverScript = preload("res://src/core/dependency_solver.gd")

func estimate(board, solution: Array[String]) -> Dictionary:
	var graph: Dictionary = DependencySolverScript.new().build_graph(board)
	var blockers: Dictionary = graph["blockers"]
	var dependents: Dictionary = graph["dependents"]

	var steps: int = solution.size()
	var total_dependencies := 0
	var max_blockers := 0
	var initially_open := 0
	for piece_id in board.pieces:
		var id := String(piece_id)
		var blocker_count: int = blockers[id].size()
		total_dependencies += blocker_count
		max_blockers = maxi(max_blockers, blocker_count)
		if blocker_count == 0:
			initially_open += 1

	var depth_by_id: Dictionary = {}
	var max_depth := 0
	for piece_id in solution:
		var id := String(piece_id)
		var depth := 1
		for blocker_id in blockers[id]:
			if depth_by_id.has(blocker_id):
				depth = maxi(depth, int(depth_by_id[blocker_id]) + 1)
		depth_by_id[id] = depth
		max_depth = maxi(max_depth, depth)

	var remaining_blockers: Dictionary = {}
	var branching_sum := 0
	var max_branching := 0
	var min_branching := 0 if steps == 0 else 1 << 30
	var forced_steps := 0
	var ready: Dictionary = {}

	for piece_id in board.pieces:
		var id := String(piece_id)
		remaining_blockers[id] = blockers[id].duplicate()
		if remaining_blockers[id].is_empty():
			ready[id] = true

	for piece_id in solution:
		var legal_count: int = ready.size()
		branching_sum += legal_count
		max_branching = maxi(max_branching, legal_count)
		min_branching = mini(min_branching, legal_count)
		if legal_count == 1:
			forced_steps += 1

		var id := String(piece_id)
		ready.erase(id)
		for dependent_id in dependents[id]:
			var dep := String(dependent_id)
			if not remaining_blockers.has(dep):
				continue
			remaining_blockers[dep].erase(id)
			if remaining_blockers[dep].is_empty():
				ready[dep] = true

	var avg_branching: float = 0.0 if steps == 0 else float(branching_sum) / float(steps)
	var avg_dependencies: float = 0.0 if steps == 0 else float(total_dependencies) / float(steps)
	var forced_ratio: float = 0.0 if steps == 0 else float(forced_steps) / float(steps)
	var density: float = 0.0
	if board.width > 0 and board.height > 0:
		var occupied_cells := 0
		for piece_id in board.pieces:
			occupied_cells += board.pieces[piece_id].cells.size()
		density = float(occupied_cells) / float(board.width * board.height)

	# Score rewards long dependency chains, blocker density and forced sequencing.
	# High branching reduces difficulty because the player has more valid choices.
	var score := 0
	score += steps * 4
	score += max_depth * 18
	score += total_dependencies * 3
	score += max_blockers * 8
	score += int(forced_ratio * 80.0)
	score += int(density * 120.0)
	score -= int(maxf(0.0, avg_branching - 1.0) * 7.0)
	score = maxi(score, 0)

	return {
		"score": score,
		"solution_length": steps,
		"average_legal_moves": avg_branching,
		"max_legal_moves": max_branching,
		"min_legal_moves": 0 if steps == 0 else min_branching,
		"initial_legal_moves": initially_open,
		"dependency_edges": total_dependencies,
		"average_dependencies": avg_dependencies,
		"max_blockers": max_blockers,
		"dependency_depth": max_depth,
		"forced_steps": forced_steps,
		"forced_ratio": forced_ratio,
		"board_density": density,
	}
