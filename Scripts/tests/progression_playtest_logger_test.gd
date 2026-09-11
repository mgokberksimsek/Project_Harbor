extends SceneTree
## Focused debug logger coverage. Run with --disable-playtest-logger so the
## normal GameManager bootstrap stays out of this test's isolated files.

const TEST_STATE_PATH := "res://build/progression_playtest_logger_test_state.json"
const TEST_GAME_SAVE_PATH := "res://build/progression_playtest_logger_test_save.json"

var _records: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var event_bus := root.get_node("/root/EventBus")
	var game_manager := root.get_node("/root/GameManager")
	var fleet_manager := root.get_node("/root/FleetManager")
	var port_manager := root.get_node("/root/PortManager")
	var company_manager := root.get_node("/root/CompanyManager")

	_delete_test_files()
	var world_scene := load("res://Scenes/world.tscn") as PackedScene
	assert(world_scene != null)
	root.add_child(world_scene.instantiate())
	await process_frame
	await process_frame

	var logger_script := load(
		"res://Scripts/debug/progression_playtest_logger.gd"
	) as Script
	assert(logger_script != null)
	var logger := logger_script.new() as Node
	logger.set("state_path", TEST_STATE_PATH)
	logger.set("game_save_path", TEST_GAME_SAVE_PATH)
	logger.connect("record_emitted", _on_record_emitted)
	root.add_child(logger)

	event_bus.fresh_game_started.emit()
	assert(_record_count("MILESTONE", "GAME_STARTED") == 1)

	assert(game_manager.try_purchase_ship(&"starter_freighter", &"mersin"))
	var starter_ship_id: StringName = fleet_manager.get_all_ship_ids()[0]
	assert(_record_count("EVENT", "SHIP_PURCHASED") == 1)
	assert(_record_count("MILESTONE", "FIRST_SHIP_PURCHASED") == 1)
	assert(_last_payload("EVENT", "SHIP_PURCHASED")["cost"] == 500)

	var speed_cost: int = fleet_manager.get_ship_speed_upgrade_cost(starter_ship_id)
	game_manager.add_money(speed_cost)
	assert(game_manager.try_upgrade_ship_speed(starter_ship_id))
	assert(_record_count("EVENT", "SHIP_SPEED_UPGRADED") == 1)
	var speed_payload := _last_payload("EVENT", "SHIP_SPEED_UPGRADED")
	assert(speed_payload["previous_level"] == 0)
	assert(speed_payload["new_level"] == 1)
	assert(speed_payload["cost"] == speed_cost)

	var capacity_cost: int = fleet_manager.get_ship_capacity_upgrade_cost(starter_ship_id)
	game_manager.add_money(capacity_cost)
	assert(game_manager.try_upgrade_ship_capacity(starter_ship_id))
	assert(_record_count("EVENT", "SHIP_CAPACITY_UPGRADED") == 1)
	var capacity_payload := _last_payload("EVENT", "SHIP_CAPACITY_UPGRADED")
	assert(capacity_payload["previous_level"] == 0)
	assert(capacity_payload["new_level"] == 1)
	assert(capacity_payload["cost"] == capacity_cost)

	var refrigerated_cost: int = fleet_manager.get_ship_purchase_price(
		&"refrigerated_freighter"
	)
	game_manager.add_money(refrigerated_cost)
	assert(game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	assert(_record_count("MILESTONE", "SECOND_SHIP_PURCHASED") == 1)

	var antalya_data: PortData = port_manager.get_port_data(&"antalya")
	game_manager.add_money(antalya_data.base_unlock_cost)
	assert(game_manager.try_unlock_port(&"antalya"))
	assert(_record_count("MILESTONE", "ANTALYA_UNLOCKED") == 1)
	assert(_last_payload("EVENT", "PORT_UNLOCKED")["cost"] \
		== antalya_data.base_unlock_cost)

	var antalya_upgrade_cost: int = antalya_data.get_upgrade_cost(1)
	game_manager.add_money(antalya_upgrade_cost)
	assert(game_manager.try_upgrade_port(&"antalya"))
	assert(_record_count("EVENT", "PORT_UPGRADED") == 1)
	var port_upgrade_payload := _last_payload("EVENT", "PORT_UPGRADED")
	assert(port_upgrade_payload["previous_level"] == 1)
	assert(port_upgrade_payload["new_level"] == 2)
	assert(port_upgrade_payload["cost"] == antalya_upgrade_cost)

	assert(company_manager.company_level == 3)
	assert(company_manager.debug_advance_level())
	await process_frame
	assert(_record_count("MILESTONE", "COMPANY_LEVEL_4") == 1)
	event_bus.company_level_changed.emit(4, 3)
	await process_frame
	assert(_record_count("MILESTONE", "COMPANY_LEVEL_4") == 1)

	var large_contract := Mission.new()
	large_contract.id = "logger-large-contract"
	large_contract.assigned_ship_id = starter_ship_id
	large_contract.mission_type = Mission.MissionType.LARGE_CONTRACT
	large_contract.contract_port_ids.assign([&"mersin", &"izmir", &"antalya"])
	large_contract.pickup_port_id = &"izmir"
	large_contract.delivery_port_id = &"antalya"
	large_contract.cargo_type_id = &"containers"
	large_contract.cargo_amount = 1
	large_contract.reward = 300
	large_contract.operating_cost = 40
	large_contract.estimated_duration_sec = 25.0
	event_bus.mission_completed.emit(large_contract)
	assert(_record_count("EVENT", "LARGE_CONTRACT_COMPLETED") == 1)
	assert(_record_count("MILESTONE", "FIRST_LARGE_CONTRACT_COMPLETED") == 1)
	var mission_payload := _last_payload("EVENT", "LARGE_CONTRACT_COMPLETED")
	assert(mission_payload["gross_reward"] == 300)
	assert(mission_payload["operating_cost"] == 40)
	assert(mission_payload["net_reward"] == 260)

	assert(company_manager.debug_advance_level())
	await process_frame
	var fleet_states: Dictionary = fleet_manager.get("_states")
	var starter_runtime: ShipRuntimeState = fleet_states[starter_ship_id]
	starter_runtime.completed_large_contract_count = \
		game_manager.AUTOMATION_REQUIRED_LARGE_CONTRACTS
	game_manager.add_money(game_manager.AUTOMATION_UNLOCK_COST)
	assert(game_manager.try_toggle_ship_automation(starter_ship_id))
	assert(_record_count("EVENT", "AUTOMATION_UNLOCKED") == 1)
	assert(_record_count("EVENT", "AUTOMATION_ENABLED") == 1)
	assert(_record_count("MILESTONE", "FIRST_AUTOMATION_UNLOCKED") == 1)

	assert(company_manager.debug_advance_level())
	await process_frame
	var bulk_cost: int = fleet_manager.get_ship_purchase_price(&"bulk_carrier")
	game_manager.add_money(bulk_cost)
	assert(game_manager.try_purchase_ship(&"bulk_carrier", &"mersin"))
	assert(_record_count("MILESTONE", "FIRST_BULK_CARRIER_PURCHASED") == 1)
	assert(_last_payload("EVENT", "SHIP_PURCHASED")["model"] == "bulk_carrier")

	var canakkale_data: PortData = port_manager.get_port_data(&"canakkale")
	game_manager.add_money(canakkale_data.base_unlock_cost)
	assert(game_manager.try_unlock_port(&"canakkale"))
	var canakkale_milestone := _last_payload("MILESTONE", "CANAKKALE_UNLOCKED")
	var antalya_level_found := false
	for port_detail in canakkale_milestone["port_details"]:
		if port_detail["port_id"] == "antalya":
			antalya_level_found = port_detail["level"] == 2
	assert(antalya_level_found)

	var totals: Dictionary = logger.call("get_totals_snapshot")
	assert(totals["ship_speed_upgrade_spend"] == speed_cost)
	assert(totals["ship_capacity_upgrade_spend"] == capacity_cost)
	assert(totals["total_ship_upgrade_spend"] == speed_cost + capacity_cost)
	assert(totals["port_upgrade_spend"] == antalya_upgrade_cost)

	var active_before := float(logger.get("_active_sec"))
	logger.call("_set_foreground", false)
	logger.call("_process", 5.0)
	assert(is_equal_approx(float(logger.get("_active_sec")), active_before))
	logger.call("_set_foreground", true)
	logger.call("_process", 2.0)
	assert(is_equal_approx(float(logger.get("_active_sec")), active_before + 2.0))
	logger.set("_run_started_unix", Time.get_unix_time_from_system() - 20.0)
	totals = logger.call("get_totals_snapshot")
	assert(float(totals["elapsed_sec"]) >= 19.0)

	logger.call("_save_continuity_state")
	var test_save := FileAccess.open(TEST_GAME_SAVE_PATH, FileAccess.WRITE)
	assert(test_save != null)
	test_save.store_string("{}")
	test_save.close()
	logger.queue_free()
	await process_frame

	_records.clear()
	var resumed_logger := logger_script.new() as Node
	resumed_logger.set("state_path", TEST_STATE_PATH)
	resumed_logger.set("game_save_path", TEST_GAME_SAVE_PATH)
	resumed_logger.connect("record_emitted", _on_record_emitted)
	root.add_child(resumed_logger)
	assert(bool(resumed_logger.get("_run_active")))
	# Save restoration replays port signals before game_loaded; they must not
	# create duplicate events or milestones.
	event_bus.port_unlocked.emit(&"antalya")
	event_bus.company_level_changed.emit(4, 3)
	await process_frame
	assert(_records.is_empty())
	event_bus.game_loaded.emit()
	assert(_record_count("CONTROL", "RUN_RESUMED") == 1)
	assert(resumed_logger.call("get_recorded_milestones").has("ANTALYA_UNLOCKED"))
	assert(_record_count("MILESTONE", "ANTALYA_UNLOCKED") == 0)

	resumed_logger.queue_free()
	await process_frame
	_delete_test_files()
	print("PROGRESSION_PLAYTEST_LOGGER_TEST_OK")
	quit(0)


func _on_record_emitted(
	category: String,
	record_name: String,
	payload: Dictionary
) -> void:
	_records.append({
		"category": category,
		"name": record_name,
		"payload": payload,
	})


func _record_count(category: String, record_name: String) -> int:
	var count := 0
	for record in _records:
		if record["category"] == category and record["name"] == record_name:
			count += 1
	return count


func _last_payload(category: String, record_name: String) -> Dictionary:
	for index in range(_records.size() - 1, -1, -1):
		var record: Dictionary = _records[index]
		if record["category"] == category and record["name"] == record_name:
			return record["payload"]
	assert(false, "Missing record: %s/%s" % [category, record_name])
	return {}


func _delete_test_files() -> void:
	for path in [TEST_STATE_PATH, TEST_GAME_SAVE_PATH]:
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK)
