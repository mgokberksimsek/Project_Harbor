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

	assert(port_manager.get_all_port_ids().size() == 5)
	assert(port_manager.is_unlocked(&"mersin"))
	assert(port_manager.is_unlocked(&"izmir"))
	assert(not port_manager.is_unlocked(&"istanbul"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	assert(port_manager.has_sea_route(&"mersin", &"izmir"))
	assert(port_manager.has_sea_route(&"izmir", &"antalya"))
	assert(port_manager.has_sea_route(&"istanbul", &"antalya"))
	assert(port_manager.has_sea_route(&"antalya", &"samsun"))
	assert(port_manager.has_sea_route(&"mersin", &"samsun"))
	var antalya_data: PortData = port_manager.get_port_data(&"antalya")
	var samsun_data: PortData = port_manager.get_port_data(&"samsun")
	assert(antalya_data.required_company_level == 3)
	assert(antalya_data.base_unlock_cost == 1500)
	assert(antalya_data.base_company_value == 800)
	assert(samsun_data.required_company_level == 4)
	assert(samsun_data.base_unlock_cost == 2600)
	assert(samsun_data.base_company_value == 1200)
	port_manager.apply_save_state({
		"mersin": {"port_id": "mersin", "unlocked": true, "level": 1},
		"izmir": {"port_id": "izmir", "unlocked": true, "level": 1},
		"istanbul": {"port_id": "istanbul", "unlocked": false, "level": 1},
	})
	assert(port_manager.get_all_port_ids().size() == 5)
	assert(port_manager.is_registered(&"antalya"))
	assert(port_manager.is_registered(&"samsun"))
	assert(not port_manager.is_unlocked(&"antalya"))
	assert(not port_manager.is_unlocked(&"samsun"))
	world.call("_update_tutorial_instruction")
	var antalya_status := world.get_node("Ports/Antalya/StatusLabel") as Label
	assert(antalya_status.text.contains("Sv. 3"))
	assert(antalya_status.text.contains("1500"))
	assert(company_manager.company_value == 900)
	assert(company_manager.company_level == 1)
	assert(company_manager.get_next_level_threshold() == 1000)
	var headquarters := world.get_node("CompanyHeadquarters")
	assert(headquarters != null)
	assert(headquarters.get_delivery_position() != Vector2.ZERO)
	var company_label := world.get_node("UI/CompanyProgressLabel") as Label
	assert(company_label != null)
	assert(company_label.text.contains("900 / 1000 CV"))
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
	var instruction_label := world.get_node("UI/InstructionLabel") as Label
	assert(instruction_label != null)
	assert(int(game_manager.get("tutorial_step")) == 0)
	assert(instruction_label.text.contains("ÖĞRETİCİ 1/3"))
	var fleet_panel := world.get_node("UI/FleetStatusPanel")
	assert(fleet_panel != null)
	var fleet_toggle := fleet_panel.get_node("Margin/VBox/ToggleButton") as Button
	assert(not fleet_panel.is_expanded())
	assert(is_equal_approx(fleet_panel.offset_bottom - fleet_panel.offset_top, 64.0))
	assert(not fleet_panel.get_node("Margin/VBox/Body").visible)
	fleet_toggle.pressed.emit()
	assert(fleet_panel.is_expanded())
	assert(is_equal_approx(fleet_panel.offset_bottom - fleet_panel.offset_top, 330.0))
	assert(fleet_panel.get_node("Margin/VBox/Body").visible)
	fleet_toggle.pressed.emit()
	assert(not fleet_panel.is_expanded())
	var shop_panel := world.get_node("UI/ShipShopPanel") as PanelContainer
	assert(shop_panel != null)
	var shop_toggle := shop_panel.get_node("Margin/VBox/ToggleButton") as Button
	assert(not bool(shop_panel.call("is_expanded")))
	assert(is_equal_approx(shop_panel.offset_bottom - shop_panel.offset_top, 64.0))
	shop_toggle.pressed.emit()
	assert(bool(shop_panel.call("is_expanded")))
	assert(is_equal_approx(shop_panel.offset_bottom - shop_panel.offset_top, 215.0))
	assert(shop_panel.get_node("Margin/VBox/Body").visible)
	shop_toggle.pressed.emit()
	assert(not bool(shop_panel.call("is_expanded")))
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
	var starter_map_ship: Area2D = fleet_manager.get_ship_node(&"starter_ship") as Area2D
	var mersin_map_port: Area2D = port_manager.get_port_node(&"mersin") as Area2D
	assert(starter_map_ship != null)
	assert(starter_map_ship.global_position.is_equal_approx(
		headquarters.get_delivery_position()
	))
	var starter_icon := starter_map_ship.get_node("Icon") as Sprite2D
	assert(starter_icon != null)
	var starter_selection_outline := starter_icon.get_node("SelectionOutline") as Sprite2D
	assert(starter_selection_outline != null)
	assert(not starter_selection_outline.visible)
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
	assert(fleet_manager.get_ship_dock_slot_index(&"starter_ship") == 0)
	assert(fleet_manager.get_ship_dock_position(&"starter_ship") != mersin_map_port.global_position)
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
	assert(world.get("_selected_ship_id") == &"starter_ship")
	assert(starter_selection_outline.visible)

	# Re-registering a ship (as scene reload does after New Game) must rebuild offers.
	mission_manager.reset_state()
	var starter_node: Node2D = fleet_manager.get_ship_node(&"starter_ship")
	var starter_data: ShipData = fleet_manager.get_ship_data(&"starter_ship")
	fleet_manager.register_ship(&"starter_ship", starter_data, &"mersin", starter_node)
	await process_frame
	assert(not mission_manager.get_offers().is_empty())

	await process_frame

	var offers: Array = mission_manager.get_offers()
	assert(offers.size() == 3)
	var starter_ship_data: ShipData = fleet_manager.get_ship_data(&"starter_ship")
	var food_cargo: CargoTypeData = mission_manager.get_cargo_type(&"food")
	assert(starter_ship_data != null)
	assert(food_cargo != null)
	assert(not starter_ship_data.can_carry(food_cargo))
	var has_local_pickup_offer := false
	var has_remote_pickup_offer := false
	for offer in offers:
		assert(offer.offered_ship_id == &"starter_ship")
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
	assert(has_local_pickup_offer)
	assert(has_remote_pickup_offer)

	event_bus.ship_tapped.emit(&"starter_ship")
	await process_frame
	assert(int(game_manager.get("tutorial_step")) == 1)
	assert(instruction_label.text.contains("ÖĞRETİCİ 2/3"))
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
	event_bus.port_tapped.emit(first_offer.pickup_port_id)
	await process_frame
	assert(int(game_manager.get("tutorial_step")) == 2)
	assert(instruction_label.text.contains("ÖĞRETİCİ 3/3"))
	var pickup_icon := pickup_node.get_node("Icon") as Sprite2D
	var pickup_highlight := pickup_icon.get_node("SelectionOutline") as Sprite2D
	assert(pickup_highlight != null)
	assert(pickup_highlight.visible)
	assert(world.get_node("UI/MissionOfferPanel").visible)

	world.call("_on_offer_accepted", first_offer.id)
	await process_frame
	assert(game_manager.is_tutorial_completed())
	assert(instruction_label.text.contains("ÖĞRETİCİ TAMAMLANDI"))
	assert(not pickup_highlight.visible)
	assert(starter_selection_outline.visible)
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
	assert(fleet_manager.get_ship_mission_remaining_sec(&"starter_ship") > 0.0)
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
	assert(fleet_manager.get_ship_state(&"starter_ship") == ShipRuntimeState.State.LOADING)
	assert(fleet_manager.get_ship_dock_slot_index(&"starter_ship") == -1)
	assert(starter_map_ship.global_position.is_equal_approx(pickup_port_node.global_position))
	while fleet_manager.get_ship_state(&"starter_ship") \
			!= ShipRuntimeState.State.SAILING_TO_DELIVERY \
			and delivery_state_safety < 3:
		mission.leg_duration_sec = 0.0
		await process_frame
		delivery_state_safety += 1
	assert(fleet_manager.get_ship_state(&"starter_ship") \
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

	var refrigerated_model: ShipData = fleet_manager.get_ship_model(&"refrigerated_freighter")
	assert(refrigerated_model != null)
	assert(refrigerated_model.purchase_cost == 800)
	assert(refrigerated_model.can_carry(food_cargo))
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 0)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 800)
	game_manager.add_money(800)
	assert(game_manager.try_purchase_ship(&"refrigerated_freighter", &"mersin"))
	await process_frame
	assert(game_manager.money == 0)
	assert(fleet_manager.get_all_ship_ids().size() == 2)
	assert(fleet_manager.get_owned_model_count(&"refrigerated_freighter") == 1)
	assert(fleet_manager.get_ship_purchase_price(&"refrigerated_freighter") == 1280)
	assert(company_manager.company_value == 2600)
	assert(company_manager.company_level == 3)
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
		if ship_id == &"starter_ship":
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
	var expansion_candidates: Array = mission_manager.call(
		"_build_offer_candidates",
		&"izmir",
		&"starter_ship"
	)
	var has_antalya_candidate := false
	for candidate in expansion_candidates:
		has_antalya_candidate = has_antalya_candidate \
			or candidate["pickup_id"] == &"antalya" \
			or candidate["destination_id"] == &"antalya"
	assert(has_antalya_candidate)

	var starter_speed_before: float = fleet_manager.get_ship_effective_speed(&"starter_ship")
	var company_value_before_speed_upgrade: int = company_manager.company_value
	var starter_upgrade_cost: int = fleet_manager.get_ship_speed_upgrade_cost(&"starter_ship")
	assert(starter_upgrade_cost > 0)
	game_manager.add_money(starter_upgrade_cost)
	assert(game_manager.try_upgrade_ship_speed(&"starter_ship"))
	assert(game_manager.money == 0)
	assert(fleet_manager.get_ship_speed_level(&"starter_ship") == 1)
	assert(is_equal_approx(
		fleet_manager.get_ship_effective_speed(&"starter_ship"),
		starter_speed_before * 1.15
	))
	assert(company_manager.company_value == company_value_before_speed_upgrade + 100)
	var starter_capacity_upgrade_cost: int = fleet_manager.get_ship_capacity_upgrade_cost(&"starter_ship")
	var company_value_before_capacity_upgrade: int = company_manager.company_value
	assert(starter_capacity_upgrade_cost > 0)
	game_manager.add_money(starter_capacity_upgrade_cost)
	assert(game_manager.try_upgrade_ship_capacity(&"starter_ship"))
	assert(game_manager.money == 0)
	assert(fleet_manager.get_ship_capacity_level(&"starter_ship") == 1)
	assert(fleet_manager.get_ship_effective_capacity(&"starter_ship") == 2)
	assert(company_manager.company_value == company_value_before_capacity_upgrade + 120)
	await process_frame

	mission_manager.refresh_offers()
	var multi_ship_offers: Array = mission_manager.get_offers()
	assert(multi_ship_offers.size() >= 2)
	var offered_ship_ids: Array[StringName] = []
	for offer in multi_ship_offers:
		if not offered_ship_ids.has(offer.offered_ship_id):
			offered_ship_ids.append(offer.offered_ship_id)
	assert(offered_ship_ids.size() == 2)

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
	assert(fleet_manager.get_idle_ship_ids().size() == 2)
	assert(fleet_manager.get_ship_speed_level(&"starter_ship") == 1)
	assert(fleet_manager.get_ship_capacity_level(&"starter_ship") == 1)
	assert(company_manager.company_value == saved_company_value)
	assert(company_manager.company_level == saved_company_level)
	assert(company_manager.peak_company_value >= company_manager.company_value)
	assert(game_manager.is_tutorial_completed())

	var starter_max_speed_level := starter_ship_data.max_speed_level
	while fleet_manager.get_ship_speed_level(&"starter_ship") < starter_max_speed_level:
		assert(fleet_manager.upgrade_ship_speed(&"starter_ship"))
	assert(fleet_manager.get_ship_speed_level(&"starter_ship") == starter_max_speed_level)
	assert(fleet_manager.get_ship_speed_upgrade_cost(&"starter_ship") == -1)
	assert(not fleet_manager.upgrade_ship_speed(&"starter_ship"))

	var starter_max_capacity_level := starter_ship_data.max_capacity_level
	while fleet_manager.get_ship_capacity_level(&"starter_ship") < starter_max_capacity_level:
		assert(fleet_manager.upgrade_ship_capacity(&"starter_ship"))
	assert(fleet_manager.get_ship_capacity_level(&"starter_ship") == starter_max_capacity_level)
	assert(fleet_manager.get_ship_capacity_upgrade_cost(&"starter_ship") == -1)
	assert(not fleet_manager.upgrade_ship_capacity(&"starter_ship"))

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
	assert(int(game_manager.get("tutorial_step")) == 0)
	print("SMOKE_TEST_OK reward=%d" % mission.reward)
	quit(0)


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
