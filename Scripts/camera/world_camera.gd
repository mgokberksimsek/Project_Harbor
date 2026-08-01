class_name WorldCamera
extends Camera2D

const WORLD_SIZE := Vector2(6000.0, 3500.0)
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.30
const ZOOM_STEP := 0.10

var _mouse_dragging := false
var _touches: Dictionary = {}


func _ready() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(WORLD_SIZE.x)
	limit_bottom = int(WORLD_SIZE.y)
	limit_smoothed = false
	position = _clamp_camera_position(position)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_dragging:
		pan_by_screen_delta(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func pan_by_screen_delta(screen_delta: Vector2) -> void:
	position -= screen_delta / zoom.x
	position = _clamp_camera_position(position)


func zoom_at_screen_position(target_zoom: float, screen_position: Vector2) -> void:
	var clamped_zoom := clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped_zoom, zoom.x):
		return

	var viewport_center := get_viewport_rect().size * 0.5
	var world_anchor := position + (screen_position - viewport_center) / zoom.x
	zoom = Vector2.ONE * clamped_zoom
	position = world_anchor - (screen_position - viewport_center) / zoom.x
	position = _clamp_camera_position(position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and try_select_ship_at_screen_position(event.position):
			_mouse_dragging = false
			get_viewport().set_input_as_handled()
			return
		_mouse_dragging = event.pressed
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_screen_position(zoom.x + ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_screen_position(zoom.x - ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if try_select_ship_at_screen_position(event.position):
			get_viewport().set_input_as_handled()
	else:
		_touches.erase(event.index)


func try_select_ship_at_screen_position(screen_position: Vector2) -> bool:
	var world_position := get_viewport().get_canvas_transform().affine_inverse() \
		* screen_position
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = get_world_2d().direct_space_state.intersect_point(query, 32)
	var selected_ship: Ship = null
	for hit in hits:
		var collider: Object = hit.get("collider") as Object
		if collider is Ship and (
			selected_ship == null or collider.z_index > selected_ship.z_index
		):
			selected_ship = collider
	if selected_ship == null:
		return false
	EventBus.ship_tapped.emit(selected_ship.ship_id)
	return true


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return

	if _touches.size() == 1:
		_touches[event.index] = event.position
		pan_by_screen_delta(event.relative)
	else:
		var indices := _touches.keys()
		if indices.size() < 2:
			return
		var first_index: int = indices[0]
		var second_index: int = indices[1]
		var previous_first: Vector2 = _touches[first_index]
		var previous_second: Vector2 = _touches[second_index]
		_touches[event.index] = event.position
		var current_first: Vector2 = _touches[first_index]
		var current_second: Vector2 = _touches[second_index]
		var previous_distance := previous_first.distance_to(previous_second)
		var current_distance := current_first.distance_to(current_second)
		if previous_distance > 0.001:
			var midpoint := (current_first + current_second) * 0.5
			zoom_at_screen_position(zoom.x * current_distance / previous_distance, midpoint)
	get_viewport().set_input_as_handled()


func _clamp_camera_position(candidate: Vector2) -> Vector2:
	var half_visible := get_viewport_rect().size * 0.5 / zoom.x
	var minimum := half_visible
	var maximum := WORLD_SIZE - half_visible
	return Vector2(
		clampf(candidate.x, minimum.x, maximum.x),
		clampf(candidate.y, minimum.y, maximum.y)
	)
