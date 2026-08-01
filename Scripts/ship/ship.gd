class_name Ship
extends Area2D

@export var ship_id: StringName = &""
@export var ship_data: ShipData
@export var home_port_id: StringName = &""

@onready var _icon: Sprite2D = $Icon
@onready var _status_label: Label = $StatusLabel
@onready var _route_line: ShipRouteLine = $RouteLine

const DOCK_REPOSITION_SPEED := 300.0
const TURN_SPRING_STRENGTH := 22.0
const TURN_DAMPING := 8.0
const MAX_TURN_SPEED_RAD_PER_SEC := 4.5
const MIN_HEADING_MOVEMENT_SQUARED := 0.01
const ROUTE_TANGENT_SAMPLE_PROGRESS := 0.015
const DOCK_TRANSITION_DURATION_SEC := 0.9

var _sailing_route_points := PackedVector2Array()
var _is_selected := false
var _turn_velocity := 0.0
var _departure_start_rotation := 0.0
var _preparing_departure_heading := false
var _dock_transition_active := false
var _dock_transition_elapsed := 0.0
var _dock_transition_start := Vector2.ZERO


func _ready() -> void:
	if ship_id == &"" or ship_data == null or home_port_id == &"":
		push_error("Ship instance '%s' is missing ship_id, ShipData, or home_port_id." % name)
		return

	if ship_data.icon != null:
		_icon.texture = ship_data.icon
	_icon.scale = Vector2.ONE * clampf(ship_data.sprite_scale, 0.1, 2.0)

	FleetManager.register_ship(ship_id, ship_data, home_port_id, self)
	EventBus.ship_state_changed.connect(_on_ship_state_changed)
	EventBus.ship_dock_slot_changed.connect(_on_ship_dock_slot_changed)
	EventBus.ship_tapped.connect(_on_any_ship_tapped)
	input_event.connect(_on_input_event)

	call_deferred("_snap_to_home_port")
	_refresh_visuals()


func _process(delta: float) -> void:
	var previous_position := global_position
	var state := FleetManager.get_ship_state(ship_id)
	var sailing_to_pickup: bool = state == ShipRuntimeState.State.SAILING_TO_PICKUP
	var sailing_to_delivery: bool = state == ShipRuntimeState.State.SAILING_TO_DELIVERY
	var heading_locked_to_route := false
	var heading_prepared_for_departure := false
	if sailing_to_pickup or sailing_to_delivery:
		heading_locked_to_route = _update_sailing_position(state)
	else:
		_update_docked_position(delta)
	if state == ShipRuntimeState.State.LOADING:
		heading_prepared_for_departure = _update_pre_departure_heading()
	if not heading_locked_to_route and not heading_prepared_for_departure:
		_update_heading(previous_position, delta)
	_update_route_visual(state)


func _snap_to_home_port() -> void:
	var dock_position := FleetManager.get_ship_dock_position(ship_id)
	if dock_position != Vector2.ZERO:
		global_position = dock_position
	else:
		push_warning("Ship '%s': home port '%s' has no dock position." % [ship_id, home_port_id])


func _update_docked_position(delta: float) -> void:
	var dock_position := FleetManager.get_ship_dock_position(ship_id)
	if dock_position == Vector2.ZERO:
		return
	if _dock_transition_active:
		_dock_transition_elapsed += delta
		var linear_progress := clampf(
			_dock_transition_elapsed / DOCK_TRANSITION_DURATION_SEC,
			0.0,
			1.0
		)
		var smooth_progress := linear_progress * linear_progress \
			* (3.0 - 2.0 * linear_progress)
		global_position = _dock_transition_start.lerp(
			dock_position,
			smooth_progress
		)
		if linear_progress >= 1.0:
			_dock_transition_active = false
		return
	global_position = global_position.move_toward(
		dock_position,
		DOCK_REPOSITION_SPEED * delta
	)


func _update_heading(previous_position: Vector2, delta: float) -> void:
	var movement := global_position - previous_position
	if movement.length_squared() < MIN_HEADING_MOVEMENT_SQUARED:
		_turn_velocity *= exp(-TURN_DAMPING * delta)
		return
	var target_rotation := calculate_visual_rotation(
		movement.normalized(),
		ship_data.sprite_forward_angle_rad
	)
	var angle_error := wrapf(target_rotation - _icon.rotation, -PI, PI)
	_turn_velocity += angle_error * TURN_SPRING_STRENGTH * delta
	_turn_velocity *= exp(-TURN_DAMPING * delta)
	_turn_velocity = clampf(
		_turn_velocity,
		-MAX_TURN_SPEED_RAD_PER_SEC,
		MAX_TURN_SPEED_RAD_PER_SEC
	)
	_icon.rotation = wrapf(_icon.rotation + _turn_velocity * delta, -PI, PI)


func _update_pre_departure_heading() -> bool:
	if not _preparing_departure_heading or _sailing_route_points.size() < 2:
		return false
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		return false
	# The ship may still be finishing a previous dock animation while loading.
	# Rebuild from its current visual position so departure never jumps.
	_sailing_route_points = _build_delivery_route(mission)
	var departure_direction := _get_direction_along_points(
		_sailing_route_points,
		0.0
	)
	if departure_direction.is_zero_approx():
		return false
	var target_rotation := calculate_visual_rotation(
		departure_direction,
		ship_data.sprite_forward_angle_rad
	)
	var linear_progress := mission.get_leg_progress()
	var smooth_progress := linear_progress * linear_progress \
		* (3.0 - 2.0 * linear_progress)
	_icon.rotation = lerp_angle(
		_departure_start_rotation,
		target_rotation,
		smooth_progress
	)
	_turn_velocity = 0.0
	return true


func calculate_visual_rotation(
		direction: Vector2,
		sprite_forward_angle_rad: float = PI / 2.0
) -> float:
	if direction.is_zero_approx():
		return 0.0
	return wrapf(direction.angle() - sprite_forward_angle_rad, -PI, PI)


func _update_sailing_position(state: ShipRuntimeState.State) -> bool:
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		return false

	var origin_id := FleetManager.get_ship_current_port(ship_id)
	var destination_id: StringName
	if state == ShipRuntimeState.State.SAILING_TO_PICKUP:
		destination_id = mission.pickup_port_id
	else:
		destination_id = mission.delivery_port_id
	if origin_id == destination_id:
		return false

	if _sailing_route_points.is_empty():
		if state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
			_sailing_route_points = _build_delivery_route(mission)
		else:
			_sailing_route_points = PortManager.get_smoothed_route_points(
				origin_id,
				destination_id
			)
	var progress := mission.get_leg_progress()
	var route_position := _get_position_along_points(_sailing_route_points, progress)
	if route_position != Vector2.ZERO:
		global_position = route_position
	var tangent := _get_direction_along_points(_sailing_route_points, progress)
	if not tangent.is_zero_approx():
		_icon.rotation = calculate_visual_rotation(
			tangent,
			ship_data.sprite_forward_angle_rad
		)
		_turn_velocity = 0.0
		return true
	return false


func _on_ship_state_changed(changed_ship_id: StringName, _previous_state: int, new_state: int) -> void:
	if changed_ship_id == ship_id:
		var mission := FleetManager.get_ship_mission(ship_id)
		if new_state == ShipRuntimeState.State.LOADING and mission != null:
			_sailing_route_points = _build_delivery_route(mission)
			_departure_start_rotation = _icon.rotation
			_preparing_departure_heading = true
		elif new_state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
			_preparing_departure_heading = false
			if _sailing_route_points.is_empty() and mission != null:
				_sailing_route_points = _build_delivery_route(mission)
		else:
			_preparing_departure_heading = false
			_sailing_route_points.clear()
		if new_state == ShipRuntimeState.State.UNLOADING:
			_dock_transition_start = global_position
			_dock_transition_elapsed = 0.0
			_dock_transition_active = true
		_refresh_visuals()


func _on_ship_dock_slot_changed(
		changed_ship_id: StringName,
		_port_id: StringName,
		_previous_slot_index: int,
		_new_slot_index: int
) -> void:
	if changed_ship_id != ship_id:
		return
	_dock_transition_start = global_position
	_dock_transition_elapsed = 0.0
	_dock_transition_active = true


func _build_delivery_route(mission: Mission) -> PackedVector2Array:
	var sea_points := PortManager.get_route_points(
		mission.pickup_port_id,
		mission.delivery_port_id
	)
	if sea_points.is_empty():
		return sea_points
	var dock_to_dock_points := PackedVector2Array([global_position])
	dock_to_dock_points.append_array(sea_points)
	return PortManager.smooth_polyline_points(dock_to_dock_points)


func _on_any_ship_tapped(tapped_ship_id: StringName) -> void:
	_is_selected = tapped_ship_id == ship_id


func _update_route_visual(state: ShipRuntimeState.State) -> void:
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		_route_line.clear_route()
		return
	if state == ShipRuntimeState.State.LOADING:
		_route_line.set_route(
			_sailing_route_points,
			0.0,
			_is_selected
		)
	elif state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
		_route_line.set_route(
			_sailing_route_points,
			mission.get_leg_progress(),
			_is_selected
		)
	else:
		_route_line.clear_route()


func _get_position_along_points(points: PackedVector2Array, progress: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += points[point_index].distance_to(points[point_index + 1])
	if total_length <= 0.001:
		return points[points.size() - 1]
	var remaining := total_length * clampf(progress, 0.0, 1.0)
	for point_index in range(points.size() - 1):
		var segment_start := points[point_index]
		var segment_end := points[point_index + 1]
		var segment_length := segment_start.distance_to(segment_end)
		if remaining <= segment_length:
			if segment_length <= 0.001:
				return segment_end
			return segment_start.lerp(segment_end, remaining / segment_length)
		remaining -= segment_length
	return points[points.size() - 1]


func _get_direction_along_points(
		points: PackedVector2Array,
		progress: float
) -> Vector2:
	if points.size() < 2:
		return Vector2.ZERO
	var before_progress := maxf(progress - ROUTE_TANGENT_SAMPLE_PROGRESS, 0.0)
	var after_progress := minf(progress + ROUTE_TANGENT_SAMPLE_PROGRESS, 1.0)
	var before_position := _get_position_along_points(points, before_progress)
	var after_position := _get_position_along_points(points, after_progress)
	return before_position.direction_to(after_position)


func _on_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var touch_pressed: bool = event is InputEventScreenTouch and event.pressed
	var mouse_pressed: bool = event is InputEventMouseButton and event.pressed
	if touch_pressed or mouse_pressed:
		EventBus.ship_tapped.emit(ship_id)
		viewport.set_input_as_handled()


func _refresh_visuals() -> void:
	var state := FleetManager.get_ship_state(ship_id)
	_status_label.text = ShipRuntimeState.State.keys()[state]
