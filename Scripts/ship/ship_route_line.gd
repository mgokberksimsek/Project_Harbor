class_name ShipRouteLine
extends Node2D

const SELECTED_COLOR := Color(0.95, 0.12, 0.08, 0.95)
const UNSELECTED_COLOR := Color(0.95, 0.12, 0.08, 0.34)
const SELECTED_WIDTH := 6.0
const UNSELECTED_WIDTH := 3.5
const DASH_LENGTH := 30.0
const GAP_LENGTH := 18.0

var _route_points := PackedVector2Array()
var _progress := 0.0
var _highlighted := false


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 12
	global_position = Vector2.ZERO
	visible = false


func set_route(
		points: PackedVector2Array,
		progress: float,
		highlighted: bool
) -> void:
	_route_points = points
	_progress = clampf(progress, 0.0, 1.0)
	_highlighted = highlighted
	visible = _route_points.size() >= 2 and _progress < 1.0
	queue_redraw()


func clear_route() -> void:
	_route_points.clear()
	_progress = 0.0
	visible = false
	queue_redraw()


func get_remaining_length() -> float:
	return _get_polyline_length(_get_remaining_points())


func _draw() -> void:
	var remaining_points := _get_remaining_points()
	if remaining_points.size() < 2:
		return
	var line_color := SELECTED_COLOR if _highlighted else UNSELECTED_COLOR
	var line_width := SELECTED_WIDTH if _highlighted else UNSELECTED_WIDTH
	var drawing_dash := true
	var phase_remaining := DASH_LENGTH

	for point_index in range(remaining_points.size() - 1):
		var segment_start := remaining_points[point_index]
		var segment_end := remaining_points[point_index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.001:
			continue
		var direction := (segment_end - segment_start) / segment_length
		var travelled := 0.0
		while travelled < segment_length:
			var step := minf(phase_remaining, segment_length - travelled)
			if drawing_dash:
				draw_line(
					segment_start + direction * travelled,
					segment_start + direction * (travelled + step),
					line_color,
					line_width,
					true
				)
			travelled += step
			phase_remaining -= step
			if phase_remaining <= 0.001:
				drawing_dash = not drawing_dash
				phase_remaining = DASH_LENGTH if drawing_dash else GAP_LENGTH


func _get_remaining_points() -> PackedVector2Array:
	if _route_points.size() < 2:
		return PackedVector2Array()
	var total_length := _get_polyline_length(_route_points)
	if total_length <= 0.001:
		return PackedVector2Array()
	var consumed_length := total_length * _progress
	var remaining := PackedVector2Array()
	for point_index in range(_route_points.size() - 1):
		var segment_start := _route_points[point_index]
		var segment_end := _route_points[point_index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if consumed_length >= segment_length:
			consumed_length -= segment_length
			continue
		var segment_progress := 0.0
		if segment_length > 0.001:
			segment_progress = consumed_length / segment_length
		remaining.append(segment_start.lerp(segment_end, segment_progress))
		for remaining_index in range(point_index + 1, _route_points.size()):
			remaining.append(_route_points[remaining_index])
		break
	return remaining


func _get_polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += points[point_index].distance_to(points[point_index + 1])
	return total
