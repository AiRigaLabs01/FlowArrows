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
			return piece_id
	return ""

func can_exit(piece_id: String) -> bool:
	if not pieces.has(piece_id):
		return false
	var piece = pieces[piece_id]
	for origin in piece.cells:
		var cursor := origin + piece.direction
		while is_inside(cursor):
			if occupied_by(cursor, piece_id) != "":
				return false
			cursor += piece.direction
	return true

func legal_moves() -> Array[String]:
	var result: Array[String] = []
	for piece_id in pieces:
		if can_exit(piece_id):
			result.append(piece_id)
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
	return ",".join(ids)
