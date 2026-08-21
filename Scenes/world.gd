extends Node2D

@onready var _money_label: Label = $UI/MoneyLabel
@onready var _company_progress_label: Button = $UI/CompanyProgressLabel
@onready var _debug_level_up_button: Button = $UI/DebugLevelUpButton
@onready var _next_goal_label: Label = $UI/NextGoalLabel
@onready var _instruction_label: Label = $UI/InstructionLabel
@onready var _mission_offer_panel: MissionOfferPanel = $UI/MissionOfferPanel
@onready var _fleet_status_panel: FleetStatusPanel = $UI/FleetStatusPanel
@onready var _ship_shop_panel = $UI/ShipShopPanel
@onready var _port_unlock_panel: PortUnlockPanel = $UI/PortUnlockPanel
@onready var _company_progress_panel: CompanyProgressPanel = $UI/CompanyProgressPanel
@onready var _settings_menu: SettingsMenu = $UI/SettingsMenu
@onready var _world_camera: WorldCamera = $Camera2D
@onready var _company_headquarters: CompanyHeadquarters = $CompanyHeadquarters

var _selected_ship_id: StringName = &""
var _open_mission_port_id: StringName = &""
var _mission_offers: Array[Mission] = []
var _fleet_refresh_elapsed := 0.0

const MAP_SHIP_TAP_RADIUS_PX := 48.0
const MAP_PORT_TAP_RADIUS_PX := 48.0


func _input(event: InputEvent) -> void:
	var screen_position := Vector2.ZERO
	var is_pointer_press := false
	if event is InputEventMouseButton:
		is_pointer_press = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		screen_position = event.position
	elif event is InputEventScreenTouch:
		is_pointer_press = event.pressed
		screen_position = event.position
	if not is_pointer_press or _is_ui_at_screen_position(screen_position):
		return
	if try_select_ship_at_screen_position(screen_position):
		get_viewport().set_input_as_handled()
		return
	if _is_port_at_screen_position(screen_position):
		return
	clear_map_selection()


func try_select_ship_at_screen_position(screen_position: Vector2) -> bool:
	var canvas_transform := get_viewport().get_canvas_transform()
	var nearest_ship_id: StringName = &""
	var nearest_distance_squared := MAP_SHIP_TAP_RADIUS_PX * MAP_SHIP_TAP_RADIUS_PX
	for ship_id in FleetManager.get_all_ship_ids():
		var ship_node := FleetManager.get_ship_node(ship_id) as Ship
		if ship_node == null or not ship_node.is_visible_in_tree():
			continue
		var ship_screen_position := canvas_transform * ship_node.global_position
		var distance_squared := screen_position.distance_squared_to(ship_screen_position)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_ship_id = ship_id
	if nearest_ship_id == &"":
		return false
	EventBus.ship_tapped.emit(nearest_ship_id)
	return true


func _is_port_at_screen_position(screen_position: Vector2) -> bool:
	var canvas_transform := get_viewport().get_canvas_transform()
	var maximum_distance_squared := MAP_PORT_TAP_RADIUS_PX * MAP_PORT_TAP_RADIUS_PX
	for port_id in PortManager.get_all_port_ids():
		var port_node := PortManager.get_port_node(port_id)
		if port_node == null or not port_node.is_visible_in_tree():
			continue
		var port_screen_position := canvas_transform * port_node.global_position
		if screen_position.distance_squared_to(port_screen_position) <= maximum_distance_squared:
			return true
	return false


func clear_map_selection() -> void:
	_selected_ship_id = &""
	_open_mission_port_id = &""
	EventBus.ship_selection_changed.emit(&"")
	EventBus.port_selection_changed.emit(&"")
	_mission_offer_panel.close_panel()
	_port_unlock_panel.close_panel()
	_company_progress_panel.close_panel()
	_fleet_status_panel.select_ship(&"")
	_refresh_fleet_panel()
	_update_mission_markers()
	if not _update_tutorial_instruction():
		_instruction_label.text = tr("INSTRUCTION_SELECT_SHIP")


func _is_ui_at_screen_position(screen_position: Vector2) -> bool:
	for candidate in $UI.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control != null and control.is_visible_in_tree() \
				and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.get_global_rect().has_point(screen_position):
			return true
	return false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#256BB8"))
	# Ships and ports can occupy the same dock position. Sorted, first-only
	# picking guarantees that the higher-z ship receives the tap.
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.company_value_changed.connect(_on_company_value_changed)
	EventBus.company_level_changed.connect(_on_company_level_changed)
	EventBus.company_level_requirement_failed.connect(
		_on_company_level_requirement_failed
	)
	EventBus.mission_offers_updated.connect(_on_mission_offers_updated)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_unlock_failed.connect(_on_port_unlock_failed)
	EventBus.port_tapped.connect(_on_port_tapped)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_tapped.connect(_on_ship_tapped)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	EventBus.ship_upgrade_failed.connect(_on_ship_upgrade_failed)
	EventBus.fleet_capacity_reached.connect(_on_fleet_capacity_reached)
	EventBus.language_changed.connect(_on_language_changed)
	EventBus.tutorial_step_changed.connect(_on_tutorial_step_changed)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.offline_progress_applied.connect(_on_offline_progress_applied)
	_mission_offer_panel.offer_accepted.connect(_on_offer_accepted)
	_mission_offer_panel.dismissed.connect(_on_mission_panel_dismissed)
	_fleet_status_panel.ship_selected.connect(_on_fleet_ship_selected)
	_fleet_status_panel.speed_upgrade_requested.connect(_on_speed_upgrade_requested)
	_fleet_status_panel.capacity_upgrade_requested.connect(_on_capacity_upgrade_requested)
	_port_unlock_panel.unlock_requested.connect(_on_port_unlock_requested)
	_port_unlock_panel.closed.connect(_on_port_unlock_panel_closed)
	_company_progress_label.pressed.connect(_on_company_progress_pressed)
	_debug_level_up_button.pressed.connect(_on_debug_level_up_pressed)
	_settings_menu.menu_opened.connect(_on_settings_opened)
	_settings_menu.resumed.connect(_on_settings_resumed)
	_settings_menu.sound_effects_toggled.connect(SettingsManager.set_sound_effects_enabled)
	_settings_menu.music_toggled.connect(SettingsManager.set_music_enabled)
	_settings_menu.locale_selected.connect(SettingsManager.set_locale)
	_settings_menu.new_game_confirmed.connect(_on_new_game_confirmed)
	_settings_menu.set_preferences(
		SettingsManager.sound_effects_enabled,
		SettingsManager.music_enabled,
		SettingsManager.locale
	)

	_update_money(GameManager.money)
	_update_company_progress()
	_update_debug_level_button()
	_update_next_goal()
	if not _update_tutorial_instruction():
		_instruction_label.text = tr("INSTRUCTION_SELECT_SHIP_LONG")
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()


func _process(delta: float) -> void:
	_fleet_refresh_elapsed += delta
	if _fleet_refresh_elapsed < 0.25:
		return
	_fleet_refresh_elapsed = 0.0
	_refresh_fleet_panel()


func _on_money_changed(new_amount: int, _delta: int) -> void:
	_update_money(new_amount)
	_port_unlock_panel.update_status(new_amount, CompanyManager.company_level)
	_update_next_goal()


func _on_company_value_changed(_new_value: int, _delta: int) -> void:
	_update_company_progress()
	_update_next_goal()
	if _company_progress_panel.is_open():
		_show_company_progress_panel()


func _on_tutorial_step_changed(_new_step: int, _previous_step: int) -> void:
	_update_tutorial_instruction()
	_update_tutorial_focus()
	_update_next_goal()


func _on_language_changed(_locale: String) -> void:
	_update_company_progress()
	_update_debug_level_button()
	_update_next_goal()
	_refresh_fleet_panel()
	if _company_progress_panel.is_open():
		_show_company_progress_panel()
	if _open_mission_port_id != &"":
		_show_port_offers(_open_mission_port_id)
	if not _update_tutorial_instruction():
		_refresh_context_instruction()


func _on_settings_opened() -> void:
	get_tree().paused = true


func _on_settings_resumed() -> void:
	get_tree().paused = false


func _on_new_game_confirmed() -> void:
	get_tree().paused = false
	SaveManager.reset_game()


func _on_company_level_changed(new_level: int, previous_level: int) -> void:
	_update_company_progress()
	_update_debug_level_button()
	_update_next_goal()
	_port_unlock_panel.update_status(GameManager.money, new_level)
	if _company_progress_panel.is_open():
		_show_company_progress_panel()
	if new_level > previous_level:
		_instruction_label.text = tr("INSTRUCTION_LEVEL_UP") % new_level


func _on_debug_level_up_pressed() -> void:
	CompanyManager.debug_advance_level()
	_update_debug_level_button()


func _update_debug_level_button() -> void:
	_debug_level_up_button.text = tr("DEBUG_LEVEL_UP") % CompanyManager.company_level
	_debug_level_up_button.disabled = (
		CompanyManager.company_level >= CompanyManager.get_max_level()
	)


func _on_company_level_requirement_failed(
		_content_type: StringName,
		_content_id: StringName,
		required_level: int,
		current_level: int
) -> void:
	_instruction_label.text = tr("INSTRUCTION_LEVEL_REQUIRED") % [
		required_level,
		current_level,
	]


func _on_mission_offers_updated(offers: Array) -> void:
	_mission_offers.clear()
	for offer in offers:
		if offer is Mission:
			_mission_offers.append(offer)
	_update_mission_markers()
	_update_tutorial_focus()
	if _open_mission_port_id != &"":
		_show_port_offers(_open_mission_port_id)


func _on_offer_accepted(offer_id: String) -> void:
	_open_mission_port_id = &""
	EventBus.port_selection_changed.emit(&"")
	_mission_offer_panel.close_panel()
	if MissionManager.accept_offer(offer_id):
		if GameManager.tutorial_step == GameManager.TutorialStep.ACCEPT_MISSION:
			GameManager.set_tutorial_step(GameManager.TutorialStep.COMPLETED)
			_instruction_label.text = tr("INSTRUCTION_TUTORIAL_COMPLETE")
		else:
			_instruction_label.text = tr("INSTRUCTION_MISSION_STARTED")
	_update_mission_markers()


func _on_mission_panel_dismissed() -> void:
	_open_mission_port_id = &""
	EventBus.port_selection_changed.emit(&"")
	_update_tutorial_instruction()
	_update_tutorial_focus()


func _on_fleet_ship_selected(ship_id: StringName) -> void:
	EventBus.ship_tapped.emit(ship_id)


func _on_speed_upgrade_requested(ship_id: StringName) -> void:
	GameManager.try_upgrade_ship_speed(ship_id)


func _on_capacity_upgrade_requested(ship_id: StringName) -> void:
	GameManager.try_upgrade_ship_capacity(ship_id)


func _on_ship_speed_upgraded(ship_id: StringName, new_level: int, new_speed: float) -> void:
	_instruction_label.text = tr("INSTRUCTION_SPEED_UPGRADED") % [
		_translated_ship_name(ship_id), new_level, new_speed
	]
	_refresh_fleet_panel()


func _on_ship_capacity_upgraded(ship_id: StringName, new_level: int, new_capacity: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_CAPACITY_UPGRADED") % [
		_translated_ship_name(ship_id),
		new_level,
		new_capacity,
	]
	_refresh_fleet_panel()


func _on_ship_upgrade_failed(ship_id: StringName, required_amount: int, current_amount: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_UPGRADE_SHORT") % [
		_translated_ship_name(ship_id),
		required_amount - current_amount,
	]


func _on_fleet_capacity_reached(current_count: int, maximum_count: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_FLEET_FULL") % [current_count, maximum_count]


func _on_ship_tapped(ship_id: StringName) -> void:
	_selected_ship_id = ship_id
	_open_mission_port_id = &""
	EventBus.ship_selection_changed.emit(ship_id)
	EventBus.port_selection_changed.emit(&"")
	_mission_offer_panel.close_panel()
	_port_unlock_panel.close_panel()
	_company_progress_panel.close_panel()
	_fleet_status_panel.select_ship(ship_id)
	_refresh_fleet_panel()
	_update_mission_markers()
	var ship_name := _translated_ship_name(ship_id)
	if FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		if GameManager.tutorial_step == GameManager.TutorialStep.SELECT_SHIP:
			GameManager.set_tutorial_step(GameManager.TutorialStep.SELECT_MISSION_PORT)
		if not _update_tutorial_instruction():
			_instruction_label.text = tr("INSTRUCTION_SHIP_SELECTED") % ship_name
	else:
		_instruction_label.text = tr("INSTRUCTION_SHIP_BUSY") % ship_name


func _on_port_tapped(port_id: StringName) -> void:
	_company_progress_panel.close_panel()
	if not PortManager.is_unlocked(port_id):
		_open_mission_port_id = &""
		_mission_offer_panel.close_panel()
		EventBus.port_selection_changed.emit(port_id)
		_show_port_unlock_panel(port_id)
		return
	_port_unlock_panel.close_panel()
	EventBus.port_selection_changed.emit(port_id)
	if _selected_ship_id == &"":
		_instruction_label.text = tr("INSTRUCTION_SELECT_SHIP_FIRST")
		return
	_show_port_offers(port_id)
	if _open_mission_port_id == port_id \
			and GameManager.tutorial_step == GameManager.TutorialStep.SELECT_MISSION_PORT:
		GameManager.set_tutorial_step(GameManager.TutorialStep.ACCEPT_MISSION)
	_update_tutorial_instruction()
	_update_tutorial_focus()


func _update_tutorial_instruction() -> bool:
	match GameManager.tutorial_step:
		GameManager.TutorialStep.PURCHASE_SHIP:
			_instruction_label.text = tr("TUTORIAL_1_PURCHASE")
			return true
		GameManager.TutorialStep.SELECT_SHIP:
			_instruction_label.text = tr("TUTORIAL_2_SELECT_SHIP")
			return true
		GameManager.TutorialStep.SELECT_MISSION_PORT:
			if _selected_ship_id == &"":
				_instruction_label.text = tr("TUTORIAL_3_NO_SHIP")
			else:
				_instruction_label.text = tr("TUTORIAL_3_SELECT_PORT")
			return true
		GameManager.TutorialStep.ACCEPT_MISSION:
			if _open_mission_port_id == &"":
				_instruction_label.text = tr("TUTORIAL_4_NO_PORT")
			else:
				_instruction_label.text = tr("TUTORIAL_4_ACCEPT")
			return true
		_:
			return false


func _update_money(amount: int) -> void:
	_money_label.text = "%d ₺" % amount


func _update_company_progress() -> void:
	var next_threshold := CompanyManager.get_next_level_threshold()
	if next_threshold < 0:
		_company_progress_label.text = tr("COMPANY_PROGRESS_MAX") % [
			CompanyManager.company_level,
			CompanyManager.company_value,
		]
	else:
		_company_progress_label.text = tr("COMPANY_PROGRESS") % [
			CompanyManager.company_level,
			CompanyManager.company_value,
			next_threshold,
		]


func _update_next_goal() -> void:
	_next_goal_label.visible = false
	if not GameManager.is_tutorial_completed():
		return
	if FleetManager.get_all_ship_ids().is_empty():
		return
	var expansion_port_id := _get_first_expansion_port_id()
	if expansion_port_id != &"":
		var port_data := PortManager.get_port_data(expansion_port_id)
		if port_data == null:
			return
		_next_goal_label.text = tr("NEXT_GOAL_UNLOCK_PORT") % [
			_translated_port_name(expansion_port_id),
			mini(GameManager.money, port_data.base_unlock_cost),
			port_data.base_unlock_cost,
		]
		_next_goal_label.visible = true
		return
	if FleetManager.get_all_ship_ids().size() < 2:
		var ship_data := _get_first_expansion_ship_model()
		if ship_data == null:
			return
		var ship_price := FleetManager.get_ship_purchase_price(ship_data.id)
		_next_goal_label.text = tr("NEXT_GOAL_BUY_SHIP") % [
			_translated_ship_model_name(ship_data),
			mini(GameManager.money, ship_price),
			ship_price,
		]
		_next_goal_label.visible = true
		return
	var regional_port_id := _get_available_regional_port_id()
	if regional_port_id != &"":
		var regional_port_data := PortManager.get_port_data(regional_port_id)
		if regional_port_data == null:
			return
		_next_goal_label.text = tr("NEXT_GOAL_UNLOCK_PORT") % [
			_translated_port_name(regional_port_id),
			mini(GameManager.money, regional_port_data.base_unlock_cost),
			regional_port_data.base_unlock_cost,
		]
		_next_goal_label.visible = true
		return
	var future_port_id := _get_next_level_regional_port_id()
	if future_port_id == &"":
		return
	var future_port_data := PortManager.get_port_data(future_port_id)
	if future_port_data == null:
		return
	var required_value := CompanyManager.get_level_threshold(
		future_port_data.required_company_level
	)
	if required_value < 0:
		return
	_next_goal_label.text = tr("NEXT_GOAL_REACH_LEVEL_FOR_PORT") % [
		_translated_port_name(future_port_id),
		future_port_data.required_company_level,
		mini(CompanyManager.company_value, required_value),
		required_value,
	]
	_next_goal_label.visible = true


func _get_first_expansion_port_id() -> StringName:
	var selected_id: StringName = &""
	var selected_cost := 2147483647
	for port_id in PortManager.get_all_port_ids():
		if PortManager.is_unlocked(port_id):
			continue
		var port_data := PortManager.get_port_data(port_id)
		if port_data == null \
				or port_data.base_unlock_cost <= 0 \
				or port_data.required_company_level != 1:
			continue
		if port_data.base_unlock_cost < selected_cost:
			selected_id = port_id
			selected_cost = port_data.base_unlock_cost
	return selected_id


func _get_first_expansion_ship_model() -> ShipData:
	var selected: ShipData = null
	for candidate in FleetManager.get_purchasable_ship_models():
		if candidate.unlocked_by_default \
				or FleetManager.get_owned_model_count(candidate.id) > 0 \
				or candidate.required_company_level > CompanyManager.company_level:
			continue
		if selected == null \
				or candidate.required_company_level < selected.required_company_level \
				or (candidate.required_company_level == selected.required_company_level \
				and candidate.purchase_cost < selected.purchase_cost):
			selected = candidate
	return selected


func _get_available_regional_port_id() -> StringName:
	var selected_id: StringName = &""
	var selected_level := 2147483647
	var selected_cost := 2147483647
	for port_id in PortManager.get_all_port_ids():
		if PortManager.is_unlocked(port_id):
			continue
		var port_data := PortManager.get_port_data(port_id)
		if port_data == null \
				or port_data.base_unlock_cost <= 0 \
				or port_data.required_company_level <= 1 \
				or port_data.required_company_level > CompanyManager.company_level:
			continue
		if port_data.required_company_level < selected_level \
				or (port_data.required_company_level == selected_level \
				and port_data.base_unlock_cost < selected_cost):
			selected_id = port_id
			selected_level = port_data.required_company_level
			selected_cost = port_data.base_unlock_cost
	return selected_id


func _get_next_level_regional_port_id() -> StringName:
	var selected_id: StringName = &""
	var selected_level := 2147483647
	var selected_cost := 2147483647
	for port_id in PortManager.get_all_port_ids():
		if PortManager.is_unlocked(port_id):
			continue
		var port_data := PortManager.get_port_data(port_id)
		if port_data == null \
				or port_data.base_unlock_cost <= 0 \
				or port_data.required_company_level <= CompanyManager.company_level:
			continue
		if port_data.required_company_level < selected_level \
				or (port_data.required_company_level == selected_level \
				and port_data.base_unlock_cost < selected_cost):
			selected_id = port_id
			selected_level = port_data.required_company_level
			selected_cost = port_data.base_unlock_cost
	return selected_id


func _on_port_unlocked(port_id: StringName) -> void:
	var port_name := _translated_port_name(port_id)
	_instruction_label.text = tr("INSTRUCTION_PORT_UNLOCKED") % port_name
	if _port_unlock_panel.is_open_for(port_id):
		_port_unlock_panel.close_panel()
	_update_mission_markers()
	_update_next_goal()


func _on_port_unlock_failed(port_id: StringName, required_amount: int, current_amount: int) -> void:
	var port_name := _translated_port_name(port_id)
	_instruction_label.text = tr("INSTRUCTION_PORT_MONEY") % [
		port_name,
		required_amount,
		required_amount - current_amount,
	]


func _on_ship_purchased(
		ship_id: StringName,
		ship_data: ShipData,
		home_port_id: StringName
) -> void:
	_spawn_ship(
		ship_id,
		ship_data,
		home_port_id,
		_company_headquarters.get_delivery_position(),
		true
	)
	if not _update_tutorial_instruction():
		_instruction_label.text = tr("INSTRUCTION_SHIP_JOINED") % \
			_translated_ship_model_name(ship_data)
	_refresh_fleet_panel()
	_update_tutorial_focus()
	_update_next_goal()


func _on_game_loaded() -> void:
	_port_unlock_panel.close_panel()
	_company_progress_panel.close_panel()
	if SaveManager.loaded_existing_save:
		for existing_ship_id in FleetManager.get_all_ship_ids():
			var existing_ship := FleetManager.get_ship_node(existing_ship_id) as Ship
			if existing_ship != null:
				existing_ship.clear_initial_world_position_override()
	for ship_id in FleetManager.get_all_ship_ids():
		if FleetManager.get_ship_node(ship_id) != null:
			continue
		var ship_data := FleetManager.get_ship_data(ship_id)
		var home_port_id := FleetManager.get_ship_current_port(ship_id)
		_spawn_ship(ship_id, ship_data, home_port_id)
	_update_money(GameManager.money)
	_update_company_progress()
	_update_next_goal()
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()
	_update_tutorial_instruction()


func _on_offline_progress_applied(elapsed_sec: float) -> void:
	if elapsed_sec >= 60.0:
		_instruction_label.text = tr("INSTRUCTION_OFFLINE") % floori(elapsed_sec / 60.0)


func _spawn_ship(
		ship_id: StringName,
		ship_data: ShipData,
		home_port_id: StringName,
		initial_world_position := Vector2.ZERO,
		use_initial_world_position := false
) -> void:
	if FleetManager.get_ship_node(ship_id) != null:
		return
	if ship_data == null or ship_data.scene == null:
		return
	var ship := ship_data.scene.instantiate() as Ship
	if ship == null:
		return
	ship.name = String(ship_id)
	ship.ship_id = ship_id
	ship.ship_data = ship_data
	ship.home_port_id = home_port_id
	if use_initial_world_position:
		ship.set_initial_world_position(initial_world_position)
	add_child(ship)


func _refresh_fleet_panel() -> void:
	var entries: Array[Dictionary] = []
	var ship_ids := FleetManager.get_all_ship_ids()

	for ship_id in ship_ids:
		var ship_data := FleetManager.get_ship_data(ship_id)
		var state := FleetManager.get_ship_state(ship_id)
		var mission := FleetManager.get_ship_mission(ship_id)
		var remaining_sec := FleetManager.get_ship_mission_remaining_sec(ship_id)
		var has_mission := mission != null
		var progress := 0.0
		var route_text := tr("AT_PORT") % _translated_port_name(
			FleetManager.get_ship_current_port(ship_id)
		)
		var cargo_text := tr("NO_CARGO")
		if mission != null:
			var total_duration := maxf(mission.estimated_duration_sec, 0.001)
			progress = clampf(1.0 - remaining_sec / total_duration, 0.0, 1.0)
			route_text = "%s → %s" % [
				_translated_port_name(mission.pickup_port_id),
				_translated_port_name(mission.delivery_port_id),
			]
			cargo_text = tr("CARGO_LABEL") % _translated_cargo_name(mission.cargo_type_id)
		entries.append({
			"ship_id": String(ship_id),
			"display_name": _translated_ship_model_name(ship_data) \
				if ship_data != null else String(ship_id),
			"state_text": _get_ship_state_text(state),
			"route_text": route_text,
			"cargo_text": cargo_text,
			"remaining_sec": remaining_sec,
			"progress": progress,
			"has_mission": has_mission,
			"speed_level": FleetManager.get_ship_speed_level(ship_id),
			"effective_speed": FleetManager.get_ship_effective_speed(ship_id),
			"speed_upgrade_cost": FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"can_afford_speed_upgrade": GameManager.money >= FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"capacity_level": FleetManager.get_ship_capacity_level(ship_id),
			"effective_capacity": FleetManager.get_ship_effective_capacity(ship_id),
			"capacity_upgrade_cost": FleetManager.get_ship_capacity_upgrade_cost(ship_id),
			"can_afford_capacity_upgrade": GameManager.money >= FleetManager.get_ship_capacity_upgrade_cost(ship_id),
		})
	_fleet_status_panel.set_fleet_data(entries, _selected_ship_id)


func _show_port_offers(port_id: StringName) -> void:
	_port_unlock_panel.close_panel()
	var matching_offers: Array[Mission] = []
	for offer in _mission_offers:
		if offer.offered_ship_id == _selected_ship_id and offer.pickup_port_id == port_id:
			matching_offers.append(offer)
	if matching_offers.is_empty():
		_open_mission_port_id = &""
		EventBus.port_selection_changed.emit(&"")
		_mission_offer_panel.close_panel()
		_instruction_label.text = tr("INSTRUCTION_NO_OFFERS")
		return
	_open_mission_port_id = port_id
	var title := tr("MISSION_OFFERS_TITLE") % _translated_port_name(port_id)
	_mission_offer_panel.show_offers(matching_offers, title)


func _show_port_unlock_panel(port_id: StringName) -> void:
	var port_data := PortManager.get_port_data(port_id)
	if port_data == null:
		return
	_port_unlock_panel.show_port(
		port_id,
		port_data.display_name,
		port_data.description,
		port_data.base_unlock_cost,
		port_data.base_company_value,
		port_data.required_company_level,
		GameManager.money,
		CompanyManager.company_level
	)


func _on_port_unlock_requested(port_id: StringName) -> void:
	GameManager.try_unlock_port(port_id)
	_port_unlock_panel.update_status(GameManager.money, CompanyManager.company_level)


func _on_port_unlock_panel_closed() -> void:
	EventBus.port_selection_changed.emit(&"")


func _on_company_progress_pressed() -> void:
	if _company_progress_panel.is_open():
		_company_progress_panel.close_panel()
		return
	_mission_offer_panel.close_panel()
	_port_unlock_panel.close_panel()
	_show_company_progress_panel()


func _show_company_progress_panel() -> void:
	var level := CompanyManager.company_level
	_company_progress_panel.show_progress(
		level,
		CompanyManager.company_value,
		CompanyManager.get_level_threshold(level),
		CompanyManager.get_next_level_threshold(),
		CompanyManager.get_fleet_asset_value(),
		CompanyManager.get_port_asset_value(),
		_get_next_company_unlocks(level + 1)
	)


func _get_next_company_unlocks(next_level: int) -> Array[String]:
	var unlocks: Array[String] = []
	for port_id in PortManager.get_all_port_ids():
		if PortManager.is_unlocked(port_id):
			continue
		var port_data := PortManager.get_port_data(port_id)
		if port_data != null and port_data.required_company_level == next_level:
			unlocks.append(tr("COMPANY_PANEL_PORT_UNLOCK") % _translated_port_name(port_id))
	for ship_data in FleetManager.get_purchasable_ship_models():
		if ship_data.required_company_level == next_level:
			unlocks.append(
				tr("COMPANY_PANEL_SHIP_UNLOCK") % _translated_ship_model_name(ship_data)
			)
	return unlocks


func _update_mission_markers() -> void:
	for port_id in PortManager.get_all_port_ids():
		var offer_count := 0
		if _selected_ship_id != &"":
			for offer in _mission_offers:
				if offer.offered_ship_id == _selected_ship_id and offer.pickup_port_id == port_id:
					offer_count += 1
		var port_node := PortManager.get_port_node(port_id) as Port
		if port_node != null:
			port_node.set_mission_offer_count(offer_count)
			port_node.set_tutorial_focus(
				GameManager.tutorial_step == GameManager.TutorialStep.SELECT_MISSION_PORT \
				and offer_count > 0
			)


func _update_tutorial_focus() -> void:
	_ship_shop_panel.set_tutorial_focus(
		GameManager.tutorial_step == GameManager.TutorialStep.PURCHASE_SHIP
	)
	var focus_ships := GameManager.tutorial_step == GameManager.TutorialStep.SELECT_SHIP
	for ship_id in FleetManager.get_all_ship_ids():
		var ship_node := FleetManager.get_ship_node(ship_id) as Ship
		if ship_node != null:
			ship_node.set_tutorial_focus(
				focus_ships \
				and FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE
			)
	_update_mission_markers()
	_mission_offer_panel.set_tutorial_focus(
		GameManager.tutorial_step == GameManager.TutorialStep.ACCEPT_MISSION \
		and _mission_offer_panel.visible
	)


func _get_ship_state_text(state: ShipRuntimeState.State) -> String:
	match state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			return tr("STATE_SAILING_TO_PICKUP")
		ShipRuntimeState.State.LOADING:
			return tr("STATE_LOADING")
		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			return tr("STATE_SAILING_TO_DELIVERY")
		ShipRuntimeState.State.UNLOADING:
			return tr("STATE_UNLOADING")
		_:
			return tr("STATE_IDLE")


func _refresh_context_instruction() -> void:
	if _selected_ship_id == &"":
		_instruction_label.text = tr("INSTRUCTION_SELECT_SHIP_LONG")
	elif FleetManager.get_ship_state(_selected_ship_id) == ShipRuntimeState.State.IDLE:
		_instruction_label.text = tr("INSTRUCTION_SHIP_SELECTED") % \
			_translated_ship_name(_selected_ship_id)
	else:
		_instruction_label.text = tr("INSTRUCTION_SHIP_BUSY") % \
			_translated_ship_name(_selected_ship_id)


func _translated_port_name(port_id: StringName) -> String:
	var port_data := PortManager.get_port_data(port_id)
	var fallback := port_data.display_name if port_data != null else String(port_id)
	return _translated_entity_name("PORT", port_id, fallback)


func _translated_ship_name(ship_id: StringName) -> String:
	var ship_data := FleetManager.get_ship_data(ship_id)
	return _translated_ship_model_name(ship_data) if ship_data != null else String(ship_id)


func _translated_ship_model_name(ship_data: ShipData) -> String:
	if ship_data == null:
		return tr("SHIP_DEFAULT")
	return _translated_entity_name("SHIP", ship_data.id, ship_data.display_name)


func _translated_cargo_name(cargo_id: StringName) -> String:
	var cargo_data := MissionManager.get_cargo_type(cargo_id)
	var fallback := cargo_data.display_name if cargo_data != null else String(cargo_id)
	return _translated_entity_name("CARGO", cargo_id, fallback)


func _translated_entity_name(prefix: String, entity_id: StringName, fallback: String) -> String:
	var key := StringName("%s_%s" % [prefix, String(entity_id).to_upper()])
	var translated := TranslationServer.translate(key)
	return fallback if translated == String(key) else translated
