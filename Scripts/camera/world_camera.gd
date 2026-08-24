class_name WorldCamera
extends Camera2D

signal map_tapped(screen_position: Vector2)

const WORLD_SIZE := Vector2(6000.0, 3500.0)
const MIN_ZOOM := 0.45
const MAX_ZOOM := 1.30
const ZOOM_STEP := 0.10
const DOUBLE_TAP_OVERVIEW_ZOOM := 0.65
const DOUBLE_TAP_NEAR_ZOOM := 1.00
const DOUBLE_TAP_ZOOM_THRESHOLD := 0.90
const DOUBLE_TAP_ZOOM_DURATION_SEC := 0.28
const TAP_DRAG_THRESHOLD_PX := 32.0
const PAN_DRAG_SENSITIVITY := 0.70
const PAN_INERTIA_DAMPING := 3.5
const PAN_INERTIA_MAX_SPEED_PX := 2400.0
const PAN_INERTIA_STOP_SPEED_PX := 20.0

var _mouse_dragging := false
var _mouse_pointer_active := false
var _mouse_press_position := Vector2.ZERO
var _mouse_dragged := false
var _mouse_tap_consumed := false
var _touches: Dictionary = {}
var _touch_starts: Dictionary = {}
var _touch_dragged: Dictionary = {}
var _touch_consumed: Dictionary = {}
var _pan_velocity_screen := Vector2.ZERO
var _zoom_tween: Tween = null


func _ready() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(WORLD_SIZE.x)
	limit_bottom = int(WORLD_SIZE.y)
	limit_smoothed = false
	position = _clamp_camera_position(position)


func _process(delta: float) -> void:
	if _mouse_pointer_active or not _touches.is_empty():
		return
	if _pan_velocity_screen.length() < PAN_INERTIA_STOP_SPEED_PX:
		_pan_velocity_screen = Vector2.ZERO
		return
	var previous_position := position
	pan_by_screen_delta(_pan_velocity_screen * delta)
	if position.is_equal_approx(previous_position):
		_pan_velocity_screen = Vector2.ZERO
		return
	_pan_velocity_screen *= exp(-PAN_INERTIA_DAMPING * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
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


func animate_double_tap_zoom(screen_position: Vector2) -> void:
	_stop_pan_inertia()
	_stop_zoom_animation()
	var target_zoom := DOUBLE_TAP_NEAR_ZOOM \
			if zoom.x < DOUBLE_TAP_ZOOM_THRESHOLD \
			else DOUBLE_TAP_OVERVIEW_ZOOM
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(
		_apply_animated_zoom.bind(screen_position),
		zoom.x,
		target_zoom,
		DOUBLE_TAP_ZOOM_DURATION_SEC
	)
	_zoom_tween.tween_callback(_finish_zoom_animation)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_stop_pan_inertia()
			_stop_zoom_animation()
			_mouse_pointer_active = true
			_mouse_press_position = event.position
			_mouse_dragged = false
			_mouse_tap_consumed = try_select_ship_at_screen_position(event.position)
			if event.double_click \
					and not _mouse_tap_consumed \
					and not _is_port_at_screen_position(event.position):
				animate_double_tap_zoom(event.position)
				_mouse_tap_consumed = true
			_mouse_dragging = not _mouse_tap_consumed
			if _mouse_tap_consumed:
				get_viewport().set_input_as_handled()
			return
		if not _mouse_pointer_active:
			return
		var is_map_tap := not _mouse_tap_consumed \
				and not _mouse_dragged \
				and _mouse_press_position.distance_to(event.position) <= TAP_DRAG_THRESHOLD_PX
		_mouse_pointer_active = false
		_mouse_dragging = false
		_mouse_tap_consumed = false
		if is_map_tap:
			map_tapped.emit(event.position)
			get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_stop_pan_inertia()
		_stop_zoom_animation()
		zoom_at_screen_position(zoom.x + ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_stop_pan_inertia()
		_stop_zoom_animation()
		zoom_at_screen_position(zoom.x - ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if not _mouse_dragging:
		return
	if _mouse_press_position.distance_to(event.position) > TAP_DRAG_THRESHOLD_PX:
		_mouse_dragged = true
	if not _mouse_dragged:
		return
	pan_by_screen_delta(event.relative * PAN_DRAG_SENSITIVITY)
	_capture_pan_velocity(event.velocity, event.relative)
	get_viewport().set_input_as_handled()


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_stop_pan_inertia()
		_stop_zoom_animation()
		_touches[event.index] = event.position
		_touch_starts[event.index] = event.position
		_touch_dragged[event.index] = false
		_touch_consumed[event.index] = try_select_ship_at_screen_position(event.position)
		if event.double_tap \
				and not bool(_touch_consumed[event.index]) \
				and not _is_port_at_screen_position(event.position):
			animate_double_tap_zoom(event.position)
			_touch_consumed[event.index] = true
		if _touches.size() > 1:
			for active_index in _touches.keys():
				_touch_dragged[active_index] = true
		if bool(_touch_consumed[event.index]):
			get_viewport().set_input_as_handled()
	else:
		if not _touch_starts.has(event.index):
			return
		var start_position: Vector2 = _touch_starts[event.index]
		var is_map_tap := not bool(_touch_consumed.get(event.index, false)) \
				and not bool(_touch_dragged.get(event.index, false)) \
				and start_position.distance_to(event.position) <= TAP_DRAG_THRESHOLD_PX
		_touches.erase(event.index)
		_touch_starts.erase(event.index)
		_touch_dragged.erase(event.index)
		_touch_consumed.erase(event.index)
		if is_map_tap:
			map_tapped.emit(event.position)
			get_viewport().set_input_as_handled()


func try_select_ship_at_screen_position(screen_position: Vector2) -> bool:
	var selected_ship: Node2D = null
	for hit in _get_area_hits_at_screen_position(screen_position):
		var collider := hit.get("collider") as Node2D
		if collider != null \
				and collider.is_in_group(&"ships") \
				and (selected_ship == null or collider.z_index > selected_ship.z_index):
			selected_ship = collider
	if selected_ship == null:
		return false
	get_node("/root/EventBus").ship_tapped.emit(StringName(selected_ship.get("ship_id")))
	return true


func _is_port_at_screen_position(screen_position: Vector2) -> bool:
	for hit in _get_area_hits_at_screen_position(screen_position):
		var collider := hit.get("collider") as Node
		if collider != null and collider.is_in_group(&"ports"):
			return true
	return false


func _get_area_hits_at_screen_position(screen_position: Vector2) -> Array[Dictionary]:
	var world_position := get_viewport().get_canvas_transform().affine_inverse() \
			* screen_position
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return get_world_2d().direct_space_state.intersect_point(query, 32)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var start_position: Vector2 = _touch_starts[event.index]
	if start_position.distance_to(event.position) > TAP_DRAG_THRESHOLD_PX:
		_touch_dragged[event.index] = true

	if _touches.size() == 1:
		_touches[event.index] = event.position
		if bool(_touch_dragged[event.index]):
			pan_by_screen_delta(event.relative * PAN_DRAG_SENSITIVITY)
			_capture_pan_velocity(event.velocity, event.relative)
	else:
		_stop_pan_inertia()
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


func _capture_pan_velocity(event_velocity: Vector2, relative: Vector2) -> void:
	var candidate := event_velocity
	if candidate.is_zero_approx() and not relative.is_zero_approx():
		candidate = relative * 60.0
	candidate *= PAN_DRAG_SENSITIVITY
	_pan_velocity_screen = candidate.limit_length(PAN_INERTIA_MAX_SPEED_PX)


func _stop_pan_inertia() -> void:
	_pan_velocity_screen = Vector2.ZERO


func _apply_animated_zoom(value: float, screen_position: Vector2) -> void:
	zoom_at_screen_position(value, screen_position)


func _finish_zoom_animation() -> void:
	_zoom_tween = null


func _stop_zoom_animation() -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = null


func _clamp_camera_position(candidate: Vector2) -> Vector2:
	var half_visible := get_viewport_rect().size * 0.5 / zoom.x
	var minimum := half_visible
	var maximum := WORLD_SIZE - half_visible
	return Vector2(
		clampf(candidate.x, minimum.x, maximum.x),
		clampf(candidate.y, minimum.y, maximum.y)
	)
