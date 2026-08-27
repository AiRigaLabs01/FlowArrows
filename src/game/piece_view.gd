class_name PieceView
extends Node2D

signal pressed(piece_id: String, view: PieceView)

const BASE_LINE_WIDTH := 15.0
const BASE_HIT_RADIUS := 38.0
const BASE_HEAD_LENGTH := 24.0
const BASE_HEAD_WIDTH := 16.0
const TRAIL_SPACING_FACTOR := 0.22
const TRAIL_RADIUS_FACTOR := 0.036

var piece_id := ""
var cells: Array[Vector2i] = []
var direction := Vector2i.RIGHT
var cell_size := 120.0
var enabled := true
var hinted := false
var failed_attempt := false
var impact_offset: float = 0.0:
	set(value):
		impact_offset = value
		queue_redraw()
var exit_progress: float = 0.0:
	set(value):
		exit_progress = value
		queue_redraw()

func setup(id: String, occupied_cells: Array[Vector2i], exit_direction: Vector2i, size: float) -> void:
	piece_id = id
	cells = occupied_cells.duplicate()
	direction = exit_direction
	cell_size = size
	impact_offset = 0.0
	exit_progress = 0.0
	queue_redraw()

func set_enabled(value: bool) -> void:
	enabled = value

func set_hint(value: bool) -> void:
	hinted = value
	queue_redraw()

func set_failed(value: bool) -> void:
	failed_attempt = value
	queue_redraw()

func _draw() -> void:
	if cells.is_empty():
		return
	var scale_factor: float = clampf(cell_size / 88.0, 0.66, 1.12)
	var line_width: float = BASE_LINE_WIDTH * scale_factor
	var head_length: float = BASE_HEAD_LENGTH * scale_factor
	var head_width: float = BASE_HEAD_WIDTH * scale_factor

	if exit_progress > 0.01:
		_draw_exit_trail(scale_factor)

	var points: Array[Vector2] = _local_points()
	if points.is_empty():
		return
	var draw_offset: Vector2 = Vector2(direction) * impact_offset
	for i in range(points.size()):
		points[i] += draw_offset

	var body_color := Color(0.93, 0.94, 0.97, 1.0)
	if hinted:
		body_color = Color(1.0, 0.82, 0.28, 1.0)
	if failed_attempt:
		body_color = Color(0.96, 0.24, 0.24, 1.0)

	if points.size() == 1:
		draw_circle(points[0], line_width * 0.50, body_color)
	else:
		draw_polyline(PackedVector2Array(points), body_color, line_width, true)
	var tip: Vector2 = points[-1] + Vector2(direction) * cell_size * 0.26
	var back: Vector2 = tip - Vector2(direction) * head_length
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var triangle := PackedVector2Array([tip, back + normal * head_width, back - normal * head_width])
	draw_colored_polygon(triangle, body_color)

func _draw_exit_trail(scale_factor: float) -> void:
	var trajectory: Array[Vector2] = _original_trajectory()
	if trajectory.size() < 2:
		return
	var vacated_length: float = minf(exit_progress * cell_size, _polyline_length(trajectory))
	if vacated_length <= 0.0:
		return
	var spacing: float = maxf(8.0, cell_size * TRAIL_SPACING_FACTOR)
	var radius: float = maxf(1.8, cell_size * TRAIL_RADIUS_FACTOR * scale_factor)
	var trail_color := Color(0.48, 0.83, 0.78, 0.62)
	var distance: float = 0.0
	while distance <= vacated_length:
		var point: Vector2 = _point_at_distance(trajectory, distance)
		var fade: float = 0.35 + 0.65 * (distance / maxf(vacated_length, 1.0))
		var color := trail_color
		color.a *= fade
		draw_circle(point, radius, color)
		distance += spacing

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
	var hit_radius: float = BASE_HIT_RADIUS * clampf(cell_size / 88.0, 0.76, 1.12)
	var points: Array[Vector2] = _local_points()
	for p: Vector2 in points:
		if point.distance_to(p) <= hit_radius:
			return true
	for i in range(points.size() - 1):
		if _distance_to_segment(point, points[i], points[i + 1]) <= hit_radius:
			return true
	return false

func _local_points() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if cells.is_empty():
		return result
	var trajectory: Array[Vector2] = _extended_trajectory()
	for i in range(cells.size()):
		result.append(_sample_trajectory(trajectory, float(i) + exit_progress))
	return result

func _original_trajectory() -> Array[Vector2]:
	var trajectory: Array[Vector2] = []
	if cells.is_empty():
		return trajectory
	var anchor: Vector2i = cells[0]
	for cell: Vector2i in cells:
		trajectory.append((Vector2(cell - anchor) + Vector2(0.5, 0.5)) * cell_size)
	return trajectory

func _extended_trajectory() -> Array[Vector2]:
	var trajectory: Array[Vector2] = _original_trajectory()
	if trajectory.is_empty():
		return trajectory
	var extension_start: Vector2 = trajectory[-1]
	for i in range(1, 32):
		trajectory.append(extension_start + Vector2(direction) * cell_size * float(i))
	return trajectory

func _polyline_length(points: Array[Vector2]) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func _point_at_distance(points: Array[Vector2], distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var remaining := maxf(distance, 0.0)
	for i in range(points.size() - 1):
		var segment_length: float = points[i].distance_to(points[i + 1])
		if remaining <= segment_length:
			var t: float = remaining / maxf(segment_length, 0.001)
			return points[i].lerp(points[i + 1], t)
		remaining -= segment_length
	return points[-1]

func _sample_trajectory(trajectory: Array[Vector2], index_position: float) -> Vector2:
	var base_index: int = int(floor(index_position))
	var fraction: float = index_position - float(base_index)
	if base_index >= trajectory.size() - 1:
		return trajectory[-1] + Vector2(direction) * cell_size * (index_position - float(trajectory.size() - 1))
	var start: Vector2 = trajectory[maxi(base_index, 0)]
	var finish: Vector2 = trajectory[mini(base_index + 1, trajectory.size() - 1)]
	return start.lerp(finish, fraction)

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var length_squared: float = segment.length_squared()
	if is_zero_approx(length_squared):
		return point.distance_to(start)
	var t: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * t)
