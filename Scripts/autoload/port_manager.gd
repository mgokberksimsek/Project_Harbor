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
		_states[id] = _create_default_state(port_data)


func _create_default_state(port_data: PortData) -> PortRuntimeState:
	var state := PortRuntimeState.new()
	state.port_id = port_data.id
	state.unlocked = port_data.unlocked_by_default
	state.level = 1
	return state


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


func get_all_sea_routes() -> Array[SeaRouteData]:
	var routes: Array[SeaRouteData] = []
	for route in _sea_routes.values():
		routes.append(route)
	return routes


func has_sea_route(port_a_id: StringName, port_b_id: StringName) -> bool:
	return _sea_routes.has(_get_route_key(port_a_id, port_b_id))


func has_route_path(port_a_id: StringName, port_b_id: StringName) -> bool:
	return get_route_port_path(port_a_id, port_b_id).size() >= 2


## Returns the shortest connected port sequence using authored sea corridors.
## Direct routes remain the graph edges; gameplay distance is their weight.
func get_route_port_path(
		port_a_id: StringName,
		port_b_id: StringName
) -> Array[StringName]:
	var empty_path: Array[StringName] = []
	if port_a_id == port_b_id \
			or not is_registered(port_a_id) \
			or not is_registered(port_b_id):
		return empty_path

	var distances: Dictionary = {port_a_id: 0.0}
	var previous: Dictionary = {}
	var visited: Dictionary = {}
	var frontier: Array[StringName] = [port_a_id]

	while not frontier.is_empty():
		var current: StringName = frontier[0]
		for candidate in frontier:
			var candidate_distance := float(distances.get(candidate, INF))
			var current_distance := float(distances.get(current, INF))
			if candidate_distance < current_distance \
					or (is_equal_approx(candidate_distance, current_distance) \
					and String(candidate) < String(current)):
				current = candidate
		frontier.erase(current)
		if current == port_b_id:
			break
		visited[current] = true

		for neighbor in _get_direct_route_neighbors(current):
			if visited.has(neighbor):
				continue
			var edge_distance := _get_direct_route_distance(current, neighbor)
			if edge_distance <= 0.0:
				continue
			var candidate_total := float(distances[current]) + edge_distance
			var known_total := float(distances.get(neighbor, INF))
			var should_replace := candidate_total < known_total
			if is_equal_approx(candidate_total, known_total) and previous.has(neighbor):
				should_replace = String(current) < String(previous[neighbor])
			if not should_replace:
				continue
			distances[neighbor] = candidate_total
			previous[neighbor] = current
			if not frontier.has(neighbor):
				frontier.append(neighbor)

	if not distances.has(port_b_id):
		return empty_path
	var path: Array[StringName] = [port_b_id]
	var cursor := port_b_id
	while cursor != port_a_id:
		if not previous.has(cursor):
			return empty_path
		cursor = StringName(previous[cursor])
		path.append(cursor)
	path.reverse()
	return path


func get_route_points(
		port_a_id: StringName,
		port_b_id: StringName
) -> PackedVector2Array:
	var port_path := get_route_port_path(port_a_id, port_b_id)
	if port_path.size() < 2:
		return PackedVector2Array()
	var points := PackedVector2Array()
	for path_index in range(port_path.size() - 1):
		var edge_points := _get_direct_route_points(
			port_path[path_index],
			port_path[path_index + 1]
		)
		if edge_points.size() < 2:
			return PackedVector2Array()
		# Intermediate ports are graph junctions, not gameplay stops. Replace
		# their center points with authored open-water transit points so a long
		# route can reuse sea corridors without appearing to visit each port.
		if path_index > 0:
			edge_points[0] = get_route_transit_position(port_path[path_index])
		if path_index < port_path.size() - 2:
			edge_points[edge_points.size() - 1] = get_route_transit_position(
				port_path[path_index + 1]
			)
		for point_index in range(edge_points.size()):
			if path_index > 0 and point_index == 0:
				continue
			points.append(edge_points[point_index])
	return points


func get_route_transit_position(port_id: StringName) -> Vector2:
	var port_node := get_port_node(port_id)
	var port_data := get_port_data(port_id)
	if port_node == null or port_data == null:
		return Vector2.ZERO
	return port_node.global_position + port_data.transit_offset


func _get_direct_route_points(
		port_a_id: StringName,
		port_b_id: StringName
) -> PackedVector2Array:
	var start_node := get_port_node(port_a_id)
	var end_node := get_port_node(port_b_id)
	if start_node == null or end_node == null:
		return PackedVector2Array()

	var route: SeaRouteData = _sea_routes.get(
		_get_route_key(port_a_id, port_b_id),
		null
	)
	if route == null:
		return PackedVector2Array()
	var points := PackedVector2Array([start_node.global_position])
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


## Total gameplay distance of the shortest connected sea-corridor path.
## FleetManager uses it to derive sailing duration from ship speed.
func get_distance(port_a_id: StringName, port_b_id: StringName) -> float:
	if port_a_id == port_b_id and is_registered(port_a_id):
		return 0.0
	var port_path := get_route_port_path(port_a_id, port_b_id)
	if port_path.size() < 2:
		push_warning("get_distance: no route path for '%s' or '%s'." % [port_a_id, port_b_id])
		return 0.0
	var total_distance := 0.0
	for path_index in range(port_path.size() - 1):
		total_distance += _get_direct_route_distance(
			port_path[path_index],
			port_path[path_index + 1]
		)
	return total_distance


func _get_direct_route_distance(
		port_a_id: StringName,
		port_b_id: StringName
) -> float:
	var route: SeaRouteData = _sea_routes.get(_get_route_key(port_a_id, port_b_id), null)
	if route == null:
		return 0.0
	if route.gameplay_distance > 0.0:
		return route.gameplay_distance
	var points := smooth_polyline_points(_get_direct_route_points(port_a_id, port_b_id))
	if points.size() < 2:
		return 0.0
	return _get_polyline_length(points) * GAMEPLAY_DISTANCE_PER_WORLD_PIXEL


func _get_direct_route_neighbors(port_id: StringName) -> Array[StringName]:
	var neighbors: Array[StringName] = []
	for route_value in _sea_routes.values():
		var route := route_value as SeaRouteData
		if route.from_port_id == port_id and not neighbors.has(route.to_port_id):
			neighbors.append(route.to_port_id)
		elif route.to_port_id == port_id and not neighbors.has(route.from_port_id):
			neighbors.append(route.from_port_id)
	neighbors.sort()
	return neighbors


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
	if not _states.has(port_id) or not _states[port_id].unlocked:
		push_warning("Tried to level up unavailable port id '%s'." % port_id)
		return false
	var port_data: PortData = get_port_data(port_id)
	if port_data == null or port_data.get_upgrade_cost(_states[port_id].level) < 0:
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

	# Save files only contain ports that existed when they were written. If
	# new data-driven ports were added in a later game version, keep them
	# registered with their authored defaults instead of dropping them from
	# the runtime state. This works whether loading happens before or after
	# the World scene registers its port nodes.
	for registered_id in _data.keys():
		if _states.has(registered_id):
			continue
		var port_data: PortData = _data[registered_id]
		var default_state := _create_default_state(port_data)
		_states[registered_id] = default_state
		if default_state.unlocked:
			EventBus.port_unlocked.emit(default_state.port_id)
		EventBus.port_leveled_up.emit(default_state.port_id, default_state.level)


func reset_state() -> void:
	_states.clear()
	_data.clear()
	_nodes.clear()
	_sea_routes.clear()
