extends SceneTree
## Headless smoke test for the first playable architecture slice.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var timing_probe := Mission.new()
	timing_probe.start_leg(10.0, 1000.25)
	assert(is_equal_approx(timing_probe.get_leg_progress_at(1000.75), 0.05))
	var legacy_ship_state := ShipRuntimeState.from_dict({
		"ship_id": "legacy_ship",
		"current_port_id": "mersin",
	})
	assert(legacy_ship_state.dock_port_id == &"mersin")
	assert(legacy_ship_state.dock_slot_index == -1)

	var port_manager := root.get_node("/root/PortManager")
	var fleet_manager := root.get_node("/root/FleetManager")
	var mission_manager := root.get_node("/root/MissionManager")
	var economy_manager := root.get_node("/root/EconomyManager")
	var company_manager := root.get_node("/root/CompanyManager")
	var settings_manager := root.get_node("/root/SettingsManager")
	var game_manager := root.get_node("/root/GameManager")
	var save_manager := root.get_node("/root/SaveManager")
	var event_bus := root.get_node("/root/EventBus")
	var test_save_path := "user://smoke_test_save.json"
	assert(save_manager.delete_save(test_save_path))
	assert(not save_manager.loaded_existing_save)

	var world_scene := load("res://Scenes/world.tscn") as PackedScene
	assert(world_scene != null)
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	assert(port_manager.get_all_port_ids().size() == 7)
	assert(port_manager.is_unlocked(&"mersin"))
	assert(port_manager.is_unlocked(&"izmir"))
	assert(not port_manager.is_unlocked(&"istanbul"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	assert(not port_manager.is_unlocked(&"canakkale"))
	assert(not port_manager.is_unlocked(&"trabzon"))
	assert(port_manager.has_sea_route(&"mersin", &"izmir"))
	assert(port_manager.has_sea_route(&"izmir", &"antalya"))
	assert(port_manager.has_sea_route(&"istanbul", &"antalya"))
	assert(port_manager.has_sea_route(&"antalya", &"samsun"))
	assert(port_manager.has_sea_route(&"mersin", &"samsun"))
	assert(port_manager.has_sea_route(&"izmir", &"canakkale"))
	assert(port_manager.has_sea_route(&"canakkale", &"istanbul"))
	assert(port_manager.has_sea_route(&"samsun", &"trabzon"))
	assert(port_manager.has_sea_route(&"antalya", &"trabzon"))
	_assert_port_centers_are_spaced(port_manager, 320.0)
	var antalya_data: PortData = port_manager.get_port_data(&"antalya")
	var samsun_data: PortData = port_manager.get_port_data(&"samsun")
	var canakkale_data: PortData = port_manager.get_port_data(&"canakkale")
	var trabzon_data: PortData = port_manager.get_port_data(&"trabzon")
	assert(antalya_data.required_company_level == 3)
	assert(antalya_data.base_unlock_cost == 1500)
	assert(antalya_data.base_company_value == 800)
	assert(samsun_data.required_company_level == 4)
	assert(samsun_data.base_unlock_cost == 2600)
	assert(samsun_data.base_company_value == 1200)
	assert(canakkale_data.required_company_level == 5)
	assert(canakkale_data.base_unlock_cost == 4200)
	assert(canakkale_data.base_company_value == 2000)
	assert(trabzon_data.required_company_level == 6)
	assert(trabzon_data.base_unlock_cost == 6500)
	assert(trabzon_data.base_company_value == 3000)
	port_manager.apply_save_state({
		"mersin": {"port_id": "mersin", "unlocked": true, "level": 1},
		"izmir": {"port_id": "izmir", "unlocked": true, "level": 1},
		"istanbul": {"port_id": "istanbul", "unlocked": false, "level": 1},
	})
	assert(port_manager.get_all_port_ids().size() == 7)
	assert(port_manager.is_registered(&"antalya"))
	assert(port_manager.is_registered(&"samsun"))
	assert(port_manager.is_registered(&"canakkale"))
	assert(port_manager.is_registered(&"trabzon"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	assert(not port_manager.is_unlocked(&"canakkale"))
	assert(not port_manager.is_unlocked(&"trabzon"))
	world.call("_update_tutorial_instruction")
	var antalya_status := world.get_node("Ports/Antalya/StatusLabel") as Label
	assert(antalya_status.text.contains("Sv. 3"))
	assert(antalya_status.text.contains("1500"))
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
	assert(paused)
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
	language_select.item_selected.emit(0)
	assert(settings_manager.locale == "tr")
	settings_menu.close_menu()
	assert(not settings_menu.is_open())
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
	var shop_panel := world.get_node("UI/ShipShopPanel")
	assert(shop_panel != null)
	assert(shop_panel.is_tutorial_focused())
	assert(not shop_panel.is_expanded())
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
	var shop_toggle := shop_panel.get_node("Margin/VBox/ToggleButton") as Button
	assert(not shop_toggle.disabled)
	shop_toggle.pressed.emit()
	await process_frame
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
	assert(int(game_manager.get("tutorial_step")) == 5)
	assert(instruction_label.text.contains("ÖĞRETİCİ 3/8"))
	assert(not shop_panel.is_tutorial_focused())
	assert(not shop_panel.is_expanded())
	assert(shop_toggle.disabled)
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
	var first_port_pacing := _get_mission_count_range_for_cost(
		mission_manager,
		fleet_manager,
		economy_manager,
		starter_ship_id,
		750
	)
	assert(first_port_pacing.x >= 3)
	assert(first_port_pacing.y <= 4)
	var fleet_panel := world.get_node("UI/FleetStatusPanel")
	assert(fleet_panel != null)
	var fleet_scroll := fleet_panel.get_node("Margin/VBox/Body/Scroll") as ScrollContainer
	assert(fleet_scroll != null)
	assert(fleet_scroll.scroll_deadzone == 18)
	var settings_button := settings_menu.get_node("SettingsButton") as Button
	assert(not fleet_panel.get_global_rect().intersects(settings_button.get_global_rect()))
	var fleet_toggle := fleet_panel.get_node("Margin/VBox/ToggleButton") as Button
	assert(not fleet_panel.is_expanded())
	assert(is_equal_approx(fleet_panel.offset_bottom - fleet_panel.offset_top, 56.0))
	assert(not fleet_panel.get_node("Margin/VBox/Body").visible)
	fleet_toggle.pressed.emit()
	assert(fleet_panel.is_expanded())
	assert(is_equal_approx(fleet_panel.offset_bottom - fleet_panel.offset_top, 290.0))
	assert(fleet_panel.get_node("Margin/VBox/Body").visible)
	fleet_toggle.pressed.emit()
	assert(not fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
	assert(is_equal_approx(shop_panel.offset_bottom - shop_panel.offset_top, 56.0))
	shop_toggle.pressed.emit()
	assert(shop_panel.is_expanded())
	assert(is_equal_approx(shop_panel.offset_bottom - shop_panel.offset_top, 230.0))
	assert(shop_panel.get_node("Margin/VBox/Body").visible)
	shop_toggle.pressed.emit()
	assert(not shop_panel.is_expanded())
	fleet_toggle.pressed.emit()
	shop_toggle.pressed.emit()
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
	assert(fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
	assert(world.get("_selected_ship_id") == &"selection_probe")
	world.set("_selected_ship_id", &"")
	shop_toggle.pressed.emit()
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
	assert(fleet_panel.is_expanded())
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
	assert(fleet_panel.is_expanded())
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
	assert(not fleet_panel.is_expanded())
	assert(not shop_panel.is_expanded())
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
	assert(forward_route.size() == 4)
	assert(smooth_route.size() > forward_route.size())
	assert(s_curve_route.size() == 6)
	assert(expansion_route.size() == 7)
	_assert_all_sea_routes_avoid_land(port_manager, world)
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
	assert(starter_map_ship.global_position.distance_to(
		headquarters.get_delivery_position()
	) < 40.0)
	assert(bool(starter_map_ship.get("_dock_transition_active")))
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
	starter_route_line.set_route(smooth_route, 0.0, true)
	var full_route_length := starter_route_line.get_remaining_length()
	starter_route_line.set_route(smooth_route, 0.5, true)
	assert(starter_route_line.get_remaining_length() < full_route_length)
	starter_route_line.clear_route()
	assert(port_manager.get_port_data(&"mersin").dock_slot_offsets.size() == 6)
	assert(fleet_manager.get_ship_dock_slot_index(starter_ship_id) == 0)
	assert(fleet_manager.get_ship_dock_position(starter_ship_id) != mersin_map_port.global_position)
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
	var food_cargo: CargoTypeData = mission_manager.get_cargo_type(&"food")
	var grain_cargo: CargoTypeData = mission_manager.get_cargo_type(&"grain")
	assert(starter_ship_data != null)
	assert(food_cargo != null)
	assert(grain_cargo != null)
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
		assert(port_manager.has_sea_route(offer.pickup_port_id, offer.delivery_port_id))
		if offer.pickup_port_id == &"mersin":
			has_local_pickup_offer = true
			assert(is_equal_approx(offer.loading_duration_sec, 1.7))
		else:
			has_remote_pickup_offer = true
			assert(is_equal_approx(offer.loading_duration_sec, 1.7))
		assert(offer.estimated_duration_sec > 0.0)
		assert(offer.duration_class == Mission.DurationClass.SHORT)
		assert(offer.reward > 0)
		assert(offer.cargo_amount == 1)
		var offered_cargo: CargoTypeData = mission_manager.get_cargo_type(offer.cargo_type_id)
		assert(starter_ship_data.can_carry(offered_cargo))
		assert(offer.cargo_type_id != &"food")
		assert(offer.cargo_type_id != &"grain")
	assert(has_local_pickup_offer)
	assert(has_remote_pickup_offer)
	var local_offer: Mission = null
	for offer in offers:
		if offer.pickup_port_id == offer.origin_port_id:
			local_offer = offer
			break
	assert(local_offer != null)
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

	world.call("_on_offer_accepted", first_offer.id)
	await process_frame
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
	assert(next_goal_label.text.contains("İstanbul"))
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
	assert(world.get_node("UI/FleetStatusPanel") is FleetStatusPanel)
	var delivery_state_safety := 0
	mission.leg_duration_sec = 0.0
	await process_frame
	assert(fleet_manager.get_ship_state(starter_ship_id) == ShipRuntimeState.State.LOADING)
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

	for _step in range(5):
		if mission.stage == Mission.Stage.COMPLETED:
			break
		mission.leg_duration_sec = 0.0
		await process_frame
		await process_frame

	assert(mission.stage == Mission.Stage.COMPLETED)
	assert(game_manager.money == mission.reward)
	await process_frame
	assert(next_goal_label.text.contains("%d / 750" % mission.reward))
	assert(mission_manager.get_offers().size() == 3)
	assert(not game_manager.try_unlock_port(&"istanbul"))
	assert(not port_manager.is_unlocked(&"istanbul"))

	event_bus.port_tapped.emit(&"istanbul")
	await process_frame
	assert(not port_manager.is_unlocked(&"istanbul"))
	assert(port_unlock_panel.visible)
	assert(port_unlock_panel.is_open_for(&"istanbul"))
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
	assert(port_manager.is_unlocked(&"istanbul"))
	assert(not port_unlock_panel.visible)
	assert(game_manager.money == 0)
	assert(company_manager.company_value == 1400)
	assert(company_manager.company_level == 2)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Soğutmalı"))
	assert(next_goal_label.text.contains("0 / 800"))
	var second_ship_pacing := _get_mission_count_range_for_cost(
		mission_manager,
		fleet_manager,
		economy_manager,
		starter_ship_id,
		800
	)
	assert(second_ship_pacing.x >= 3)
	assert(second_ship_pacing.y <= 4)
	print("EARLY_GAME_BALANCE first_port=%d-%d second_ship=%d-%d missions" % [
		first_port_pacing.x,
		first_port_pacing.y,
		second_ship_pacing.x,
		second_ship_pacing.y,
	])

	var refrigerated_model: ShipData = fleet_manager.get_ship_model(&"refrigerated_freighter")
	assert(refrigerated_model != null)
	assert(refrigerated_model.purchase_cost == 800)
	assert(refrigerated_model.can_carry(food_cargo))
	assert(not refrigerated_model.can_carry(grain_cargo))
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 0)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 800)
	game_manager.add_money(800)
	assert(game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	await process_frame
	assert(game_manager.money == 0)
	assert(fleet_manager.get_all_ship_ids().size() == 2)
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 1)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 1280)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Antalya"))
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
		"UI/ShipShopPanel/Margin/VBox/Body/BuyButton"
	) as Button
	assert(shop_buy_button != null)
	shop_buy_button.text = "Satın Al · 800 ₺"
	event_bus.game_loaded.emit()
	await process_frame
	assert(shop_buy_button.text.contains("1280"))
	assert(shop_buy_button.disabled == (game_manager.money < 1280))

	var refrigerated_ship_found := false
	for ship_id in fleet_manager.get_all_ship_ids():
		if ship_id == starter_ship_id:
			continue
		var purchased_data: ShipData = fleet_manager.get_ship_data(ship_id)
		assert(purchased_data != null)
		assert(purchased_data.can_carry(food_cargo))
		var purchased_ship := fleet_manager.get_ship_node(ship_id) as Node2D
		assert(purchased_ship != null)
		assert(bool(purchased_ship.get("_dock_transition_active")))
		assert(purchased_ship.global_position.distance_to(
			headquarters.get_delivery_position()
		) < 40.0)
		refrigerated_ship_found = true
	assert(refrigerated_ship_found)
	assert(not game_manager.try_unlock_port(&"samsun"))
	assert(not port_manager.is_unlocked(&"samsun"))
	event_bus.port_tapped.emit(&"samsun")
	await process_frame
	assert(port_unlock_panel.is_open_for(&"samsun"))
	assert(port_unlock_button.disabled)
	assert(port_unlock_button.text.contains("Sv. 4"))
	port_unlock_panel.close_panel()
	game_manager.add_money(1500)
	assert(game_manager.try_unlock_port(&"antalya"))
	assert(game_manager.money == 0)
	assert(port_manager.is_unlocked(&"antalya"))
	assert(antalya_status.text == "Sv. 1")
	assert(company_manager.company_value == 3400)
	assert(company_manager.company_level == 3)
	assert(next_goal_label.visible)
	assert(next_goal_label.text.contains("Dökme"))
	assert(next_goal_label.text.contains("0 / 1500"))
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
	game_manager.add_money(1500)
	assert(not tutorial_buy_button.disabled)
	tutorial_buy_button.pressed.emit()
	await process_frame
	await process_frame
	assert(fleet_manager.get_owned_model_count(&"bulk_carrier") == 1)
	assert(fleet_manager.get_all_ship_ids().size() == 3)
	assert(game_manager.money == 0)
	assert(company_manager.company_value == 4800)
	assert(company_manager.company_level == 4)
	assert(next_goal_label.text.contains("Samsun"))
	assert(next_goal_label.text.contains("0 / 2600"))
	var bulk_ship_id: StringName = &""
	for ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.get_ship_data(ship_id).id == &"bulk_carrier":
			bulk_ship_id = ship_id
			break
	assert(bulk_ship_id != &"")
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
	var has_antalya_candidate := false
	for candidate in expansion_candidates:
		has_antalya_candidate = has_antalya_candidate \
			or candidate["pickup_id"] == &"antalya" \
			or candidate["destination_id"] == &"antalya"
	assert(has_antalya_candidate)
	game_manager.add_money(samsun_data.base_unlock_cost)
	assert(game_manager.try_unlock_port(&"samsun"))
	await process_frame
	assert(company_manager.company_value == 6000)
	assert(company_manager.company_level == 4)
	assert(next_goal_label.text.contains("Çanakkale"))
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

	var first_multi_offer: Mission = multi_ship_offers[0]
	assert(mission_manager.accept_offer(first_multi_offer.id))
	await process_frame
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
	for active_mission in mission_manager.get_active_missions():
		expected_offline_reward += active_mission.reward
		var fleet_mission: Mission = fleet_manager.get_ship_mission(active_mission.assigned_ship_id)
		fleet_mission.leg_start_unix = Time.get_unix_time_from_system() - 100
	var saved_company_value: int = company_manager.company_value
	var saved_company_level: int = company_manager.company_level
	assert(save_manager.save_game(test_save_path))
	game_manager.add_money(999)
	assert(save_manager.load_game(test_save_path))
	await process_frame
	assert(save_manager.loaded_existing_save)
	assert(game_manager.money == expected_offline_reward)
	assert(mission_manager.get_active_missions().is_empty())
	assert(fleet_manager.get_idle_ship_ids().size() == fleet_manager.get_all_ship_ids().size())
	assert(fleet_manager.get_ship_speed_level(starter_ship_id) == 1)
	assert(fleet_manager.get_ship_capacity_level(starter_ship_id) == 1)
	assert(company_manager.company_value == saved_company_value)
	assert(company_manager.company_level == saved_company_level)
	assert(company_manager.peak_company_value >= company_manager.company_value)
	assert(game_manager.is_tutorial_completed())

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
	fleet_panel.set_expanded(true)
	await process_frame
	var fleet_scroll_bar := fleet_scroll.get_v_scroll_bar()
	assert(fleet_scroll_bar.max_value > fleet_scroll_bar.page)
	var fleet_cards: Dictionary = fleet_panel.get("_cards")
	for fleet_card in fleet_cards.values():
		for button_key in ["button", "upgrade_button", "capacity_button"]:
			var card_button: Button = fleet_card[button_key]
			assert(card_button.focus_mode == Control.FOCUS_NONE)
			assert(card_button.mouse_filter == Control.MOUSE_FILTER_PASS)
	var occupied_mersin_slots: Array[int] = []
	for docked_ship_id in fleet_manager.get_all_ship_ids():
		if fleet_manager.get_ship_current_port(docked_ship_id) != &"mersin":
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
		if fleet_manager.get_ship_current_port(docked_ship_id) != &"mersin":
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
	print("SMOKE_TEST_OK reward=%d" % mission.reward)
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


func _assert_all_sea_routes_avoid_land(port_manager: Node, world: Node2D) -> void:
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
		var route_points: PackedVector2Array = port_manager.call(
			"get_smoothed_route_points",
			route.from_port_id,
			route.to_port_id
		)
		assert(route_points.size() >= 2, "Sea route has fewer than two points: %s -> %s" % [
			route.from_port_id,
			route.to_port_id,
		])
		for segment_index in range(route_points.size() - 1):
			var segment_start := route_points[segment_index]
			var segment_end := route_points[segment_index + 1]
			var sample_count := maxi(
				ceili(segment_start.distance_to(segment_end) / ROUTE_SAMPLE_SPACING_PX),
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
					), "Sea route %s -> %s enters land '%s' near %s." % [
						route.from_port_id,
						route.to_port_id,
						land_entry["name"],
						sample_point,
					])


func _get_mission_count_range_for_cost(
		mission_manager: Node,
		fleet_manager: Node,
		economy_manager: Node,
		ship_id: StringName,
		target_cost: int
) -> Vector2i:
	var origin_port_id: StringName = fleet_manager.get_ship_current_port(ship_id)
	var candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		origin_port_id,
		ship_id
	)
	assert(not candidates.is_empty())
	var minimum_reward := 2147483647
	var maximum_reward := 0
	for candidate in candidates:
		var reward: int = economy_manager.calculate_mission_reward(
			candidate["pickup_id"],
			candidate["destination_id"],
			candidate["cargo_type"],
			1
		)
		minimum_reward = mini(minimum_reward, reward)
		maximum_reward = maxi(maximum_reward, reward)
	assert(minimum_reward > 0)
	var best_case_count := ceili(float(target_cost) / float(maximum_reward))
	var worst_case_count := ceili(float(target_cost) / float(minimum_reward))
	return Vector2i(best_case_count, worst_case_count)
