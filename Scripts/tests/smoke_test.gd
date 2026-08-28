extends SceneTree
## Headless smoke test for the first playable architecture slice.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var timing_probe := Mission.new()
	timing_probe.start_leg(10.0, 1000.25)
	assert(is_equal_approx(timing_probe.get_leg_progress_at(1000.75), 0.05))
	var legacy_mission := Mission.from_dict({"reward": 100})
	assert(legacy_mission.operating_cost == 0)
	assert(legacy_mission.get_net_reward() == 100)
	assert(is_equal_approx(legacy_mission.loading_duration_sec, 1.7))
	assert(is_equal_approx(legacy_mission.unloading_duration_sec, 1.7))
	var legacy_ship_state := ShipRuntimeState.from_dict({
		"ship_id": "legacy_ship",
		"current_port_id": "mersin",
	})
	assert(legacy_ship_state.dock_port_id == &"mersin")
	assert(legacy_ship_state.dock_slot_index == -1)
	assert(legacy_ship_state.ship_name.is_empty())
	assert(not legacy_ship_state.automation_unlocked)
	assert(not legacy_ship_state.automation_enabled)
	assert(not legacy_ship_state.awaiting_headquarters_dispatch)
	assert(legacy_ship_state.headquarters_slot_index == -1)
	assert(not legacy_ship_state.headquarters_dispatch_active)

	var port_manager := root.get_node("/root/PortManager")
	var fleet_manager := root.get_node("/root/FleetManager")
	var mission_manager := root.get_node("/root/MissionManager")
	var economy_manager := root.get_node("/root/EconomyManager")
	var company_manager := root.get_node("/root/CompanyManager")
	var settings_manager := root.get_node("/root/SettingsManager")
	var game_manager := root.get_node("/root/GameManager")
	var save_manager := root.get_node("/root/SaveManager")
	var event_bus := root.get_node("/root/EventBus")
	var expected_fleet_capacities: Array[int] = [
		2, 3, 4, 5, 6,
		8, 10, 12, 14, 16,
		17, 18, 19, 20, 21,
	]
	for level_index in range(expected_fleet_capacities.size()):
		assert(fleet_manager.get_fleet_capacity_for_company_level(level_index + 1) \
			== expected_fleet_capacities[level_index])
	var test_save_path := "user://smoke_test_save.json"
	assert(save_manager.delete_save(test_save_path))
	assert(not save_manager.loaded_existing_save)

	var world_scene := load("res://Scenes/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	assert(port_manager.get_all_port_ids().size() == 12)
	assert(port_manager.is_unlocked(&"mersin"))
	assert(port_manager.is_unlocked(&"izmir"))
	assert(not port_manager.is_unlocked(&"istanbul"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	assert(not port_manager.is_unlocked(&"canakkale"))
	assert(not port_manager.is_unlocked(&"trabzon"))
	assert(not port_manager.is_unlocked(&"pire"))
	assert(not port_manager.is_unlocked(&"varna"))
	assert(not port_manager.is_unlocked(&"batum"))
	assert(not port_manager.is_unlocked(&"girne"))
	assert(not port_manager.is_unlocked(&"iskenderiye"))
	assert(port_manager.has_sea_route(&"mersin", &"izmir"))
	assert(port_manager.has_sea_route(&"mersin", &"antalya"))
	assert(port_manager.has_sea_route(&"izmir", &"antalya"))
	assert(port_manager.has_sea_route(&"istanbul", &"antalya"))
	assert(port_manager.has_sea_route(&"antalya", &"samsun"))
	assert(port_manager.has_sea_route(&"mersin", &"samsun"))
	assert(port_manager.has_sea_route(&"izmir", &"canakkale"))
	assert(port_manager.has_sea_route(&"canakkale", &"istanbul"))
	assert(port_manager.has_sea_route(&"samsun", &"trabzon"))
	assert(port_manager.has_sea_route(&"antalya", &"trabzon"))
	assert(port_manager.has_sea_route(&"pire", &"izmir"))
	assert(port_manager.has_sea_route(&"pire", &"canakkale"))
	assert(port_manager.has_route_path(&"pire", &"trabzon"))
	assert(port_manager.has_sea_route(&"varna", &"istanbul"))
	assert(port_manager.has_sea_route(&"varna", &"samsun"))
	assert(port_manager.has_route_path(&"varna", &"pire"))
	assert(port_manager.has_sea_route(&"batum", &"trabzon"))
	assert(port_manager.has_sea_route(&"batum", &"samsun"))
	assert(port_manager.has_route_path(&"batum", &"pire"))
	assert(port_manager.has_sea_route(&"girne", &"mersin"))
	assert(port_manager.has_sea_route(&"girne", &"antalya"))
	assert(port_manager.has_route_path(&"girne", &"batum"))
	assert(port_manager.has_sea_route(&"girne", &"iskenderiye"))
	assert(port_manager.has_sea_route(&"iskenderiye", &"batum"))
	assert(port_manager.has_sea_route(&"izmir", &"iskenderiye"))
	assert(port_manager.has_route_path(&"iskenderiye", &"pire"))
	assert(not port_manager.has_sea_route(&"mersin", &"trabzon"))
	assert(port_manager.has_route_path(&"mersin", &"trabzon"))
	var mersin_trabzon_port_path: Array[StringName] = port_manager.get_route_port_path(
		&"mersin",
		&"trabzon"
	)
	assert(mersin_trabzon_port_path == [
		&"mersin",
		&"antalya",
		&"trabzon",
	])
	var trabzon_mersin_port_path: Array[StringName] = port_manager.get_route_port_path(
		&"trabzon",
		&"mersin"
	)
	assert(trabzon_mersin_port_path == [
		&"trabzon",
		&"antalya",
		&"mersin",
	])
	assert(is_equal_approx(
		port_manager.get_distance(&"mersin", &"trabzon"),
		700.0
	))
	_assert_port_centers_are_spaced(port_manager, 320.0)
	var antalya_data: PortData = port_manager.get_port_data(&"antalya")
	var istanbul_data: PortData = port_manager.get_port_data(&"istanbul")
	var samsun_data: PortData = port_manager.get_port_data(&"samsun")
	var canakkale_data: PortData = port_manager.get_port_data(&"canakkale")
	var trabzon_data: PortData = port_manager.get_port_data(&"trabzon")
	var pire_data: PortData = port_manager.get_port_data(&"pire")
	var varna_data: PortData = port_manager.get_port_data(&"varna")
	var batum_data: PortData = port_manager.get_port_data(&"batum")
	var girne_data: PortData = port_manager.get_port_data(&"girne")
	var iskenderiye_data: PortData = port_manager.get_port_data(&"iskenderiye")
	assert(antalya_data.required_company_level == 1)
	assert(antalya_data.base_unlock_cost == 750)
	assert(antalya_data.base_company_value == 500)
	assert(antalya_data.get_upgrade_cost(1) == 700)
	assert(antalya_data.get_upgrade_cost(3) == -1)
	assert(is_equal_approx(antalya_data.get_reward_multiplier(2), 1.08))
	assert(is_equal_approx(antalya_data.get_handling_duration_multiplier(3), 0.6))
	assert(canakkale_data.required_company_level == 3)
	assert(canakkale_data.base_unlock_cost == 1500)
	assert(canakkale_data.base_company_value == 800)
	assert(istanbul_data.required_company_level == 4)
	assert(istanbul_data.base_unlock_cost == 2600)
	assert(istanbul_data.base_company_value == 1200)
	assert(samsun_data.required_company_level == 5)
	assert(samsun_data.base_unlock_cost == 4200)
	assert(samsun_data.base_company_value == 2000)
	assert(trabzon_data.required_company_level == 6)
	assert(trabzon_data.base_unlock_cost == 6500)
	assert(trabzon_data.base_company_value == 3000)
	assert(pire_data.required_company_level == 7)
	assert(pire_data.base_unlock_cost == 8500)
	assert(pire_data.base_company_value == 4200)
	assert(pire_data.get_upgrade_cost(1) == 6500)
	assert(varna_data.required_company_level == 8)
	assert(varna_data.base_unlock_cost == 11000)
	assert(varna_data.base_company_value == 5500)
	assert(varna_data.get_upgrade_cost(1) == 8500)
	assert(batum_data.required_company_level == 9)
	assert(batum_data.base_unlock_cost == 14500)
	assert(batum_data.base_company_value == 7200)
	assert(batum_data.get_upgrade_cost(1) == 11000)
	assert(girne_data.required_company_level == 10)
	assert(girne_data.base_unlock_cost == 19000)
	assert(girne_data.base_company_value == 9000)
	assert(girne_data.get_upgrade_cost(1) == 14500)
	assert(iskenderiye_data.required_company_level == 11)
	assert(iskenderiye_data.base_unlock_cost == 25000)
	assert(iskenderiye_data.base_company_value == 11500)
	assert(iskenderiye_data.get_upgrade_cost(1) == 19000)
	_audit_full_network_balance(
		port_manager,
		fleet_manager,
		mission_manager,
		economy_manager
	)
	port_manager.apply_save_state({
		"mersin": {"port_id": "mersin", "unlocked": true, "level": 1},
		"izmir": {"port_id": "izmir", "unlocked": true, "level": 1},
		"istanbul": {"port_id": "istanbul", "unlocked": false, "level": 1},
	})
	assert(port_manager.get_all_port_ids().size() == 12)
	assert(port_manager.is_registered(&"antalya"))
	assert(port_manager.is_registered(&"samsun"))
	assert(port_manager.is_registered(&"canakkale"))
	assert(port_manager.is_registered(&"trabzon"))
	assert(port_manager.is_registered(&"pire"))
	assert(port_manager.is_registered(&"varna"))
	assert(port_manager.is_registered(&"batum"))
	assert(port_manager.is_registered(&"girne"))
	assert(port_manager.is_registered(&"iskenderiye"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	assert(not port_manager.is_unlocked(&"canakkale"))
	assert(not port_manager.is_unlocked(&"trabzon"))
	assert(not port_manager.is_unlocked(&"pire"))
	assert(not port_manager.is_unlocked(&"varna"))
	assert(not port_manager.is_unlocked(&"batum"))
	assert(not port_manager.is_unlocked(&"girne"))
	assert(not port_manager.is_unlocked(&"iskenderiye"))
	world.call("_update_tutorial_instruction")
	var antalya_status := world.get_node("Ports/Antalya/StatusLabel") as Label
	assert(antalya_status.text.contains("Sv. 1"))
	assert(antalya_status.text.contains("750"))
	assert(
		company_manager.company_value == 400,
		"Expected 400 CV, got %d (ports=%s, port assets=%d)" % [
			company_manager.company_value,
			port_manager.get_unlocked_port_ids(),
			company_manager.get_port_asset_value(),
		]
	)
	assert(company_manager.company_level == 1)
	assert(company_manager.get_next_level_threshold() == 1000)
	var headquarters := world.get_node("CompanyHeadquarters")
	assert(headquarters != null)
	assert(headquarters.get_delivery_position() != Vector2.ZERO)
	var tier_one_delivery_position: Vector2 = headquarters.get_delivery_position()
	var tier_one_pier_width: float = (headquarters.get_node("Pier") as Line2D).width
	assert(headquarters.get_visual_tier() == 1)
	assert((headquarters.get_node("Label") as Label).text.contains("Sv. 1"))
	var company_label := world.get_node("UI/CompanyProgressLabel") as Button
	assert(company_label != null)
	assert(company_label.text.contains("400 / 1000 CV"))
	var debug_level_button := world.get_node("UI/DebugLevelUpButton") as Button
	assert(debug_level_button != null)
	assert(debug_level_button.text.contains("Sv. 1"))
	var debug_money_button := world.get_node("UI/DebugMoneyButton") as Button
	assert(debug_money_button != null)
	assert(debug_money_button.text.contains("10.000"))
	assert(not debug_level_button.get_global_rect().intersects(
		debug_money_button.get_global_rect()
	))
	var next_goal_label := world.get_node("UI/NextGoalLabel") as Label
	assert(next_goal_label != null)
	assert(not next_goal_label.visible)
	assert(company_manager.get_fleet_asset_value() == 0)
	assert(company_manager.get_port_asset_value() == 400)
	assert(company_manager.get_fleet_asset_value() + company_manager.get_port_asset_value() \
		== company_manager.company_value)
	var settings_menu := world.get_node("UI/SettingsMenu")
	assert(settings_menu != null)
	assert(not bool(ProjectSettings.get_setting(
		"application/config/quit_on_go_back",
		true
	)))
	var exit_dialog := world.get_node("UI/ExitConfirmationDialog") as ConfirmationDialog
	assert(exit_dialog != null)
	assert(not exit_dialog.visible)
	var offline_summary_dialog := world.get_node("UI/OfflineSummaryDialog") as AcceptDialog
	assert(offline_summary_dialog != null)
	assert(not offline_summary_dialog.visible)
	var port_unlock_panel := world.get_node("UI/PortUnlockPanel")
	assert(port_unlock_panel != null)
	assert(not port_unlock_panel.visible)
	assert(settings_manager.locale == "tr")
	assert(settings_manager.sound_effects_enabled)
	assert(settings_manager.music_enabled)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var music_bus := AudioServer.get_bus_index("Music")
	assert(sfx_bus >= 0)
	assert(music_bus >= 0)
	settings_menu.open_menu()
	assert(settings_menu.is_open())
	assert(not paused)
	var sfx_button := settings_menu.get_node(
		"Overlay/Center/Panel/Margin/VBox/SoundEffectsButton"
	) as Button
	var music_button := settings_menu.get_node(
		"Overlay/Center/Panel/Margin/VBox/MusicButton"
	) as Button
	var language_select := settings_menu.get_node(
		"Overlay/Center/Panel/Margin/VBox/LanguageSelect"
	) as OptionButton
	sfx_button.pressed.emit()
	assert(not settings_manager.sound_effects_enabled)
	assert(AudioServer.is_bus_mute(sfx_bus))
	sfx_button.pressed.emit()
	assert(settings_manager.sound_effects_enabled)
	assert(not AudioServer.is_bus_mute(sfx_bus))
	music_button.pressed.emit()
	assert(not settings_manager.music_enabled)
	assert(AudioServer.is_bus_mute(music_bus))
	music_button.pressed.emit()
	assert(settings_manager.music_enabled)
	assert(not AudioServer.is_bus_mute(music_bus))
	language_select.item_selected.emit(1)
	assert(settings_manager.locale == "en")
	assert(company_label.text.contains("Company Lv."))
	assert(world.get_node("Ports/Antalya/StatusLabel").text.contains("Locked"))
	assert(settings_menu.get_node("SettingsButton").text.contains("Settings"))
	assert(exit_dialog.title.contains("Captain"))
	language_select.item_selected.emit(0)
	assert(settings_manager.locale == "tr")
	world.call("_notification", Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert(not settings_menu.is_open())
	assert(not paused)
	assert(not exit_dialog.visible)
	world.request_exit_confirmation()
	assert(exit_dialog.visible)
	assert(not paused)
	assert(exit_dialog.title.contains("Kaptan"))
	assert(exit_dialog.dialog_text.contains("limanın ışıklarını"))
	exit_dialog.hide()
	assert(not paused)
	var company_panel := world.get_node("UI/CompanyProgressPanel")
	assert(company_panel != null)
	var company_info_button := company_panel.get_node("Margin/VBox/Header/InfoButton") as Button
	var company_info_dialog := company_panel.get_node("InfoDialog") as AcceptDialog
	company_label.pressed.emit()
	await process_frame
	assert(not company_panel.visible)
	var instruction_label := world.get_node("UI/InstructionLabel") as Label
	assert(instruction_label != null)
	assert(int(game_manager.get("tutorial_step")) == 7)
	assert(instruction_label.text.contains("ÖĞRETİCİ 1/8"))
	var skip_tutorial_button := world.get_node("UI/SkipTutorialButton") as Button
	var tutorial_complete_dialog := world.get_node("UI/TutorialCompleteDialog") as AcceptDialog
	assert(skip_tutorial_button.visible)
	var management_dock := world.get_node("UI/ManagementDock") as ManagementDock
	assert(management_dock != null)
	var shop_panel := management_dock.ship_shop_panel
	var fleet_panel := management_dock.fleet_panel
	var shop_tab := management_dock.get_node(
		"Margin/VBox/Tabs/ShopTabButton"
	) as Button
	var fleet_tab := management_dock.get_node(
		"Margin/VBox/Tabs/FleetTabButton"
	) as Button
	assert(shop_panel != null)
	assert(fleet_panel != null)
	assert(shop_panel.is_tutorial_focused())
	assert(not shop_panel.is_expanded())
	assert(not management_dock.is_expanded())
	assert(company_label.disabled)
	assert(debug_level_button.disabled)
	assert(fleet_manager.get_all_ship_ids().is_empty())
	assert(mission_manager.get_offers().is_empty())
	var starter_model: ShipData = fleet_manager.get_initial_ship_model()
	assert(starter_model != null)
	assert(starter_model.purchase_cost == 500)
	assert(game_manager.money == starter_model.purchase_cost)
	var tutorial_buy_button := shop_panel.get_node("Margin/VBox/Body/BuyButton") as Button
	var previous_model_button := shop_panel.get_node(
		"Margin/VBox/Body/ModelSelector/PreviousButton"
	) as Button
	var next_model_button := shop_panel.get_node(
		"Margin/VBox/Body/ModelSelector/NextButton"
	) as Button
	var model_position_label := shop_panel.get_node(
		"Margin/VBox/Body/ModelSelector/PositionLabel"
	) as Label
	assert(not shop_tab.disabled)
	shop_tab.pressed.emit()
	await process_frame
	assert(management_dock.is_shop_open())
	assert(shop_panel.is_expanded())
	assert(int(game_manager.get("tutorial_step")) == 4)
	assert(instruction_label.text.contains("ÖĞRETİCİ 2/8"))
	assert(previous_model_button.disabled)
	assert(next_model_button.disabled)
	assert(model_position_label.text == "1 / 1")
	assert(not tutorial_buy_button.disabled)
	assert(tutorial_buy_button.text.contains("500"))
	tutorial_buy_button.pressed.emit()
	await process_frame
	await process_frame
	assert(game_manager.money == 0)
	assert(fleet_manager.get_all_ship_ids().size() == 1)
	var starter_ship_id: StringName = fleet_manager.get_all_ship_ids()[0]
	assert(fleet_manager.get_ship_data(starter_ship_id).id == starter_model.id)
	assert(fleet_manager.get_ship_purchase_price(&"starter_freighter") == 800)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 1280)
	assert(fleet_manager.get_ship_purchase_price(&"bulk_carrier") == 2400)
	assert(not fleet_manager.get_ship_name(starter_ship_id).is_empty())
	var legacy_fleet_save: Dictionary = fleet_manager.get_save_state()
	var legacy_starter_state: Dictionary = legacy_fleet_save[String(starter_ship_id)]
	legacy_starter_state.erase("ship_name")
	legacy_starter_state.erase("completed_mission_count")
	legacy_starter_state.erase("total_net_earnings")
	fleet_manager.apply_save_state(legacy_fleet_save)
	assert(fleet_manager.get_ship_completed_mission_count(starter_ship_id) == 0)
	assert(fleet_manager.get_ship_total_net_earnings(starter_ship_id) == 0)
	var starter_generated_name: String = fleet_manager.get_ship_name(starter_ship_id)
	assert(starter_generated_name.length() >= 2)
	assert(starter_generated_name.length() <= 20)
	fleet_manager.apply_save_state(legacy_fleet_save)
	assert(fleet_manager.get_ship_name(starter_ship_id) == starter_generated_name)
	assert(int(game_manager.get("tutorial_step")) == 5)
	assert(instruction_label.text.contains("ÖĞRETİCİ 3/8"))
	assert(not shop_panel.is_tutorial_focused())
	assert(not shop_panel.is_expanded())
	assert(not management_dock.is_expanded())
	assert(shop_tab.disabled)
	assert(not company_label.disabled)
	event_bus.ship_tapped.emit(starter_ship_id)
	event_bus.port_tapped.emit(&"mersin")
	await process_frame
	assert(world.get("_selected_ship_id") == &"")
	assert(world.get("_open_mission_port_id") == &"")
	assert(int(game_manager.get("tutorial_step")) == 5)
	var tutorial_blocked_offers: Array = mission_manager.get_offers()
	assert(tutorial_blocked_offers.size() == 3)
	world.call("_on_offer_accepted", (tutorial_blocked_offers[0] as Mission).id)
	assert(mission_manager.get_active_missions().is_empty())
	company_label.pressed.emit()
	await process_frame
	assert(company_panel.visible)
	assert(company_panel.get_node("Margin/VBox/TotalValue").text.contains("900 CV"))
	assert(company_panel.get_node("Margin/VBox/Breakdown/FleetValue").text.contains("500 CV"))
	assert(company_panel.get_node("Margin/VBox/Breakdown/PortValue").text.contains("400 CV"))
	assert(company_panel.get_node("Margin/VBox/NextUnlocks").text.contains("Soğutmalı"))
	assert(int(game_manager.get("tutorial_step")) == 6)
	assert(instruction_label.text.contains("ÖĞRETİCİ 4/8"))
	assert(company_panel.is_info_tutorial_focused())
	event_bus.ship_tapped.emit(starter_ship_id)
	event_bus.port_tapped.emit(&"mersin")
	await process_frame
	assert(world.get("_selected_ship_id") == &"")
	assert(world.get("_open_mission_port_id") == &"")
	assert(company_panel.visible)
	assert(int(game_manager.get("tutorial_step")) == 6)
	company_info_button.pressed.emit()
	await process_frame
	assert(company_info_dialog.visible)
	assert(company_info_dialog.dialog_text.contains("harcanabilen para değildir"))
	company_info_dialog.confirmed.emit()
	company_info_dialog.hide()
	assert(int(game_manager.get("tutorial_step")) == 0)
	assert(instruction_label.text.contains("ÖĞRETİCİ 5/8"))
	assert(not company_panel.visible)
	game_manager.set_tutorial_step(GameManager.TutorialStep.COMPLETED)
	await process_frame
	assert(not previous_model_button.disabled)
	assert(not next_model_button.disabled)
	assert(model_position_label.text == "2 / 3")
	next_model_button.pressed.emit()
	assert((shop_panel.get_node("Margin/VBox/Body/Title") as Label).text.contains("Dökme"))
	assert(tutorial_buy_button.text.contains("Sv. 3"))
	assert(tutorial_buy_button.disabled)
	previous_model_button.pressed.emit()
	assert((shop_panel.get_node("Margin/VBox/Body/Title") as Label).text.contains("Soğutmalı"))
	var first_port_balance := _get_mission_balance_for_cost(
		mission_manager,
		fleet_manager,
		economy_manager,
		starter_ship_id,
		750
	)
	var first_port_mission_range: Vector2i = first_port_balance["mission_range"]
	assert(first_port_mission_range.x >= 3 and first_port_mission_range.y <= 5)
	var fleet_info_button := fleet_panel.get_node("Margin/VBox/Header/InfoButton") as Button
	var fleet_help_dialog := fleet_panel.get_node("HelpDialog") as AcceptDialog
	assert(fleet_info_button != null)
	assert(fleet_info_button.custom_minimum_size.x >= 42.0)
	assert(fleet_help_dialog != null)
	assert(not fleet_help_dialog.visible)
	fleet_info_button.pressed.emit()
	await process_frame
	assert(fleet_help_dialog.visible)
	assert(fleet_help_dialog.size.x <= 420)
	assert(fleet_help_dialog.size.y <= 230)
	assert(fleet_help_dialog.dialog_text.contains("kapasite"))
	settings_manager.set_locale("en")
	assert(fleet_help_dialog.title == "Fleet Status")
	assert(fleet_help_dialog.dialog_text.contains("Auto Dispatch"))
	settings_manager.set_locale("tr")
	fleet_help_dialog.hide()
	world.call("_refresh_fleet_panel")
	var starter_card_button: Button = fleet_panel.get("_cards")[starter_ship_id]
	var starter_rename_button := fleet_panel.get_node(
		"Margin/VBox/Body/Details/Actions/RenameButton"
	) as Button
	assert(starter_card_button.text.contains(starter_generated_name))
	assert(starter_card_button.text.contains("Başlangıç Yük Gemisi"))
	starter_card_button.pressed.emit()
	await process_frame
	assert(starter_rename_button.text == "İsim Değiştir")
	starter_rename_button.pressed.emit()
	await process_frame
	var ship_rename_dialog := world.get_node("UI/ShipRenameDialog") as PopupPanel
	var ship_name_input := ship_rename_dialog.get_node(
		"Content/Rows/NameRow/NameInput"
	) as LineEdit
	var random_name_button := ship_rename_dialog.get_node(
		"Content/Rows/NameRow/RandomNameButton"
	) as Button
	var rename_cancel_button := ship_rename_dialog.get_node(
		"Content/Rows/ActionRow/CancelButton"
	) as Button
	var rename_save_button := ship_rename_dialog.get_node(
		"Content/Rows/ActionRow/SaveButton"
	) as Button
	assert(ship_rename_dialog.visible)
	assert(
		ship_rename_dialog.size == Vector2i(300, 114),
		"Rename dialog is not compact: %s" % ship_rename_dialog.size
	)
	assert(ship_rename_dialog.position.y == 16)
	assert(ship_name_input.size.y == random_name_button.size.y)
	assert(rename_cancel_button.position.y == rename_save_button.position.y)
	assert(rename_cancel_button.size.y == rename_save_button.size.y)
	assert(rename_save_button.global_position.y > ship_name_input.global_position.y)
	assert(ship_name_input.text == starter_generated_name)
	random_name_button.pressed.emit()
	assert(ship_name_input.text != starter_generated_name)
	assert(fleet_manager.is_ship_name_available(ship_name_input.text, starter_ship_id))
	ship_name_input.text = "Deniz Yıldızı"
	rename_save_button.pressed.emit()
	await process_frame
	assert(not ship_rename_dialog.visible)
	assert(fleet_manager.get_ship_name(starter_ship_id) == "Deniz Yıldızı")
	assert(starter_card_button.text.contains("Deniz Yıldızı"))
	assert(instruction_label.text.contains("Deniz Yıldızı"))
	event_bus.ship_tapped.emit(starter_ship_id)
	assert(instruction_label.text.contains("Deniz Yıldızı"))
	assert(not instruction_label.text.contains(starter_generated_name))
	starter_rename_button.pressed.emit()
	ship_name_input.text = "A"
	rename_save_button.pressed.emit()
	await process_frame
	assert(ship_rename_dialog.visible)
	assert(instruction_label.text.contains("2–20"))
	rename_cancel_button.pressed.emit()
	assert(not ship_rename_dialog.visible)
	var fleet_scroll := fleet_panel.get_node(
		"Margin/VBox/Body/ListColumn/Scroll"
	) as ScrollContainer
	assert(fleet_scroll != null)
	assert(fleet_scroll.scroll_deadzone == 18)
	var settings_button := settings_menu.get_node("SettingsButton") as Button
	assert(not management_dock.get_global_rect().intersects(settings_button.get_global_rect()))
	assert(not management_dock.is_expanded())
	assert(is_equal_approx(management_dock.offset_bottom - management_dock.offset_top, 58.0))
	fleet_tab.pressed.emit()
	assert(management_dock.is_fleet_open())
	assert(fleet_panel.is_expanded())
	assert(is_equal_approx(management_dock.offset_bottom - management_dock.offset_top, 286.0))
	assert(fleet_panel.get_node("Margin/VBox/Body").visible)
	fleet_tab.pressed.emit()
	assert(not management_dock.is_expanded())
	assert(not fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
	shop_tab.pressed.emit()
	assert(management_dock.is_shop_open())
	assert(shop_panel.is_expanded())
	assert(shop_panel.get_node("Margin/VBox/Body").visible)
	shop_tab.pressed.emit()
	assert(not management_dock.is_expanded())
	assert(not shop_panel.is_expanded())
	fleet_tab.pressed.emit()
	shop_tab.pressed.emit()
	assert(management_dock.is_fleet_open())
	assert(management_dock.is_shop_open())
	assert(fleet_panel.is_expanded())
	assert(shop_panel.is_expanded())
	var world_camera := world.get_node("Camera2D")
	assert(world_camera != null)
	world.set("_selected_ship_id", &"selection_probe")
	var mersin_node := port_manager.get_port_node(&"mersin") as Node2D
	assert(mersin_node != null)
	var mersin_screen_position: Vector2 = get_root().get_viewport().get_canvas_transform() \
			* mersin_node.global_position
	world.call("_handle_map_tap", mersin_screen_position)
	assert(not management_dock.is_expanded())
	assert(not fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
	assert(world.get("_selected_ship_id") == &"selection_probe")
	world.set("_selected_ship_id", &"")
	shop_tab.pressed.emit()
	assert(shop_panel.is_expanded())
	var map_drag_press := InputEventMouseButton.new()
	map_drag_press.button_index = MOUSE_BUTTON_LEFT
	map_drag_press.pressed = true
	map_drag_press.position = Vector2(640, 400)
	map_drag_press.global_position = map_drag_press.position
	world_camera.call("_unhandled_input", map_drag_press)
	var map_drag_motion := InputEventMouseMotion.new()
	map_drag_motion.position = Vector2(700, 400)
	map_drag_motion.relative = Vector2(60, 0)
	map_drag_motion.velocity = Vector2(600, 0)
	world_camera.call("_unhandled_input", map_drag_motion)
	var map_drag_release := InputEventMouseButton.new()
	map_drag_release.button_index = MOUSE_BUTTON_LEFT
	map_drag_release.pressed = false
	map_drag_release.position = map_drag_motion.position
	map_drag_release.global_position = map_drag_release.position
	world_camera.call("_unhandled_input", map_drag_release)
	assert(management_dock.is_shop_open())
	assert(shop_panel.is_expanded())
	var position_before_inertia: Vector2 = world_camera.position
	world_camera.call("_process", 0.1)
	assert(world_camera.position != position_before_inertia)
	var map_tap_press := InputEventMouseButton.new()
	map_tap_press.button_index = MOUSE_BUTTON_LEFT
	map_tap_press.pressed = true
	map_tap_press.position = Vector2(640, 400)
	map_tap_press.global_position = map_tap_press.position
	world_camera.call("_unhandled_input", map_tap_press)
	assert(management_dock.is_shop_open())
	assert(shop_panel.is_expanded())
	var map_tap_jitter := InputEventMouseMotion.new()
	map_tap_jitter.position = Vector2(658, 400)
	map_tap_jitter.relative = Vector2(18, 0)
	world_camera.call("_unhandled_input", map_tap_jitter)
	var map_tap_release := InputEventMouseButton.new()
	map_tap_release.button_index = MOUSE_BUTTON_LEFT
	map_tap_release.pressed = false
	map_tap_release.position = map_tap_jitter.position
	map_tap_release.global_position = map_tap_release.position
	world_camera.call("_unhandled_input", map_tap_release)
	assert(not management_dock.is_expanded())
	assert(not fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
	world_camera.zoom = Vector2.ONE * 0.65
	world_camera.position = WorldCamera.WORLD_SIZE * 0.5
	var double_tap_position := Vector2(760, 420)
	var viewport_center: Vector2 = get_root().get_viewport().get_visible_rect().size * 0.5
	world_camera.zoom_at_screen_position(0.10, viewport_center)
	assert(is_equal_approx(world_camera.zoom.x, 0.40))
	world_camera.zoom_at_screen_position(0.65, viewport_center)
	assert(is_equal_approx(world_camera.zoom.x, 0.65))
	world_camera.call("_enter_cinematic_overview")
	await create_timer(0.50).timeout
	assert(bool(world_camera.get("_cinematic_overview_active")))
	assert(world_camera.limit_left < 0)
	assert(world_camera.zoom.x < WorldCamera.MIN_ZOOM)
	assert(world_camera.position.is_equal_approx(WorldCamera.WORLD_SIZE * 0.5))
	var cinematic_visible_size: Vector2 = get_root().get_viewport().get_visible_rect().size \
		/ world_camera.zoom.x
	assert(cinematic_visible_size.x >= WorldCamera.WORLD_SIZE.x)
	assert(cinematic_visible_size.y >= WorldCamera.WORLD_SIZE.y)
	var ocean_background := world.get_node("Ocean") as ColorRect
	assert(ocean_background != null)
	assert(ocean_background.size.x >= WorldCamera.WORLD_SIZE.x)
	assert(ocean_background.size.y >= WorldCamera.WORLD_SIZE.y)
	var cinematic_position: Vector2 = world_camera.position
	world_camera.pan_by_screen_delta(Vector2(200.0, 0.0))
	assert(world_camera.position.is_equal_approx(cinematic_position))
	world_camera.call("_exit_cinematic_overview")
	await create_timer(0.50).timeout
	assert(not bool(world_camera.get("_cinematic_overview_active")))
	assert(not bool(world_camera.get("_cinematic_exit_in_progress")))
	assert(world_camera.limit_left == 0)
	assert(world_camera.limit_right == int(WorldCamera.WORLD_SIZE.x))
	assert(is_equal_approx(world_camera.zoom.x, WorldCamera.MIN_ZOOM))
	world_camera.zoom_at_screen_position(0.65, viewport_center)
	var zoom_anchor_before: Vector2 = world_camera.position \
			+ (double_tap_position - viewport_center) / world_camera.zoom.x
	var double_tap_press := InputEventMouseButton.new()
	double_tap_press.button_index = MOUSE_BUTTON_LEFT
	double_tap_press.pressed = true
	double_tap_press.double_click = true
	double_tap_press.position = double_tap_position
	double_tap_press.global_position = double_tap_position
	world_camera.call("_unhandled_input", double_tap_press)
	var double_tap_release := InputEventMouseButton.new()
	double_tap_release.button_index = MOUSE_BUTTON_LEFT
	double_tap_release.pressed = false
	double_tap_release.position = double_tap_position
	double_tap_release.global_position = double_tap_position
	world_camera.call("_unhandled_input", double_tap_release)
	await create_timer(0.35).timeout
	assert(is_equal_approx(world_camera.zoom.x, 1.0))
	var zoom_anchor_after: Vector2 = world_camera.position \
			+ (double_tap_position - viewport_center) / world_camera.zoom.x
	assert(zoom_anchor_after.distance_to(zoom_anchor_before) < 0.5)
	var touch_double_tap_press := InputEventScreenTouch.new()
	touch_double_tap_press.index = 0
	touch_double_tap_press.pressed = true
	touch_double_tap_press.double_tap = true
	touch_double_tap_press.position = double_tap_position
	world_camera.call("_unhandled_input", touch_double_tap_press)
	var touch_double_tap_release := InputEventScreenTouch.new()
	touch_double_tap_release.index = 0
	touch_double_tap_release.pressed = false
	touch_double_tap_release.position = double_tap_position
	world_camera.call("_unhandled_input", touch_double_tap_release)
	await create_timer(0.35).timeout
	assert(is_equal_approx(world_camera.zoom.x, 0.65))
	var emulated_mouse_double_tap := InputEventMouseButton.new()
	emulated_mouse_double_tap.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse_double_tap.button_index = MOUSE_BUTTON_LEFT
	emulated_mouse_double_tap.pressed = true
	emulated_mouse_double_tap.double_click = true
	emulated_mouse_double_tap.position = double_tap_position
	world_camera.call("_unhandled_input", emulated_mouse_double_tap)
	await create_timer(0.05).timeout
	assert(is_equal_approx(world_camera.zoom.x, 0.65))
	game_manager.set_tutorial_step(GameManager.TutorialStep.SELECT_SHIP)
	await process_frame
	assert(skip_tutorial_button.visible)
	var initial_company_value: int = company_manager.company_value
	game_manager.add_money(800)
	assert(company_manager.company_value == initial_company_value)
	assert(not game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	assert(game_manager.money == 800)
	assert(game_manager.spend_money(800))
	var forward_route: PackedVector2Array = port_manager.get_route_points(&"mersin", &"izmir")
	var reverse_route: PackedVector2Array = port_manager.get_route_points(&"izmir", &"mersin")
	var smooth_route: PackedVector2Array = port_manager.get_smoothed_route_points(&"mersin", &"izmir")
	var s_curve_route: PackedVector2Array = port_manager.get_route_points(&"mersin", &"istanbul")
	var expansion_route: PackedVector2Array = port_manager.get_route_points(&"izmir", &"antalya")
	var connected_route_points: PackedVector2Array = port_manager.get_route_points(
		&"mersin",
		&"trabzon"
	)
	var connected_route: PackedVector2Array = port_manager.get_smoothed_route_points(
		&"mersin",
		&"trabzon"
	)
	assert(forward_route.size() >= 5)
	assert(smooth_route.size() > forward_route.size())
	assert(s_curve_route.size() >= 6)
	assert(expansion_route.size() >= 5)
	assert(connected_route.size() > expansion_route.size())
	assert(connected_route[0].is_equal_approx(
		port_manager.get_port_node(&"mersin").global_position
	))
	assert(connected_route[connected_route.size() - 1].is_equal_approx(
		port_manager.get_port_node(&"trabzon").global_position
	))
	var antalya_port_position: Vector2 = port_manager.get_port_node(&"antalya").global_position
	var antalya_transit_position: Vector2 = port_manager.get_route_transit_position(&"antalya")
	assert(connected_route_points.has(antalya_transit_position))
	assert(not connected_route_points.has(antalya_port_position))
	assert(port_manager.has_sea_route(&"istanbul", &"samsun"))
	assert(port_manager.get_route_port_path(&"canakkale", &"trabzon") == [
		&"canakkale",
		&"istanbul",
		&"samsun",
		&"trabzon",
	])
	_assert_sea_routes_have_varied_curves(port_manager)
	var has_clockwise_turn := false
	var has_counterclockwise_turn := false
	for curve_index in range(1, s_curve_route.size() - 1):
		var incoming := s_curve_route[curve_index] - s_curve_route[curve_index - 1]
		var outgoing := s_curve_route[curve_index + 1] - s_curve_route[curve_index]
		var turn := incoming.cross(outgoing)
		has_clockwise_turn = has_clockwise_turn or turn < -0.001
		has_counterclockwise_turn = has_counterclockwise_turn or turn > 0.001
	assert(has_clockwise_turn and has_counterclockwise_turn)
	assert(reverse_route.size() == forward_route.size())
	for route_index in range(forward_route.size()):
		assert(forward_route[route_index].is_equal_approx(
			reverse_route[reverse_route.size() - 1 - route_index]
		))
	var route_midpoint: Vector2 = port_manager.get_route_position(&"mersin", &"izmir", 0.5)
	var direct_midpoint: Vector2 = (
		port_manager.get_port_node(&"mersin").global_position
		+ port_manager.get_port_node(&"izmir").global_position
	) * 0.5
	assert(not route_midpoint.is_equal_approx(direct_midpoint))
	assert(fleet_manager.get_all_ship_ids().size() == 1)
	var starter_map_ship: Area2D = fleet_manager.get_ship_node(starter_ship_id) as Area2D
	var mersin_map_port: Area2D = port_manager.get_port_node(&"mersin") as Area2D
	assert(starter_map_ship != null)
	_assert_all_sea_routes_avoid_land(port_manager, world)
	var route_line := starter_map_ship.get_node("RouteLine") as ShipRouteLine
	var doubled_back_route := PackedVector2Array([
		Vector2(0, 0),
		Vector2(100, 0),
		Vector2(200, 0),
		Vector2(100, 0),
		Vector2(0, 0),
	])
	var hidden_overlap_segments: Array = route_line.call(
		"_get_hidden_reverse_overlap_segments",
		doubled_back_route
	)
	assert(hidden_overlap_segments == [true, true, false, false])
	route_line.set_route(doubled_back_route, 0.0, true)
	var visible_doubled_back_length := 0.0
	for dash_segment in route_line.get_visible_dash_segments():
		visible_doubled_back_length += dash_segment[0].distance_to(dash_segment[1])
	assert(visible_doubled_back_length > 0.0)
	assert(visible_doubled_back_length < 200.0)
	var approach_probe_duration := 10.0 * 60.0
	var approach_probe_length := 1000.0
	# Match the authored Ship approach values without loading the Ship class
	# before the test tree's autoload identifiers are available.
	var approach_time_ratio := 1.6 / approach_probe_duration
	var approach_route_ratio := 140.0 / approach_probe_length
	var approach_start_raw := 1.0 - approach_time_ratio
	var approach_start_visual: float = starter_map_ship.call(
		"calculate_visual_sailing_progress",
		approach_start_raw,
		approach_probe_duration,
		approach_probe_length
	)
	assert(is_equal_approx(approach_start_visual, 1.0 - approach_route_ratio))
	var approach_half_visual: float = starter_map_ship.call(
		"calculate_visual_sailing_progress",
		approach_start_raw + approach_time_ratio * 0.5,
		approach_probe_duration,
		approach_probe_length
	)
	assert(is_equal_approx(
		approach_half_visual,
		1.0 - approach_route_ratio * 0.5
	))
	assert(is_equal_approx(float(starter_map_ship.call(
		"calculate_visual_sailing_progress",
		1.0,
		approach_probe_duration,
		approach_probe_length
	)), 1.0))
	var headquarters_delivery_position: Vector2 = headquarters.get_delivery_position(
		fleet_manager.get_ship_headquarters_slot_index(starter_ship_id)
	)
	var headquarters_approach_position: Vector2 = headquarters.get_delivery_approach_position(
		fleet_manager.get_ship_headquarters_slot_index(starter_ship_id)
	)
	assert(fleet_manager.is_awaiting_headquarters_dispatch(starter_ship_id))
	assert(bool(starter_map_ship.get("_hold_initial_position_while_idle")))
	assert(starter_map_ship.global_position.distance_to(
		headquarters_delivery_position
	) <= headquarters_approach_position.distance_to(
		headquarters_delivery_position
	))
	if bool(starter_map_ship.get("_dock_transition_active")):
		starter_map_ship.call("_update_docked_position", 2.0)
	assert(starter_map_ship.global_position.is_equal_approx(
		headquarters_delivery_position
	))
	assert(not bool(starter_map_ship.get("_dock_transition_active")))
	var starter_icon := starter_map_ship.get_node("Icon") as Sprite2D
	assert(starter_icon != null)
	var starter_selection_outline := starter_icon.get_node("SelectionOutline") as Sprite2D
	assert(starter_selection_outline != null)
	assert(starter_map_ship.is_tutorial_focused())
	assert(starter_selection_outline.visible)
	assert(is_equal_approx(starter_icon.scale.x, 0.8))
	assert(is_equal_approx(starter_icon.scale.y, 0.8))
	var starter_route_line := starter_map_ship.get_node("RouteLine") as ShipRouteLine
	assert(starter_route_line != null)
	var starter_status_label := starter_map_ship.get_node("StatusLabel") as Label
	assert(starter_status_label != null)
	starter_map_ship.set_tutorial_focus(false)
	starter_map_ship.call(
		"_update_idle_status_visual",
		ShipRuntimeState.State.IDLE,
		0.5
	)
	assert(starter_status_label.modulate != Color.WHITE)
	assert(starter_status_label.scale == Vector2.ONE)
	settings_manager.set_locale("en")
	assert(starter_status_label.text == "Idle")
	settings_manager.set_locale("tr")
	assert(starter_status_label.text == "Boşta")
	starter_map_ship.set_tutorial_focus(true)
	starter_map_ship.call(
		"_update_idle_status_visual",
		ShipRuntimeState.State.IDLE,
		0.1
	)
	assert(starter_status_label.modulate == Color.WHITE)
	assert(starter_status_label.scale == Vector2.ONE)
	starter_route_line.set_route(smooth_route, 0.0, true)
	var full_route_length := starter_route_line.get_remaining_length()
	starter_route_line.set_route(smooth_route, 0.5, true)
	assert(starter_route_line.get_remaining_length() < full_route_length)
	starter_route_line.clear_route()
	assert(port_manager.get_port_data(&"mersin").dock_slot_offsets.size() == 6)
	assert(port_manager.get_dock_slot_count(&"mersin") == 2)
	assert(fleet_manager.get_ship_dock_slot_index(starter_ship_id) == -1)
	assert(fleet_manager.get_ship_reserved_dock_port(starter_ship_id) == &"")
	assert(fleet_manager.get_ship_dock_position(starter_ship_id) == Vector2.ZERO)
	assert(starter_map_ship.z_index > mersin_map_port.z_index)
	assert(world.get_viewport().physics_object_picking_sort)
	assert(world.get_viewport().physics_object_picking_first_only)
	var ship_tap_event := InputEventMouseButton.new()
	ship_tap_event.button_index = MOUSE_BUTTON_LEFT
	ship_tap_event.pressed = true
	ship_tap_event.position = world.get_viewport().get_canvas_transform() \
		* starter_map_ship.global_position
	ship_tap_event.global_position = ship_tap_event.position
	world.set("_selected_ship_id", &"")
	assert(world.try_select_ship_at_screen_position(ship_tap_event.position))
	assert(world.get("_selected_ship_id") == starter_ship_id)
	assert(starter_selection_outline.visible)
	world_camera.position = WorldCamera.WORLD_SIZE * 0.5
	var expected_fleet_focus_position: Vector2 = world_camera.call(
		"_clamp_camera_position_for_zoom",
		starter_map_ship.global_position,
		world_camera.zoom.x
	)
	world.call("_on_fleet_ship_selected", starter_ship_id)
	await create_timer(WorldCamera.WORLD_FOCUS_DURATION_SEC + 0.05).timeout
	assert(world_camera.position.distance_to(expected_fleet_focus_position) < 1.0)

	# Re-registering a ship (as scene reload does after New Game) must rebuild offers.
	mission_manager.reset_state()
	var starter_node: Node2D = fleet_manager.get_ship_node(starter_ship_id)
	var starter_data: ShipData = fleet_manager.get_ship_data(starter_ship_id)
	fleet_manager.register_ship(starter_ship_id, starter_data, &"mersin", starter_node)
	await process_frame
	assert(not mission_manager.get_offers().is_empty())

	await process_frame

	var offers: Array = mission_manager.get_offers()
	assert(offers.size() == 3)
	var starter_ship_data: ShipData = fleet_manager.get_ship_data(starter_ship_id)
	var container_cargo: CargoTypeData = mission_manager.get_cargo_type(&"containers")
	var food_cargo: CargoTypeData = mission_manager.get_cargo_type(&"food")
	var grain_cargo: CargoTypeData = mission_manager.get_cargo_type(&"grain")
	assert(starter_ship_data != null)
	assert(container_cargo != null)
	assert(food_cargo != null)
	assert(grain_cargo != null)
	var one_unit_reward: int = economy_manager.calculate_mission_reward(
		&"mersin", &"izmir", container_cargo, 1
	)
	var two_unit_reward: int = economy_manager.calculate_mission_reward(
		&"mersin", &"izmir", container_cargo, 2
	)
	var starting_port_multiplier: float = economy_manager.call(
		"_get_port_pair_reward_multiplier",
		&"mersin",
		&"izmir"
	)
	var first_expansion_multiplier: float = economy_manager.call(
		"_get_port_pair_reward_multiplier",
		&"mersin",
		&"antalya"
	)
	var late_region_multiplier: float = economy_manager.call(
		"_get_port_pair_reward_multiplier",
		&"mersin",
		&"trabzon"
	)
	assert(is_equal_approx(starting_port_multiplier, 1.0))
	assert(is_equal_approx(first_expansion_multiplier, 1.04))
	assert(is_equal_approx(late_region_multiplier, 1.125))
	assert(first_expansion_multiplier > starting_port_multiplier)
	assert(late_region_multiplier > first_expansion_multiplier)
	var extra_unit_reward_ratio := float(two_unit_reward) / float(one_unit_reward)
	assert(extra_unit_reward_ratio >= 1.24 and extra_unit_reward_ratio <= 1.26)
	assert(not starter_ship_data.can_carry(food_cargo))
	assert(not starter_ship_data.can_carry(grain_cargo))
	var has_local_pickup_offer := false
	var has_remote_pickup_offer := false
	for offer in offers:
		assert(offer.offered_ship_id == starter_ship_id)
		assert(offer.origin_port_id == &"mersin")
		assert(port_manager.is_unlocked(offer.pickup_port_id))
		assert(port_manager.is_unlocked(offer.delivery_port_id))
		assert(offer.pickup_port_id != offer.delivery_port_id)
		assert(port_manager.has_route_path(offer.pickup_port_id, offer.delivery_port_id))
		if offer.pickup_port_id == &"mersin":
			has_local_pickup_offer = true
			assert(is_equal_approx(offer.loading_duration_sec, 3.0))
		else:
			has_remote_pickup_offer = true
			assert(is_equal_approx(offer.loading_duration_sec, 3.0))
		assert(is_equal_approx(offer.unloading_duration_sec, 3.0))
		assert(offer.estimated_duration_sec > 0.0)
		assert(offer.duration_class == Mission.DurationClass.SHORT)
		assert(offer.reward > 0)
		assert(offer.operating_cost > 0)
		assert(offer.get_net_reward() > 0)
		var operating_cost_ratio := float(offer.operating_cost) / float(offer.reward)
		assert(operating_cost_ratio >= 0.08 and operating_cost_ratio <= 0.25)
		assert(offer.cargo_amount == 1)
		var offered_cargo: CargoTypeData = mission_manager.get_cargo_type(offer.cargo_type_id)
		assert(starter_ship_data.can_carry(offered_cargo))
		assert(offer.cargo_type_id != &"food")
		assert(offer.cargo_type_id != &"grain")
	assert(has_local_pickup_offer)
	assert(has_remote_pickup_offer)
	var samsun_runtime: PortRuntimeState = port_manager.get("_states")[&"samsun"]
	var trabzon_runtime: PortRuntimeState = port_manager.get("_states")[&"trabzon"]
	samsun_runtime.unlocked = true
	trabzon_runtime.unlocked = true
	var connected_candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		&"mersin",
		starter_ship_id
	)
	var has_mersin_trabzon_candidate := false
	for candidate in connected_candidates:
		has_mersin_trabzon_candidate = has_mersin_trabzon_candidate \
			or (candidate["pickup_id"] == &"mersin" \
			and candidate["destination_id"] == &"trabzon")
	assert(has_mersin_trabzon_candidate)
	samsun_runtime.unlocked = false
	trabzon_runtime.unlocked = false
	var local_offer: Mission = null
	for offer in offers:
		if offer.pickup_port_id == offer.origin_port_id:
			local_offer = offer
			break
	assert(local_offer != null)
	var mission_offer_panel: Node = world.get_node("UI/MissionOfferPanel")
	var local_offer_text: String = mission_offer_panel.call("_format_offer", local_offer)
	assert(local_offer_text.contains("NET +%d ₺" % local_offer.get_net_reward()))
	var local_pickup_route: PackedVector2Array = starter_map_ship.call(
		"_build_delivery_route",
		local_offer
	)
	var local_pickup_port: Node2D = port_manager.get_port_node(local_offer.pickup_port_id)
	assert(local_pickup_route.size() > 2)
	assert(local_pickup_route[0].is_equal_approx(starter_map_ship.global_position))
	assert(local_pickup_route[1].is_equal_approx(local_pickup_port.global_position))
	assert(local_pickup_route[local_pickup_route.size() - 1].is_equal_approx(
		port_manager.get_port_node(local_offer.delivery_port_id).global_position
	))
	var local_route_test_position := starter_map_ship.global_position
	starter_map_ship.set("_sailing_route_points", local_pickup_route)
	var local_loading_start_progress: float = starter_map_ship.call(
		"_get_local_loading_route_progress",
		local_offer
	)
	starter_map_ship.global_position = local_route_test_position.lerp(
		local_pickup_port.global_position,
		0.5
	)
	var local_loading_mid_progress: float = starter_map_ship.call(
		"_get_local_loading_route_progress",
		local_offer
	)
	starter_map_ship.global_position = local_pickup_port.global_position
	var local_loading_end_progress: float = starter_map_ship.call(
		"_get_local_loading_route_progress",
		local_offer
	)
	var expected_local_loading_end := local_route_test_position.distance_to(
		local_pickup_port.global_position
	) / float(starter_map_ship.call(
		"_get_polyline_length",
		local_pickup_route
	))
	assert(is_equal_approx(local_loading_start_progress, 0.0))
	assert(local_loading_mid_progress > local_loading_start_progress)
	assert(local_loading_end_progress > local_loading_mid_progress)
	assert(is_equal_approx(local_loading_end_progress, expected_local_loading_end))
	starter_route_line.set_route(local_pickup_route, local_loading_mid_progress, true)
	var local_mid_dash_segments := starter_route_line.get_visible_dash_segments()
	assert(not local_mid_dash_segments.is_empty())
	var local_approach_direction := local_route_test_position.direction_to(
		local_pickup_port.global_position
	)
	var first_visible_local_distance := (
		local_mid_dash_segments[0][0] - local_route_test_position
	).dot(local_approach_direction)
	assert(first_visible_local_distance \
		>= local_route_test_position.distance_to(local_pickup_port.global_position) * 0.5)
	starter_route_line.clear_route()
	starter_map_ship.global_position = local_route_test_position
	starter_map_ship.set("_sailing_route_points", PackedVector2Array())

	event_bus.ship_tapped.emit(starter_ship_id)
	await process_frame
	assert(int(game_manager.get("tutorial_step")) == 1)
	assert(instruction_label.text.contains("ÖĞRETİCİ 6/8"))
	var first_offer: Mission = null
	for offer in offers:
		if offer.pickup_port_id != &"mersin":
			first_offer = offer
			break
	assert(first_offer != null)
	assert(local_offer.estimated_duration_sec >= 10.0)
	assert(local_offer.estimated_duration_sec <= 38.0)
	assert(first_offer.estimated_duration_sec > local_offer.estimated_duration_sec)
	assert(first_offer.estimated_duration_sec <= 63.0)
	assert(first_offer.operating_cost > local_offer.operating_cost)
	var pickup_node: Node = port_manager.get_port_node(first_offer.pickup_port_id)
	var mission_badge := pickup_node.get_node("MissionBadge") as Button
	var pickup_offer_count := 0
	for offer in offers:
		if offer.pickup_port_id == first_offer.pickup_port_id:
			pickup_offer_count += 1
	assert(mission_badge.visible)
	assert(mission_badge.text == str(pickup_offer_count))
	assert(pickup_node.is_tutorial_focused())
	event_bus.port_tapped.emit(first_offer.pickup_port_id)
	await process_frame
	assert(int(game_manager.get("tutorial_step")) == 2)
	assert(instruction_label.text.contains("ÖĞRETİCİ 7/8"))
	var pickup_icon := pickup_node.get_node("Icon") as Sprite2D
	var pickup_highlight := pickup_icon.get_node("SelectionOutline") as Sprite2D
	assert(pickup_highlight != null)
	assert(pickup_highlight.visible)
	assert(world.get_node("UI/MissionOfferPanel").visible)
	assert(world.get_node("UI/MissionOfferPanel").is_tutorial_focused())
	var first_offer_button := world.get_node(
		"UI/MissionOfferPanel/Margin/VBox/Cards/Offer1"
	) as Button
	assert(first_offer_button.text.contains("Brüt"))
	assert(first_offer_button.text.contains("Masraf"))
	assert(first_offer_button.text.contains("NET"))
	settings_manager.set_locale("en")
	assert(first_offer_button.text.contains("Gross"))
	assert(first_offer_button.text.contains("Cost"))
	settings_manager.set_locale("tr")

	world.call("_on_offer_accepted", first_offer.id)
	await process_frame
	assert(not fleet_manager.is_awaiting_headquarters_dispatch(starter_ship_id))
	assert(fleet_manager.is_headquarters_dispatch_active(starter_ship_id))
	assert(not bool(starter_map_ship.get("_hold_initial_position_while_idle")))
	assert(starter_status_label.modulate == Color.WHITE)
	assert(starter_status_label.scale == Vector2.ONE)
	assert(int(game_manager.get("tutorial_step")) == 8)
	assert(not game_manager.is_tutorial_completed())
	assert(instruction_label.text.contains("ÖĞRETİCİ 8/8"))
	assert(tutorial_complete_dialog.visible)
	assert(tutorial_complete_dialog.dialog_text.contains("İyi eğlenceler"))
	assert(not next_goal_label.visible)
	tutorial_complete_dialog.confirmed.emit()
	tutorial_complete_dialog.hide()
	assert(game_manager.is_tutorial_completed())
	assert(instruction_label.text.contains("ÖĞRETİCİ TAMAMLANDI"))
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Antalya"))
	assert(next_goal_label.text.contains("0 / 750"))
	assert(not pickup_highlight.visible)
	assert(starter_selection_outline.visible)
	assert(not starter_map_ship.is_tutorial_focused())
	assert(not pickup_node.is_tutorial_focused())
	world.clear_map_selection()
	assert(world.get("_selected_ship_id") == &"")
	assert(not starter_selection_outline.visible)
	assert(not pickup_highlight.visible)
	var active_missions: Array = mission_manager.get_active_missions()
	assert(active_missions.size() == 1)
	var mission: Mission = active_missions[0]
	assert(mission.pickup_port_id == first_offer.pickup_port_id)
	assert(mission.delivery_port_id == first_offer.delivery_port_id)
	assert(mission.reward > 0)
	assert(mission.operating_cost > 0)
	assert(mission.get_net_reward() == mission.reward - mission.operating_cost)
	assert(fleet_manager.get_ship_mission_remaining_sec(starter_ship_id) > 0.0)
	await process_frame
	var complete_preview_route: PackedVector2Array = starter_map_ship.get(
		"_mission_preview_route_points"
	)
	var pickup_sailing_route: PackedVector2Array = starter_map_ship.get(
		"_sailing_route_points"
	)
	var pickup_port_node: Node2D = port_manager.get_port_node(mission.pickup_port_id)
	var origin_port_node: Node2D = port_manager.get_port_node(mission.origin_port_id)
	assert(not pickup_sailing_route.has(origin_port_node.global_position))
	var departure_direction := pickup_sailing_route[0].direction_to(
		pickup_sailing_route[1]
	)
	var icon := starter_map_ship.get_node("Icon") as Sprite2D
	var initial_ship_forward := Vector2.RIGHT.rotated(
		icon.rotation + starter_map_ship.ship_data.sprite_forward_angle_rad
	)
	assert(departure_direction.dot(initial_ship_forward) > 0.99)
	assert(complete_preview_route.size() > 3)
	assert(complete_preview_route.has(pickup_port_node.global_position))
	assert(complete_preview_route[complete_preview_route.size() - 1].is_equal_approx(
		port_manager.get_port_node(mission.delivery_port_id).global_position
	))
	starter_route_line.set_route(complete_preview_route, 0.0, true)
	var complete_preview_length := starter_route_line.get_remaining_length()
	var initial_dash_segments := starter_route_line.get_visible_dash_segments()
	var preview_pickup_length: float = starter_map_ship.get("_preview_pickup_route_length")
	var preview_total_length: float = starter_map_ship.get("_preview_total_route_length")
	starter_route_line.set_route(
		complete_preview_route,
		0.5 * preview_pickup_length / preview_total_length,
		true
	)
	var progressed_dash_segments := starter_route_line.get_visible_dash_segments()
	assert(progressed_dash_segments.size() < initial_dash_segments.size())
	assert(progressed_dash_segments.back()[0].is_equal_approx(initial_dash_segments.back()[0]))
	assert(progressed_dash_segments.back()[1].is_equal_approx(initial_dash_segments.back()[1]))
	assert(world.get_node(
		"UI/ManagementDock/Margin/VBox/Content/FleetStatusPanel"
	) is FleetStatusPanel)
	var delivery_state_safety := 0
	mission.leg_duration_sec = 0.0
	await process_frame
	assert(fleet_manager.get_ship_state(starter_ship_id) == ShipRuntimeState.State.LOADING)
	assert(not fleet_manager.is_headquarters_dispatch_active(starter_ship_id))
	assert(fleet_manager.get_ship_dock_slot_index(starter_ship_id) == -1)
	assert(starter_map_ship.global_position.is_equal_approx(pickup_port_node.global_position))
	while fleet_manager.get_ship_state(starter_ship_id) \
			!= ShipRuntimeState.State.SAILING_TO_DELIVERY \
			and delivery_state_safety < 3:
		mission.leg_duration_sec = 0.0
		await process_frame
		delivery_state_safety += 1
	assert(fleet_manager.get_ship_state(starter_ship_id) \
		== ShipRuntimeState.State.SAILING_TO_DELIVERY)
	assert(starter_route_line.get_remaining_length() < complete_preview_length)
	var delivery_route: PackedVector2Array = starter_map_ship.get("_sailing_route_points")
	var delivery_port_node: Node2D = port_manager.get_port_node(mission.delivery_port_id)
	assert(delivery_route.size() > 2)
	assert(delivery_route[delivery_route.size() - 1].is_equal_approx(
		delivery_port_node.global_position
	))

	mission.leg_duration_sec = 0.0
	await process_frame
	await process_frame
	assert(fleet_manager.get_ship_state(starter_ship_id) \
		== ShipRuntimeState.State.UNLOADING)
	assert(is_equal_approx(mission.leg_duration_sec, mission.unloading_duration_sec))
	assert(starter_map_ship.global_position.distance_to(
		delivery_port_node.global_position
	) < 1.0)
	starter_map_ship.call("_update_docked_position", 0.5)
	assert(starter_map_ship.global_position.distance_to(
		delivery_port_node.global_position
	) < 1.0)
	mission.leg_duration_sec = 0.0
	await process_frame
	await process_frame

	assert(mission.stage == Mission.Stage.COMPLETED)
	assert(bool(starter_map_ship.get("_dock_transition_active")))
	assert(game_manager.money == mission.get_net_reward())
	assert(fleet_manager.get_ship_completed_mission_count(starter_ship_id) == 1)
	assert(fleet_manager.get_ship_total_net_earnings(starter_ship_id) \
		== mission.get_net_reward())
	world.call("_refresh_fleet_panel")
	fleet_panel.select_ship(starter_ship_id)
	var fleet_stats_label := fleet_panel.get_node(
		"Margin/VBox/Body/Details/Stats"
	) as Label
	assert(fleet_stats_label.text.contains("1 görev tamamladı"))
	assert(fleet_stats_label.text.contains("%d ₺" % mission.get_net_reward()))
	assert(instruction_label.text.contains("Net +%d" % mission.get_net_reward()))
	assert(instruction_label.text.contains("%d gelir" % mission.reward))
	assert(instruction_label.text.contains("-%d masraf" % mission.operating_cost))
	await process_frame
	assert(next_goal_label.text.contains("%d / 750" % mission.get_net_reward()))
	assert(mission_manager.get_offers().size() == 3)
	assert(not game_manager.try_unlock_port(&"antalya"))
	assert(not port_manager.is_unlocked(&"antalya"))

	event_bus.port_tapped.emit(&"antalya")
	await process_frame
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(port_unlock_panel.visible)
	assert(port_unlock_panel.is_open_for(&"antalya"))
	assert(port_unlock_panel.get_node("Margin/VBox/CompanyValue").text.contains("+500 CV"))
	var port_unlock_button := port_unlock_panel.get_node(
		"Margin/VBox/Buttons/UnlockButton"
	) as Button
	assert(port_unlock_button.disabled)
	assert(port_unlock_button.text.contains("Eksik"))
	game_manager.add_money(750 - game_manager.money)
	await process_frame
	assert(not port_unlock_button.disabled)
	port_unlock_button.pressed.emit()
	await process_frame
	assert(port_manager.is_unlocked(&"antalya"))
	assert(not port_unlock_panel.visible)
	assert(game_manager.money == 0)
	assert(company_manager.company_value == 1400)
	assert(company_manager.company_level == 2)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Soğutmalı"))
	var refrigerated_purchase_price: int = fleet_manager.get_ship_purchase_price(
		&"refrigerated_freighter"
	)
	assert(refrigerated_purchase_price == 1280)
	assert(next_goal_label.text.contains("0 / %d" % refrigerated_purchase_price))
	var second_ship_balance := _get_mission_balance_for_cost(
		mission_manager,
		fleet_manager,
		economy_manager,
		starter_ship_id,
		refrigerated_purchase_price
	)
	var second_ship_mission_range: Vector2i = second_ship_balance["mission_range"]
	assert(second_ship_mission_range.x >= 4 and second_ship_mission_range.y <= 8)
	var first_port_missions: Vector2i = first_port_balance["mission_range"]
	var first_port_gross: Vector2i = first_port_balance["gross_reward_range"]
	var first_port_costs: Vector2i = first_port_balance["operating_cost_range"]
	var first_port_net: Vector2i = first_port_balance["net_reward_range"]
	var second_ship_missions: Vector2i = second_ship_balance["mission_range"]
	var second_ship_gross: Vector2i = second_ship_balance["gross_reward_range"]
	var second_ship_costs: Vector2i = second_ship_balance["operating_cost_range"]
	var second_ship_net: Vector2i = second_ship_balance["net_reward_range"]
	var balance_log_format := "EARLY_GAME_BALANCE first_port=%d-%d missions " \
			+ "gross=%d-%d cost=%d-%d net=%d-%d second_ship=%d-%d missions " \
			+ "gross=%d-%d cost=%d-%d net=%d-%d"
	print(balance_log_format % [
		first_port_missions.x,
		first_port_missions.y,
		first_port_gross.x,
		first_port_gross.y,
		first_port_costs.x,
		first_port_costs.y,
		first_port_net.x,
		first_port_net.y,
		second_ship_missions.x,
		second_ship_missions.y,
		second_ship_gross.x,
		second_ship_gross.y,
		second_ship_costs.x,
		second_ship_costs.y,
		second_ship_net.x,
		second_ship_net.y,
	])

	var refrigerated_model: ShipData = fleet_manager.get_ship_model(&"refrigerated_freighter")
	assert(refrigerated_model != null)
	assert(refrigerated_model.purchase_cost == 800)
	assert(refrigerated_model.can_carry(food_cargo))
	assert(not refrigerated_model.can_carry(grain_cargo))
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 0)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") \
		== refrigerated_purchase_price)
	game_manager.add_money(refrigerated_purchase_price)
	assert(game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	await process_frame
	assert(game_manager.money == 0)
	assert(fleet_manager.get_all_ship_ids().size() == 2)
	var headquarters_arrival_ship: Node2D = null
	var headquarters_arrival_ship_id: StringName = &""
	for purchased_ship_id in fleet_manager.get_all_ship_ids():
		if purchased_ship_id == starter_ship_id:
			continue
		headquarters_arrival_ship_id = purchased_ship_id
		headquarters_arrival_ship = fleet_manager.get_ship_node(purchased_ship_id)
		break
	assert(headquarters_arrival_ship != null)
	var headquarters_arrival_slot: int = fleet_manager.get_ship_headquarters_slot_index(
		headquarters_arrival_ship_id
	)
	assert(headquarters_arrival_slot >= 0)
	assert(fleet_manager.get_ship_reserved_dock_port(headquarters_arrival_ship_id) == &"")
	var headquarters_arrival_berth: Vector2 = headquarters.get_delivery_position(
		headquarters_arrival_slot
	)
	var headquarters_arrival_approach: Vector2 = headquarters.get_delivery_approach_position(
		headquarters_arrival_slot
	)
	assert(bool(headquarters_arrival_ship.get("_dock_transition_active")))
	var headquarters_arrival_start: Vector2 = headquarters_arrival_ship.get(
		"_dock_transition_start"
	)
	assert(headquarters_arrival_start.is_equal_approx(headquarters_arrival_approach))
	assert(headquarters_arrival_ship.global_position.distance_to(
		headquarters_arrival_berth
	) <= headquarters_arrival_approach.distance_to(headquarters_arrival_berth))
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 1)
	assert(fleet_manager.get_ship_purchase_price(&"starter_freighter") == 1280)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 2050)
	assert(fleet_manager.get_ship_purchase_price(&"bulk_carrier") == 3840)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Çanakkale"))
	assert(next_goal_label.text.contains("0 / 1500"))
	assert(company_manager.company_value == 2600)
	assert(company_manager.company_level == 3)
	assert(headquarters.get_visual_tier() == 2)
	var tier_two_delivery_position: Vector2 = headquarters.get_delivery_position()
	assert(tier_two_delivery_position.is_equal_approx(tier_one_delivery_position))
	var headquarters_pier := headquarters.get_node("Pier") as Line2D
	assert(headquarters_pier.width > tier_one_pier_width)
	assert(headquarters_pier.points[headquarters_pier.points.size() - 1].is_equal_approx(
		(headquarters.get_node("DeliveryBerth") as Marker2D).position
	))
	var shop_buy_button := world.get_node(
		"UI/ManagementDock/Margin/VBox/Content/ShipShopPanel/Margin/VBox/Body/BuyButton"
	) as Button
	assert(shop_buy_button != null)
	shop_buy_button.text = "Satın Al · 800 ₺"
	event_bus.game_loaded.emit()
	await process_frame
	assert(shop_buy_button.text.contains("2050"))
	assert(shop_buy_button.disabled == (game_manager.money < 2050))

	var refrigerated_ship_found := false
	var refrigerated_ship_id: StringName = &""
	for ship_id in fleet_manager.get_all_ship_ids():
		if ship_id == starter_ship_id:
			continue
		var purchased_data: ShipData = fleet_manager.get_ship_data(ship_id)
		assert(purchased_data != null)
		assert(purchased_data.can_carry(food_cargo))
		var purchased_ship := fleet_manager.get_ship_node(ship_id) as Node2D
		assert(purchased_ship != null)
		assert(fleet_manager.is_awaiting_headquarters_dispatch(ship_id))
		assert(bool(purchased_ship.get("_hold_initial_position_while_idle")))
		var purchased_delivery_position: Vector2 = headquarters.get_delivery_position(
			fleet_manager.get_ship_headquarters_slot_index(ship_id)
		)
		var delivery_transition_deadline := Time.get_ticks_msec() + 3000
		while bool(purchased_ship.get("_dock_transition_active")) \
				and Time.get_ticks_msec() < delivery_transition_deadline:
			await process_frame
		assert(not bool(purchased_ship.get("_dock_transition_active")))
		assert(purchased_ship.global_position.is_equal_approx(
			purchased_delivery_position
		))
		refrigerated_ship_id = ship_id
		refrigerated_ship_found = true
	assert(refrigerated_ship_found)
	var refrigerated_saved_state: Dictionary = fleet_manager.get_save_state()[
		String(refrigerated_ship_id)
	]
	assert(bool(refrigerated_saved_state["awaiting_headquarters_dispatch"]))
	assert(int(refrigerated_saved_state["headquarters_slot_index"]) \
		== fleet_manager.get_ship_headquarters_slot_index(refrigerated_ship_id))
	assert(not bool(refrigerated_saved_state["headquarters_dispatch_active"]))
	assert(ShipRuntimeState.from_dict(
		refrigerated_saved_state
	).awaiting_headquarters_dispatch)
	assert(not fleet_manager.get_ship_name(refrigerated_ship_id).is_empty())
	assert(fleet_manager.get_ship_name(refrigerated_ship_id) != "Deniz Yıldızı")
	assert(not fleet_manager.rename_ship(refrigerated_ship_id, "deniz yıldızı"))
	assert(not game_manager.try_unlock_port(&"istanbul"))
	assert(not port_manager.is_unlocked(&"istanbul"))
	event_bus.port_tapped.emit(&"istanbul")
	await process_frame
	assert(port_unlock_panel.is_open_for(&"istanbul"))
	assert(port_unlock_button.disabled)
	assert(port_unlock_button.text.contains("Sv. 4"))
	port_unlock_panel.close_panel()
	game_manager.add_money(1500)
	assert(game_manager.try_unlock_port(&"canakkale"))
	assert(game_manager.money == 0)
	assert(port_manager.is_unlocked(&"canakkale"))
	assert((world.get_node("Ports/Canakkale/StatusLabel") as Label).text == "Sv. 1")
	assert(company_manager.company_value == 3400)
	assert(company_manager.company_level == 3)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Dökme"))
	var bulk_purchase_price: int = fleet_manager.get_ship_purchase_price(&"bulk_carrier")
	assert(bulk_purchase_price == 3840)
	assert(next_goal_label.text.contains("0 / %d" % bulk_purchase_price))
	settings_manager.set_locale("en")
	assert(next_goal_label.text.contains("Buy Bulk Carrier"))
	settings_manager.set_locale("tr")
	var bulk_model: ShipData = fleet_manager.get_ship_model(&"bulk_carrier")
	assert(bulk_model != null)
	assert(bulk_model.required_company_level == 3)
	assert(bulk_model.purchase_cost == 1500)
	assert(bulk_model.base_company_value == 1400)
	assert(bulk_model.can_carry(grain_cargo))
	assert(not bulk_model.can_carry(food_cargo))
	next_model_button.pressed.emit()
	assert(model_position_label.text == "3 / 3")
	assert((shop_panel.get_node("Margin/VBox/Body/Title") as Label).text.contains("Dökme"))
	game_manager.add_money(bulk_purchase_price)
	assert(not tutorial_buy_button.disabled)
	tutorial_buy_button.pressed.emit()
	await process_frame
	await process_frame
	assert(fleet_manager.get_owned_model_count(&"bulk_carrier") == 1)
	assert(fleet_manager.get_all_ship_ids().size() == 3)
	assert(game_manager.money == 0)
	assert(company_manager.company_value == 4800)
	assert(company_manager.company_level == 4)
	assert(next_goal_label.text.contains("İstanbul"))
	assert(next_goal_label.text.contains("0 / 2600"))
	var bulk_ship_id: StringName = &""
	for ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.get_ship_data(ship_id).id == &"bulk_carrier":
			bulk_ship_id = ship_id
			break
	assert(bulk_ship_id != &"")
	assert(not fleet_manager.get_ship_name(bulk_ship_id).is_empty())
	assert(fleet_manager.get_ship_name(bulk_ship_id) != "Deniz Yıldızı")
	var bulk_offer_count := 0
	for offer in mission_manager.get_offers():
		if offer.offered_ship_id != bulk_ship_id:
			continue
		bulk_offer_count += 1
		assert(offer.cargo_type_id == &"grain")
	assert(bulk_offer_count == 3)
	var expansion_candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		&"izmir",
		starter_ship_id
	)
	var has_canakkale_candidate := false
	for candidate in expansion_candidates:
		has_canakkale_candidate = has_canakkale_candidate \
			or candidate["pickup_id"] == &"canakkale" \
			or candidate["destination_id"] == &"canakkale"
	assert(has_canakkale_candidate)
	game_manager.add_money(istanbul_data.base_unlock_cost)
	assert(game_manager.try_unlock_port(&"istanbul"))
	await process_frame
	assert(company_manager.company_value == 6000)
	assert(company_manager.company_level == 4)
	assert(is_equal_approx(port_manager.get_distance(&"mersin", &"izmir"), 250.0))
	assert(is_equal_approx(port_manager.get_distance(&"izmir", &"mersin"), 250.0))
	assert(is_equal_approx(port_manager.get_distance(&"samsun", &"trabzon"), 195.0))
	assert(is_equal_approx(port_manager.get_distance(&"antalya", &"trabzon"), 500.0))
	assert(port_manager.get_distance(&"mersin", &"samsun") \
		< port_manager.get_distance(&"antalya", &"samsun"))
	var nominal_starter_speed: float = fleet_manager.get_ship_effective_speed(
		starter_ship_id
	)
	assert(is_equal_approx(
		fleet_manager.get_ship_sailing_speed(starter_ship_id, 0),
		nominal_starter_speed * 1.10
	))
	assert(is_equal_approx(
		fleet_manager.get_ship_sailing_speed(starter_ship_id, 1),
		nominal_starter_speed * 0.95
	))
	assert(is_equal_approx(
		fleet_manager.get_ship_sailing_speed(starter_ship_id, 4),
		nominal_starter_speed * 0.80
	))
	assert(is_equal_approx(
		fleet_manager.get_ship_sailing_speed(starter_ship_id, 8),
		nominal_starter_speed * 0.80
	))
	var mersin_samsun_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"mersin",
		&"samsun",
		&"mersin",
		-1.0,
		1
	)
	var antalya_samsun_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"antalya",
		&"samsun",
		&"antalya",
		-1.0,
		1
	)
	assert(mersin_samsun_duration < antalya_samsun_duration)
	var samsun_trabzon_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"samsun",
		&"trabzon",
		&"samsun",
		-1.0,
		1
	)
	var antalya_trabzon_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"antalya",
		&"trabzon",
		&"antalya",
		-1.0,
		1
	)
	assert(antalya_trabzon_duration > samsun_trabzon_duration)
	var mersin_izmir_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"mersin",
		&"izmir",
		&"mersin",
		-1.0,
		1
	)
	var mersin_trabzon_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"mersin",
		&"trabzon",
		&"mersin",
		-1.0,
		1
	)
	assert(mersin_trabzon_duration > mersin_izmir_duration)
	assert(mersin_trabzon_duration > 45.0)
	var four_unit_antalya_trabzon_duration: float = fleet_manager.estimate_mission_duration(
		starter_ship_id,
		&"antalya",
		&"trabzon",
		&"antalya",
		-1.0,
		4
	)
	assert(four_unit_antalya_trabzon_duration > antalya_trabzon_duration)
	assert(next_goal_label.text.contains("Samsun"))
	assert(next_goal_label.text.contains("Sv. 5"))
	assert(next_goal_label.text.contains("6000 / 8000 CV"))

	var starter_speed_before: float = fleet_manager.get_ship_effective_speed(starter_ship_id)
	var company_value_before_speed_upgrade: int = company_manager.company_value
	var starter_upgrade_cost: int = fleet_manager.get_ship_speed_upgrade_cost(starter_ship_id)
	assert(starter_upgrade_cost > 0)
	game_manager.add_money(starter_upgrade_cost)
	assert(game_manager.try_upgrade_ship_speed(starter_ship_id))
	assert(game_manager.money == 0)
	assert(fleet_manager.get_ship_speed_level(starter_ship_id) == 1)
	assert(is_equal_approx(
		fleet_manager.get_ship_effective_speed(starter_ship_id),
		starter_speed_before * 1.15
	))
	assert(company_manager.company_value == company_value_before_speed_upgrade + 100)
	var starter_capacity_upgrade_cost: int = fleet_manager.get_ship_capacity_upgrade_cost(starter_ship_id)
	var company_value_before_capacity_upgrade: int = company_manager.company_value
	assert(starter_capacity_upgrade_cost > 0)
	game_manager.add_money(starter_capacity_upgrade_cost)
	assert(game_manager.try_upgrade_ship_capacity(starter_ship_id))
	assert(game_manager.money == 0)
	assert(fleet_manager.get_ship_capacity_level(starter_ship_id) == 1)
	assert(fleet_manager.get_ship_effective_capacity(starter_ship_id) == 2)
	assert(company_manager.company_value == company_value_before_capacity_upgrade + 120)
	await process_frame

	mission_manager.refresh_offers()
	var multi_ship_offers: Array = mission_manager.get_offers()
	assert(multi_ship_offers.size() >= 2)
	var offered_ship_ids: Array[StringName] = []
	for offer in multi_ship_offers:
		if not offered_ship_ids.has(offer.offered_ship_id):
			offered_ship_ids.append(offer.offered_ship_id)
	assert(offered_ship_ids.size() == fleet_manager.get_all_ship_ids().size())

	var first_multi_offer: Mission = null
	for candidate_offer in multi_ship_offers:
		if candidate_offer.origin_port_id != candidate_offer.pickup_port_id:
			first_multi_offer = candidate_offer
			break
	assert(first_multi_offer != null)
	assert(mission_manager.accept_offer(first_multi_offer.id))
	await process_frame
	var resumed_ship_id := first_multi_offer.assigned_ship_id
	var resumed_mission: Mission = fleet_manager.get_ship_mission(resumed_ship_id)
	assert(resumed_mission != null)
	assert(fleet_manager.get_ship_state(resumed_ship_id) \
		== ShipRuntimeState.State.SAILING_TO_PICKUP)
	resumed_mission.leg_start_unix = Time.get_unix_time_from_system() \
		- resumed_mission.leg_duration_sec * 0.4
	var replaced_ship := fleet_manager.get_ship_node(resumed_ship_id) as Node2D
	assert(replaced_ship != null)
	replaced_ship.queue_free()
	await process_frame
	var resumed_ship_data: ShipData = fleet_manager.get_ship_data(resumed_ship_id)
	var resumed_ship := resumed_ship_data.scene.instantiate() as Area2D
	assert(resumed_ship != null)
	resumed_ship.name = String(resumed_ship_id)
	resumed_ship.set("ship_id", resumed_ship_id)
	resumed_ship.set("ship_data", resumed_ship_data)
	resumed_ship.set(
		"home_port_id",
		fleet_manager.get_ship_current_port(resumed_ship_id)
	)
	world.add_child(resumed_ship)
	var resumed_progress: float = resumed_mission.get_leg_progress()
	var resumed_route: PackedVector2Array = resumed_ship.get("_sailing_route_points")
	assert(resumed_route.size() >= 2)
	var resumed_visual_progress: float = resumed_ship.call(
		"calculate_visual_sailing_progress",
		resumed_progress,
		resumed_mission.leg_duration_sec,
		resumed_ship.call("_get_polyline_length", resumed_route)
	)
	var expected_resume_position: Vector2 = resumed_ship.call(
		"_get_position_along_points",
		resumed_route,
		resumed_visual_progress
	)
	assert(resumed_ship.global_position.distance_to(expected_resume_position) < 2.0)
	assert(resumed_ship.global_position.distance_to(Vector2.ZERO) > 100.0)
	var resumed_tangent: Vector2 = resumed_ship.call(
		"_get_direction_along_points",
		resumed_route,
		resumed_visual_progress
	)
	var resumed_icon := resumed_ship.get_node("Icon") as Sprite2D
	var resumed_forward := Vector2.RIGHT.rotated(
		resumed_icon.rotation + resumed_ship_data.sprite_forward_angle_rad
	)
	assert(resumed_forward.dot(resumed_tangent.normalized()) > 0.98)
	var remaining_offers: Array = mission_manager.get_offers()
	var second_multi_offer: Mission = null
	for offer in remaining_offers:
		if offer.offered_ship_id != first_multi_offer.offered_ship_id:
			second_multi_offer = offer
			break
	assert(second_multi_offer != null)
	assert(mission_manager.accept_offer(second_multi_offer.id))
	await process_frame
	assert(mission_manager.get_active_missions().size() == 2)

	var expected_offline_reward := 0
	var expected_completed_counts: Dictionary = {}
	var expected_lifetime_earnings: Dictionary = {}
	for active_mission in mission_manager.get_active_missions():
		expected_offline_reward += active_mission.get_net_reward()
		var assigned_ship_id: StringName = active_mission.assigned_ship_id
		expected_completed_counts[assigned_ship_id] = \
			fleet_manager.get_ship_completed_mission_count(assigned_ship_id) + 1
		expected_lifetime_earnings[assigned_ship_id] = \
			fleet_manager.get_ship_total_net_earnings(assigned_ship_id) \
			+ active_mission.get_net_reward()
		var fleet_mission: Mission = fleet_manager.get_ship_mission(active_mission.assigned_ship_id)
		fleet_mission.leg_start_unix = Time.get_unix_time_from_system() - 3600
	var saved_company_value: int = company_manager.company_value
	var saved_company_level: int = company_manager.company_level
	var saved_starter_ship_name: String = fleet_manager.get_ship_name(starter_ship_id)
	assert(save_manager.save_game(test_save_path))
	game_manager.add_money(999)
	assert(save_manager.load_game(test_save_path))
	await process_frame
	assert(save_manager.loaded_existing_save)
	assert(game_manager.money == expected_offline_reward)
	assert(offline_summary_dialog.visible)
	assert(offline_summary_dialog.title.contains("Sen yokken"))
	assert(offline_summary_dialog.dialog_text.contains("2 sefer"))
	assert(offline_summary_dialog.dialog_text.contains("+%d ₺" % expected_offline_reward))
	assert(not paused)
	offline_summary_dialog.hide()
	assert(mission_manager.get_active_missions().is_empty())
	assert(fleet_manager.get_idle_ship_ids().size() == fleet_manager.get_all_ship_ids().size())
	assert(fleet_manager.get_ship_speed_level(starter_ship_id) == 1)
	assert(fleet_manager.get_ship_capacity_level(starter_ship_id) == 1)
	assert(fleet_manager.get_ship_name(starter_ship_id) == saved_starter_ship_name)
	for completed_ship_id in expected_completed_counts.keys():
		assert(fleet_manager.get_ship_completed_mission_count(completed_ship_id) \
			== expected_completed_counts[completed_ship_id])
		assert(fleet_manager.get_ship_total_net_earnings(completed_ship_id) \
			== expected_lifetime_earnings[completed_ship_id])
	assert(company_manager.company_value == saved_company_value)
	assert(company_manager.company_level == saved_company_level)
	assert(company_manager.peak_company_value >= company_manager.company_value)
	assert(game_manager.is_tutorial_completed())

	# Per-ship automation becomes visible one level early, then requires three
	# completed missions on that ship. It never chains new missions offline.
	event_bus.ship_tapped.emit(starter_ship_id)
	world.call("_refresh_fleet_panel")
	var automation_button := fleet_panel.get_node(
		"Margin/VBox/Body/Details/Actions/AutomationButton"
	) as Button
	assert(not fleet_manager.is_ship_automation_unlocked(starter_ship_id))
	while company_manager.company_level < 4:
		assert(company_manager.debug_advance_level())
	world.call("_refresh_fleet_panel")
	assert(automation_button.visible)
	assert(automation_button.disabled)
	assert(automation_button.text.contains("Şirket Sv.5"))
	assert(not game_manager.try_toggle_ship_automation(starter_ship_id))
	assert(company_manager.debug_advance_level())
	world.call("_refresh_fleet_panel")
	var completed_before_automation: int = \
		fleet_manager.get_ship_completed_mission_count(starter_ship_id)
	assert(completed_before_automation == 2)
	assert(automation_button.disabled)
	assert(automation_button.text.contains("Görev 2/3"))
	assert(not game_manager.try_toggle_ship_automation(starter_ship_id))
	mission_manager.refresh_offers()
	var readiness_offer: Mission = null
	for candidate_offer in mission_manager.get_offers():
		if candidate_offer.offered_ship_id == starter_ship_id:
			readiness_offer = candidate_offer
			break
	assert(readiness_offer != null)
	assert(mission_manager.accept_offer(readiness_offer.id))
	for _step in range(10):
		if readiness_offer.stage == Mission.Stage.COMPLETED:
			break
		readiness_offer.leg_duration_sec = 0.0
		await process_frame
		await process_frame
	assert(readiness_offer.stage == Mission.Stage.COMPLETED)
	assert(fleet_manager.get_ship_completed_mission_count(starter_ship_id) == 3)
	assert(fleet_manager.get_ship_total_upgrade_levels(starter_ship_id) == 2)
	assert(instruction_label.text.contains("otomatik göreve hazır"))
	assert(instruction_label.text.contains("5000"))
	mission_manager.refresh_offers()
	var expected_auto_offer: Mission = null
	var expected_profit_rate := -1.0
	for candidate_offer in mission_manager.get_offers():
		if candidate_offer.offered_ship_id != starter_ship_id \
				or candidate_offer.get_net_reward() <= 0:
			continue
		var profit_rate: float = float(candidate_offer.get_net_reward()) \
			/ maxf(candidate_offer.estimated_duration_sec, 0.001)
		if profit_rate > expected_profit_rate:
			expected_auto_offer = candidate_offer
			expected_profit_rate = profit_rate
	assert(expected_auto_offer != null)
	game_manager.apply_save_state({"money": GameManager.AUTOMATION_UNLOCK_COST})
	world.call("_refresh_fleet_panel")
	assert(not automation_button.disabled)
	assert(automation_button.text.contains("5000"))
	automation_button.pressed.emit()
	await process_frame
	await process_frame
	assert(game_manager.money == 0)
	assert(fleet_manager.is_ship_automation_unlocked(starter_ship_id))
	assert(fleet_manager.is_ship_automation_enabled(starter_ship_id))
	var first_auto_mission: Mission = fleet_manager.get_ship_mission(starter_ship_id)
	assert(first_auto_mission == expected_auto_offer)

	for _step in range(8):
		if fleet_manager.get_ship_mission(starter_ship_id) != first_auto_mission:
			break
		first_auto_mission.leg_duration_sec = 0.0
		await process_frame
		await process_frame
	assert(first_auto_mission.stage == Mission.Stage.COMPLETED)
	await process_frame
	await process_frame
	var second_auto_mission: Mission = fleet_manager.get_ship_mission(starter_ship_id)
	assert(second_auto_mission != null)
	assert(second_auto_mission != first_auto_mission)
	automation_button.pressed.emit()
	assert(not fleet_manager.is_ship_automation_enabled(starter_ship_id))
	for _step in range(8):
		if fleet_manager.get_ship_mission(starter_ship_id) != second_auto_mission:
			break
		second_auto_mission.leg_duration_sec = 0.0
		await process_frame
		await process_frame
	assert(second_auto_mission.stage == Mission.Stage.COMPLETED)
	await process_frame
	await process_frame
	assert(fleet_manager.get_ship_mission(starter_ship_id) == null)
	assert(fleet_manager.get_ship_state(starter_ship_id) == ShipRuntimeState.State.IDLE)
	var cash_after_automation: int = game_manager.money
	assert(cash_after_automation \
		== first_auto_mission.get_net_reward() + second_auto_mission.get_net_reward())
	assert(save_manager.save_game(test_save_path))
	assert(fleet_manager.set_ship_automation_enabled(starter_ship_id, true))
	game_manager.add_money(999)
	assert(save_manager.load_game(test_save_path))
	await process_frame
	await process_frame
	assert(game_manager.money == cash_after_automation)
	assert(fleet_manager.is_ship_automation_unlocked(starter_ship_id))
	assert(not fleet_manager.is_ship_automation_enabled(starter_ship_id))
	assert(fleet_manager.get_ship_mission(starter_ship_id) == null)
	assert(not offline_summary_dialog.visible)
	assert(game_manager.spend_money(game_manager.money))

	var starter_max_speed_level := starter_ship_data.max_speed_level
	while fleet_manager.get_ship_speed_level(starter_ship_id) < starter_max_speed_level:
		assert(fleet_manager.upgrade_ship_speed(starter_ship_id))
	assert(fleet_manager.get_ship_speed_level(starter_ship_id) == starter_max_speed_level)
	assert(fleet_manager.get_ship_speed_upgrade_cost(starter_ship_id) == -1)
	assert(not fleet_manager.upgrade_ship_speed(starter_ship_id))

	var starter_max_capacity_level := starter_ship_data.max_capacity_level
	while fleet_manager.get_ship_capacity_level(starter_ship_id) < starter_max_capacity_level:
		assert(fleet_manager.upgrade_ship_capacity(starter_ship_id))
	assert(fleet_manager.get_ship_capacity_level(starter_ship_id) == starter_max_capacity_level)
	assert(fleet_manager.get_ship_capacity_upgrade_cost(starter_ship_id) == -1)
	assert(not fleet_manager.upgrade_ship_capacity(starter_ship_id))

	var fleet_capacity: int = fleet_manager.get_fleet_capacity()
	while fleet_manager.get_all_ship_ids().size() < fleet_capacity:
		var stable_mersin_slots := {}
		for existing_ship_id in fleet_manager.get_all_ship_ids():
			if fleet_manager.get_ship_current_port(existing_ship_id) == &"mersin" \
					and fleet_manager.get_ship_dock_slot_index(existing_ship_id) >= 0:
				stable_mersin_slots[String(existing_ship_id)] = \
					fleet_manager.get_ship_dock_slot_index(existing_ship_id)
		assert(fleet_manager.purchase_ship(&"refrigerated_freighter", &"mersin") != &"")
		for existing_ship_id_string in stable_mersin_slots.keys():
			var existing_ship_id := StringName(existing_ship_id_string)
			assert(fleet_manager.get_ship_dock_slot_index(existing_ship_id) \
				== stable_mersin_slots[existing_ship_id_string])
	assert(fleet_manager.get_all_ship_ids().size() == fleet_capacity)
	world.call("_refresh_fleet_panel")
	management_dock.open_fleet()
	await process_frame
	var fleet_scroll_bar := fleet_scroll.get_v_scroll_bar()
	assert(fleet_scroll_bar.max_value > fleet_scroll_bar.page)
	var fleet_cards: Dictionary = fleet_panel.get("_cards")
	for card_button: Button in fleet_cards.values():
		assert(card_button.focus_mode == Control.FOCUS_NONE)
		assert(card_button.mouse_filter == Control.MOUSE_FILTER_PASS)
	for action_button: Button in [
		fleet_panel.get_node("Margin/VBox/Body/Details/Actions/SpeedButton"),
		fleet_panel.get_node("Margin/VBox/Body/Details/Actions/CapacityButton"),
		fleet_panel.get_node("Margin/VBox/Body/Details/Actions/AutomationButton"),
		fleet_panel.get_node("Margin/VBox/Body/Details/Actions/RenameButton"),
	]:
		assert(action_button.focus_mode == Control.FOCUS_NONE)
	var fleet_ship_names: Array[String] = []
	for named_ship_id in fleet_manager.get_all_ship_ids():
		var fleet_ship_name: String = fleet_manager.get_ship_name(named_ship_id)
		assert(not fleet_ship_name.is_empty())
		assert(not fleet_ship_names.has(fleet_ship_name.to_lower()))
		fleet_ship_names.append(fleet_ship_name.to_lower())
	var headquarters_dispatch_count := 0
	while fleet_manager.get_reserved_dock_count(&"mersin") < 2 \
			and headquarters_dispatch_count < 2:
		var berth_test_ship_id: StringName = &""
		for candidate_ship_id in fleet_manager.get_all_ship_ids():
			if fleet_manager.is_awaiting_headquarters_dispatch(candidate_ship_id):
				berth_test_ship_id = candidate_ship_id
				break
		assert(berth_test_ship_id != &"")
		assert(fleet_manager.get_ship_reserved_dock_port(berth_test_ship_id) == &"")
		var headquarters_to_mersin_mission := Mission.new()
		headquarters_to_mersin_mission.id = \
			"headquarters_to_mersin_berth_test_%d" % headquarters_dispatch_count
		headquarters_to_mersin_mission.pickup_port_id = &"izmir"
		headquarters_to_mersin_mission.delivery_port_id = &"mersin"
		headquarters_to_mersin_mission.loading_duration_sec = 0.0
		headquarters_to_mersin_mission.unloading_duration_sec = 0.0
		assert(fleet_manager.assign_mission(
			berth_test_ship_id,
			headquarters_to_mersin_mission
		))
		var headquarters_mission_safety := 0
		while fleet_manager.get_ship_state(berth_test_ship_id) \
				!= ShipRuntimeState.State.IDLE and headquarters_mission_safety < 6:
			headquarters_to_mersin_mission.leg_duration_sec = 0.0
			await process_frame
			headquarters_mission_safety += 1
		assert(fleet_manager.get_ship_state(berth_test_ship_id) \
			== ShipRuntimeState.State.IDLE)
		assert(fleet_manager.get_ship_current_port(berth_test_ship_id) == &"mersin")
		headquarters_dispatch_count += 1
	assert(fleet_manager.get_reserved_dock_count(&"mersin") == 2)
	var full_port_probe_ship_id: StringName = &""
	for candidate_ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.is_awaiting_headquarters_dispatch(candidate_ship_id):
			full_port_probe_ship_id = candidate_ship_id
			break
	assert(full_port_probe_ship_id != &"")
	assert(not fleet_manager.can_reserve_dock_at_port(&"mersin", full_port_probe_ship_id))
	var full_port_candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		fleet_manager.get_ship_current_port(full_port_probe_ship_id),
		full_port_probe_ship_id
	)
	for candidate in full_port_candidates:
		assert(candidate["destination_id"] != &"mersin")
	var occupied_mersin_slots: Array[int] = []
	for docked_ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.get_ship_current_port(docked_ship_id) != &"mersin" \
				or fleet_manager.is_awaiting_headquarters_dispatch(docked_ship_id):
			continue
		var dock_slot_index: int = fleet_manager.get_ship_dock_slot_index(docked_ship_id)
		assert(dock_slot_index >= 0)
		assert(not occupied_mersin_slots.has(dock_slot_index))
		occupied_mersin_slots.append(dock_slot_index)

	# Departing from a lower berth pulls the last docked ship into that gap.
	var lowest_slot := 999
	var highest_slot := -1
	var departing_ship_id: StringName = &""
	var replacement_ship_id: StringName = &""
	for docked_ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.get_ship_current_port(docked_ship_id) != &"mersin" \
				or fleet_manager.is_awaiting_headquarters_dispatch(docked_ship_id):
			continue
		var slot_index: int = fleet_manager.get_ship_dock_slot_index(docked_ship_id)
		if slot_index >= 0 and slot_index < lowest_slot:
			lowest_slot = slot_index
			departing_ship_id = docked_ship_id
		if slot_index > highest_slot:
			highest_slot = slot_index
			replacement_ship_id = docked_ship_id
	assert(departing_ship_id != &"")
	assert(replacement_ship_id != &"")
	assert(departing_ship_id != replacement_ship_id)
	var berth_compaction_mission := Mission.new()
	berth_compaction_mission.id = "berth_compaction_test"
	berth_compaction_mission.pickup_port_id = &"mersin"
	berth_compaction_mission.delivery_port_id = &"izmir"
	assert(fleet_manager.assign_mission(departing_ship_id, berth_compaction_mission))
	berth_compaction_mission.leg_duration_sec = 0.0
	await process_frame
	berth_compaction_mission.leg_duration_sec = 0.0
	await process_frame
	assert(fleet_manager.get_ship_state(departing_ship_id) \
		== ShipRuntimeState.State.SAILING_TO_DELIVERY)
	assert(fleet_manager.get_ship_dock_slot_index(replacement_ship_id) == lowest_slot)
	assert(fleet_manager.can_reserve_dock_at_port(&"mersin", full_port_probe_ship_id))
	assert(fleet_manager.purchase_ship(&"refrigerated_freighter", &"mersin") == &"")
	game_manager.add_money(10000)
	var money_before_full_fleet_purchase: int = game_manager.money
	assert(not game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	assert(game_manager.money == money_before_full_fleet_purchase)
	assert(save_manager.delete_save(test_save_path))
	assert(not save_manager.has_save(test_save_path))
	game_manager.apply_save_state({"money": 0})
	assert(game_manager.is_tutorial_completed())
	game_manager.reset_state()
	assert(int(game_manager.get("tutorial_step")) == 7)
	assert(game_manager.money == starter_model.purchase_cost)
	assert(skip_tutorial_button.visible)
	assert(debug_level_button.disabled)
	assert(debug_money_button.disabled)
	skip_tutorial_button.pressed.emit()
	assert(tutorial_complete_dialog.visible)
	assert(tutorial_complete_dialog.title.contains("Hazırsın Kaptan"))
	assert(tutorial_complete_dialog.dialog_text.contains("İyi eğlenceler Kaptan"))
	assert(int(game_manager.get("tutorial_step")) == 7)
	tutorial_complete_dialog.confirmed.emit()
	tutorial_complete_dialog.hide()
	assert(game_manager.is_tutorial_completed())
	assert(not skip_tutorial_button.visible)
	assert(instruction_label.text.contains("ÖĞRETİCİ ATLANDI"))
	assert(not debug_level_button.disabled)
	assert(not debug_money_button.disabled)
	var money_before_debug: int = game_manager.money
	debug_money_button.emit_signal("pressed")
	assert(game_manager.money == money_before_debug + 10000)
	var level_before_debug: int = company_manager.company_level
	debug_level_button.emit_signal("pressed")
	assert(company_manager.company_level == level_before_debug + 1)
	assert(debug_level_button.text.contains("Sv. %d" % company_manager.company_level))
	world.set("_selected_ship_id", &"")
	event_bus.port_tapped.emit(&"mersin")
	await process_frame
	assert(port_unlock_panel.is_open_for(&"mersin"))
	assert((port_unlock_panel.get_node("Margin/VBox/Title") as Label).text.contains("Sv. 1"))
	var port_company_value_before_upgrade: int = company_manager.company_value
	var money_before_port_upgrade: int = game_manager.money
	port_unlock_button.pressed.emit()
	await process_frame
	assert(port_manager.get_level(&"mersin") == 2)
	assert(port_manager.get_dock_slot_count(&"mersin") == 4)
	assert(game_manager.money == money_before_port_upgrade - 450)
	assert(company_manager.company_value == port_company_value_before_upgrade + 200)
	assert(is_equal_approx(
		fleet_manager.get_mission_loading_duration(&"mersin", &"mersin"),
		2.4
	))
	assert(port_unlock_button.text.contains("900"))
	port_unlock_button.pressed.emit()
	await process_frame
	assert(port_manager.get_level(&"mersin") == 3)
	assert(port_manager.get_dock_slot_count(&"mersin") == 6)
	assert(is_equal_approx(
		fleet_manager.get_mission_unloading_duration(&"mersin"),
		1.8
	))
	assert(port_unlock_button.disabled)
	assert(port_unlock_button.text.contains("Maksimum"))
	var money_at_max_port_level: int = game_manager.money
	assert(not game_manager.try_upgrade_port(&"mersin"))
	assert(game_manager.money == money_at_max_port_level)
	print("SMOKE_TEST_OK gross=%d cost=%d net=%d" % [
		mission.reward,
		mission.operating_cost,
		mission.get_net_reward(),
	])
	quit(0)


func _assert_port_centers_are_spaced(port_manager: Node, minimum_distance: float) -> void:
	var port_ids: Array[StringName] = port_manager.get_all_port_ids()
	for first_index in range(port_ids.size()):
		var first_id := port_ids[first_index]
		var first_node := port_manager.get_port_node(first_id) as Node2D
		assert(first_node != null)
		for second_index in range(first_index + 1, port_ids.size()):
			var second_id := port_ids[second_index]
			var second_node := port_manager.get_port_node(second_id) as Node2D
			assert(second_node != null)
			assert(
				first_node.global_position.distance_to(second_node.global_position) \
					>= minimum_distance,
				"Ports '%s' and '%s' are too close for mobile labels and berths." % [
					first_id,
					second_id,
				]
			)


func _assert_all_sea_routes_avoid_land(
		port_manager: Node,
		world: Node2D
) -> void:
	const ROUTE_SAMPLE_SPACING_PX := 20.0
	var land_entries: Array[Dictionary] = []
	var land_root := world.get_node("LandMasses")
	for candidate in land_root.find_children("*", "Polygon2D", true, false):
		var land := candidate as Polygon2D
		var global_polygon := PackedVector2Array()
		for local_point in land.polygon:
			global_polygon.append(land.to_global(local_point))
		land_entries.append({
			"name": land.name,
			"polygon": global_polygon,
		})

	var routes: Array = port_manager.call("get_all_sea_routes")
	assert(not routes.is_empty(), "No sea routes were registered for validation.")
	for route in routes:
		var direct_points: PackedVector2Array = port_manager.call(
			"_get_direct_route_points",
			route.from_port_id,
			route.to_port_id
		)
		var route_points: PackedVector2Array = port_manager.call(
			"smooth_polyline_points",
			direct_points
		)
		assert(route_points.size() >= 2, "Sea route has fewer than two points: %s -> %s" % [
			route.from_port_id,
			route.to_port_id,
		])
		_assert_route_points_avoid_land(
			route_points,
			land_entries,
			"%s -> %s" % [route.from_port_id, route.to_port_id],
			ROUTE_SAMPLE_SPACING_PX
		)

	# Connected missions may combine several authored corridors. Validate every
	# possible port pair too, because their open-water junctions are different
	# from the endpoints used by each direct corridor.
	var port_ids: Array[StringName] = port_manager.get_all_port_ids()
	for first_index in range(port_ids.size()):
		for second_index in range(first_index + 1, port_ids.size()):
			var connected_points: PackedVector2Array = port_manager.get_smoothed_route_points(
				port_ids[first_index],
				port_ids[second_index]
			)
			assert(connected_points.size() >= 2)
			_assert_route_points_avoid_land(
				connected_points,
				land_entries,
				"%s -> %s" % [port_ids[first_index], port_ids[second_index]],
				ROUTE_SAMPLE_SPACING_PX
			)



func _assert_route_points_avoid_land(
		route_points: PackedVector2Array,
		land_entries: Array[Dictionary],
		route_label: String,
		sample_spacing_px: float
) -> void:
	for segment_index in range(route_points.size() - 1):
		var segment_start := route_points[segment_index]
		var segment_end := route_points[segment_index + 1]
		var sample_count := maxi(
			ceili(segment_start.distance_to(segment_end) / sample_spacing_px),
			1
		)
		for sample_index in range(sample_count + 1):
			var is_route_start := segment_index == 0 and sample_index == 0
			var is_route_end := segment_index == route_points.size() - 2 \
				and sample_index == sample_count
			if is_route_start or is_route_end:
				continue
			var sample_point := segment_start.lerp(
				segment_end,
				float(sample_index) / float(sample_count)
			)
			for land_entry in land_entries:
				assert(not Geometry2D.is_point_in_polygon(
					sample_point,
					land_entry["polygon"]
				), "Sea route %s enters land '%s' near %s." % [
					route_label,
					land_entry["name"],
					sample_point,
				])


func _assert_sea_routes_have_varied_curves(port_manager: Node) -> void:
	var routes: Array = port_manager.call("get_all_sea_routes")
	var s_curve_count := 0
	for route in routes:
		var points: PackedVector2Array = port_manager.call(
			"_get_direct_route_points",
			route.from_port_id,
			route.to_port_id
		)
		assert(points.size() >= 4, "Sea route needs authored curve points: %s -> %s" % [
			route.from_port_id,
			route.to_port_id,
		])
		var has_clockwise_turn := false
		var has_counterclockwise_turn := false
		for point_index in range(1, points.size() - 1):
			var incoming := points[point_index] - points[point_index - 1]
			var outgoing := points[point_index + 1] - points[point_index]
			var turn := incoming.cross(outgoing)
			has_clockwise_turn = has_clockwise_turn or turn < -0.001
			has_counterclockwise_turn = has_counterclockwise_turn or turn > 0.001
		assert(has_clockwise_turn or has_counterclockwise_turn,
			"Sea route is visually straight: %s -> %s" % [
				route.from_port_id,
				route.to_port_id,
			])
		if has_clockwise_turn and has_counterclockwise_turn:
			s_curve_count += 1
	assert(s_curve_count >= mini(3, routes.size()),
		"The sea network needs several distinct S-curved routes.")


func _get_mission_balance_for_cost(
		mission_manager: Node,
		fleet_manager: Node,
		economy_manager: Node,
		ship_id: StringName,
		target_cost: int
) -> Dictionary:
	var origin_port_id: StringName = fleet_manager.get_ship_current_port(ship_id)
	var candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		origin_port_id,
		ship_id
	)
	assert(not candidates.is_empty())
	var ship_data: ShipData = fleet_manager.get_ship_data(ship_id)
	assert(ship_data != null)
	var minimum_gross_reward := 2147483647
	var maximum_gross_reward := 0
	var minimum_operating_cost := 2147483647
	var maximum_operating_cost := 0
	var minimum_net_reward := 2147483647
	var maximum_net_reward := 0
	for candidate in candidates:
		var gross_reward: int = economy_manager.calculate_mission_reward(
			candidate["pickup_id"],
			candidate["destination_id"],
			candidate["cargo_type"],
			1
		)
		var operating_cost: int = economy_manager.calculate_mission_operating_cost(
			origin_port_id,
			candidate["pickup_id"],
			candidate["destination_id"],
			ship_data
		)
		var net_reward := gross_reward - operating_cost
		assert(net_reward > 0)
		minimum_gross_reward = mini(minimum_gross_reward, gross_reward)
		maximum_gross_reward = maxi(maximum_gross_reward, gross_reward)
		minimum_operating_cost = mini(minimum_operating_cost, operating_cost)
		maximum_operating_cost = maxi(maximum_operating_cost, operating_cost)
		minimum_net_reward = mini(minimum_net_reward, net_reward)
		maximum_net_reward = maxi(maximum_net_reward, net_reward)
	assert(minimum_net_reward > 0)
	var best_case_count := ceili(float(target_cost) / float(maximum_net_reward))
	var worst_case_count := ceili(float(target_cost) / float(minimum_net_reward))
	return {
		"mission_range": Vector2i(best_case_count, worst_case_count),
		"gross_reward_range": Vector2i(minimum_gross_reward, maximum_gross_reward),
		"operating_cost_range": Vector2i(minimum_operating_cost, maximum_operating_cost),
		"net_reward_range": Vector2i(minimum_net_reward, maximum_net_reward),
	}


func _audit_full_network_balance(
		port_manager: Node,
		fleet_manager: Node,
		mission_manager: Node,
		economy_manager: Node
) -> void:
	var port_ids: Array[StringName] = port_manager.get_all_port_ids()
	port_ids.sort()
	var ship_models: Array[ShipData] = fleet_manager.get_purchasable_ship_models()
	var fleet_script := fleet_manager.get_script() as Script
	var fleet_constants: Dictionary = fleet_script.get_script_constant_map()
	var sailing_duration_scale := float(fleet_constants["SAILING_DURATION_SCALE"])
	var minimum_sailing_duration := float(fleet_constants["MIN_SAILING_DURATION_SEC"])
	var loading_duration := float(fleet_constants["LOADING_DURATION_SEC"])
	var unloading_duration := float(fleet_constants["UNLOADING_DURATION_SEC"])
	var route_pair_count := 0
	var scenario_count := 0
	var late_scenario_count := 0
	var minimum_net_reward := 2147483647
	var maximum_net_reward := 0
	var minimum_duration := INF
	var maximum_duration := 0.0
	var minimum_profit_per_minute := INF
	var maximum_profit_per_minute := 0.0
	var maximum_cost_ratio := 0.0

	for first_index in range(port_ids.size()):
		for second_index in range(first_index + 1, port_ids.size()):
			var pickup_id := port_ids[first_index]
			var delivery_id := port_ids[second_index]
			var distance: float = port_manager.get_distance(pickup_id, delivery_id)
			assert(distance > 0.0)
			route_pair_count += 1
			var pickup_data: PortData = port_manager.get_port_data(pickup_id)
			var delivery_data: PortData = port_manager.get_port_data(delivery_id)
			var is_late_pair := pickup_data.required_company_level >= 7 \
					or delivery_data.required_company_level >= 7
			for ship_data in ship_models:
				var cargo_types: Array = mission_manager.call(
					"_get_compatible_cargo_types",
					ship_data
				)
				assert(not cargo_types.is_empty())
				for cargo_type: CargoTypeData in cargo_types:
					for cargo_amount in range(1, maxi(ship_data.cargo_capacity, 1) + 1):
						var gross_reward: int = economy_manager.calculate_mission_reward(
							pickup_id,
							delivery_id,
							cargo_type,
							cargo_amount
						)
						var operating_cost: int = economy_manager.calculate_mission_operating_cost(
							pickup_id,
							pickup_id,
							delivery_id,
							ship_data
						)
						var net_reward := gross_reward - operating_cost
						assert(net_reward > 0)
						var sailing_speed: float = economy_manager.calculate_ship_sailing_speed(
							ship_data.base_speed,
							cargo_amount
						)
						var duration := maxf(
							distance / sailing_speed * sailing_duration_scale,
							minimum_sailing_duration
						) + loading_duration + unloading_duration
						var profit_per_minute := float(net_reward) / duration * 60.0
						var cost_ratio := float(operating_cost) / float(gross_reward)
						minimum_net_reward = mini(minimum_net_reward, net_reward)
						maximum_net_reward = maxi(maximum_net_reward, net_reward)
						minimum_duration = minf(minimum_duration, duration)
						maximum_duration = maxf(maximum_duration, duration)
						minimum_profit_per_minute = minf(
							minimum_profit_per_minute,
							profit_per_minute
						)
						maximum_profit_per_minute = maxf(
							maximum_profit_per_minute,
							profit_per_minute
						)
						maximum_cost_ratio = maxf(maximum_cost_ratio, cost_ratio)
						scenario_count += 1
						if is_late_pair:
							late_scenario_count += 1

	assert(route_pair_count == port_ids.size() * (port_ids.size() - 1) / 2)
	assert(scenario_count > 0)
	assert(late_scenario_count > 0)
	assert(maximum_cost_ratio <= 0.30)
	assert(maximum_duration > minimum_duration)
	var report_format := "FULL_NETWORK_BALANCE routes=%d scenarios=%d " \
			+ "late=%d net=%d-%d duration=%.1f-%.1fs " \
			+ "profit_per_min=%.1f-%.1f max_cost=%.1f%%"
	print(report_format % [
			route_pair_count,
			scenario_count,
			late_scenario_count,
			minimum_net_reward,
			maximum_net_reward,
			minimum_duration,
			maximum_duration,
			minimum_profit_per_minute,
			maximum_profit_per_minute,
			maximum_cost_ratio * 100.0,
		])

	for origin_id in port_ids:
		for ship_data in ship_models:
			var has_profitable_remote_offer := false
			var cargo_types: Array = mission_manager.call(
				"_get_compatible_cargo_types",
				ship_data
			)
			for pickup_id in port_ids:
				if pickup_id == origin_id:
					continue
				for delivery_id in port_ids:
					if delivery_id == pickup_id:
						continue
					for cargo_type: CargoTypeData in cargo_types:
						var gross_reward: int = economy_manager.calculate_mission_reward(
							pickup_id,
							delivery_id,
							cargo_type,
							1
						)
						var operating_cost: int = economy_manager.calculate_mission_operating_cost(
							origin_id,
							pickup_id,
							delivery_id,
							ship_data
						)
						if gross_reward > operating_cost:
							has_profitable_remote_offer = true
							break
					if has_profitable_remote_offer:
						break
				if has_profitable_remote_offer:
					break
			assert(has_profitable_remote_offer, "%s has no profitable remote offer from %s" % [
				ship_data.id,
				origin_id,
			])
