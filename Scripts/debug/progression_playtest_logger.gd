extends Node
## Debug-only observer for local Android balance playtests.
##
## GameManager loads this script dynamically only in debug builds. It observes
## existing EventBus facts, prints one-line JSON records for ADB/logcat, and
## keeps only a small debug continuity file outside the gameplay save.

signal record_emitted(category: String, record_name: String, payload: Dictionary)

const LOG_PREFIX := "PH_PLAYTEST"
const LOG_CHUNK_PREFIX := "PH_PLAYTEST_CHUNK"
# Conservative character bound keeps localized UTF-8 records below logcat's
# per-entry byte limit after protocol metadata is included.
const LOG_CHUNK_CHARACTER_LIMIT := 700
const ROUTE_DEBUG_SAMPLE_INTERVAL_SEC := 0.5
const ROUTE_DEBUG_PROGRESS_STEPS := 10
const STATE_VERSION := 1
const DEFAULT_STATE_PATH := "user://progression_playtest_state.json"
const DEFAULT_GAME_SAVE_PATH := "user://savegame.json"

const PORT_MILESTONES := {
	&"antalya": "ANTALYA_UNLOCKED",
	&"canakkale": "CANAKKALE_UNLOCKED",
	&"samsun": "SAMSUN_UNLOCKED",
	&"trabzon": "TRABZON_UNLOCKED",
	&"pire": "PIRE_UNLOCKED",
	&"varna": "VARNA_UNLOCKED",
}

const LEVEL_MILESTONES := {
	4: "COMPANY_LEVEL_4",
	5: "COMPANY_LEVEL_5",
	6: "COMPANY_LEVEL_6",
	7: "COMPANY_LEVEL_7",
	8: "COMPANY_LEVEL_8",
}

var state_path := DEFAULT_STATE_PATH
var game_save_path := DEFAULT_GAME_SAVE_PATH

var _run_active := false
var _awaiting_initial_load := true
var _foreground := true
var _run_id := ""
var _run_started_unix := 0.0
var _active_sec := 0.0
var _event_sequence := 0
var _milestones: Dictionary = {}
var _offer_batch_by_id: Dictionary = {}
var _route_debug_signatures: Dictionary = {}
var _route_debug_elapsed := 0.0

var _normal_missions_completed := 0
var _large_contracts_completed := 0
var _total_net_mission_earnings := 0
var _ship_purchase_spend := 0
var _port_unlock_spend := 0
var _ship_speed_upgrade_spend := 0
var _ship_capacity_upgrade_spend := 0
var _port_upgrade_spend := 0
var _automation_spend := 0

var _ship_purchase_spend_by_id: Dictionary = {}
var _ship_speed_spend_by_id: Dictionary = {}
var _ship_capacity_spend_by_id: Dictionary = {}
var _automation_spend_by_id: Dictionary = {}
var _port_unlock_spend_by_id: Dictionary = {}
var _port_upgrade_spend_by_id: Dictionary = {}
var _known_automation_unlocked: Dictionary = {}
var _known_automation_enabled: Dictionary = {}
var _pending_cash_spend := 0


func _ready() -> void:
	set_process(true)
	_load_continuity_state()
	EventBus.fresh_game_started.connect(_on_fresh_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.mission_offers_updated.connect(_on_mission_offers_updated)
	EventBus.mission_generated.connect(_on_mission_generated)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	EventBus.port_leveled_up.connect(_on_port_leveled_up)
	EventBus.ship_automation_changed.connect(_on_ship_automation_changed)
	EventBus.company_level_changed.connect(_on_company_level_changed)


func _process(delta: float) -> void:
	if not _run_active or not _foreground:
		return
	var safe_delta := maxf(delta, 0.0)
	_active_sec += safe_delta
	_route_debug_elapsed += safe_delta
	if _route_debug_elapsed < ROUTE_DEBUG_SAMPLE_INTERVAL_SEC:
		return
	_route_debug_elapsed = 0.0
	_sample_large_contract_routes()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_set_foreground(false)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_set_foreground(true)


func _exit_tree() -> void:
	if _run_active:
		_save_continuity_state()


func _set_foreground(is_foreground: bool) -> void:
	if _foreground == is_foreground:
		return
	_foreground = is_foreground
	if _run_active:
		_emit_record(
			"CONTROL",
			"APP_RESUMED" if is_foreground else "APP_PAUSED",
			{}
		)
		_save_continuity_state()


func _on_fresh_game_started() -> void:
	_reset_run_state()
	_run_active = true
	_awaiting_initial_load = false
	_foreground = true
	_run_started_unix = Time.get_unix_time_from_system()
	_run_id = "%d-%d" % [int(_run_started_unix), Time.get_ticks_usec()]
	_emit_record("CONTROL", "RUN_STARTED", {
		"state_version": STATE_VERSION,
	})
	_emit_event("GAME_STARTED", {})
	_record_milestone("GAME_STARTED")
	_save_continuity_state()


func _on_game_loaded() -> void:
	if not _run_active or not _awaiting_initial_load:
		return
	_awaiting_initial_load = false
	_foreground = true
	_sync_known_automation_state()
	_emit_record("CONTROL", "RUN_RESUMED", {
		"state_version": STATE_VERSION,
	})
	_save_continuity_state()


func _on_money_changed(_new_amount: int, delta: int) -> void:
	if not _can_record_runtime_event():
		return
	if delta < 0:
		_pending_cash_spend = -delta
	elif delta > 0 and _pending_cash_spend > 0:
		# A failed manager operation refunds its synchronous transaction.
		_pending_cash_spend = 0


func _on_ship_purchased(
	ship_id: StringName,
	ship_data: ShipData,
	home_port_id: StringName
) -> void:
	if not _can_record_runtime_event() or ship_data == null:
		return
	var previous_owned_count := maxi(FleetManager.get_all_ship_ids().size() - 1, 0)
	var fallback_cost := EconomyManager.calculate_ship_purchase_price(
		ship_data.purchase_cost,
		previous_owned_count
	)
	var cost := _take_pending_cash_spend(fallback_cost)
	_ship_purchase_spend += cost
	_add_dictionary_amount(_ship_purchase_spend_by_id, ship_id, cost)
	_known_automation_unlocked[String(ship_id)] = false
	_known_automation_enabled[String(ship_id)] = false
	_emit_event("SHIP_PURCHASED", {
		"ship_id": String(ship_id),
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id),
		"model_name": ship_data.display_name,
		"home_port_id": String(home_port_id),
		"cost": cost,
		"company_value_gain": maxi(ship_data.base_company_value, 0),
		"ship_total_investment": _get_ship_total_investment(ship_id),
	})
	var fleet_size := FleetManager.get_all_ship_ids().size()
	if fleet_size == 1:
		_record_milestone("FIRST_SHIP_PURCHASED")
	if fleet_size == 2:
		_record_milestone("SECOND_SHIP_PURCHASED")
	if ship_data.id == &"bulk_carrier":
		_record_milestone("FIRST_BULK_CARRIER_PURCHASED")
	_save_continuity_state()


func _on_port_unlocked(port_id: StringName) -> void:
	if not _can_record_runtime_event():
		return
	var port_data: PortData = PortManager.get_port_data(port_id)
	if port_data == null:
		return
	var cost := _take_pending_cash_spend(maxi(port_data.base_unlock_cost, 0))
	_port_unlock_spend += cost
	_add_dictionary_amount(_port_unlock_spend_by_id, port_id, cost)
	_emit_event("PORT_UNLOCKED", {
		"port_id": String(port_id),
		"port_name": port_data.display_name,
		"cost": cost,
		"company_value_gain": maxi(port_data.base_company_value, 0),
		"port_total_investment": _get_port_total_investment(port_id),
	})
	var milestone_name := String(PORT_MILESTONES.get(port_id, ""))
	if not milestone_name.is_empty():
		_record_milestone(milestone_name)
	_save_continuity_state()


func _on_ship_speed_upgraded(
	ship_id: StringName,
	new_level: int,
	new_speed: float
) -> void:
	if not _can_record_runtime_event():
		return
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	if ship_data == null:
		return
	var previous_level := maxi(new_level - 1, 0)
	var fallback_cost := EconomyManager.calculate_ship_speed_upgrade_cost(
		ship_data.speed_upgrade_base_cost,
		previous_level
	)
	var cost := _take_pending_cash_spend(fallback_cost)
	var previous_speed := EconomyManager.calculate_ship_speed(
		ship_data.base_speed,
		previous_level
	)
	var company_value_gain := maxi(ship_data.speed_upgrade_company_value, 0)
	_ship_speed_upgrade_spend += cost
	_add_dictionary_amount(_ship_speed_spend_by_id, ship_id, cost)
	_emit_event("SHIP_SPEED_UPGRADED", {
		"ship_id": String(ship_id),
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id),
		"previous_level": previous_level,
		"new_level": new_level,
		"cost": cost,
		"previous_value": previous_speed,
		"new_value": new_speed,
		"previous_effective_speed": previous_speed,
		"new_effective_speed": new_speed,
		"company_value_gain": company_value_gain,
		"ship_upgrade_spend": _get_ship_upgrade_spend(ship_id),
		"ship_total_investment": _get_ship_total_investment(ship_id),
	})
	_save_continuity_state()


func _on_ship_capacity_upgraded(
	ship_id: StringName,
	new_level: int,
	new_capacity: int
) -> void:
	if not _can_record_runtime_event():
		return
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	if ship_data == null:
		return
	var previous_level := maxi(new_level - 1, 0)
	var fallback_cost := EconomyManager.calculate_ship_capacity_upgrade_cost(
		ship_data.capacity_upgrade_base_cost,
		previous_level
	)
	var cost := _take_pending_cash_spend(fallback_cost)
	var previous_capacity := maxi(new_capacity - 1, 0)
	var company_value_gain := maxi(ship_data.capacity_upgrade_company_value, 0)
	_ship_capacity_upgrade_spend += cost
	_add_dictionary_amount(_ship_capacity_spend_by_id, ship_id, cost)
	_emit_event("SHIP_CAPACITY_UPGRADED", {
		"ship_id": String(ship_id),
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id),
		"previous_level": previous_level,
		"new_level": new_level,
		"cost": cost,
		"previous_value": previous_capacity,
		"new_value": new_capacity,
		"previous_capacity": previous_capacity,
		"new_capacity": new_capacity,
		"company_value_gain": company_value_gain,
		"ship_upgrade_spend": _get_ship_upgrade_spend(ship_id),
		"ship_total_investment": _get_ship_total_investment(ship_id),
	})
	_save_continuity_state()


func _on_port_leveled_up(port_id: StringName, new_level: int) -> void:
	if not _can_record_runtime_event():
		return
	var port_data: PortData = PortManager.get_port_data(port_id)
	if port_data == null:
		return
	var previous_level := maxi(new_level - 1, 1)
	var fallback_cost := maxi(port_data.get_upgrade_cost(previous_level), 0)
	var cost := _take_pending_cash_spend(fallback_cost)
	var previous_loading_duration := FleetManager.LOADING_DURATION_SEC \
		* port_data.get_handling_duration_multiplier(previous_level)
	var new_loading_duration := FleetManager.LOADING_DURATION_SEC \
		* port_data.get_handling_duration_multiplier(new_level)
	var previous_unloading_duration := FleetManager.UNLOADING_DURATION_SEC \
		* port_data.get_handling_duration_multiplier(previous_level)
	var new_unloading_duration := FleetManager.UNLOADING_DURATION_SEC \
		* port_data.get_handling_duration_multiplier(new_level)
	var company_value_gain := port_data.get_upgrade_company_value(previous_level)
	_port_upgrade_spend += cost
	_add_dictionary_amount(_port_upgrade_spend_by_id, port_id, cost)
	_emit_event("PORT_UPGRADED", {
		"port_id": String(port_id),
		"port_name": port_data.display_name,
		"previous_level": previous_level,
		"new_level": new_level,
		"cost": cost,
		"company_value_gain": company_value_gain,
		"previous_reward_modifier": port_data.get_reward_multiplier(previous_level),
		"new_reward_modifier": port_data.get_reward_multiplier(new_level),
		"previous_handling_time": previous_loading_duration,
		"new_handling_time": new_loading_duration,
		"previous_loading_duration": previous_loading_duration,
		"new_loading_duration": new_loading_duration,
		"previous_unloading_duration": previous_unloading_duration,
		"new_unloading_duration": new_unloading_duration,
		"previous_handling_multiplier": port_data.get_handling_duration_multiplier(
			previous_level
		),
		"new_handling_multiplier": port_data.get_handling_duration_multiplier(
			new_level
		),
		"previous_berths": PortManager.get_dock_slot_count_for_level(
			port_id,
			previous_level
		),
		"new_berths": PortManager.get_dock_slot_count_for_level(port_id, new_level),
		"port_total_investment": _get_port_total_investment(port_id),
	})
	_save_continuity_state()


func _on_ship_automation_changed(
	ship_id: StringName,
	unlocked: bool,
	enabled: bool
) -> void:
	if not _can_record_runtime_event():
		return
	var key := String(ship_id)
	var was_unlocked := bool(_known_automation_unlocked.get(key, false))
	var was_enabled := bool(_known_automation_enabled.get(key, false))
	_known_automation_unlocked[key] = unlocked
	_known_automation_enabled[key] = enabled
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	var base_payload := {
		"ship_id": key,
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id) if ship_data != null else "",
	}
	if unlocked and not was_unlocked:
		var cost := _take_pending_cash_spend(GameManager.AUTOMATION_UNLOCK_COST)
		_automation_spend += cost
		_add_dictionary_amount(_automation_spend_by_id, ship_id, cost)
		var unlock_payload := base_payload.duplicate()
		unlock_payload["cost"] = cost
		unlock_payload["ship_total_investment"] = _get_ship_total_investment(ship_id)
		_emit_event("AUTOMATION_UNLOCKED", unlock_payload)
		_record_milestone("FIRST_AUTOMATION_UNLOCKED")
		if enabled:
			_emit_event("AUTOMATION_ENABLED", base_payload)
	elif enabled != was_enabled:
		_emit_event(
			"AUTOMATION_ENABLED" if enabled else "AUTOMATION_DISABLED",
			base_payload
		)
	_save_continuity_state()


func _on_company_level_changed(new_level: int, previous_level: int) -> void:
	if not _can_record_runtime_event() or new_level <= previous_level:
		return
	# Asset signals trigger CompanyManager synchronously before this observer
	# receives the originating purchase/upgrade. Deferring gives that investment
	# event time to update cumulative spend before the level milestone snapshot.
	call_deferred("_record_company_level_changed", new_level, previous_level)


func _record_company_level_changed(new_level: int, previous_level: int) -> void:
	if not _can_record_runtime_event():
		return
	_emit_event("COMPANY_LEVEL_CHANGED", {
		"previous_level": previous_level,
		"new_level": new_level,
	})
	for level in range(previous_level + 1, new_level + 1):
		var milestone_name := String(LEVEL_MILESTONES.get(level, ""))
		if not milestone_name.is_empty():
			_record_milestone(milestone_name)
	_save_continuity_state()


func _on_mission_offers_updated(offers: Array) -> void:
	if not _can_record_runtime_event():
		return
	var batch_id := "%s:offers:%d" % [_run_id, _event_sequence + 1]
	var offers_by_ship := {}
	for idle_ship_id in FleetManager.get_idle_ship_ids():
		offers_by_ship[String(idle_ship_id)] = 0
	var valid_offer_count := 0
	for candidate in offers:
		if not (candidate is Mission):
			continue
		var offer := candidate as Mission
		if FleetManager.get_ship_state(offer.offered_ship_id) \
				!= ShipRuntimeState.State.IDLE:
			continue
		_offer_batch_by_id[offer.id] = batch_id
		var ship_key := String(offer.offered_ship_id)
		offers_by_ship[ship_key] = int(offers_by_ship.get(ship_key, 0)) + 1
		valid_offer_count += 1
		_emit_event(
			"MISSION_OFFER_PRESENTED",
			_build_mission_offer_payload(offer, batch_id, false)
		)
	_emit_event("MISSION_OFFER_BATCH", {
		"offer_batch_id": batch_id,
		"offer_count": valid_offer_count,
		"idle_ship_count": FleetManager.get_idle_ship_ids().size(),
		"offers_by_ship": offers_by_ship,
	})


func _on_mission_generated(mission: Mission) -> void:
	if not _can_record_runtime_event() or mission == null:
		return
	_emit_event("MISSION_OFFER_SELECTED", _build_mission_offer_payload(
		mission,
		String(_offer_batch_by_id.get(mission.id, "")),
		true
	))


func _build_mission_offer_payload(
		mission: Mission,
		offer_batch_id: String,
		is_selected: bool
) -> Dictionary:
	var ship_id := mission.offered_ship_id
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	var cargo_data: CargoTypeData = MissionManager.get_cargo_type(
		mission.cargo_type_id
	)
	var contract_ports: Array[String] = []
	for contract_port_id in mission.contract_port_ids:
		contract_ports.append(String(contract_port_id))
	return {
		"offer_batch_id": offer_batch_id,
		"offer_id": mission.id,
		"ship_id": String(ship_id),
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id) if ship_data != null else "",
		"origin_port": String(mission.origin_port_id),
		"pickup_port": String(mission.pickup_port_id),
		"destination_port": String(mission.delivery_port_id),
		"final_destination_port": String(mission.get_final_delivery_port_id()),
		"contract_ports": contract_ports,
		"pickup_is_local": mission.origin_port_id == mission.pickup_port_id,
		"pickup_type": "local" \
			if mission.origin_port_id == mission.pickup_port_id else "remote",
		"cargo_type": String(mission.cargo_type_id),
		"cargo_name": cargo_data.display_name if cargo_data != null else "",
		"cargo_amount": mission.cargo_amount,
		"gross_reward": mission.reward,
		"operating_cost": mission.operating_cost,
		"net_reward": mission.get_net_reward(),
		"mission_duration": mission.estimated_duration_sec,
		"net_per_min": float(mission.get_net_reward()) \
			/ maxf(mission.estimated_duration_sec, 0.001) * 60.0,
		"is_large_contract": mission.is_large_contract(),
		"is_selected": is_selected,
		"automation_enabled": FleetManager.is_ship_automation_enabled(ship_id),
	}


func _sample_large_contract_routes() -> void:
	if not _can_record_runtime_event():
		return
	var active_ship_ids := {}
	for ship_id in FleetManager.get_all_ship_ids():
		var mission := FleetManager.get_ship_mission(ship_id)
		if mission == null or not mission.is_large_contract():
			continue
		var ship_node := FleetManager.get_ship_node(ship_id) as Ship
		if ship_node == null:
			continue
		var ship_key := String(ship_id)
		active_ship_ids[ship_key] = true
		var route_state := ship_node.get_route_visual_debug_state()
		var progress_bucket := clampi(
			floori(float(route_state.get("current_leg_progress", 0.0)) \
				* ROUTE_DEBUG_PROGRESS_STEPS),
			0,
			ROUTE_DEBUG_PROGRESS_STEPS
		)
		route_state["progress_bucket"] = progress_bucket
		var signature := "%s|%s|%s|%s|%s" % [
			route_state.get("ship_state", -1),
			route_state.get("contract_leg_index", -1),
			progress_bucket,
			route_state.get("route_point_count", 0),
			route_state.get("route_visible", false),
		]
		if String(_route_debug_signatures.get(ship_key, "")) == signature:
			continue
		_route_debug_signatures[ship_key] = signature
		_emit_event("LARGE_CONTRACT_ROUTE_STATE", route_state)
	for recorded_ship_id in _route_debug_signatures.keys():
		if not active_ship_ids.has(recorded_ship_id):
			_route_debug_signatures.erase(recorded_ship_id)


func _on_mission_completed(mission: Mission) -> void:
	if not _run_active or mission == null:
		return
	if _awaiting_initial_load and not FleetManager.is_applying_offline_progress():
		return
	# Mission payout may be negative in future balance data. It is income/cost,
	# never an asset investment waiting for the next purchase signal.
	_pending_cash_spend = 0
	var is_large := mission.is_large_contract()
	if is_large:
		_large_contracts_completed += 1
	else:
		_normal_missions_completed += 1
	_total_net_mission_earnings += mission.get_net_reward()
	var ship_id := mission.assigned_ship_id
	var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
	var pickup_port_id := mission.pickup_port_id
	var delivery_port_id := mission.delivery_port_id
	var contract_ports: Array[String] = []
	for contract_port_id in mission.contract_port_ids:
		contract_ports.append(String(contract_port_id))
	if is_large and not mission.contract_port_ids.is_empty():
		pickup_port_id = mission.contract_port_ids[0]
		delivery_port_id = mission.get_final_delivery_port_id()
	var cargo_data: CargoTypeData = MissionManager.get_cargo_type(mission.cargo_type_id)
	_emit_event("LARGE_CONTRACT_COMPLETED" if is_large else "MISSION_COMPLETED", {
		"mission_id": mission.id,
		"ship_id": String(ship_id),
		"ship_name": FleetManager.get_ship_name(ship_id),
		"model": String(ship_data.id) if ship_data != null else "",
		"pickup_port": String(pickup_port_id),
		"delivery_port": String(delivery_port_id),
		"contract_ports": contract_ports,
		"cargo_type": String(mission.cargo_type_id),
		"cargo_name": cargo_data.display_name if cargo_data != null else "",
		"cargo_amount": mission.cargo_amount,
		"gross_reward": mission.reward,
		"operating_cost": mission.operating_cost,
		"net_reward": mission.get_net_reward(),
		"mission_duration": mission.estimated_duration_sec,
		"is_large_contract": is_large,
		"completed_offline": FleetManager.is_applying_offline_progress(),
	})
	if is_large:
		_record_milestone("FIRST_LARGE_CONTRACT_COMPLETED")
	_save_continuity_state()


func _record_milestone(milestone_name: String) -> void:
	if not _run_active or _milestones.has(milestone_name):
		return
	_milestones[milestone_name] = true
	_emit_record("MILESTONE", milestone_name, _build_snapshot())


func _emit_event(event_name: String, details: Dictionary) -> void:
	var payload := _build_common_payload()
	payload.merge(details, true)
	_emit_record("EVENT", event_name, payload)


func _emit_record(category: String, record_name: String, details: Dictionary) -> void:
	if not _run_active:
		return
	_event_sequence += 1
	var payload := _build_common_payload()
	payload.merge(details, true)
	payload["event_id"] = "%s:%d" % [_run_id, _event_sequence]
	record_emitted.emit(category, record_name, payload.duplicate(true))
	var json_payload := JSON.stringify(payload)
	var regular_line := "%s|%s|%s|%s" % [
		LOG_PREFIX,
		category,
		record_name,
		json_payload,
	]
	if regular_line.length() <= LOG_CHUNK_CHARACTER_LIMIT:
		print(regular_line)
		return
	var chunk_count := ceili(
		float(json_payload.length()) / float(LOG_CHUNK_CHARACTER_LIMIT)
	)
	for chunk_index in range(chunk_count):
		var chunk := json_payload.substr(
			chunk_index * LOG_CHUNK_CHARACTER_LIMIT,
			LOG_CHUNK_CHARACTER_LIMIT
		)
		print("%s|%s|%d|%d|%s|%s|%s" % [
			LOG_CHUNK_PREFIX,
			payload["event_id"],
			chunk_index,
			chunk_count,
			category,
			record_name,
			chunk,
		])


func _build_common_payload() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	return {
		"run_id": _run_id,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"unix_time": now,
		"active_sec": snappedf(maxf(_active_sec, 0.0), 0.001),
		"elapsed_sec": snappedf(maxf(now - _run_started_unix, 0.0), 0.001),
		"cash": GameManager.money,
		"company_value": CompanyManager.company_value,
		"peak_company_value": CompanyManager.peak_company_value,
		"company_level": CompanyManager.company_level,
	}


func _build_snapshot() -> Dictionary:
	var snapshot := _build_common_payload()
	var ship_ids := FleetManager.get_all_ship_ids()
	ship_ids.sort()
	var fleet_models: Dictionary = {}
	var ship_details: Array[Dictionary] = []
	var ship_upgrade_parts: Array[String] = []
	var automation_unlocked_count := 0
	var automation_enabled_count := 0
	for ship_id in ship_ids:
		var ship_data: ShipData = FleetManager.get_ship_data(ship_id)
		if ship_data == null:
			continue
		var model_id := String(ship_data.id)
		fleet_models[model_id] = int(fleet_models.get(model_id, 0)) + 1
		var ship_name := FleetManager.get_ship_name(ship_id)
		var speed_level := FleetManager.get_ship_speed_level(ship_id)
		var capacity_level := FleetManager.get_ship_capacity_level(ship_id)
		var upgrade_spend := _get_ship_upgrade_spend(ship_id)
		ship_upgrade_parts.append("%s(%s): S%d/C%d" % [
			ship_name,
			model_id,
			speed_level,
			capacity_level,
		])
		ship_details.append({
			"ship_id": String(ship_id),
			"ship_name": ship_name,
			"model": model_id,
			"speed_level": speed_level,
			"capacity_level": capacity_level,
			"effective_speed": FleetManager.get_ship_effective_speed(ship_id),
			"effective_capacity": FleetManager.get_ship_effective_capacity(ship_id),
			"ship_upgrade_spend": upgrade_spend,
			"ship_total_investment": _get_ship_total_investment(ship_id),
		})
		if FleetManager.is_ship_automation_unlocked(ship_id):
			automation_unlocked_count += 1
		if FleetManager.is_ship_automation_enabled(ship_id):
			automation_enabled_count += 1

	var port_ids := PortManager.get_unlocked_port_ids()
	port_ids.sort()
	var unlocked_ports: Array[String] = []
	var port_details: Array[Dictionary] = []
	var port_level_parts: Array[String] = []
	for port_id in port_ids:
		var port_data: PortData = PortManager.get_port_data(port_id)
		if port_data == null:
			continue
		var port_level := PortManager.get_level(port_id)
		unlocked_ports.append(String(port_id))
		port_level_parts.append("%s:L%d" % [port_data.display_name, port_level])
		port_details.append({
			"port_id": String(port_id),
			"port_name": port_data.display_name,
			"level": port_level,
			"unlock_spend": int(_port_unlock_spend_by_id.get(String(port_id), 0)),
			"upgrade_spend": int(_port_upgrade_spend_by_id.get(String(port_id), 0)),
			"total_investment": _get_port_total_investment(port_id),
		})

	snapshot.merge({
		"fleet_size": ship_ids.size(),
		"fleet_models": fleet_models,
		"ship_upgrade_state": " | ".join(ship_upgrade_parts),
		"ship_upgrade_details": ship_details,
		"unlocked_ports": unlocked_ports,
		"port_levels": " | ".join(port_level_parts),
		"port_details": port_details,
		"missions_completed": _normal_missions_completed,
		"large_contracts": _large_contracts_completed,
		"total_net_mission_earnings": _total_net_mission_earnings,
		"ship_purchase_spend": _ship_purchase_spend,
		"port_unlock_spend": _port_unlock_spend,
		"ship_speed_upgrade_spend": _ship_speed_upgrade_spend,
		"ship_capacity_upgrade_spend": _ship_capacity_upgrade_spend,
		"total_ship_upgrade_spend": (
			_ship_speed_upgrade_spend + _ship_capacity_upgrade_spend
		),
		"port_upgrade_spend": _port_upgrade_spend,
		"automation_spend": _automation_spend,
		"automation_unlocked_count": automation_unlocked_count,
		"automation_enabled_count": automation_enabled_count,
	}, true)
	return snapshot


func _take_pending_cash_spend(fallback_cost: int) -> int:
	var cost := _pending_cash_spend if _pending_cash_spend > 0 else fallback_cost
	_pending_cash_spend = 0
	return maxi(cost, 0)


func _add_dictionary_amount(target: Dictionary, id: StringName, amount: int) -> void:
	var key := String(id)
	target[key] = int(target.get(key, 0)) + maxi(amount, 0)


func _get_ship_upgrade_spend(ship_id: StringName) -> int:
	var key := String(ship_id)
	return int(_ship_speed_spend_by_id.get(key, 0)) \
		+ int(_ship_capacity_spend_by_id.get(key, 0))


func _get_ship_total_investment(ship_id: StringName) -> int:
	var key := String(ship_id)
	return int(_ship_purchase_spend_by_id.get(key, 0)) \
		+ _get_ship_upgrade_spend(ship_id) \
		+ int(_automation_spend_by_id.get(key, 0))


func _get_port_total_investment(port_id: StringName) -> int:
	var key := String(port_id)
	return int(_port_unlock_spend_by_id.get(key, 0)) \
		+ int(_port_upgrade_spend_by_id.get(key, 0))


func _can_record_runtime_event() -> bool:
	return _run_active and not _awaiting_initial_load


func _sync_known_automation_state() -> void:
	for ship_id in FleetManager.get_all_ship_ids():
		var key := String(ship_id)
		if not _known_automation_unlocked.has(key):
			_known_automation_unlocked[key] = FleetManager.is_ship_automation_unlocked(
				ship_id
			)
		if not _known_automation_enabled.has(key):
			_known_automation_enabled[key] = FleetManager.is_ship_automation_enabled(
				ship_id
			)


func _reset_run_state() -> void:
	_run_active = false
	_run_id = ""
	_run_started_unix = 0.0
	_active_sec = 0.0
	_event_sequence = 0
	_milestones.clear()
	_offer_batch_by_id.clear()
	_route_debug_signatures.clear()
	_route_debug_elapsed = 0.0
	_normal_missions_completed = 0
	_large_contracts_completed = 0
	_total_net_mission_earnings = 0
	_ship_purchase_spend = 0
	_port_unlock_spend = 0
	_ship_speed_upgrade_spend = 0
	_ship_capacity_upgrade_spend = 0
	_port_upgrade_spend = 0
	_automation_spend = 0
	_ship_purchase_spend_by_id.clear()
	_ship_speed_spend_by_id.clear()
	_ship_capacity_spend_by_id.clear()
	_automation_spend_by_id.clear()
	_port_unlock_spend_by_id.clear()
	_port_upgrade_spend_by_id.clear()
	_known_automation_unlocked.clear()
	_known_automation_enabled.clear()
	_pending_cash_spend = 0


func _save_continuity_state() -> void:
	if not _run_active:
		return
	var file := FileAccess.open(state_path, FileAccess.WRITE)
	if file == null:
		push_warning("Playtest logger could not write continuity state: %s" % state_path)
		return
	file.store_string(JSON.stringify({
		"version": STATE_VERSION,
		"run_id": _run_id,
		"run_started_unix": _run_started_unix,
		"active_sec": _active_sec,
		"event_sequence": _event_sequence,
		"milestones": _milestones.keys(),
		"normal_missions_completed": _normal_missions_completed,
		"large_contracts_completed": _large_contracts_completed,
		"total_net_mission_earnings": _total_net_mission_earnings,
		"ship_purchase_spend": _ship_purchase_spend,
		"port_unlock_spend": _port_unlock_spend,
		"ship_speed_upgrade_spend": _ship_speed_upgrade_spend,
		"ship_capacity_upgrade_spend": _ship_capacity_upgrade_spend,
		"port_upgrade_spend": _port_upgrade_spend,
		"automation_spend": _automation_spend,
		"ship_purchase_spend_by_id": _ship_purchase_spend_by_id,
		"ship_speed_spend_by_id": _ship_speed_spend_by_id,
		"ship_capacity_spend_by_id": _ship_capacity_spend_by_id,
		"automation_spend_by_id": _automation_spend_by_id,
		"port_unlock_spend_by_id": _port_unlock_spend_by_id,
		"port_upgrade_spend_by_id": _port_upgrade_spend_by_id,
		"known_automation_unlocked": _known_automation_unlocked,
		"known_automation_enabled": _known_automation_enabled,
	}))
	file.close()


func _load_continuity_state() -> void:
	if not FileAccess.file_exists(game_save_path) \
			or not FileAccess.file_exists(state_path):
		return
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", 0)) != STATE_VERSION:
		return
	_run_id = String(parsed.get("run_id", ""))
	_run_started_unix = float(parsed.get("run_started_unix", 0.0))
	if _run_id.is_empty() or _run_started_unix <= 0.0:
		return
	_run_active = true
	_awaiting_initial_load = true
	_active_sec = maxf(float(parsed.get("active_sec", 0.0)), 0.0)
	_event_sequence = maxi(int(parsed.get("event_sequence", 0)), 0)
	for milestone_name in parsed.get("milestones", []):
		_milestones[String(milestone_name)] = true
	_normal_missions_completed = maxi(
		int(parsed.get("normal_missions_completed", 0)),
		0
	)
	_large_contracts_completed = maxi(int(parsed.get("large_contracts_completed", 0)), 0)
	_total_net_mission_earnings = int(parsed.get("total_net_mission_earnings", 0))
	_ship_purchase_spend = maxi(int(parsed.get("ship_purchase_spend", 0)), 0)
	_port_unlock_spend = maxi(int(parsed.get("port_unlock_spend", 0)), 0)
	_ship_speed_upgrade_spend = maxi(
		int(parsed.get("ship_speed_upgrade_spend", 0)),
		0
	)
	_ship_capacity_upgrade_spend = maxi(
		int(parsed.get("ship_capacity_upgrade_spend", 0)),
		0
	)
	_port_upgrade_spend = maxi(int(parsed.get("port_upgrade_spend", 0)), 0)
	_automation_spend = maxi(int(parsed.get("automation_spend", 0)), 0)
	_ship_purchase_spend_by_id = _load_dictionary(parsed, "ship_purchase_spend_by_id")
	_ship_speed_spend_by_id = _load_dictionary(parsed, "ship_speed_spend_by_id")
	_ship_capacity_spend_by_id = _load_dictionary(parsed, "ship_capacity_spend_by_id")
	_automation_spend_by_id = _load_dictionary(parsed, "automation_spend_by_id")
	_port_unlock_spend_by_id = _load_dictionary(parsed, "port_unlock_spend_by_id")
	_port_upgrade_spend_by_id = _load_dictionary(parsed, "port_upgrade_spend_by_id")
	_known_automation_unlocked = _load_dictionary(parsed, "known_automation_unlocked")
	_known_automation_enabled = _load_dictionary(parsed, "known_automation_enabled")


func _load_dictionary(source: Dictionary, key: String) -> Dictionary:
	var value = source.get(key, {})
	return value.duplicate(true) if value is Dictionary else {}


func get_recorded_milestones() -> Array[String]:
	var result: Array[String] = []
	for milestone_name in _milestones.keys():
		result.append(String(milestone_name))
	result.sort()
	return result


func get_totals_snapshot() -> Dictionary:
	return _build_snapshot() if _run_active else {}
