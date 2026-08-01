extends Node
## Autoload: the single source of truth for which ports exist, which are
## unlocked, and at what level. Register as "PortManager" in Project
## Settings > Autoload, directly below EventBus.
##
## PortManager never touches currency (GameManager's job, once it exists in
## Phase 6 — it checks/deducts cost, THEN calls unlock_port here) and never
## scans the scene tree looking for ports. Ports register themselves on
## _ready(). This is what makes "add an 11th port" a zero-code operation:
## drop a new Port.tscn instance into World, assign a new PortData
## resource, done — PortManager finds out the port exists the moment it
## registers, same as every other port.

## The world is intentionally much larger than the original prototype.
## Keeping visual pixels separate from gameplay distance prevents map scale
## changes from inflating every mission's duration and reward.
const GAMEPLAY_DISTANCE_PER_WORLD_PIXEL := 0.45

## port_id -> PortRuntimeState (persisted: unlocked, level)
var _states: Dictionary = {}

## port_id -> PortData (static resource, repopulated every registration —
## never persisted, it's just a pointer to a designer-authored asset)
var _data: Dictionary = {}

## port_id -> Node2D (TRANSIENT scene-tree lookup for spatial queries, e.g.
## "where is this port" for ship movement in Phase 3. Rebuilt every time
## World.tscn loads and each Port re-registers. Never persisted.
var _nodes: Dictionary = {}

## Canonical port-pair key -> SeaRouteData. Static/transient map data, never
## written into the save file.
var _sea_routes: Dictionary = {}


## Called by Port.gd in _ready(). Safe to call repeatedly for the same id
## (e.g. on scene reload) — existing persisted state is never overwritten,
## only the data/node pointers are refreshed.
func register_port(port_data: PortData, node: Node2D) -> void:
	if port_data == null or port_data.id == &"":
		push_error("Port node '%s' has no PortData (or an empty id) assigned." % node.name)
		return

	var id: StringName = port_data.id
	_data[id] = port_data
	_nodes[id] = node

	if not _states.has(id):
		var state := PortRuntimeState.new()
		state.port_id = id
		state.unlocked = port_data.unlocked_by_default
		state.level = 1
		_states[id] = state


func is_registered(port_id: StringName) -> bool:
	return _states.has(port_id)


func get_all_port_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _states.keys():
		ids.append(id)
	return ids


## What MissionManager will call in Phase 4 to pick pickup/delivery ports.
func get_unlocked_port_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _states.keys():
		if _states[id].unlocked:
			ids.append(id)
	return ids


func is_unlocked(port_id: StringName) -> bool:
	return _states.has(port_id) and _states[port_id].unlocked


func get_level(port_id: StringName) -> int:
	if not _states.has(port_id):
		return 0
	return _states[port_id].level


func get_port_data(port_id: StringName) -> PortData:
	return _data.get(port_id, null)


## Transient lookup for systems that need the port's actual world position
## (Ship movement, Phase 3). Returns null if the port hasn't registered yet.
func get_port_node(port_id: StringName) -> Node2D:
	return _nodes.get(port_id, null)


func get_dock_position(port_id: StringName, slot_index: int) -> Vector2:
	var port_node := get_port_node(port_id)
	var port_data := get_port_data(port_id)
	if port_node == null or port_data == null:
		return Vector2.ZERO
	return port_node.global_position + port_data.get_dock_slot_offset(slot_index)


func get_dock_slot_count(port_id: StringName) -> int:
	var port_data := get_port_data(port_id)
	if port_data == null:
		return 0
	return port_data.dock_slot_offsets.size()


func register_sea_route(route: SeaRouteData) -> void:
	if route == null or not route.is_valid():
		push_error("Cannot register an invalid sea route.")
		return
	_sea_routes[_get_route_key(route.from_port_id, route.to_port_id)] = route


func has_sea_route(port_a_id: StringName, port_b_id: StringName) -> bool:
	return _sea_routes.has(_get_route_key(port_a_id, port_b_id))


func get_route_points(
		port_a_id: StringName,
		port_b_id: StringName
) -> PackedVector2Array:
	var start_node := get_port_node(port_a_id)
	var end_node := get_port_node(port_b_id)
	if start_node == null or end_node == null:
		return PackedVector2Array()

	var points := PackedVector2Array([start_node.global_position])
	var route: SeaRouteData = _sea_routes.get(
		_get_route_key(port_a_id, port_b_id),
		null
	)
	if route != null:
		if route.from_port_id == port_a_id:
			points.append_array(route.waypoints)
		else:
			for waypoint_index in range(route.waypoints.size() - 1, -1, -1):
				points.append(route.waypoints[waypoint_index])
	points.append(end_node.global_position)
	return points


func get_smoothed_route_points(
		port_a_id: StringName,
		port_b_id: StringName
) -> PackedVector2Array:
	return smooth_polyline_points(get_route_points(port_a_id, port_b_id))


func smooth_polyline_points(
		input_points: PackedVector2Array,
		passes: int = 2
) -> PackedVector2Array:
	var points := input_points.duplicate()
	# Two Chaikin passes soften corners while keeping the curve inside the
	# original corridor instead of overshooting toward nearby land.
	for _pass_index in range(maxi(passes, 0)):
		if points.size() < 3:
			break
		var smoothed := PackedVector2Array([points[0]])
		for point_index in range(points.size() - 1):
			var segment_start := points[point_index]
			var segment_end := points[point_index + 1]
			smoothed.append(segment_start.lerp(segment_end, 0.25))
			smoothed.append(segment_start.lerp(segment_end, 0.75))
		smoothed.append(points[points.size() - 1])
		points = smoothed
	return points


func get_route_position(
		port_a_id: StringName,
		port_b_id: StringName,
		progress: float
) -> Vector2:
	var points := get_smoothed_route_points(port_a_id, port_b_id)
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total_length := _get_polyline_length(points)
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


## Straight-line gameplay distance between two ports. Used by
## FleetManager to turn "sail from A to B" into a duration, given a ship's
## speed. Returns 0.0 (with a warning) if either port hasn't registered a
## node yet — callers should treat that as "not ready", not as "arrived".
func get_distance(port_a_id: StringName, port_b_id: StringName) -> float:
	var points := get_smoothed_route_points(port_a_id, port_b_id)
	if points.is_empty():
		push_warning("get_distance: missing node for '%s' or '%s'." % [port_a_id, port_b_id])
		return 0.0
	return _get_polyline_length(points) * GAMEPLAY_DISTANCE_PER_WORLD_PIXEL


func _get_polyline_length(points: PackedVector2Array) -> float:
	var total := 0.0
	for point_index in range(points.size() - 1):
		total += points[point_index].distance_to(points[point_index + 1])
	return total


func _get_route_key(port_a_id: StringName, port_b_id: StringName) -> String:
	var a := String(port_a_id)
	var b := String(port_b_id)
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Flips a port to unlocked and notifies the world via EventBus. Callers are
## responsible for validating/deducting cost BEFORE calling this —
## PortManager intentionally has no concept of currency.
func unlock_port(port_id: StringName) -> bool:
	if not _states.has(port_id):
		push_warning("Tried to unlock unregistered port id '%s'." % port_id)
		return false
	if _states[port_id].unlocked:
		return false # already unlocked — not an error, just a no-op
	_states[port_id].unlocked = true
	EventBus.port_unlocked.emit(port_id)
	return true


func level_up_port(port_id: StringName) -> bool:
	if not _states.has(port_id):
		push_warning("Tried to level up unregistered port id '%s'." % port_id)
		return false
	_states[port_id].level += 1
	EventBus.port_leveled_up.emit(port_id, _states[port_id].level)
	return true


# --- Save/load hooks, wired up by SaveManager in Phase 7 --------------------

func get_save_state() -> Dictionary:
	var out := {}
	for id in _states.keys():
		out[String(id)] = _states[id].to_dict()
	return out


## Call BEFORE World.tscn's ports register themselves (e.g. during a boot/
## loading step) so register_port() sees the restored state and doesn't
## silently overwrite it with each PortData's defaults.
func apply_save_state(saved: Dictionary) -> void:
	_states.clear()
	for id_str in saved.keys():
		var state := PortRuntimeState.from_dict(saved[id_str])
		_states[StringName(id_str)] = state
		if state.unlocked:
			EventBus.port_unlocked.emit(state.port_id)
		EventBus.port_leveled_up.emit(state.port_id, state.level)


func reset_state() -> void:
	_states.clear()
	_data.clear()
	_nodes.clear()
	_sea_routes.clear()
