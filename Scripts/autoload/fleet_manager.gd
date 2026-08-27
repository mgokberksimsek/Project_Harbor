extends Node
## Autoload: registry of every ship (player-owned, and later AI-owned) and
## the single owner of the state machine that moves them through
## SAILING_TO_PICKUP -> LOADING -> SAILING_TO_DELIVERY -> UNLOADING -> IDLE.
## Register as "FleetManager" in Project Settings > Autoload, directly
## below PortManager.
##
## Every leg (sailing OR stationary loading/unloading) is timed using the
## SAME mechanism: a Unix start timestamp + a duration, stored on the
## Mission currently assigned to the ship (see Mission.start_leg /
## get_leg_progress). This file never runs a per-frame physics simulation
## of "how far did the ship move this frame" — _process() just asks
## "has enough wall-clock time passed to finish this leg", which is exactly
## what still needs to be true after the app was closed for six hours.
## That single design choice is what makes idle/offline income possible
## later without touching this state machine again.

## Stationary cargo legs use these shared level-1 durations. Each port's
## authored handling multiplier shortens them as that port is upgraded.
const LOADING_DURATION_SEC := 3.0
const UNLOADING_DURATION_SEC := 3.0
const MIN_SAILING_DURATION_SEC := 2.0
## Converts operating distance and ship speed into prototype mission seconds.
## The current value keeps the first route under half a minute while allowing
## the far side of the regional map to approach a full minute.
const SAILING_DURATION_SCALE := 10.0
## The headquarters sits outside the port graph, so its first departure uses a
## short authored duration instead of pretending that the ship already starts
## inside its home port.
const HEADQUARTERS_DISPATCH_DURATION_SEC := 8.0
const SHIP_RESOURCE_DIR := "res://Resources/ships"
## Designer-tunable global fleet ceiling for Company Levels 1 through 15.
## Early growth stays deliberate, Levels 6-10 expand faster alongside
## automation, and late growth slows again to protect map readability.
const FLEET_CAPACITY_BY_COMPANY_LEVEL: Array[int] = [
	2, 3, 4, 5, 6,
	8, 10, 12, 14, 16,
	17, 18, 19, 20, 21,
]
const MIN_SHIP_NAME_LENGTH := 2
const MAX_SHIP_NAME_LENGTH := 20
const SHIP_NAME_POOL: Array[String] = [
	"Atlas", "Aurora", "Orion", "Marina", "Vega", "Luna",
	"Nova", "Nautica", "Calypso", "Horizon", "Poyraz", "Mercan",
	"Ufuk", "Yakamoz", "Mistral", "Argo", "Kuzey", "Rüzgâr",
]

var _states: Dictionary = {}  # ship_id -> ShipRuntimeState
var _data: Dictionary = {}    # ship_id -> ShipData
var _nodes: Dictionary = {}   # ship_id -> Node2D (transient, not persisted)
var _catalog: Dictionary = {} # model_id -> ShipData
var _ship_sequence: int = 0


func _ready() -> void:
	_load_ship_catalog()


## Called by Ship.gd in _ready(). home_port_id is where the ship starts
## docked — used both for its initial world position and as the sailing
## origin the first time it's assigned a mission.
func register_ship(ship_id: StringName, ship_data: ShipData, home_port_id: StringName, node: Node2D) -> void:
	if ship_id == &"" or ship_data == null:
		push_error("Ship node '%s' is missing ship_id or ShipData." % node.name)
		return

	_data[ship_id] = ship_data
	_nodes[ship_id] = node

	if not _states.has(ship_id):
		var state := ShipRuntimeState.new()
		state.ship_id = ship_id
		state.model_id = ship_data.id
		state.ship_name = _generate_unique_ship_name()
		state.current_port_id = home_port_id
		state.state = ShipRuntimeState.State.IDLE
		_states[ship_id] = state

	var runtime: ShipRuntimeState = _states[ship_id]
	_reserve_first_free_dock_slot(ship_id, _get_expected_dock_port(runtime))
	EventBus.ship_registered.emit(ship_id)


func get_all_ship_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _states.keys():
		ids.append(id)
	return ids


## What MissionManager will call in Phase 4 to find a ship to hand a fresh
## mission to.
func get_idle_ship_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in _states.keys():
		if _states[id].state == ShipRuntimeState.State.IDLE:
			ids.append(id)
	return ids


func get_ship_state(ship_id: StringName) -> ShipRuntimeState.State:
	if not _states.has(ship_id):
		return ShipRuntimeState.State.IDLE
	return _states[ship_id].state


func get_ship_mission(ship_id: StringName) -> Mission:
	if not _states.has(ship_id):
		return null
	return _states[ship_id].current_mission


func get_ship_current_port(ship_id: StringName) -> StringName:
	if not _states.has(ship_id):
		return &""
	return _states[ship_id].current_port_id


func is_awaiting_headquarters_dispatch(ship_id: StringName) -> bool:
	return _states.has(ship_id) \
		and _states[ship_id].awaiting_headquarters_dispatch


func is_headquarters_dispatch_active(ship_id: StringName) -> bool:
	return _states.has(ship_id) \
		and _states[ship_id].headquarters_dispatch_active


func get_ship_dock_slot_index(ship_id: StringName) -> int:
	if not _states.has(ship_id) or not _is_ship_docked(ship_id):
		return -1
	var runtime: ShipRuntimeState = _states[ship_id]
	var expected_port_id := _get_expected_dock_port(runtime)
	if expected_port_id == &"" or runtime.current_port_id != expected_port_id:
		return -1
	return _reserve_first_free_dock_slot(ship_id, expected_port_id)


func get_ship_headquarters_slot_index(ship_id: StringName) -> int:
	if not _states.has(ship_id) or not _states[ship_id].awaiting_headquarters_dispatch:
		return -1
	return _states[ship_id].headquarters_slot_index


func get_ship_reserved_dock_port(ship_id: StringName) -> StringName:
	if not _states.has(ship_id):
		return &""
	return _states[ship_id].dock_port_id


func get_ship_dock_position(ship_id: StringName) -> Vector2:
	var slot_index := get_ship_dock_slot_index(ship_id)
	if slot_index < 0:
		return Vector2.ZERO
	return PortManager.get_dock_position(get_ship_current_port(ship_id), slot_index)


func get_ship_arrival_dock_position(
		ship_id: StringName,
		port_id: StringName
) -> Vector2:
	if not _states.has(ship_id):
		return Vector2.ZERO
	var slot_index := _reserve_first_free_dock_slot(ship_id, port_id)
	if slot_index < 0:
		return Vector2.ZERO
	return PortManager.get_dock_position(port_id, slot_index)


func _reserve_first_free_dock_slot(ship_id: StringName, port_id: StringName) -> int:
	if not _states.has(ship_id) or port_id == &"":
		return -1
	var slot_count := PortManager.get_dock_slot_count(port_id)
	var authored_slot_count := PortManager.get_authored_dock_slot_count(port_id)
	if slot_count <= 0:
		return -1

	var runtime: ShipRuntimeState = _states[ship_id]
	var occupied_slots := {}
	for candidate_id in _states.keys():
		if candidate_id == ship_id:
			continue
		var candidate: ShipRuntimeState = _states[candidate_id]
		if candidate.dock_port_id == port_id \
				and candidate.dock_slot_index >= 0 \
				and candidate.dock_slot_index < authored_slot_count:
			occupied_slots[candidate.dock_slot_index] = true

	# Preserve a valid berth from an older save even if the port's new level
	# capacity is currently lower. It remains occupied until that ship leaves;
	# new reservations still use only the unlocked slots below.
	if runtime.dock_port_id == port_id \
			and runtime.dock_slot_index >= 0 \
			and runtime.dock_slot_index < authored_slot_count \
			and not occupied_slots.has(runtime.dock_slot_index):
		return runtime.dock_slot_index
	if occupied_slots.size() >= slot_count:
		runtime.dock_port_id = &""
		runtime.dock_slot_index = -1
		return -1

	for slot_index in range(slot_count):
		if occupied_slots.has(slot_index):
			continue
		runtime.dock_port_id = port_id
		runtime.dock_slot_index = slot_index
		return slot_index

	runtime.dock_port_id = &""
	runtime.dock_slot_index = -1
	push_warning("No free dock slot at port '%s' for ship '%s'." % [port_id, ship_id])
	return -1


func can_reserve_dock_at_port(port_id: StringName, ship_id: StringName = &"") -> bool:
	var slot_count := PortManager.get_dock_slot_count(port_id)
	if slot_count <= 0:
		return false
	if ship_id != &"" and _states.has(ship_id):
		var runtime: ShipRuntimeState = _states[ship_id]
		if runtime.dock_port_id == port_id and runtime.dock_slot_index >= 0:
			return true
	var occupied_slots := {}
	var authored_slot_count := PortManager.get_authored_dock_slot_count(port_id)
	for candidate_id in _states.keys():
		if candidate_id == ship_id:
			continue
		var candidate: ShipRuntimeState = _states[candidate_id]
		if candidate.dock_port_id == port_id \
				and candidate.dock_slot_index >= 0 \
				and candidate.dock_slot_index < authored_slot_count:
			occupied_slots[candidate.dock_slot_index] = true
	if occupied_slots.size() >= slot_count:
		return false
	for slot_index in range(slot_count):
		if not occupied_slots.has(slot_index):
			return true
	return false


func get_reserved_dock_count(port_id: StringName) -> int:
	var count := 0
	for runtime: ShipRuntimeState in _states.values():
		if runtime.dock_port_id == port_id and runtime.dock_slot_index >= 0:
			count += 1
	return count


func _move_reservation_to_port(ship_id: StringName, port_id: StringName) -> int:
	var runtime: ShipRuntimeState = _states[ship_id]
	var previous_port_id := runtime.dock_port_id
	var previous_slot_index := runtime.dock_slot_index
	var new_slot_index := _reserve_first_free_dock_slot(ship_id, port_id)
	if new_slot_index >= 0 \
			and previous_port_id != &"" \
			and previous_port_id != port_id \
			and previous_slot_index >= 0:
		_fill_vacated_dock_slot(previous_port_id, previous_slot_index)
	return new_slot_index


func _release_dock_reservation(ship_id: StringName) -> void:
	if not _states.has(ship_id):
		return
	var runtime: ShipRuntimeState = _states[ship_id]
	var previous_port_id := runtime.dock_port_id
	var previous_slot_index := runtime.dock_slot_index
	runtime.dock_port_id = &""
	runtime.dock_slot_index = -1
	if previous_port_id != &"" and previous_slot_index >= 0:
		_fill_vacated_dock_slot(previous_port_id, previous_slot_index)


func _fill_vacated_dock_slot(port_id: StringName, vacated_slot_index: int) -> void:
	var replacement_ship_id: StringName = &""
	var replacement_slot_index := vacated_slot_index
	for candidate_id in _states.keys():
		var candidate: ShipRuntimeState = _states[candidate_id]
		if candidate.dock_port_id != port_id \
				or candidate.dock_slot_index <= replacement_slot_index \
				or not _is_ship_docked(candidate_id):
			continue
		replacement_ship_id = candidate_id
		replacement_slot_index = candidate.dock_slot_index

	if replacement_ship_id == &"":
		return
	var replacement: ShipRuntimeState = _states[replacement_ship_id]
	replacement.dock_slot_index = vacated_slot_index
	EventBus.ship_dock_slot_changed.emit(
		replacement_ship_id,
		port_id,
		replacement_slot_index,
		vacated_slot_index
	)


func _get_expected_dock_port(runtime: ShipRuntimeState) -> StringName:
	if runtime.awaiting_headquarters_dispatch:
		return &""
	if runtime.current_mission != null:
		return runtime.current_mission.delivery_port_id
	return runtime.current_port_id


func _reconcile_dock_reservations() -> void:
	var sorted_ids: Array[StringName] = []
	for ship_id in _states.keys():
		sorted_ids.append(ship_id)
	sorted_ids.sort()

	# First preserve every valid, unique reservation. Invalid and duplicate
	# values (including old saves without berth data) are cleared.
	var occupied_by_port := {}
	for ship_id in sorted_ids:
		var runtime: ShipRuntimeState = _states[ship_id]
		var expected_port := _get_expected_dock_port(runtime)
		var slot_count := PortManager.get_authored_dock_slot_count(expected_port)
		if not occupied_by_port.has(expected_port):
			occupied_by_port[expected_port] = {}
		var occupied: Dictionary = occupied_by_port[expected_port]
		var reservation_is_valid := runtime.dock_port_id == expected_port \
			and runtime.dock_slot_index >= 0 \
			and runtime.dock_slot_index < slot_count \
			and not occupied.has(runtime.dock_slot_index)
		if reservation_is_valid:
			occupied[runtime.dock_slot_index] = true
		else:
			runtime.dock_port_id = &""
			runtime.dock_slot_index = -1

	# Assign only the ships that still need a berth; preserved ships do not
	# move merely because another ship was loaded or arrived later.
	for ship_id in sorted_ids:
		var runtime: ShipRuntimeState = _states[ship_id]
		if runtime.dock_slot_index < 0:
			_reserve_first_free_dock_slot(ship_id, _get_expected_dock_port(runtime))


func _reconcile_headquarters_slots() -> void:
	var occupied_slots := {}
	var awaiting_ids: Array[StringName] = []
	for ship_id in _states.keys():
		var runtime: ShipRuntimeState = _states[ship_id]
		if not runtime.awaiting_headquarters_dispatch:
			runtime.headquarters_slot_index = -1
			continue
		awaiting_ids.append(ship_id)
		if runtime.headquarters_slot_index >= 0 \
				and not occupied_slots.has(runtime.headquarters_slot_index):
			occupied_slots[runtime.headquarters_slot_index] = true
		else:
			runtime.headquarters_slot_index = -1
	awaiting_ids.sort()
	for ship_id in awaiting_ids:
		var runtime: ShipRuntimeState = _states[ship_id]
		if runtime.headquarters_slot_index >= 0:
			continue
		runtime.headquarters_slot_index = _first_free_index(occupied_slots)
		occupied_slots[runtime.headquarters_slot_index] = true


func _first_free_index(occupied_slots: Dictionary) -> int:
	var slot_index := 0
	while occupied_slots.has(slot_index):
		slot_index += 1
	return slot_index


func _is_ship_docked(ship_id: StringName) -> bool:
	if not _states.has(ship_id):
		return false
	var state: ShipRuntimeState.State = _states[ship_id].state
	return state == ShipRuntimeState.State.IDLE \
		or state == ShipRuntimeState.State.UNLOADING


func get_ship_data(ship_id: StringName) -> ShipData:
	return _data.get(ship_id, null)


func get_ship_name(ship_id: StringName) -> String:
	if not _states.has(ship_id):
		return ""
	return _states[ship_id].ship_name


func is_ship_name_available(
		requested_name: String,
		excluded_ship_id: StringName = &""
) -> bool:
	var normalized_name := requested_name.strip_edges()
	if normalized_name.length() < MIN_SHIP_NAME_LENGTH \
			or normalized_name.length() > MAX_SHIP_NAME_LENGTH:
		return false
	var comparison_name := normalized_name.to_lower()
	for candidate_id in _states.keys():
		if candidate_id == excluded_ship_id:
			continue
		var candidate_name: String = _states[candidate_id].ship_name
		if candidate_name.to_lower() == comparison_name:
			return false
	return true


func rename_ship(ship_id: StringName, requested_name: String) -> bool:
	if not _states.has(ship_id):
		return false
	var normalized_name := requested_name.strip_edges()
	if not is_ship_name_available(normalized_name, ship_id):
		return false
	var runtime: ShipRuntimeState = _states[ship_id]
	if runtime.ship_name == normalized_name:
		return true
	runtime.ship_name = normalized_name
	return true


func get_random_available_ship_name() -> String:
	return _generate_unique_ship_name()


func get_ship_speed_level(ship_id: StringName) -> int:
	if not _states.has(ship_id):
		return 0
	return _states[ship_id].speed_level


func get_ship_effective_speed(ship_id: StringName) -> float:
	var ship_data := get_ship_data(ship_id)
	if ship_data == null:
		return 0.0
	return EconomyManager.calculate_ship_speed(
		ship_data.base_speed,
		get_ship_speed_level(ship_id)
	)


func get_ship_sailing_speed(ship_id: StringName, cargo_amount: int = 0) -> float:
	return EconomyManager.calculate_ship_sailing_speed(
		get_ship_effective_speed(ship_id),
		cargo_amount
	)


func get_ship_speed_upgrade_cost(ship_id: StringName) -> int:
	var ship_data := get_ship_data(ship_id)
	if ship_data == null:
		return -1
	if get_ship_speed_level(ship_id) >= maxi(ship_data.max_speed_level, 0):
		return -1
	return EconomyManager.calculate_ship_speed_upgrade_cost(
		ship_data.speed_upgrade_base_cost,
		get_ship_speed_level(ship_id)
	)


func upgrade_ship_speed(ship_id: StringName) -> bool:
	if not _states.has(ship_id) or not _data.has(ship_id):
		return false
	var ship_data: ShipData = _data[ship_id]
	var runtime: ShipRuntimeState = _states[ship_id]
	if runtime.speed_level >= maxi(ship_data.max_speed_level, 0):
		return false
	runtime.speed_level += 1
	EventBus.ship_speed_upgraded.emit(
		ship_id,
		runtime.speed_level,
		get_ship_effective_speed(ship_id)
	)
	return true


func get_ship_capacity_level(ship_id: StringName) -> int:
	if not _states.has(ship_id):
		return 0
	return _states[ship_id].capacity_level


func get_ship_effective_capacity(ship_id: StringName) -> int:
	var ship_data := get_ship_data(ship_id)
	if ship_data == null:
		return 0
	return maxi(ship_data.cargo_capacity, 1) + get_ship_capacity_level(ship_id)


func get_ship_capacity_upgrade_cost(ship_id: StringName) -> int:
	var ship_data := get_ship_data(ship_id)
	if ship_data == null:
		return -1
	if get_ship_capacity_level(ship_id) >= maxi(ship_data.max_capacity_level, 0):
		return -1
	return EconomyManager.calculate_ship_capacity_upgrade_cost(
		ship_data.capacity_upgrade_base_cost,
		get_ship_capacity_level(ship_id)
	)


func upgrade_ship_capacity(ship_id: StringName) -> bool:
	if not _states.has(ship_id) or not _data.has(ship_id):
		return false
	var ship_data: ShipData = _data[ship_id]
	var runtime: ShipRuntimeState = _states[ship_id]
	if runtime.capacity_level >= maxi(ship_data.max_capacity_level, 0):
		return false
	runtime.capacity_level += 1
	EventBus.ship_capacity_upgraded.emit(
		ship_id,
		runtime.capacity_level,
		get_ship_effective_capacity(ship_id)
	)
	return true


func get_ship_total_upgrade_levels(ship_id: StringName) -> int:
	return get_ship_speed_level(ship_id) + get_ship_capacity_level(ship_id)


func is_ship_automation_unlocked(ship_id: StringName) -> bool:
	return _states.has(ship_id) and _states[ship_id].automation_unlocked


func is_ship_automation_enabled(ship_id: StringName) -> bool:
	return _states.has(ship_id) and _states[ship_id].automation_enabled


func unlock_ship_automation(ship_id: StringName) -> bool:
	if not _states.has(ship_id):
		return false
	var runtime: ShipRuntimeState = _states[ship_id]
	if runtime.automation_unlocked:
		return false
	runtime.automation_unlocked = true
	runtime.automation_enabled = true
	EventBus.ship_automation_changed.emit(ship_id, true, true)
	return true


func set_ship_automation_enabled(ship_id: StringName, enabled: bool) -> bool:
	if not _states.has(ship_id) or not _states[ship_id].automation_unlocked:
		return false
	var runtime: ShipRuntimeState = _states[ship_id]
	if runtime.automation_enabled == enabled:
		return true
	runtime.automation_enabled = enabled
	EventBus.ship_automation_changed.emit(ship_id, true, enabled)
	return true


func get_ship_model(model_id: StringName) -> ShipData:
	return _catalog.get(model_id, null)


func get_initial_ship_model() -> ShipData:
	for ship_data in _catalog.values():
		if ship_data.unlocked_by_default and ship_data.scene != null:
			return ship_data
	return null


func get_purchasable_ship_models() -> Array[ShipData]:
	var models: Array[ShipData] = []
	for ship_data in _catalog.values():
		if ship_data.scene != null and ship_data.purchase_cost > 0:
			models.append(ship_data)
	return models


func get_owned_model_count(model_id: StringName) -> int:
	var count := 0
	for state in _states.values():
		if state.model_id == model_id:
			count += 1
	return count


func get_fleet_capacity() -> int:
	var company_manager := get_node_or_null("/root/CompanyManager")
	var company_level := int(company_manager.get("company_level")) \
		if company_manager != null else 1
	# Existing saves may already own more ships than the newly introduced
	# level ceiling. Never remove them or display an impossible over-cap count;
	# simply block further purchases until progression catches up.
	return maxi(
		get_fleet_capacity_for_company_level(company_level),
		_states.size()
	)


func get_fleet_capacity_for_company_level(company_level: int) -> int:
	var level_index := clampi(
		company_level - 1,
		0,
		FLEET_CAPACITY_BY_COMPANY_LEVEL.size() - 1
	)
	return FLEET_CAPACITY_BY_COMPANY_LEVEL[level_index]


func get_next_fleet_capacity_level() -> int:
	var company_manager := get_node_or_null("/root/CompanyManager")
	var current_level := int(company_manager.get("company_level")) \
		if company_manager != null else 1
	var current_capacity := get_fleet_capacity()
	for level in range(current_level + 1, FLEET_CAPACITY_BY_COMPANY_LEVEL.size() + 1):
		if get_fleet_capacity_for_company_level(level) > current_capacity:
			return level
	return -1


func is_fleet_at_capacity() -> bool:
	return _states.size() >= get_fleet_capacity()


func get_ship_purchase_price(model_id: StringName) -> int:
	var ship_data := get_ship_model(model_id)
	if ship_data == null:
		return -1
	return EconomyManager.calculate_ship_purchase_price(
		ship_data.purchase_cost,
		_states.size()
	)


func purchase_ship(model_id: StringName, home_port_id: StringName) -> StringName:
	if is_fleet_at_capacity():
		return &""
	var ship_data := get_ship_model(model_id)
	if ship_data == null or ship_data.scene == null:
		return &""
	if not PortManager.is_unlocked(home_port_id):
		return &""

	_ship_sequence += 1
	var ship_id := StringName("%s_%d" % [model_id, _ship_sequence])
	while _states.has(ship_id):
		_ship_sequence += 1
		ship_id = StringName("%s_%d" % [model_id, _ship_sequence])

	var state := ShipRuntimeState.new()
	state.ship_id = ship_id
	state.model_id = model_id
	state.ship_name = _generate_unique_ship_name()
	state.current_port_id = home_port_id
	state.awaiting_headquarters_dispatch = true
	var occupied_headquarters_slots := {}
	for runtime: ShipRuntimeState in _states.values():
		if runtime.awaiting_headquarters_dispatch \
				and runtime.headquarters_slot_index >= 0:
			occupied_headquarters_slots[runtime.headquarters_slot_index] = true
	state.headquarters_slot_index = _first_free_index(occupied_headquarters_slots)
	state.state = ShipRuntimeState.State.IDLE
	_states[ship_id] = state
	_data[ship_id] = ship_data
	EventBus.ship_purchased.emit(ship_id, ship_data, home_port_id)
	return ship_id


func get_ship_node(ship_id: StringName) -> Node2D:
	return _nodes.get(ship_id, null)


func get_ship_mission_remaining_sec(ship_id: StringName, unix_time: float = -1.0) -> float:
	if not _states.has(ship_id):
		return 0.0
	var runtime: ShipRuntimeState = _states[ship_id]
	var mission := runtime.current_mission
	if mission == null:
		return 0.0
	var now := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var current_leg_remaining := maxf(
		mission.leg_start_unix + mission.leg_duration_sec - now,
		0.0
	)
	match runtime.state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			return current_leg_remaining + estimate_mission_duration(
				ship_id,
				mission.pickup_port_id,
				mission.delivery_port_id,
				mission.pickup_port_id,
				mission.loading_duration_sec,
				mission.cargo_amount,
				mission.unloading_duration_sec
			)
		ShipRuntimeState.State.LOADING:
			return current_leg_remaining + maxf(
				estimate_mission_duration(
					ship_id,
					mission.pickup_port_id,
					mission.delivery_port_id,
					mission.pickup_port_id,
					mission.loading_duration_sec,
					mission.cargo_amount,
					mission.unloading_duration_sec
				)
				- mission.loading_duration_sec,
				0.0
			)
		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			return current_leg_remaining + mission.unloading_duration_sec
		ShipRuntimeState.State.UNLOADING:
			return current_leg_remaining
		_:
			return 0.0


func estimate_mission_duration(
		ship_id: StringName,
		pickup_port_id: StringName,
		delivery_port_id: StringName,
		origin_port_id: StringName = &"",
		loading_duration_sec: float = -1.0,
		cargo_amount: int = 1,
		unloading_duration_sec: float = -1.0
) -> float:
	var ship_data: ShipData = get_ship_data(ship_id)
	if ship_data == null:
		return 0.0
	var actual_origin := origin_port_id
	if actual_origin == &"":
		actual_origin = get_ship_current_port(ship_id)
	var actual_loading_duration := loading_duration_sec
	if actual_loading_duration < 0.0:
		actual_loading_duration = get_mission_loading_duration(
			actual_origin,
			pickup_port_id
		)
	var actual_unloading_duration := unloading_duration_sec
	if actual_unloading_duration < 0.0:
		actual_unloading_duration = get_mission_unloading_duration(delivery_port_id)
	var pickup_sailing_duration := 0.0
	if actual_origin != pickup_port_id:
		pickup_sailing_duration = _estimate_sailing_duration(
			ship_id,
			actual_origin,
			pickup_port_id,
			0
		)
	var delivery_sailing_duration := _estimate_sailing_duration(
		ship_id,
		pickup_port_id,
		delivery_port_id,
		maxi(cargo_amount, 1)
	)
	var headquarters_dispatch_duration := HEADQUARTERS_DISPATCH_DURATION_SEC \
		if is_awaiting_headquarters_dispatch(ship_id) else 0.0
	return headquarters_dispatch_duration \
		+ pickup_sailing_duration \
		+ actual_loading_duration \
		+ delivery_sailing_duration \
		+ actual_unloading_duration


func get_mission_loading_duration(
		_origin_port_id: StringName,
		pickup_port_id: StringName
) -> float:
	return LOADING_DURATION_SEC * _get_port_handling_duration_multiplier(
		pickup_port_id
	)


func get_mission_unloading_duration(delivery_port_id: StringName) -> float:
	return UNLOADING_DURATION_SEC * _get_port_handling_duration_multiplier(
		delivery_port_id
	)


func _get_port_handling_duration_multiplier(port_id: StringName) -> float:
	var port_data: PortData = PortManager.get_port_data(port_id)
	if port_data == null:
		return 1.0
	return port_data.get_handling_duration_multiplier(
		PortManager.get_level(port_id)
	)


func _estimate_sailing_duration(
		ship_id: StringName,
		from_port_id: StringName,
		to_port_id: StringName,
		cargo_amount: int = 0
) -> float:
	var distance := PortManager.get_distance(from_port_id, to_port_id)
	if distance <= 0.0:
		return 0.0
	return maxf(
		distance / maxf(get_ship_sailing_speed(ship_id, cargo_amount), 1.0) \
				* SAILING_DURATION_SCALE,
		MIN_SAILING_DURATION_SEC
	)


## Hands a mission to an idle ship and kicks off the SAILING_TO_PICKUP leg.
## Called by MissionManager once Phase 4 exists; safe to call manually for
## testing before that.
func assign_mission(ship_id: StringName, mission: Mission) -> bool:
	if not _states.has(ship_id):
		push_warning("Tried to assign a mission to unregistered ship '%s'." % ship_id)
		return false

	var state: ShipRuntimeState = _states[ship_id]
	if state.state != ShipRuntimeState.State.IDLE:
		push_warning("Ship '%s' is not idle, cannot assign a new mission." % ship_id)
		return false
	if mission == null \
			or not can_reserve_dock_at_port(mission.delivery_port_id, ship_id):
		return false
	if _move_reservation_to_port(ship_id, mission.delivery_port_id) < 0:
		return false

	var headquarters_dispatch_duration := HEADQUARTERS_DISPATCH_DURATION_SEC \
		if state.awaiting_headquarters_dispatch else 0.0
	state.headquarters_dispatch_active = state.awaiting_headquarters_dispatch
	state.awaiting_headquarters_dispatch = false
	state.headquarters_slot_index = -1
	state.current_mission = mission
	mission.assigned_ship_id = ship_id
	_start_leg(
		ship_id,
		ShipRuntimeState.State.SAILING_TO_PICKUP,
		state.current_port_id,
		mission.pickup_port_id,
		-1.0,
		-1.0,
		headquarters_dispatch_duration
	)
	return true


func _process(_delta: float) -> void:
	for ship_id in _states.keys():
		var state: ShipRuntimeState = _states[ship_id]
		if state.state == ShipRuntimeState.State.IDLE:
			continue
		if state.current_mission != null and state.current_mission.is_leg_complete():
			_advance_state(ship_id, state)


## The state machine's transition table. Each branch starts the NEXT leg
## (or, for the final UNLOADING -> IDLE transition, completes the mission).
func _advance_state(
		ship_id: StringName,
		state: ShipRuntimeState,
		next_leg_start_unix: float = -1.0
) -> void:
	var mission: Mission = state.current_mission

	match state.state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			state.headquarters_dispatch_active = false
			var loading_duration := mission.loading_duration_sec
			if loading_duration <= 0.0:
				loading_duration = get_mission_loading_duration(
					state.current_port_id,
					mission.pickup_port_id
				)
				mission.loading_duration_sec = loading_duration
			state.current_port_id = mission.pickup_port_id
			_start_leg(ship_id, ShipRuntimeState.State.LOADING,
				mission.pickup_port_id, mission.pickup_port_id,
				loading_duration, next_leg_start_unix)

		ShipRuntimeState.State.LOADING:
			_start_leg(ship_id, ShipRuntimeState.State.SAILING_TO_DELIVERY,
				mission.pickup_port_id, mission.delivery_port_id,
				-1.0, next_leg_start_unix)

		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			state.current_port_id = mission.delivery_port_id
			var unloading_duration := mission.unloading_duration_sec
			if unloading_duration <= 0.0:
				unloading_duration = get_mission_unloading_duration(
					mission.delivery_port_id
				)
				mission.unloading_duration_sec = unloading_duration
			_start_leg(ship_id, ShipRuntimeState.State.UNLOADING,
				mission.delivery_port_id, mission.delivery_port_id,
				unloading_duration, next_leg_start_unix)

		ShipRuntimeState.State.UNLOADING:
			mission.stage = Mission.Stage.COMPLETED
			state.current_mission = null
			var previous := state.state
			state.state = ShipRuntimeState.State.IDLE
			EventBus.ship_state_changed.emit(ship_id, previous, state.state)
			EventBus.mission_completed.emit(mission)


## Starts a timed leg. Sailing legs (from_port_id != to_port_id) derive
## their duration from distance / ship speed; stationary legs (loading,
## unloading) pass forced_duration_sec instead of relying on distance.
func _start_leg(ship_id: StringName, new_state: ShipRuntimeState.State,
		from_port_id: StringName, to_port_id: StringName,
		forced_duration_sec: float = -1.0, leg_start_unix: float = -1.0,
		extra_duration_sec: float = 0.0) -> void:
	var state: ShipRuntimeState = _states[ship_id]
	var mission: Mission = state.current_mission

	var duration: float
	if forced_duration_sec >= 0.0:
		duration = forced_duration_sec
	else:
		var cargo_amount := mission.cargo_amount \
			if new_state == ShipRuntimeState.State.SAILING_TO_DELIVERY else 0
		duration = _estimate_sailing_duration(
			ship_id,
			from_port_id,
			to_port_id,
			cargo_amount
		)
	duration += maxf(extra_duration_sec, 0.0)

	mission.stage = _state_to_mission_stage(new_state)
	mission.start_leg(duration, leg_start_unix)
	# The delivery berth is reserved when the mission is accepted and remains
	# stable throughout pickup/loading. This prevents several ships from being
	# offered the same final free berth while they are still at sea.
	if mission != null and state.dock_port_id != mission.delivery_port_id:
		_move_reservation_to_port(ship_id, mission.delivery_port_id)

	var previous := state.state
	state.state = new_state
	EventBus.ship_state_changed.emit(ship_id, previous, new_state)
	EventBus.mission_stage_changed.emit(mission)


func _state_to_mission_stage(state: ShipRuntimeState.State) -> Mission.Stage:
	match state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			return Mission.Stage.SAILING_TO_PICKUP
		ShipRuntimeState.State.LOADING:
			return Mission.Stage.LOADING
		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			return Mission.Stage.SAILING_TO_DELIVERY
		ShipRuntimeState.State.UNLOADING:
			return Mission.Stage.UNLOADING
		_:
			return Mission.Stage.AWAITING_PICKUP


# --- Save/load hooks, wired up by SaveManager in Phase 7 --------------------

func get_save_state() -> Dictionary:
	var out := {}
	for id in _states.keys():
		out[String(id)] = _states[id].to_dict()
	return out


func apply_save_state(saved: Dictionary) -> void:
	var registered_data := _data.duplicate()
	_states.clear()
	_data.clear()
	for id_str in saved.keys():
		var ship_id := StringName(id_str)
		var state := ShipRuntimeState.from_dict(saved[id_str])
		_states[ship_id] = state
		var ship_data := get_ship_model(state.model_id)
		if ship_data == null:
			ship_data = registered_data.get(ship_id, null)
			if ship_data != null and state.model_id == &"":
				state.model_id = ship_data.id
		if ship_data != null:
			_data[ship_id] = ship_data
	_assign_missing_ship_names()
	_reconcile_headquarters_slots()
	_reconcile_dock_reservations()


func apply_offline_progress(unix_time: float) -> void:
	for ship_id in _states.keys():
		var state: ShipRuntimeState = _states[ship_id]
		var safety := 0
		while state.current_mission != null \
				and state.current_mission.is_leg_complete_at(unix_time) \
				and safety < 8:
			var completed_at := state.current_mission.leg_start_unix \
				+ state.current_mission.leg_duration_sec
			_advance_state(ship_id, state, completed_at)
			safety += 1


func reset_state() -> void:
	_states.clear()
	_data.clear()
	_nodes.clear()
	_ship_sequence = 0


func _assign_missing_ship_names() -> void:
	var sorted_ship_ids: Array[StringName] = []
	for ship_id in _states.keys():
		sorted_ship_ids.append(ship_id)
	sorted_ship_ids.sort()
	for ship_id in sorted_ship_ids:
		var runtime: ShipRuntimeState = _states[ship_id]
		if not runtime.ship_name.is_empty():
			continue
		var preferred_index := posmod(String(ship_id).hash(), SHIP_NAME_POOL.size())
		runtime.ship_name = _generate_unique_ship_name(preferred_index)


func _generate_unique_ship_name(preferred_index: int = -1) -> String:
	var pool_size := SHIP_NAME_POOL.size()
	if pool_size <= 0:
		return "Ship %d" % (_states.size() + 1)
	var start_index := preferred_index
	if start_index < 0:
		start_index = randi_range(0, pool_size - 1)
	for offset in range(pool_size):
		var candidate := SHIP_NAME_POOL[(start_index + offset) % pool_size]
		if is_ship_name_available(candidate):
			return candidate

	var suffix := 2
	while true:
		for base_name in SHIP_NAME_POOL:
			var candidate := "%s %d" % [base_name, suffix]
			if is_ship_name_available(candidate):
				return candidate
		suffix += 1
	return "Ship"


func _load_ship_catalog() -> void:
	_catalog.clear()
	for file_name in ResourceLoader.list_directory(SHIP_RESOURCE_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := file_name if file_name.begins_with("res://") \
				else "%s/%s" % [SHIP_RESOURCE_DIR, file_name]
		var resource := load(resource_path)
		if resource is ShipData and resource.id != &"":
			_catalog[resource.id] = resource
	if _catalog.is_empty():
		push_warning("No ship resources found in: %s" % SHIP_RESOURCE_DIR)
