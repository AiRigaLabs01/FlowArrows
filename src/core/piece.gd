class_name FlowPiece
extends RefCounted

var id: String
var cells: Array[Vector2i]
var direction: Vector2i

func _init(piece_id: String, occupied_cells: Array[Vector2i], exit_direction: Vector2i) -> void:
	id = piece_id
	cells = occupied_cells.duplicate()
	direction = exit_direction

func copy():
	# Avoid referring to the script's own global class_name in the return type/body.
	# In headless CI the global script-class cache may not be populated yet while
	# this file is being compiled through preload(), which made FlowPiece unresolved.
	return get_script().new(id, cells, direction)
