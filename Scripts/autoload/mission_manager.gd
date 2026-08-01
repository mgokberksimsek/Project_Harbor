extends Node
## Owns generated mission offers and active mission lifecycle.
##
## Offers are runtime data. The player chooses one; MissionManager then
## assigns it to an idle ship. Port taps are reserved for port interaction
## and no longer create cargo missions directly.

const CARGO_RESOURCE_DIR := "res://Resources/cargo_types"
const OFFER_COUNT_PER_SHIP := 3
const MEDIUM_MISSION_THRESHOLD_SEC := 5.0 * 60.0
const LONG_MISSION_THRESHOLD_SEC := 45.0 * 60.0

var _active_missions: Dictionary = {}
var _offers: Array[Mission] = []
var _cargo_types: Array[CargoTypeData] = []
var _rng := RandomNumberGenerator.new()
var _mission_sequence: int = 0


func _ready() -> void:
	_rng.randomize()
	_load_cargo_types()
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_registered.connect(_on_ship_registered)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	call_deferred("refresh_offers")


func get_active_missions() -> Array[Mission]:
	var missions: Array[Mission] = []
	for mission in _active_missions.values():
		missions.append(mission)
	return missions


func get_offers() -> Array[Mission]:
	return _offers.duplicate()


func get_cargo_type(cargo_type_id: StringName) -> CargoTypeData:
	for cargo_type in _cargo_types:
		if cargo_type.id == cargo_type_id:
			return cargo_type
	return null


func refresh_offers() -> void:
	_offers.clear()
	var idle_ship_ids := FleetManager.get_idle_ship_ids()
	if idle_ship_ids.is_empty():
		EventBus.mission_offers_updated.emit(get_offers())
		return

	for ship_id in idle_ship_ids:
		var ship_port_id := FleetManager.get_ship_current_port(ship_id)
		if ship_port_id == &"":
			continue
		var candidates: Array[Dictionary] = _build_offer_candidates(ship_port_id, ship_id)

		# Always keep a useful local job and, whenever possible, a remote
		# pickup job among the three choices.
		for pickup_is_current_port in [true, false]:
			var candidate_index := _pick_candidate_index_for_pickup(
				candidates,
				ship_port_id,
				pickup_is_current_port
			)
			if candidate_index < 0 or _offers_for_ship(ship_id) >= OFFER_COUNT_PER_SHIP:
				continue
			var candidate: Dictionary = candidates[candidate_index]
			candidates.remove_at(candidate_index)
			_offers.append(_create_offer(
				ship_id,
				ship_port_id,
				candidate["pickup_id"],
				candidate["destination_id"],
				candidate["cargo_type"]
			))

		for _offer_index in range(mini(OFFER_COUNT_PER_SHIP, candidates.size())):
			if _offers_for_ship(ship_id) >= OFFER_COUNT_PER_SHIP:
				break
			var candidate_index := _pick_candidate_index(candidates)
			var candidate: Dictionary = candidates[candidate_index]
			candidates.remove_at(candidate_index)
			_offers.append(_create_offer(
				ship_id,
				ship_port_id,
				candidate["pickup_id"],
				candidate["destination_id"],
				candidate["cargo_type"]
			))

	EventBus.mission_offers_updated.emit(get_offers())


func accept_offer(offer_id: String, ship_id: StringName = &"") -> bool:
	var offer := _find_offer(offer_id)
	if offer == null:
		return false

	var selected_ship_id := offer.offered_ship_id if ship_id == &"" else ship_id
	if selected_ship_id != offer.offered_ship_id:
		return false
	if offer.origin_port_id != &"" \
			and FleetManager.get_ship_current_port(selected_ship_id) != offer.origin_port_id:
		return false

	var ship_data: ShipData = FleetManager.get_ship_data(selected_ship_id)
	var cargo_type := get_cargo_type(offer.cargo_type_id)
	if ship_data == null or not ship_data.can_carry(cargo_type):
		return false
	if not FleetManager.assign_mission(selected_ship_id, offer):
		return false

	_active_missions[offer.id] = offer
	_offers.erase(offer)
	EventBus.mission_offers_updated.emit(get_offers())
	EventBus.mission_generated.emit(offer)
	call_deferred("refresh_offers")
	return true


func _create_offer(
		ship_id: StringName,
		ship_port_id: StringName,
		pickup_port_id: StringName,
		delivery_port_id: StringName,
		cargo_type: CargoTypeData
) -> Mission:
	_mission_sequence += 1
	var mission := Mission.new()
	mission.id = "offer-%d-%d" % [Time.get_unix_time_from_system(), _mission_sequence]
	mission.offered_ship_id = ship_id
	mission.origin_port_id = ship_port_id
	mission.pickup_port_id = pickup_port_id
	mission.delivery_port_id = delivery_port_id
	mission.cargo_type_id = cargo_type.id if cargo_type != null else &""
	mission.cargo_amount = _rng.randi_range(
		1,
		maxi(FleetManager.get_ship_effective_capacity(ship_id), 1)
	)
	mission.reward = EconomyManager.calculate_mission_reward(
		pickup_port_id,
		delivery_port_id,
		cargo_type,
		mission.cargo_amount
	)
	mission.loading_duration_sec = FleetManager.get_mission_loading_duration(
		ship_port_id,
		pickup_port_id
	)
	mission.estimated_duration_sec = FleetManager.estimate_mission_duration(
		ship_id,
		pickup_port_id,
		delivery_port_id,
		ship_port_id,
		mission.loading_duration_sec
	)
	mission.duration_class = _classify_duration(mission.estimated_duration_sec)
	return mission


func _build_offer_candidates(
		ship_port_id: StringName,
		ship_id: StringName
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	var compatible_cargo_types := _get_compatible_cargo_types(ship_data)
	if compatible_cargo_types.is_empty():
		return candidates
	for pickup_id in PortManager.get_unlocked_port_ids():
		if pickup_id != ship_port_id \
				and not PortManager.has_sea_route(ship_port_id, pickup_id):
			continue
		for destination_id in _get_destinations(pickup_id):
			for cargo_type in compatible_cargo_types:
				candidates.append({
					"pickup_id": pickup_id,
					"destination_id": destination_id,
					"cargo_type": cargo_type,
					"weight": cargo_type.spawn_weight,
				})
	return candidates


func _offers_for_ship(ship_id: StringName) -> int:
	var count := 0
	for offer in _offers:
		if offer.offered_ship_id == ship_id:
			count += 1
	return count


func _pick_candidate_index_for_pickup(
		candidates: Array[Dictionary],
		ship_port_id: StringName,
		pickup_is_current_port: bool
) -> int:
	var matching_candidates: Array[Dictionary] = []
	var original_indices: Array[int] = []
	for index in range(candidates.size()):
		var is_current_port: bool = candidates[index]["pickup_id"] == ship_port_id
		if is_current_port == pickup_is_current_port:
			matching_candidates.append(candidates[index])
			original_indices.append(index)
	if matching_candidates.is_empty():
		return -1
	return original_indices[_pick_candidate_index(matching_candidates)]


func _pick_candidate_index(candidates: Array[Dictionary]) -> int:
	var total_weight: float = 0.0
	for candidate in candidates:
		total_weight += maxf(candidate["weight"], 0.0)
	if total_weight <= 0.0:
		return 0

	var roll := _rng.randf_range(0.0, total_weight)
	for index in range(candidates.size()):
		roll -= maxf(candidates[index]["weight"], 0.0)
		if roll <= 0.0:
			return index
	return candidates.size() - 1


func _get_destinations(pickup_port_id: StringName) -> Array[StringName]:
	var destinations: Array[StringName] = []
	for port_id in PortManager.get_unlocked_port_ids():
		if port_id != pickup_port_id and PortManager.has_sea_route(pickup_port_id, port_id):
			destinations.append(port_id)
	return destinations


func _classify_duration(duration_sec: float) -> Mission.DurationClass:
	if duration_sec >= LONG_MISSION_THRESHOLD_SEC:
		return Mission.DurationClass.LONG
	if duration_sec >= MEDIUM_MISSION_THRESHOLD_SEC:
		return Mission.DurationClass.MEDIUM
	return Mission.DurationClass.SHORT


func _find_offer(offer_id: String) -> Mission:
	for offer in _offers:
		if offer.id == offer_id:
			return offer
	return null


func _get_compatible_cargo_types(ship_data: ShipData) -> Array[CargoTypeData]:
	var compatible: Array[CargoTypeData] = []
	if ship_data == null:
		return compatible
	for cargo_type in _cargo_types:
		if cargo_type.spawn_weight > 0.0 and ship_data.can_carry(cargo_type):
			compatible.append(cargo_type)
	return compatible


func _pick_cargo_type(cargo_types: Array[CargoTypeData]) -> CargoTypeData:
	var total_weight: float = 0.0
	for cargo_type in cargo_types:
		total_weight += maxf(cargo_type.spawn_weight, 0.0)
	if total_weight <= 0.0:
		return null

	var roll := _rng.randf_range(0.0, total_weight)
	for cargo_type in cargo_types:
		roll -= maxf(cargo_type.spawn_weight, 0.0)
		if roll <= 0.0:
			return cargo_type
	return cargo_types.back()


func _load_cargo_types() -> void:
	_cargo_types.clear()
	var directory := DirAccess.open(CARGO_RESOURCE_DIR)
	if directory == null:
		push_warning("Cargo resource directory could not be opened: %s" % CARGO_RESOURCE_DIR)
		return
	for file_name in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var resource := load("%s/%s" % [CARGO_RESOURCE_DIR, file_name])
		if resource is CargoTypeData:
			_cargo_types.append(resource)


func _on_mission_completed(mission: Mission) -> void:
	_active_missions.erase(mission.id)
	call_deferred("refresh_offers")


func _on_port_unlocked(_port_id: StringName) -> void:
	if not FleetManager.get_idle_ship_ids().is_empty():
		call_deferred("refresh_offers")


func _on_ship_purchased(
		_ship_id: StringName,
		_ship_data: ShipData,
		_home_port_id: StringName
) -> void:
	call_deferred("refresh_offers")


func _on_ship_registered(_ship_id: StringName) -> void:
	call_deferred("refresh_offers")


func _on_ship_speed_upgraded(ship_id: StringName, _new_level: int, _new_speed: float) -> void:
	if FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		call_deferred("refresh_offers")


func _on_ship_capacity_upgraded(ship_id: StringName, _new_level: int, _new_capacity: int) -> void:
	if FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		call_deferred("refresh_offers")


func get_save_state() -> Dictionary:
	var active: Array[Dictionary] = []
	for mission in _active_missions.values():
		active.append(mission.to_dict())
	var offers: Array[Dictionary] = []
	for mission in _offers:
		offers.append(mission.to_dict())
	return {
		"active_missions": active,
		"offers": offers,
		"mission_sequence": _mission_sequence,
	}


func apply_save_state(saved: Dictionary) -> void:
	_active_missions.clear()
	_offers.clear()
	for mission_data in saved.get("active_missions", []):
		var mission := Mission.from_dict(mission_data)
		_active_missions[mission.id] = mission
	for mission_data in saved.get("offers", []):
		_offers.append(Mission.from_dict(mission_data))
	_mission_sequence = maxi(int(saved.get("mission_sequence", 0)), 0)


func sync_active_missions_from_fleet() -> void:
	_active_missions.clear()
	for ship_id in FleetManager.get_all_ship_ids():
		var mission := FleetManager.get_ship_mission(ship_id)
		if mission != null:
			_active_missions[mission.id] = mission


func reset_state() -> void:
	_active_missions.clear()
	_offers.clear()
	_mission_sequence = 0
	EventBus.mission_offers_updated.emit(get_offers())
