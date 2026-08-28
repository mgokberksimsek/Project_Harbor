class_name Ship
extends Area2D

@export var ship_id: StringName = &""
@export var ship_data: ShipData
@export var home_port_id: StringName = &""

@onready var _icon: Sprite2D = $Icon
@onready var _selection_outline: Sprite2D = $Icon/SelectionOutline
@onready var _status_label: Label = $StatusLabel
@onready var _route_line: ShipRouteLine = $RouteLine

const DOCK_REPOSITION_SPEED := 300.0
const TURN_SPRING_STRENGTH := 22.0
const TURN_DAMPING := 8.0
const MAX_TURN_SPEED_RAD_PER_SEC := 4.5
const MIN_HEADING_MOVEMENT_SQUARED := 0.01
const ROUTE_TANGENT_SAMPLE_PROGRESS := 0.015
const PORT_APPROACH_WORLD_DISTANCE := 140.0
const PORT_APPROACH_DURATION_SEC := 1.6
const MAX_PORT_APPROACH_ROUTE_RATIO := 0.25
const DOCK_TRANSITION_DURATION_SEC := 0.9
const DELIVERY_TRANSITION_DURATION_SEC := 1.8
const DEPARTURE_HEADING_LEAD_MIN := 24.0
const DEPARTURE_HEADING_LEAD_MAX := 60.0
const DEPARTURE_HEADING_LEAD_RATIO := 0.16
const DEPARTURE_TURN_SPEED_RAD_PER_SEC := 1.8
const DEPARTURE_TURN_SNAP_RAD := 0.02
const SELECTED_SCALE_MULTIPLIER := 1.05
const SELECTION_SCALE_TWEEN_SEC := 0.16
const TUTORIAL_PULSE_SPEED := 4.0
const IDLE_STATUS_PULSE_SPEED := 3.4
const IDLE_STATUS_DIM_COLOR := Color(1.0, 0.78, 0.28, 0.58)
const IDLE_STATUS_BRIGHT_COLOR := Color(1.0, 0.96, 0.70, 1.0)

var _sailing_route_points := PackedVector2Array()
var _mission_preview_route_points := PackedVector2Array()
var _preview_pickup_route_length := 0.0
var _preview_total_route_length := 0.0
var _is_selected := false
var _tutorial_focused := false
var _tutorial_pulse_elapsed := 0.0
var _idle_status_pulse_elapsed := 0.0
var _turn_velocity := 0.0
var _departure_start_rotation := 0.0
var _departure_turn_start_progress := 0.0
var _departure_turn_initialized := false
var _preparing_departure_heading := false
var _smoothing_departure_turn := false
var _dock_transition_active := false
var _dock_transition_elapsed := 0.0
var _dock_transition_start := Vector2.ZERO
var _dock_transition_duration_sec := DOCK_TRANSITION_DURATION_SEC
var _has_initial_world_position := false
var _initial_world_position := Vector2.ZERO
var _hold_initial_position_while_idle := false
var _held_world_position := Vector2.ZERO
var _base_icon_scale := Vector2.ONE
var _selection_scale_tween: Tween = null


func _ready() -> void:
	add_to_group(&"ships")
	if ship_id == &"" or ship_data == null or home_port_id == &"":
		push_error("Ship instance '%s' is missing ship_id, ShipData, or home_port_id." % name)
		return

	if ship_data.icon != null:
		_icon.texture = ship_data.icon
	_icon.scale = Vector2.ONE * clampf(ship_data.sprite_scale, 0.1, 2.0)
	_base_icon_scale = _icon.scale
	_selection_outline.texture = _icon.texture

	FleetManager.register_ship(ship_id, ship_data, home_port_id, self)
	EventBus.ship_state_changed.connect(_on_ship_state_changed)
	EventBus.ship_dock_slot_changed.connect(_on_ship_dock_slot_changed)
	EventBus.ship_selection_changed.connect(_on_ship_selection_changed)
	EventBus.language_changed.connect(_on_language_changed)
	input_event.connect(_on_input_event)

	if not _restore_runtime_visual_state():
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
		heading_locked_to_route = _update_sailing_position(state, delta)
	else:
		_update_docked_position(delta)
	if state == ShipRuntimeState.State.LOADING:
		heading_prepared_for_departure = _update_pre_departure_heading()
	if not heading_locked_to_route and not heading_prepared_for_departure:
		_update_heading(previous_position, delta)
	_update_route_visual(state)
	_update_tutorial_focus_visual(delta)
	_update_idle_status_visual(state, delta)


func set_initial_world_position(
		world_position: Vector2,
		hold_while_idle := false
) -> void:
	_initial_world_position = world_position
	_has_initial_world_position = true
	_hold_initial_position_while_idle = hold_while_idle
	_held_world_position = world_position if hold_while_idle else Vector2.ZERO
	global_position = world_position


func set_headquarters_delivery(
		approach_world_position: Vector2,
		berth_world_position: Vector2
) -> void:
	_initial_world_position = approach_world_position
	_held_world_position = berth_world_position
	_has_initial_world_position = true
	_hold_initial_position_while_idle = true
	global_position = approach_world_position


func hold_at_world_position(world_position: Vector2) -> void:
	_initial_world_position = world_position
	_held_world_position = world_position
	_has_initial_world_position = false
	_hold_initial_position_while_idle = true
	global_position = world_position
	_dock_transition_active = false


func clear_initial_world_position_override() -> void:
	_has_initial_world_position = false
	_hold_initial_position_while_idle = false
	_held_world_position = Vector2.ZERO
	if FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		_dock_transition_active = false
		_snap_to_home_port()


func _restore_runtime_visual_state() -> bool:
	var state := FleetManager.get_ship_state(ship_id)
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		return false
	_has_initial_world_position = false
	_hold_initial_position_while_idle = false
	_held_world_position = Vector2.ZERO

	match state:
		ShipRuntimeState.State.SAILING_TO_PICKUP, \
				ShipRuntimeState.State.SAILING_TO_DELIVERY:
			var origin_id := FleetManager.get_ship_current_port(ship_id)
			var destination_id := mission.pickup_port_id \
					if state == ShipRuntimeState.State.SAILING_TO_PICKUP \
					else mission.delivery_port_id
			if FleetManager.is_headquarters_dispatch_active(ship_id):
				_sailing_route_points = _build_initial_pickup_route(
					origin_id,
					destination_id
				)
			else:
				_sailing_route_points = PortManager.get_smoothed_route_points(
					origin_id,
					destination_id
				)
			if _sailing_route_points.size() < 2:
				return false
			var progress := _get_visual_sailing_progress(
				mission,
				_sailing_route_points
			)
			global_position = _get_position_along_points(
				_sailing_route_points,
				progress
			)
			_snap_heading_to_route(progress)
			if state == ShipRuntimeState.State.SAILING_TO_PICKUP:
				_build_remote_mission_preview(mission)
			_update_route_visual(state)
			return true
		ShipRuntimeState.State.LOADING:
			var pickup_port := PortManager.get_port_node(mission.pickup_port_id)
			if pickup_port == null:
				return false
			global_position = pickup_port.global_position
			_sailing_route_points = _build_delivery_route(mission)
			_build_delivery_mission_preview(mission)
			_snap_heading_to_route(0.0)
			_departure_start_rotation = _icon.rotation
			_departure_turn_initialized = false
			_preparing_departure_heading = true
			_update_route_visual(state)
			return true
		ShipRuntimeState.State.UNLOADING:
			var delivery_port := PortManager.get_port_node(mission.delivery_port_id)
			if delivery_port == null:
				return false
			global_position = delivery_port.global_position
			return true
	return false


func _snap_to_home_port() -> void:
	var dock_position := FleetManager.get_ship_dock_position(ship_id)
	if _has_initial_world_position:
		global_position = _initial_world_position
		_has_initial_world_position = false
		if _hold_initial_position_while_idle:
			if not global_position.is_equal_approx(_held_world_position):
				_dock_transition_start = global_position
				_dock_transition_elapsed = 0.0
				_dock_transition_duration_sec = DELIVERY_TRANSITION_DURATION_SEC
				_dock_transition_active = true
			return
		if dock_position != Vector2.ZERO:
			_dock_transition_start = global_position
			_dock_transition_elapsed = 0.0
			_dock_transition_duration_sec = DELIVERY_TRANSITION_DURATION_SEC
			_dock_transition_active = true
		return
	if dock_position != Vector2.ZERO:
		global_position = dock_position
	elif FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		push_warning("Ship '%s': home port '%s' has no dock position." % [ship_id, home_port_id])


func _update_docked_position(delta: float) -> void:
	var dock_position := _held_world_position \
		if _hold_initial_position_while_idle \
		else FleetManager.get_ship_dock_position(ship_id)
	var state := FleetManager.get_ship_state(ship_id)
	if state == ShipRuntimeState.State.UNLOADING:
		var mission := FleetManager.get_ship_mission(ship_id)
		var delivery_port := PortManager.get_port_node(mission.delivery_port_id) \
			if mission != null else null
		if delivery_port != null:
			dock_position = delivery_port.global_position
	elif dock_position == Vector2.ZERO and state == ShipRuntimeState.State.LOADING:
		var mission := FleetManager.get_ship_mission(ship_id)
		var pickup_port := PortManager.get_port_node(mission.pickup_port_id) \
			if mission != null else null
		if pickup_port != null:
			dock_position = pickup_port.global_position
	if dock_position == Vector2.ZERO:
		return
	if _dock_transition_active:
		_dock_transition_elapsed += delta
		var linear_progress := clampf(
			_dock_transition_elapsed / _dock_transition_duration_sec,
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


func _snap_heading_to_route(progress: float) -> void:
	var tangent := _get_direction_along_points(_sailing_route_points, progress)
	if tangent.is_zero_approx():
		return
	_icon.rotation = calculate_visual_rotation(
		tangent,
		ship_data.sprite_forward_angle_rad
	)
	_turn_velocity = 0.0


func _update_pre_departure_heading() -> bool:
	if not _preparing_departure_heading or _sailing_route_points.size() < 2:
		return false
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		return false
	# While entering the pickup center, the bow follows the actual movement.
	# Departure preparation begins only after that fixed-speed approach ends.
	if _dock_transition_active:
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
	if not _departure_turn_initialized:
		_departure_start_rotation = _icon.rotation
		_departure_turn_start_progress = mission.get_leg_progress()
		_departure_turn_initialized = true
	var progress_span := maxf(1.0 - _departure_turn_start_progress, 0.001)
	var linear_progress := clampf(
		(mission.get_leg_progress() - _departure_turn_start_progress) / progress_span,
		0.0,
		1.0
	)
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


func _update_sailing_position(state: ShipRuntimeState.State, delta: float) -> bool:
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		return false

	var origin_id := FleetManager.get_ship_current_port(ship_id)
	var destination_id: StringName
	if state == ShipRuntimeState.State.SAILING_TO_PICKUP:
		destination_id = mission.pickup_port_id
	else:
		destination_id = mission.delivery_port_id
	if _sailing_route_points.is_empty():
		if state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
			_sailing_route_points = _build_delivery_route(mission)
		elif origin_id == destination_id:
			_sailing_route_points = _build_local_pickup_sailing_route(
				destination_id
			)
		else:
			_sailing_route_points = _build_route_from_current_position(
				origin_id,
				destination_id,
				true
			)
		if state == ShipRuntimeState.State.SAILING_TO_PICKUP:
			_build_remote_mission_preview(mission)
	if _sailing_route_points.size() < 2:
		return false
	var progress := _get_visual_sailing_progress(mission, _sailing_route_points)
	var route_position := _get_position_along_points(_sailing_route_points, progress)
	if route_position != Vector2.ZERO:
		global_position = route_position
	var tangent := _get_direction_along_points(_sailing_route_points, progress)
	if not tangent.is_zero_approx():
		var target_rotation := calculate_visual_rotation(
			tangent,
			ship_data.sprite_forward_angle_rad
		)
		if _smoothing_departure_turn:
			var angle_error := wrapf(target_rotation - _icon.rotation, -PI, PI)
			var maximum_turn := DEPARTURE_TURN_SPEED_RAD_PER_SEC * delta
			if absf(angle_error) <= maxf(maximum_turn, DEPARTURE_TURN_SNAP_RAD):
				_icon.rotation = target_rotation
				_smoothing_departure_turn = false
			else:
				_icon.rotation = wrapf(
					_icon.rotation + signf(angle_error) * maximum_turn,
					-PI,
					PI
				)
		else:
			_icon.rotation = target_rotation
		_turn_velocity = 0.0
		return true
	return false


func _on_ship_state_changed(changed_ship_id: StringName, previous_state: int, new_state: int) -> void:
	if changed_ship_id == ship_id:
		if new_state != ShipRuntimeState.State.IDLE:
			_hold_initial_position_while_idle = false
			_held_world_position = Vector2.ZERO
		var mission := FleetManager.get_ship_mission(ship_id)
		if new_state == ShipRuntimeState.State.LOADING and mission != null:
			_smoothing_departure_turn = false
			if FleetManager.get_ship_dock_slot_index(ship_id) < 0 \
					and not _sailing_route_points.is_empty():
				global_position = _sailing_route_points[_sailing_route_points.size() - 1]
			_clear_mission_preview()
			_sailing_route_points = _build_delivery_route(mission)
			_build_delivery_mission_preview(mission)
			_departure_turn_initialized = false
			_preparing_departure_heading = true
		elif new_state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
			_preparing_departure_heading = false
			_departure_turn_initialized = false
			_smoothing_departure_turn = true
			if _sailing_route_points.is_empty() and mission != null:
				_sailing_route_points = _build_delivery_route(mission)
		elif new_state == ShipRuntimeState.State.SAILING_TO_PICKUP:
			_preparing_departure_heading = false
			_departure_turn_initialized = false
			_smoothing_departure_turn = mission != null \
				and (
					FleetManager.get_ship_current_port(ship_id) \
						!= mission.pickup_port_id \
					or FleetManager.is_headquarters_dispatch_active(ship_id)
				)
			_turn_velocity = 0.0
			_sailing_route_points.clear()
			_clear_mission_preview()
		else:
			_preparing_departure_heading = false
			_departure_turn_initialized = false
			_smoothing_departure_turn = false
			_sailing_route_points.clear()
			_clear_mission_preview()
		if new_state == ShipRuntimeState.State.UNLOADING:
			# The route ends at the port center. Hold there while cargo is
			# unloaded; the berth transition begins only after completion.
			var delivery_port := PortManager.get_port_node(mission.delivery_port_id) \
				if mission != null else null
			if delivery_port != null:
				global_position = delivery_port.global_position
			_dock_transition_active = false
		elif new_state == ShipRuntimeState.State.LOADING \
				and previous_state == ShipRuntimeState.State.SAILING_TO_PICKUP:
			_dock_transition_start = global_position
			_dock_transition_elapsed = 0.0
			_dock_transition_duration_sec = DOCK_TRANSITION_DURATION_SEC
			_dock_transition_active = true
		elif new_state == ShipRuntimeState.State.IDLE \
				and previous_state == ShipRuntimeState.State.UNLOADING:
			_dock_transition_start = global_position
			_dock_transition_elapsed = 0.0
			_dock_transition_duration_sec = DELIVERY_TRANSITION_DURATION_SEC
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
	if _hold_initial_position_while_idle:
		return
	_dock_transition_start = global_position
	_dock_transition_elapsed = 0.0
	_dock_transition_duration_sec = DOCK_TRANSITION_DURATION_SEC
	_dock_transition_active = true


func _build_initial_pickup_route(
		origin_port_id: StringName,
		pickup_port_id: StringName
) -> PackedVector2Array:
	if origin_port_id == pickup_port_id:
		return _build_local_pickup_sailing_route(pickup_port_id)
	return _build_route_from_current_position(
		origin_port_id,
		pickup_port_id,
		true
	)


func _build_local_pickup_sailing_route(
		pickup_port_id: StringName
) -> PackedVector2Array:
	var pickup_port := PortManager.get_port_node(pickup_port_id)
	if pickup_port == null \
			or global_position.distance_squared_to(pickup_port.global_position) <= 0.25:
		return PackedVector2Array()
	# This short leg mirrors the actual dock transition exactly. Sea-route
	# transit points belong to travel between ports, not movement from a berth
	# into the same port's loading center.
	return PackedVector2Array([
		global_position,
		pickup_port.global_position,
	])


func _build_delivery_route(mission: Mission) -> PackedVector2Array:
	# A local pickup still begins with a short visual handling leg from the
	# assigned berth into the pickup port center. Keep that center in the
	# preview before joining the authored sea route to the destination.
	if mission.origin_port_id == mission.pickup_port_id:
		var pickup_port := PortManager.get_port_node(mission.pickup_port_id)
		if pickup_port != null \
				and global_position.distance_squared_to(pickup_port.global_position) > 0.25:
			var delivery_points := PortManager.get_smoothed_route_points(
				mission.pickup_port_id,
				mission.delivery_port_id
			)
			if delivery_points.size() >= 2:
				var local_pickup_route := _build_local_pickup_sailing_route(
					mission.pickup_port_id
				)
				if local_pickup_route.size() < 2:
					return delivery_points
				for point_index in range(1, delivery_points.size()):
					local_pickup_route.append(delivery_points[point_index])
				return local_pickup_route
	var delivery_route := _build_route_from_current_position(
		mission.pickup_port_id,
		mission.delivery_port_id
	)
	return delivery_route


func _build_route_from_current_position(
		origin_port_id: StringName,
		destination_port_id: StringName,
		preserve_departure_heading: bool = false
) -> PackedVector2Array:
	var sea_points := PortManager.get_route_points(
		origin_port_id,
		destination_port_id
	)
	if sea_points.is_empty():
		return sea_points
	var dock_to_dock_points := PackedVector2Array([global_position])
	if preserve_departure_heading and sea_points.size() >= 2:
		var distance_to_first_sea_point := global_position.distance_to(sea_points[1])
		var departure_lead_length := clampf(
			distance_to_first_sea_point * DEPARTURE_HEADING_LEAD_RATIO,
			DEPARTURE_HEADING_LEAD_MIN,
			DEPARTURE_HEADING_LEAD_MAX
		)
		var current_forward := Vector2.RIGHT.rotated(
			_icon.rotation + ship_data.sprite_forward_angle_rad
		)
		dock_to_dock_points.append(
			global_position + current_forward * departure_lead_length
		)
	# global_position already represents the departure point. Skipping the
	# route's authored origin-center point lets a ship leave its berth directly
	# toward the first sea waypoint instead of detouring through its own port.
	# Remote pickups also receive a short control point in the ship's current
	# forward direction, so the smoothed route curves naturally out of the berth.
	for point_index in range(1, sea_points.size()):
		dock_to_dock_points.append(sea_points[point_index])
	return PortManager.smooth_polyline_points(dock_to_dock_points)


func _build_remote_mission_preview(mission: Mission) -> void:
	_clear_mission_preview()
	if mission == null or _sailing_route_points.size() < 2:
		return

	var delivery_points := PortManager.get_smoothed_route_points(
		mission.pickup_port_id,
		mission.delivery_port_id
	)
	if delivery_points.size() < 2:
		return

	_mission_preview_route_points = _sailing_route_points.duplicate()
	# Both legs contain the pickup port center. Keep the first copy so the
	# red preview remains a single continuous polyline without a zero-length
	# duplicate segment at the transfer point.
	for point_index in range(1, delivery_points.size()):
		_mission_preview_route_points.append(delivery_points[point_index])
	_append_future_contract_routes(mission, _mission_preview_route_points)
	_preview_pickup_route_length = _get_polyline_length(_sailing_route_points)
	_preview_total_route_length = _get_polyline_length(_mission_preview_route_points)


func _build_delivery_mission_preview(mission: Mission) -> void:
	if mission == null or not mission.has_next_contract_delivery() \
			or _sailing_route_points.size() < 2:
		return
	_mission_preview_route_points = _sailing_route_points.duplicate()
	_append_future_contract_routes(mission, _mission_preview_route_points)
	_preview_pickup_route_length = _get_polyline_length(_sailing_route_points)
	_preview_total_route_length = _get_polyline_length(_mission_preview_route_points)


func _append_future_contract_routes(
		mission: Mission,
		points: PackedVector2Array
) -> void:
	if mission == null:
		return
	var future_ports := mission.get_future_contract_port_ids()
	for port_index in range(future_ports.size() - 1):
		var next_route := PortManager.get_smoothed_route_points(
			future_ports[port_index],
			future_ports[port_index + 1]
		)
		for point_index in range(1, next_route.size()):
			points.append(next_route[point_index])


func _clear_mission_preview() -> void:
	_mission_preview_route_points.clear()
	_preview_pickup_route_length = 0.0
	_preview_total_route_length = 0.0


func _on_ship_selection_changed(selected_ship_id: StringName) -> void:
	_is_selected = selected_ship_id == ship_id
	_selection_outline.visible = _is_selected or _tutorial_focused
	if _selection_scale_tween != null and _selection_scale_tween.is_valid():
		_selection_scale_tween.kill()
	var target_scale := _base_icon_scale * (
		SELECTED_SCALE_MULTIPLIER if _is_selected else 1.0
	)
	_selection_scale_tween = create_tween()
	_selection_scale_tween.set_trans(Tween.TRANS_QUAD)
	_selection_scale_tween.set_ease(Tween.EASE_OUT)
	_selection_scale_tween.tween_property(
		_icon,
		"scale",
		target_scale,
		SELECTION_SCALE_TWEEN_SEC
	)


func set_tutorial_focus(enabled: bool) -> void:
	_tutorial_focused = enabled
	if not enabled:
		_tutorial_pulse_elapsed = 0.0
		_selection_outline.modulate = Color.WHITE
	_selection_outline.visible = _is_selected or _tutorial_focused


func is_tutorial_focused() -> bool:
	return _tutorial_focused


func _update_tutorial_focus_visual(delta: float) -> void:
	if not _tutorial_focused:
		return
	_tutorial_pulse_elapsed += delta
	var pulse := (sin(_tutorial_pulse_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	_selection_outline.modulate = Color(1.0, 0.72 + pulse * 0.28, 0.35, 0.55 + pulse * 0.45)


func _update_idle_status_visual(state: ShipRuntimeState.State, delta: float) -> void:
	if state != ShipRuntimeState.State.IDLE or _tutorial_focused:
		_reset_idle_status_visual()
		return
	_idle_status_pulse_elapsed += delta
	var pulse := (sin(_idle_status_pulse_elapsed * IDLE_STATUS_PULSE_SPEED) + 1.0) * 0.5
	_status_label.modulate = IDLE_STATUS_DIM_COLOR.lerp(
		IDLE_STATUS_BRIGHT_COLOR,
		pulse
	)


func _reset_idle_status_visual() -> void:
	_idle_status_pulse_elapsed = 0.0
	_status_label.modulate = Color.WHITE
	_status_label.scale = Vector2.ONE


func _update_route_visual(state: ShipRuntimeState.State) -> void:
	var mission := FleetManager.get_ship_mission(ship_id)
	if mission == null:
		_route_line.clear_route()
		return
	if state == ShipRuntimeState.State.LOADING:
		var loading_progress := _get_local_loading_route_progress(mission)
		if not _mission_preview_route_points.is_empty():
			loading_progress = _scale_current_route_progress_to_preview(
				loading_progress
			)
		_route_line.set_route(
			_mission_preview_route_points \
				if not _mission_preview_route_points.is_empty() \
				else _sailing_route_points,
			loading_progress,
			_is_selected
		)
	elif state == ShipRuntimeState.State.SAILING_TO_DELIVERY:
		if mission.has_next_contract_delivery() \
				and _mission_preview_route_points.is_empty():
			_build_delivery_mission_preview(mission)
		var delivery_progress := _get_visual_sailing_progress(
			mission,
			_sailing_route_points
		)
		if not _mission_preview_route_points.is_empty():
			delivery_progress = _scale_current_route_progress_to_preview(
				delivery_progress
			)
		_route_line.set_route(
			_mission_preview_route_points \
				if not _mission_preview_route_points.is_empty() \
				else _sailing_route_points,
			delivery_progress,
			_is_selected
		)
	elif state == ShipRuntimeState.State.SAILING_TO_PICKUP:
		if _mission_preview_route_points.is_empty():
			_build_remote_mission_preview(mission)
		var preview_progress := 0.0
		if _preview_total_route_length > 0.001:
			preview_progress = _get_visual_sailing_progress(
				mission,
				_sailing_route_points
			) \
				* _preview_pickup_route_length / _preview_total_route_length
		_route_line.set_route(
			_mission_preview_route_points,
			preview_progress,
			_is_selected
		)
	else:
		_route_line.clear_route()


func _scale_current_route_progress_to_preview(progress: float) -> float:
	if _preview_total_route_length <= 0.001:
		return progress
	return progress * _preview_pickup_route_length / _preview_total_route_length


func _get_local_loading_route_progress(mission: Mission) -> float:
	if mission == null \
			or mission.origin_port_id != mission.pickup_port_id \
			or _sailing_route_points.size() < 2:
		return 0.0
	var pickup_port := PortManager.get_port_node(mission.pickup_port_id)
	if pickup_port == null:
		return 0.0
	var total_route_length := _get_polyline_length(_sailing_route_points)
	var local_pickup_length := _sailing_route_points[0].distance_to(
		pickup_port.global_position
	)
	if total_route_length <= 0.001 or local_pickup_length <= 0.001:
		return 0.0
	var travelled_pickup_length := clampf(
		local_pickup_length - global_position.distance_to(pickup_port.global_position),
		0.0,
		local_pickup_length
	)
	return travelled_pickup_length / total_route_length


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


func _get_polyline_length(points: PackedVector2Array) -> float:
	var total_length := 0.0
	for point_index in range(points.size() - 1):
		total_length += points[point_index].distance_to(points[point_index + 1])
	return total_length


func _get_visual_sailing_progress(
		mission: Mission,
		points: PackedVector2Array
) -> float:
	if mission == null:
		return 0.0
	return calculate_visual_sailing_progress(
		mission.get_leg_progress(),
		mission.leg_duration_sec,
		_get_polyline_length(points)
	)


func calculate_visual_sailing_progress(
		raw_progress: float,
		leg_duration_sec: float,
		route_length: float
) -> float:
	var progress := clampf(raw_progress, 0.0, 1.0)
	if leg_duration_sec <= PORT_APPROACH_DURATION_SEC \
			or route_length <= PORT_APPROACH_WORLD_DISTANCE:
		return progress

	var approach_route_ratio := minf(
		PORT_APPROACH_WORLD_DISTANCE / route_length,
		MAX_PORT_APPROACH_ROUTE_RATIO
	)
	var approach_time_ratio := PORT_APPROACH_DURATION_SEC / leg_duration_sec
	var cruise_time_ratio := 1.0 - approach_time_ratio
	var cruise_route_ratio := 1.0 - approach_route_ratio
	if progress <= cruise_time_ratio:
		return progress / cruise_time_ratio * cruise_route_ratio
	return cruise_route_ratio \
		+ (progress - cruise_time_ratio) / approach_time_ratio \
		* approach_route_ratio


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


func _on_language_changed(_locale: String) -> void:
	_refresh_visuals()


func _refresh_visuals() -> void:
	var state := FleetManager.get_ship_state(ship_id)
	match state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			_status_label.text = tr("STATE_SAILING_TO_PICKUP")
		ShipRuntimeState.State.LOADING:
			_status_label.text = tr("STATE_LOADING")
		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			_status_label.text = tr("STATE_SAILING_TO_DELIVERY")
		ShipRuntimeState.State.UNLOADING:
			_status_label.text = tr("STATE_UNLOADING")
		_:
			_status_label.text = tr("STATE_IDLE")
