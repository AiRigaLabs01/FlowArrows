class_name BoardState
extends RefCounted

const FlowPieceScript = preload("res://src/core/piece.gd")

var width: int
var height: int
var pieces: Dictionary = {}

func _init(board_width: int, board_height: int, initial_pieces: Array = []) -> void:
	width = board_width
	height = board_height
	for piece in initial_pieces:
		pieces[piece.id] = piece

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height

func occupied_by(cell: Vector2i, ignored_piece_id: String = "") -> String:
	for piece_id in pieces:
		if piece_id == ignored_piece_id:
			continue
		var piece = pieces[piece_id]
		if cell in piece.cells:
			return String(piece_id)
	return ""

func exit_steps(piece_id: String) -> int:
	var analysis: Dictionary = _travel_analysis(piece_id)
	return int(analysis["exit_steps"]) if bool(analysis["can_exit"]) else -1

func blocked_progress(piece_id: String) -> float:
	var analysis: Dictionary = _travel_analysis(piece_id)
	if bool(analysis["can_exit"]):
		return 0.0
	return float(analysis["blocked_progress"])

func _travel_analysis(piece_id: String) -> Dictionary:
	if not pieces.has(piece_id):
		return {"can_exit": false, "exit_steps": -1, "blocked_progress": 0.0}
	var piece = pieces[piece_id]
	if piece.cells.is_empty():
		return {"can_exit": false, "exit_steps": -1, "blocked_progress": 0.0}
	var positions: Array[Vector2i] = piece.cells.duplicate()
	var max_steps: int = width + height + positions.size() + 4
	for step in range(1, max_steps + 1):
		var previous: Array[Vector2i] = positions.duplicate()
		for i in range(positions.size() - 1):
			positions[i] = previous[i + 1]
		positions[-1] = previous[-1] + Vector2i(piece.direction)

		var inside_count := 0
		var own_cells: Dictionary = {}
		for cell: Vector2i in positions:
			if not is_inside(cell):
				continue
			inside_count += 1
			var key := "%d:%d" % [cell.x, cell.y]
			if own_cells.has(key):
				return {"can_exit": false, "exit_steps": -1, "blocked_progress": maxf(0.35, float(step) - 0.22)}
			own_cells[key] = true
			if occupied_by(cell, piece_id) != "":
				# Stop just before the discrete collision cell so the visual thread
				# reaches the obstacle and then reverses without drawing through it.
				return {"can_exit": false, "exit_steps": -1, "blocked_progress": maxf(0.35, float(step) - 0.22)}
		if inside_count == 0:
			return {"can_exit": true, "exit_steps": step, "blocked_progress": 0.0}
	return {"can_exit": false, "exit_steps": -1, "blocked_progress": 0.35}

func can_exit(piece_id: String) -> bool:
	return exit_steps(piece_id) > 0

func legal_moves() -> Array[String]:
	var result: Array[String] = []
	for piece_id in pieces:
		var id := String(piece_id)
		if can_exit(id):
			result.append(id)
	result.sort()
	return result

func remove_piece(piece_id: String) -> bool:
	if not can_exit(piece_id):
		return false
	pieces.erase(piece_id)
	return true

func is_solved() -> bool:
	return pieces.is_empty()

func copy():
	var cloned: Array = []
	for piece_id in pieces:
		cloned.append(pieces[piece_id].copy())
	return get_script().new(width, height, cloned)

func state_key() -> String:
	var ids := pieces.keys()
	ids.sort()
	var strings: Array[String] = []
	for id in ids:
		strings.append(String(id))
	return ",".join(strings)
