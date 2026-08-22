class_name FlowSolver
extends RefCounted

const NO_SOLUTION: Array[String] = []

func solve(initial_state: BoardState) -> Array[String]:
	var visited: Dictionary = {}
	return _search(initial_state.copy(), visited)

func _search(state: BoardState, visited: Dictionary) -> Array[String]:
	if state.is_solved():
		return []
	var key := state.state_key()
	if visited.has(key):
		return NO_SOLUTION
	visited[key] = true
	for piece_id in state.legal_moves():
		var next_state := state.copy()
		if not next_state.remove_piece(piece_id):
			continue
		var tail := _search(next_state, visited)
		if next_state.is_solved() or not tail.is_empty():
			var solution: Array[String] = [piece_id]
			solution.append_array(tail)
			return solution
	return NO_SOLUTION

func is_solvable(state: BoardState) -> bool:
	if state.is_solved():
		return true
	return not solve(state).is_empty()
