extends SceneTree
## Focused regression coverage for cold-load and Android resume catch-up.

var _completion_counts: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fleet_manager := root.get_node("/root/FleetManager")
	var mission_manager := root.get_node("/root/MissionManager")
	var game_manager := root.get_node("/root/GameManager")
	var save_manager := root.get_node("/root/SaveManager")
	var event_bus := root.get_node("/root/EventBus")

	var world_scene := load("res://Scenes/world.tscn") as PackedScene
	assert(world_scene != null)
	root.add_child(world_scene.instantiate())
	await process_frame
	await process_frame

	var ship_data: ShipData = fleet_manager.get_initial_ship_model()
	assert(ship_data != null)
	event_bus.mission_completed.connect(_on_mission_completed)

	_test_surplus_time_reaches_next_leg(fleet_manager, mission_manager, ship_data)
	_test_multiple_transitions_stop_mid_mission(fleet_manager, mission_manager, ship_data)
	await _test_full_standard_completion_once(
		fleet_manager,
		mission_manager,
		game_manager,
		save_manager,
		ship_data
	)
	_test_large_contract_completion_once(
		fleet_manager,
		mission_manager,
		game_manager,
		ship_data
	)
	_test_cold_load_and_resume_paths_match(
		fleet_manager,
		mission_manager,
		save_manager,
		ship_data
	)

	print("OFFLINE_PROGRESS_TEST_OK")
	quit(0)


func _test_surplus_time_reaches_next_leg(
		fleet_manager: Node,
		mission_manager: Node,
		ship_data: ShipData
) -> void:
	var mission := _make_standard_mission("offline_surplus")
	var ship_id := &"offline_surplus_ship"
	var start_unix := 1000.0
	_install_active_mission(
		fleet_manager, mission_manager, ship_data, ship_id, mission, start_unix, 20.0
	)

	# Ten seconds remained at pause; twenty seconds passed before resume.
	fleet_manager.apply_offline_progress(start_unix + 30.0)
	assert(fleet_manager.get_ship_state(ship_id) \
		== ShipRuntimeState.State.SAILING_TO_DELIVERY)
	assert(is_equal_approx(mission.leg_start_unix, start_unix + 23.0))
	assert(is_equal_approx(
		(start_unix + 30.0) - mission.leg_start_unix,
		7.0
	))
	_cleanup_test_ship(fleet_manager, mission_manager, ship_id, mission.id)


func _test_multiple_transitions_stop_mid_mission(
		fleet_manager: Node,
		mission_manager: Node,
		ship_data: ShipData
) -> void:
	var mission := _make_standard_mission("offline_mid_mission")
	var ship_id := &"offline_mid_mission_ship"
	var start_unix := 2000.0
	_install_active_mission(
		fleet_manager, mission_manager, ship_data, ship_id, mission, start_unix, 10.0
	)
	var delivery_duration: float = fleet_manager.call(
		"_estimate_sailing_duration",
		ship_id,
		mission.pickup_port_id,
		mission.delivery_port_id,
		mission.cargo_amount
	)
	var target_unix := start_unix + 10.0 + 3.0 + delivery_duration * 0.5

	fleet_manager.apply_offline_progress(target_unix)
	assert(fleet_manager.get_ship_state(ship_id) \
		== ShipRuntimeState.State.SAILING_TO_DELIVERY)
	assert(is_equal_approx(mission.leg_start_unix, start_unix + 13.0))
	var remaining := mission.leg_start_unix + mission.leg_duration_sec - target_unix
	assert(is_equal_approx(remaining, delivery_duration * 0.5))
	_cleanup_test_ship(fleet_manager, mission_manager, ship_id, mission.id)


func _test_full_standard_completion_once(
		fleet_manager: Node,
		mission_manager: Node,
		game_manager: Node,
		save_manager: Node,
		ship_data: ShipData
) -> void:
	var mission := _make_standard_mission("offline_standard_complete")
	var ship_id := &"offline_standard_complete_ship"
	var start_unix := 3000.0
	_install_active_mission(
		fleet_manager, mission_manager, ship_data, ship_id, mission, start_unix, 10.0
	)
	var runtime: ShipRuntimeState = fleet_manager.get("_states")[ship_id]
	runtime.automation_unlocked = true
	runtime.automation_enabled = true
	var money_before: int = game_manager.money
	var completed_before: int = runtime.completed_mission_count

	# Exercise the same resume entry point used by the Android notification.
	save_manager.set("_last_pause_unix", start_unix + 5.0)
	save_manager.call("_apply_resume_progress", start_unix + 1000.0)
	await process_frame
	assert(fleet_manager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE)
	assert(fleet_manager.get_ship_mission(ship_id) == null)
	assert(mission_manager.get_offers().is_empty())
	assert(mission.stage == Mission.Stage.COMPLETED)
	assert(game_manager.money == money_before + mission.get_net_reward())
	assert(runtime.completed_mission_count == completed_before + 1)
	assert(_completion_counts.get(mission.id, 0) == 1)

	# A duplicate resume notification has no pause timestamp and is a no-op.
	save_manager.call("_apply_resume_progress", start_unix + 2000.0)
	assert(game_manager.money == money_before + mission.get_net_reward())
	assert(runtime.completed_mission_count == completed_before + 1)
	assert(_completion_counts.get(mission.id, 0) == 1)
	_cleanup_test_ship(fleet_manager, mission_manager, ship_id, mission.id)


func _test_large_contract_completion_once(
		fleet_manager: Node,
		mission_manager: Node,
		game_manager: Node,
		ship_data: ShipData
) -> void:
	var mission := _make_standard_mission("offline_large_contract")
	mission.mission_type = Mission.MissionType.LARGE_CONTRACT
	mission.contract_port_ids.assign([&"mersin", &"izmir", &"mersin"])
	mission.pickup_port_id = mission.contract_port_ids[0]
	mission.delivery_port_id = mission.contract_port_ids[1]
	var ship_id := &"offline_large_contract_ship"
	var start_unix := 4000.0
	_install_active_mission(
		fleet_manager, mission_manager, ship_data, ship_id, mission, start_unix, 10.0
	)
	var runtime: ShipRuntimeState = fleet_manager.get("_states")[ship_id]
	var money_before: int = game_manager.money

	fleet_manager.apply_offline_progress(start_unix + 1000.0)
	assert(fleet_manager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE)
	assert(mission.stage == Mission.Stage.COMPLETED)
	assert(mission.contract_leg_index == 1)
	assert(runtime.completed_mission_count == 1)
	assert(runtime.completed_large_contract_count == 1)
	assert(game_manager.money == money_before + mission.get_net_reward())
	assert(_completion_counts.get(mission.id, 0) == 1)

	fleet_manager.apply_offline_progress(start_unix + 2000.0)
	assert(game_manager.money == money_before + mission.get_net_reward())
	assert(runtime.completed_large_contract_count == 1)
	assert(_completion_counts.get(mission.id, 0) == 1)
	_cleanup_test_ship(fleet_manager, mission_manager, ship_id, mission.id)


func _test_cold_load_and_resume_paths_match(
		fleet_manager: Node,
		mission_manager: Node,
		save_manager: Node,
		ship_data: ShipData
) -> void:
	var target_unix := 5030.0
	var cold_mission := _make_standard_mission("offline_cold_path")
	var cold_ship_id := &"offline_cold_path_ship"
	_install_active_mission(
		fleet_manager,
		mission_manager,
		ship_data,
		cold_ship_id,
		cold_mission,
		5000.0,
		20.0
	)
	# load_game() delegates to this one progression coordinator.
	save_manager.call("_apply_mission_progress", target_unix, 20.0)
	var cold_result := _capture_progress_result(
		fleet_manager, cold_ship_id, cold_mission, target_unix
	)
	_cleanup_test_ship(fleet_manager, mission_manager, cold_ship_id, cold_mission.id)

	var resume_mission := _make_standard_mission("offline_resume_path")
	var resume_ship_id := &"offline_resume_path_ship"
	_install_active_mission(
		fleet_manager,
		mission_manager,
		ship_data,
		resume_ship_id,
		resume_mission,
		5000.0,
		20.0
	)
	save_manager.set("_last_pause_unix", target_unix - 20.0)
	save_manager.call("_apply_resume_progress", target_unix)
	var resume_result := _capture_progress_result(
		fleet_manager, resume_ship_id, resume_mission, target_unix
	)
	assert(cold_result == resume_result)
	_cleanup_test_ship(fleet_manager, mission_manager, resume_ship_id, resume_mission.id)


func _make_standard_mission(mission_id: String) -> Mission:
	var mission := Mission.new()
	mission.id = mission_id
	mission.origin_port_id = &"mersin"
	mission.pickup_port_id = &"mersin"
	mission.delivery_port_id = &"izmir"
	mission.cargo_type_id = &"containers"
	mission.cargo_amount = 1
	mission.reward = 125
	mission.operating_cost = 25
	mission.loading_duration_sec = 3.0
	mission.unloading_duration_sec = 3.0
	return mission


func _install_active_mission(
		fleet_manager: Node,
		mission_manager: Node,
		ship_data: ShipData,
		ship_id: StringName,
		mission: Mission,
		start_unix: float,
		duration_sec: float
) -> void:
	var runtime := ShipRuntimeState.new()
	runtime.ship_id = ship_id
	runtime.model_id = ship_data.id
	runtime.current_port_id = mission.origin_port_id
	runtime.state = ShipRuntimeState.State.SAILING_TO_PICKUP
	runtime.current_mission = mission
	mission.assigned_ship_id = ship_id
	mission.stage = Mission.Stage.SAILING_TO_PICKUP
	mission.start_leg(duration_sec, start_unix)
	var fleet_states: Dictionary = fleet_manager.get("_states")
	var fleet_data: Dictionary = fleet_manager.get("_data")
	var active_missions: Dictionary = mission_manager.get("_active_missions")
	fleet_states[ship_id] = runtime
	fleet_data[ship_id] = ship_data
	active_missions[mission.id] = mission


func _capture_progress_result(
		fleet_manager: Node,
		ship_id: StringName,
		mission: Mission,
		target_unix: float
) -> Dictionary:
	return {
		"ship_state": fleet_manager.get_ship_state(ship_id),
		"mission_stage": mission.stage,
		"leg_start_unix": mission.leg_start_unix,
		"leg_duration_sec": mission.leg_duration_sec,
		"remaining_sec": mission.leg_start_unix + mission.leg_duration_sec - target_unix,
	}


func _cleanup_test_ship(
		fleet_manager: Node,
		mission_manager: Node,
		ship_id: StringName,
		mission_id: String
) -> void:
	var fleet_states: Dictionary = fleet_manager.get("_states")
	var fleet_data: Dictionary = fleet_manager.get("_data")
	var active_missions: Dictionary = mission_manager.get("_active_missions")
	fleet_states.erase(ship_id)
	fleet_data.erase(ship_id)
	active_missions.erase(mission_id)


func _on_mission_completed(mission: Mission) -> void:
	_completion_counts[mission.id] = int(_completion_counts.get(mission.id, 0)) + 1
