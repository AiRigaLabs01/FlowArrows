class_name DependencySolver
extends RefCounted

# Exact solver for the current monotonic rules: pieces only disappear and never move
# until they exit. For every piece, compute the fixed set of pieces intersecting
# its complete exit sweep. Solvability then reduces to topological elimination.

func solve(initial_state) -> Array[String]:
	var graph: Dictionary = build_graph(initial_state)
	var blockers: Dictionary = graph["blockers"]
	var dependents: Dictionary = graph["dependents"]
	var remaining: Dictionary = {}
	var ready: Array[String] = []

	for piece_id in initial_state.pieces:
		var id := String(piece_id)
		remaining[id] = true
		if blockers[id].is_empty():
			ready.append(id)
	ready.sort()

	var solution: Array[String] = []
	while not ready.is_empty():
		var id: String = ready.pop_front()
		if not remaining.has(id):
			continue
		remaining.erase(id)
		solution.append(id)
		for dependent in dependents[id]:
			var dependent_id := String(dependent)
			if not remaining.has(dependent_id):
				continue
			blockers[dependent_id].erase(id)
			if blockers[dependent_id].is_empty() and not ready.has(dependent_id):
				ready.append(dependent_id)
		ready.sort()

	if not remaining.is_empty():
		return []
	return solution

func is_solvable(initial_state) -> bool:
	if initial_state.is_solved():
		return true
	return solve(initial_state).size() == initial_state.pieces.size()

func build_graph(state) -> Dictionary:
	var blockers: Dictionary = {}
	var dependents: Dictionary = {}
	var occupancy: Dictionary = {}

	for piece_id in state.pieces:
		var id := String(piece_id)
		blockers[id] = {}
		dependents[id] = []
		var piece = state.pieces[id]
		for cell: Vector2i in piece.cells:
			if state.is_inside(cell):
				occupancy[_cell_key(cell)] = id

	for piece_id in state.pieces:
		var id := String(piece_id)
		var piece = state.pieces[id]
		var swept_cells: Array[Vector2i] = _exit_sweep_cells(state, piece)
		for cell: Vector2i in swept_cells:
			var key := _cell_key(cell)
			if not occupancy.has(key):
				continue
			var blocker_id := String(occupancy[key])
			if blocker_id == id:
				continue
			blockers[id][blocker_id] = true

	for id in blockers:
		for blocker_id in blockers[id]:
			dependents[blocker_id].append(String(id))

	return {
		"blockers": blockers,
		"dependents": dependents,
	}

func _exit_sweep_cells(state, piece) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary = {}
	var positions: Array[Vector2i] = piece.cells.duplicate()
	var max_steps: int = state.width + state.height + positions.size() + 4

	for _step in range(max_steps):
		var inside_count := 0
		for cell: Vector2i in positions:
			if not state.is_inside(cell):
				continue
			inside_count += 1
			var key := _cell_key(cell)
			if not seen.has(key):
				seen[key] = true
				result.append(cell)
		if inside_count == 0:
			break
		var previous: Array[Vector2i] = positions.duplicate()
		for i in range(positions.size() - 1):
			positions[i] = previous[i + 1]
		positions[-1] = previous[-1] + Vector2i(piece.direction)

	return result

func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
