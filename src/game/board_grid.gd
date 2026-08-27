class_name BoardGrid
extends Node2D

var columns: int = 0
var rows: int = 0
var cell_size: float = 60.0
var dot_radius: float = 2.2
var dot_color := Color(0.42, 0.45, 0.50, 0.34)

func setup(board_columns: int, board_rows: int, size: float) -> void:
	columns = board_columns
	rows = board_rows
	cell_size = size
	dot_radius = clampf(cell_size * 0.035, 1.5, 2.5)
	queue_redraw()

func _draw() -> void:
	if columns <= 0 or rows <= 0:
		return
	for y in range(rows):
		for x in range(columns):
			var point := Vector2((float(x) + 0.5) * cell_size, (float(y) + 0.5) * cell_size)
			draw_circle(point, dot_radius, dot_color)
