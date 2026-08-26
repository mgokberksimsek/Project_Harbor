class_name ShipRouteLine
extends Node2D

const SELECTED_COLOR := Color(0.95, 0.12, 0.08, 0.95)
const UNSELECTED_COLOR := Color(0.95, 0.12, 0.08, 0.34)
const SELECTED_WIDTH := 6.0
const UNSELECTED_WIDTH := 3.5
const DASH_LENGTH := 30.0
const GAP_LENGTH := 18.0
const REVERSE_OVERLAP_TOLERANCE_PX := 10.0
const REVERSE_DIRECTION_DOT_LIMIT := -0.92

var _route_points := PackedVector2Array()
var _hidden_reverse_segments: Array[bool] = []
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
	if _route_points != points:
		_route_points = points
		_hidden_reverse_segments = _get_hidden_reverse_overlap_segments(
			_route_points
		)
	_progress = clampf(progress, 0.0, 1.0)
	_highlighted = highlighted
	visible = _route_points.size() >= 2 and _progress < 1.0
	queue_redraw()


func clear_route() -> void:
	_route_points.clear()
	_hidden_reverse_segments.clear()
	_progress = 0.0
	visible = false
	queue_redraw()


func get_remaining_length() -> float:
	return _get_polyline_length(_get_remaining_points())


func _draw() -> void:
	var line_color := SELECTED_COLOR if _highlighted else UNSELECTED_COLOR
	var line_width := SELECTED_WIDTH if _highlighted else UNSELECTED_WIDTH
	for dash_segment in get_visible_dash_segments():
		draw_line(
			dash_segment[0],
			dash_segment[1],
			line_color,
			line_width,
			true
		)


func get_visible_dash_segments() -> Array[PackedVector2Array]:
	var visible_segments: Array[PackedVector2Array] = []
	if _route_points.size() < 2:
		return visible_segments
	var total_length := _get_polyline_length(_route_points)
	if total_length <= 0.001:
		return visible_segments
	var consumed_length := total_length * _progress
	var drawing_dash := true
	var phase_remaining := DASH_LENGTH
	var route_distance := 0.0

	# Walk the complete route so the dash/gap phase always stays anchored to
	# the original path. Progress only clips travelled portions; it never
	# shifts the dashes that are still ahead of the ship.
	for point_index in range(_route_points.size() - 1):
		var segment_start := _route_points[point_index]
		var segment_end := _route_points[point_index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if segment_length <= 0.001:
			continue
		var direction := (segment_end - segment_start) / segment_length
		var travelled := 0.0
		while travelled < segment_length:
			var step := minf(phase_remaining, segment_length - travelled)
			var piece_start_distance := route_distance + travelled
			var piece_end_distance := piece_start_distance + step
			if drawing_dash \
					and not _hidden_reverse_segments[point_index] \
					and piece_end_distance > consumed_length:
				var visible_start_offset := travelled + maxf(
					consumed_length - piece_start_distance,
					0.0
				)
				var visible_start := segment_start + direction * visible_start_offset
				var visible_end := segment_start + direction * (travelled + step)
				if visible_start.distance_squared_to(visible_end) > 0.001:
					visible_segments.append(PackedVector2Array([
						visible_start,
						visible_end,
					]))
			travelled += step
			phase_remaining -= step
			if phase_remaining <= 0.001:
				drawing_dash = not drawing_dash
				phase_remaining = DASH_LENGTH if drawing_dash else GAP_LENGTH
		route_distance += segment_length
	return visible_segments


func _get_hidden_reverse_overlap_segments(
		points: PackedVector2Array
) -> Array[bool]:
	var hidden_segments: Array[bool] = []
	hidden_segments.resize(maxi(points.size() - 1, 0))
	hidden_segments.fill(false)
	for segment_index in range(hidden_segments.size()):
		var segment_start := points[segment_index]
		var segment_end := points[segment_index + 1]
		var segment_direction := segment_end - segment_start
		if segment_direction.length_squared() <= 0.001:
			continue
		segment_direction = segment_direction.normalized()
		var segment_midpoint := (segment_start + segment_end) * 0.5
		# Prefer the later occurrence. During the pickup leg this keeps a shared
		# corridor visible because the ship still needs to traverse it again.
		for later_index in range(segment_index + 1, hidden_segments.size()):
			var later_start := points[later_index]
			var later_end := points[later_index + 1]
			var later_direction := later_end - later_start
			if later_direction.length_squared() <= 0.001:
				continue
			later_direction = later_direction.normalized()
			if segment_direction.dot(later_direction) > REVERSE_DIRECTION_DOT_LIMIT:
				continue
			var closest_point := Geometry2D.get_closest_point_to_segment(
				segment_midpoint,
				later_start,
				later_end
			)
			if segment_midpoint.distance_to(closest_point) \
					> REVERSE_OVERLAP_TOLERANCE_PX:
				continue
			hidden_segments[segment_index] = true
			break
	return hidden_segments


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
