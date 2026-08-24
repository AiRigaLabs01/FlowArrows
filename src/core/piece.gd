class_name FlowPiece
extends RefCounted

var id: String
var cells: Array[Vector2i]
var direction: Vector2i

func _init(piece_id: String, occupied_cells: Array[Vector2i], exit_direction: Vector2i) -> void:
	id = piece_id
	cells = occupied_cells.duplicate()
	direction = exit_direction

func copy() -> FlowPiece:
	return FlowPiece.new(id, cells, direction)
