class_name PieceView
extends Node2D

signal pressed(piece_id: String, view: PieceView)

const LINE_WIDTH := 24.0
const HIT_RADIUS := 44.0
const HEAD_LENGTH := 34.0
const HEAD_WIDTH := 28.0

var piece_id := ""
var cells: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var cell_size := 120.0
var enabled := true
var hinted := false

func setup(id: String, occupied_cells: Array[Vector2i], exit_direction: Vector2i, size: float) -> void:
	piece_id = id
	cells = occupied_cells.duplicate()
	direction = exit_direction
	cell_size = size
	queue_redraw()

func set_enabled(value: bool) -> void:
	enabled = value
	queue_redraw()

func set_hint(value: bool) -> void:
	hinted = value
	queue_redraw()

func _draw() -> void:
	if cells.is_empty():
		return
	var points: Array[Vector2] = _local_points()
	var body_color: Color = Color(0.93, 0.94, 0.97, 1.0) if enabled else Color(0.42, 0.44, 0.49, 1.0)
	if hinted:
		body_color = Color(1.0, 0.82, 0.28, 1.0)
	if points.size() == 1:
		draw_circle(points[0], LINE_WIDTH * 0.55, body_color)
	else:
		draw_polyline(PackedVector2Array(points), body_color, LINE_WIDTH, true)
	var tip: Vector2 = points[-1] + Vector2(direction) * cell_size * 0.30
	var back: Vector2 = tip - Vector2(direction) * HEAD_LENGTH
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var triangle := PackedVector2Array([tip, back + normal * HEAD_WIDTH, back - normal * HEAD_WIDTH])
	draw_colored_polygon(triangle, body_color)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var click_position: Vector2
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_position = to_local(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		click_position = to_local(event.position)
	else:
		return
	if _hit_test(click_position):
		get_viewport().set_input_as_handled()
		pressed.emit(piece_id, self)

func _hit_test(point: Vector2) -> bool:
	var points: Array[Vector2] = _local_points()
	for p: Vector2 in points:
		if point.distance_to(p) <= HIT_RADIUS:
			return true
	for i in range(points.size() - 1):
		if _distance_to_segment(point, points[i], points[i + 1]) <= HIT_RADIUS:
			return true
	return false

func _local_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	var anchor: Vector2i = cells[0]
	for cell: Vector2i in cells:
		result.append((Vector2(cell - anchor) + Vector2(0.5, 0.5)) * cell_size)
	return result

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var length_squared: float = segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
