class_name FlowValidator
extends RefCounted

const DependencySolverScript = preload("res://src/core/dependency_solver.gd")

func validate(board) -> Dictionary:
	var errors: Array[String] = []
	var seen_cells: Dictionary = {}

	if board.width <= 0 or board.height <= 0:
		errors.append("Board dimensions must be positive")

	for piece_id in board.pieces:
		var piece = board.pieces[piece_id]
		if piece.cells.is_empty():
			errors.append("Piece %s has no cells" % piece_id)
		if piece.direction not in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			errors.append("Piece %s has invalid direction" % piece_id)
		if not _is_connected_path(piece.cells):
			errors.append("Piece %s cells must form a connected orthogonal path" % piece_id)
		for cell in piece.cells:
			if not board.is_inside(cell):
				errors.append("Piece %s occupies out-of-bounds cell %s" % [piece_id, cell])
			var key := "%d:%d" % [cell.x, cell.y]
			if seen_cells.has(key):
				errors.append("Cell %s is occupied by multiple pieces" % cell)
			else:
				seen_cells[key] = piece_id

	var solver = DependencySolverScript.new()
	var solution := solver.solve(board)
	if not board.is_solved() and solution.is_empty():
		errors.append("Board is not solvable")

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"solution": solution,
	}

func _is_connected_path(cells: Array[Vector2i]) -> bool:
	if cells.size() <= 1:
		return true
	var seen: Dictionary = {}
	for i in range(cells.size()):
		var cell: Vector2i = cells[i]
		var key := "%d:%d" % [cell.x, cell.y]
		if seen.has(key):
			return false
		seen[key] = true
		if i == 0:
			continue
		var previous: Vector2i = cells[i - 1]
		var delta: Vector2i = cell - previous
		if abs(delta.x) + abs(delta.y) != 1:
			return false
	return true
