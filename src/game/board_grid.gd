class_name BoardGrid
extends Node2D

const SUBDIVISIONS := 1

var columns: int = 0
var rows: int = 0
var cell_size: float = 60.0
var dot_radius: float = 1.7
var dot_color := Color(0.55, 0.58, 0.63, 0.48)

func setup(board_columns: int, board_rows: int, size: float) -> void:
	columns = board_columns
	rows = board_rows
	cell_size = size
	dot_radius = clampf(cell_size * 0.045, 1.15, 1.9)
	queue_redraw()

func _draw() -> void:
	if columns <= 0 or rows <= 0:
		return
	var step := cell_size / float(SUBDIVISIONS)
	var total_columns := columns * SUBDIVISIONS
	var total_rows := rows * SUBDIVISIONS
	for y in range(total_rows):
		for x in range(total_columns):
			var point := Vector2((float(x) + 0.5) * step, (float(y) + 0.5) * step)
			draw_circle(point, dot_radius, dot_color)
