class_name DifficultyEstimator
extends RefCounted

func estimate(board, solution: Array[String]) -> Dictionary:
	var branching_sum: int = 0
	var max_branching: int = 0
	var state = board.copy()

	for piece_id in solution:
		var legal: Array[String] = state.legal_moves()
		branching_sum += legal.size()
		max_branching = max(max_branching, legal.size())
		state.remove_piece(piece_id)

	var steps: int = solution.size()
	var avg_branching: float = 0.0 if steps == 0 else float(branching_sum) / float(steps)
	var score: int = steps * 10 + int(avg_branching * 5.0) + max_branching * 3

	return {
		"score": score,
		"solution_length": steps,
		"average_legal_moves": avg_branching,
		"max_legal_moves": max_branching,
	}
