class_name WorldCamera
extends Camera2D

signal map_tapped(screen_position: Vector2)

const WORLD_SIZE := Vector2(6000.0, 3500.0)
# Normal interactive zoom limit. The whole-map cinematic view is a separate
# camera state instead of weakening normal map navigation.
const MIN_ZOOM := 0.40
const MAX_ZOOM := 1.30
const ZOOM_STEP := 0.10
const DOUBLE_TAP_OVERVIEW_ZOOM := 0.65
const DOUBLE_TAP_NEAR_ZOOM := 1.00
const DOUBLE_TAP_ZOOM_THRESHOLD := 0.90
const DOUBLE_TAP_ZOOM_DURATION_SEC := 0.28
const WORLD_FOCUS_DURATION_SEC := 0.35
const CINEMATIC_TRIGGER_PULL := 0.055
const CINEMATIC_VIEW_PADDING := 0.94
const CINEMATIC_ZOOM_DURATION_SEC := 0.45
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
var _cinematic_overview_active := false
var _cinematic_exit_in_progress := false
var _cinematic_zoom_pull := 0.0


func _ready() -> void:
	_apply_normal_camera_limits()
	limit_smoothed = false
	position = _clamp_camera_position(position)


func _apply_normal_camera_limits() -> void:
	limit_left = 0
	limit_top = 0
	limit_right = int(WORLD_SIZE.x)
	limit_bottom = int(WORLD_SIZE.y)


func _apply_cinematic_camera_limits() -> void:
	limit_left = -int(WORLD_SIZE.x)
	limit_top = -int(WORLD_SIZE.y)
	limit_right = int(WORLD_SIZE.x * 2.0)
	limit_bottom = int(WORLD_SIZE.y * 2.0)


func _process(delta: float) -> void:
	if _is_cinematic_camera_locked():
		return
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
	if _is_cinematic_camera_locked():
		return
	position -= screen_delta / zoom.x
	position = _clamp_camera_position(position)


func zoom_at_screen_position(target_zoom: float, screen_position: Vector2) -> void:
	if _is_cinematic_camera_locked():
		return
	var clamped_zoom := clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(clamped_zoom, zoom.x):
		return

	var viewport_center := get_viewport_rect().size * 0.5
	var world_anchor := position + (screen_position - viewport_center) / zoom.x
	zoom = Vector2.ONE * clamped_zoom
	position = world_anchor - (screen_position - viewport_center) / zoom.x
	position = _clamp_camera_position(position)


func focus_world_position(world_position: Vector2) -> void:
	_stop_pan_inertia()
	_stop_zoom_animation()
	var target_zoom := clampf(zoom.x, MIN_ZOOM, MAX_ZOOM)
	_cinematic_overview_active = false
	_cinematic_exit_in_progress = false
	_cinematic_zoom_pull = 0.0
	_apply_normal_camera_limits()
	_animate_camera_to(
		target_zoom,
		_clamp_camera_position_for_zoom(world_position, target_zoom),
		WORLD_FOCUS_DURATION_SEC
	)


func animate_double_tap_zoom(screen_position: Vector2) -> void:
	_stop_pan_inertia()
	if _cinematic_overview_active:
		_stop_zoom_animation()
		_exit_cinematic_overview()
		return
	if _cinematic_exit_in_progress:
		return
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
			if not _is_cinematic_camera_locked():
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
		if _cinematic_overview_active:
			_exit_cinematic_overview()
		elif not _cinematic_exit_in_progress:
			_stop_zoom_animation()
			zoom_at_screen_position(zoom.x + ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_stop_pan_inertia()
		if not _is_cinematic_camera_locked():
			_stop_zoom_animation()
			if zoom.x <= MIN_ZOOM + 0.001:
				_enter_cinematic_overview()
			else:
				zoom_at_screen_position(zoom.x - ZOOM_STEP, event.position)
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if _is_cinematic_camera_locked():
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
		if not _is_cinematic_camera_locked():
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
		if _touches.size() < 2:
			_cinematic_zoom_pull = 0.0
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
		if bool(_touch_dragged[event.index]) and not _is_cinematic_camera_locked():
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
			var target_zoom := zoom.x * current_distance / previous_distance
			if _cinematic_overview_active:
				if target_zoom > zoom.x:
					_exit_cinematic_overview()
			elif _cinematic_exit_in_progress:
				pass
			elif target_zoom < MIN_ZOOM:
				zoom_at_screen_position(MIN_ZOOM, midpoint)
				_cinematic_zoom_pull += MIN_ZOOM - target_zoom
				if _cinematic_zoom_pull >= CINEMATIC_TRIGGER_PULL:
					_enter_cinematic_overview()
			else:
				_cinematic_zoom_pull = 0.0
				zoom_at_screen_position(target_zoom, midpoint)
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


func _enter_cinematic_overview() -> void:
	if _cinematic_overview_active:
		return
	_stop_pan_inertia()
	_stop_zoom_animation()
	_cinematic_overview_active = true
	_cinematic_exit_in_progress = false
	_cinematic_zoom_pull = 0.0
	_apply_cinematic_camera_limits()
	_animate_camera_to(
		_get_cinematic_overview_zoom(),
		WORLD_SIZE * 0.5,
		CINEMATIC_ZOOM_DURATION_SEC
	)


func _exit_cinematic_overview() -> void:
	if not _cinematic_overview_active:
		return
	_stop_zoom_animation()
	_cinematic_overview_active = false
	_cinematic_exit_in_progress = true
	_cinematic_zoom_pull = 0.0
	_animate_camera_to(
		MIN_ZOOM,
		WORLD_SIZE * 0.5,
		CINEMATIC_ZOOM_DURATION_SEC,
		true
	)


func _animate_camera_to(
		target_zoom: float,
		target_position: Vector2,
		duration_sec: float,
		finishes_cinematic_exit := false
) -> void:
	var start_zoom := zoom.x
	var start_position := position
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_method(
		_apply_camera_transition.bind(
			start_zoom,
			target_zoom,
			start_position,
			target_position
		),
		0.0,
		1.0,
		duration_sec
	)
	if finishes_cinematic_exit:
		_zoom_tween.tween_callback(_finish_cinematic_exit)
	else:
		_zoom_tween.tween_callback(_finish_zoom_animation)


func _apply_camera_transition(
		progress: float,
		start_zoom: float,
		target_zoom: float,
		start_position: Vector2,
		target_position: Vector2
) -> void:
	zoom = Vector2.ONE * lerpf(start_zoom, target_zoom, progress)
	position = start_position.lerp(target_position, progress)


func _get_cinematic_overview_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	var fit_zoom := minf(
		viewport_size.x / WORLD_SIZE.x,
		viewport_size.y / WORLD_SIZE.y
	) * CINEMATIC_VIEW_PADDING
	return clampf(fit_zoom, 0.05, MIN_ZOOM - 0.05)


func _finish_cinematic_exit() -> void:
	_cinematic_exit_in_progress = false
	_apply_normal_camera_limits()
	position = _clamp_camera_position(position)
	_finish_zoom_animation()


func _is_cinematic_camera_locked() -> bool:
	return _cinematic_overview_active or _cinematic_exit_in_progress


func _clamp_camera_position(candidate: Vector2) -> Vector2:
	return _clamp_camera_position_for_zoom(candidate, zoom.x)


func _clamp_camera_position_for_zoom(candidate: Vector2, zoom_value: float) -> Vector2:
	var half_visible := get_viewport_rect().size * 0.5 / maxf(zoom_value, 0.001)
	var minimum := half_visible
	var maximum := WORLD_SIZE - half_visible
	return Vector2(
		clampf(candidate.x, minimum.x, maximum.x),
		clampf(candidate.y, minimum.y, maximum.y)
	)
