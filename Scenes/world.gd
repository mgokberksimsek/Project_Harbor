extends Node2D

@onready var _money_label: Label = $UI/MoneyLabel
@onready var _company_progress_label: Button = $UI/CompanyProgressLabel
@onready var _debug_level_up_button: Button = $UI/DebugLevelUpButton
@onready var _debug_money_button: Button = $UI/DebugMoneyButton
@onready var _next_goal_label: Label = $UI/NextGoalLabel
@onready var _instruction_label: Label = $UI/InstructionLabel
@onready var _skip_tutorial_button: Button = $UI/SkipTutorialButton
@onready var _tutorial_complete_dialog: AcceptDialog = $UI/TutorialCompleteDialog
@onready var _offline_summary_dialog: AcceptDialog = $UI/OfflineSummaryDialog
@onready var _ship_rename_dialog: PopupPanel = $UI/ShipRenameDialog
@onready var _ship_name_input: LineEdit = $UI/ShipRenameDialog/Content/Rows/NameRow/NameInput
@onready var _random_ship_name_button: Button = $UI/ShipRenameDialog/Content/Rows/NameRow/RandomNameButton
@onready var _ship_rename_cancel_button: Button = $UI/ShipRenameDialog/Content/Rows/ActionRow/CancelButton
@onready var _ship_rename_save_button: Button = $UI/ShipRenameDialog/Content/Rows/ActionRow/SaveButton
@onready var _exit_confirmation_dialog: ConfirmationDialog = $UI/ExitConfirmationDialog
@onready var _mission_offer_panel: MissionOfferPanel = $UI/MissionOfferPanel
@onready var _management_dock: ManagementDock = $UI/ManagementDock
@onready var _fleet_status_panel: FleetStatusPanel = \
	$UI/ManagementDock/Margin/VBox/Content/FleetStatusPanel
@onready var _ship_shop_panel = \
	$UI/ManagementDock/Margin/VBox/Content/ShipShopPanel
@onready var _port_unlock_panel: PortUnlockPanel = $UI/PortUnlockPanel
@onready var _company_progress_panel: CompanyProgressPanel = $UI/CompanyProgressPanel
@onready var _settings_menu: SettingsMenu = $UI/SettingsMenu
@onready var _world_camera: WorldCamera = $Camera2D
@onready var _company_headquarters: CompanyHeadquarters = $CompanyHeadquarters

var _selected_ship_id: StringName = &""
var _open_mission_port_id: StringName = &""
var _mission_offers: Array[Mission] = []
var _fleet_refresh_elapsed := 0.0
var _tutorial_completion_skipped := false
var _offline_completed_missions := 0
var _offline_earned_cash := 0
var _renaming_ship_id: StringName = &""
var _ship_rename_error_key := ""

const MAP_SHIP_TAP_RADIUS_PX := 48.0
const MAP_PORT_TAP_RADIUS_PX := 48.0
const TUTORIAL_PULSE_SPEED := 4.0
const DEBUG_MONEY_AMOUNT := 10000
const SHIP_RENAME_DIALOG_SIZE := Vector2i(300, 114)
const SHIP_RENAME_DIALOG_TOP_MARGIN := 16

var _company_progress_tutorial_elapsed := 0.0


func _handle_map_tap(screen_position: Vector2) -> void:
	if try_select_ship_at_screen_position(screen_position):
		_collapse_management_panels()
		get_viewport().set_input_as_handled()
		return
	if _is_port_at_screen_position(screen_position):
		_collapse_management_panels()
		return
	if not GameManager.is_tutorial_completed():
		_update_tutorial_instruction()
		_update_tutorial_focus()
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
	_collapse_management_panels()
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


func _collapse_management_panels() -> void:
	_management_dock.collapse()


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	RenderingServer.set_default_clear_color(Color("#256BB8"))
	# Ships and ports can occupy the same dock position. Sorted, first-only
	# picking guarantees that the higher-z ship receives the tap.
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true
	_world_camera.map_tapped.connect(_handle_map_tap)

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.company_value_changed.connect(_on_company_value_changed)
	EventBus.company_level_changed.connect(_on_company_level_changed)
	EventBus.company_level_requirement_failed.connect(
		_on_company_level_requirement_failed
	)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.mission_offers_updated.connect(_on_mission_offers_updated)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_leveled_up.connect(_on_port_leveled_up)
	EventBus.port_unlock_failed.connect(_on_port_unlock_failed)
	EventBus.port_tapped.connect(_on_port_tapped)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_tapped.connect(_on_ship_tapped)
	EventBus.ship_dock_slot_changed.connect(_on_ship_dock_slot_changed)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	EventBus.ship_automation_changed.connect(_on_ship_automation_changed)
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
	_fleet_status_panel.automation_requested.connect(_on_automation_requested)
	_fleet_status_panel.rename_requested.connect(_on_ship_rename_requested)
	_port_unlock_panel.unlock_requested.connect(_on_port_unlock_requested)
	_port_unlock_panel.upgrade_requested.connect(_on_port_upgrade_requested)
	_port_unlock_panel.closed.connect(_on_port_unlock_panel_closed)
	_company_progress_panel.closed.connect(_on_company_progress_panel_closed)
	_company_progress_panel.company_value_info_confirmed.connect(
		_on_company_value_info_confirmed
	)
	_management_dock.shop_opened.connect(_on_ship_shop_expanded)
	_company_progress_label.pressed.connect(_on_company_progress_pressed)
	_debug_level_up_button.pressed.connect(_on_debug_level_up_pressed)
	_debug_money_button.pressed.connect(_on_debug_money_pressed)
	_skip_tutorial_button.pressed.connect(_on_skip_tutorial_pressed)
	_tutorial_complete_dialog.confirmed.connect(_on_tutorial_complete_confirmed)
	_ship_rename_save_button.pressed.connect(_on_ship_rename_confirmed)
	_ship_rename_cancel_button.pressed.connect(_on_ship_rename_canceled)
	_random_ship_name_button.pressed.connect(_on_random_ship_name_pressed)
	_exit_confirmation_dialog.confirmed.connect(_on_exit_confirmed)
	_settings_menu.sound_effects_toggled.connect(SettingsManager.set_sound_effects_enabled)
	_settings_menu.music_toggled.connect(SettingsManager.set_music_enabled)
	_settings_menu.locale_selected.connect(SettingsManager.set_locale)
	_settings_menu.menu_opened.connect(_collapse_management_panels)
	_settings_menu.new_game_confirmed.connect(_on_new_game_confirmed)
	_settings_menu.set_preferences(
		SettingsManager.sound_effects_enabled,
		SettingsManager.music_enabled,
		SettingsManager.locale
	)
	_configure_exit_confirmation_dialog()
	_refresh_skip_tutorial_ui()

	_update_money(GameManager.money)
	_update_company_progress()
	_update_debug_buttons()
	_update_next_goal()
	if not _update_tutorial_instruction():
		_instruction_label.text = tr("INSTRUCTION_SELECT_SHIP_LONG")
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()


func _process(delta: float) -> void:
	_update_company_progress_tutorial_visual(delta)
	_fleet_refresh_elapsed += delta
	if _fleet_refresh_elapsed < 0.25:
		return
	_fleet_refresh_elapsed = 0.0
	_refresh_fleet_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_settings_menu) and _settings_menu.is_open():
			_settings_menu.close_menu()
			return
		request_exit_confirmation()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_exit_confirmation()


func request_exit_confirmation() -> void:
	if not is_instance_valid(_exit_confirmation_dialog) \
			or _exit_confirmation_dialog.visible:
		return
	_exit_confirmation_dialog.popup_centered(Vector2i(430, 185))


func _on_exit_confirmed() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _configure_exit_confirmation_dialog() -> void:
	_exit_confirmation_dialog.title = tr("EXIT_CONFIRM_TITLE")
	_exit_confirmation_dialog.dialog_text = tr("EXIT_CONFIRM_MESSAGE")
	_exit_confirmation_dialog.ok_button_text = tr("EXIT_CONFIRM_OK")
	_exit_confirmation_dialog.cancel_button_text = tr("EXIT_CONFIRM_CANCEL")
	var message_label := _exit_confirmation_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(350, 0)
	message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _on_money_changed(new_amount: int, _delta: int) -> void:
	_update_money(new_amount)
	_port_unlock_panel.update_status(new_amount, CompanyManager.company_level)
	_update_next_goal()


func _on_mission_completed(mission: Mission) -> void:
	var ship_id := mission.assigned_ship_id
	if CompanyManager.company_level >= GameManager.AUTOMATION_REQUIRED_COMPANY_LEVEL \
			and mission.is_large_contract() \
			and not FleetManager.is_ship_automation_unlocked(ship_id) \
			and FleetManager.get_ship_completed_large_contract_count(ship_id) \
				== GameManager.AUTOMATION_REQUIRED_LARGE_CONTRACTS:
		_instruction_label.text = tr("INSTRUCTION_AUTOMATION_READY") % [
			_translated_ship_name(ship_id),
			GameManager.AUTOMATION_UNLOCK_COST,
		]
		return
	_instruction_label.text = tr("INSTRUCTION_MISSION_COMPLETED") % [
		mission.get_net_reward(),
		mission.reward,
		mission.operating_cost,
	]


func _on_company_value_changed(_new_value: int, _delta: int) -> void:
	_update_company_progress()
	_update_next_goal()
	if _company_progress_panel.is_open():
		_show_company_progress_panel()


func _on_tutorial_step_changed(_new_step: int, _previous_step: int) -> void:
	_update_tutorial_instruction()
	_update_tutorial_focus()
	_update_next_goal()
	_refresh_skip_tutorial_ui()


func _on_language_changed(_locale: String) -> void:
	_configure_exit_confirmation_dialog()
	_update_company_progress()
	_update_debug_buttons()
	_update_next_goal()
	_refresh_fleet_panel()
	_refresh_skip_tutorial_ui()
	if _offline_summary_dialog.visible:
		_show_offline_summary()
	if _ship_rename_dialog.visible:
		_configure_ship_rename_dialog()
	if _company_progress_panel.is_open():
		_show_company_progress_panel()
	if _open_mission_port_id != &"":
		_show_port_offers(_open_mission_port_id)
	if not _update_tutorial_instruction():
		_refresh_context_instruction()


func _on_new_game_confirmed() -> void:
	SaveManager.reset_game()


func _on_company_level_changed(new_level: int, previous_level: int) -> void:
	_update_company_progress()
	_update_debug_buttons()
	_update_next_goal()
	_port_unlock_panel.update_status(GameManager.money, new_level)
	if _company_progress_panel.is_open():
		_show_company_progress_panel()
	if new_level > previous_level:
		_instruction_label.text = tr("INSTRUCTION_LEVEL_UP") % new_level


func _on_debug_level_up_pressed() -> void:
	_collapse_management_panels()
	CompanyManager.debug_advance_level()
	_update_debug_buttons()


func _on_debug_money_pressed() -> void:
	if not GameManager.is_tutorial_completed():
		return
	_collapse_management_panels()
	GameManager.add_money(DEBUG_MONEY_AMOUNT)


func _update_debug_buttons() -> void:
	_debug_level_up_button.text = tr("DEBUG_LEVEL_UP") % CompanyManager.company_level
	_debug_money_button.text = tr("DEBUG_ADD_MONEY")
	_debug_level_up_button.disabled = not GameManager.is_tutorial_completed() or (
		CompanyManager.company_level >= CompanyManager.get_max_level()
	)
	_debug_money_button.disabled = not GameManager.is_tutorial_completed()


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
	if not GameManager.is_tutorial_completed() \
			and GameManager.tutorial_step != GameManager.TutorialStep.ACCEPT_MISSION:
		_update_tutorial_instruction()
		_update_tutorial_focus()
		return
	_open_mission_port_id = &""
	EventBus.port_selection_changed.emit(&"")
	_mission_offer_panel.close_panel()
	if MissionManager.accept_offer(offer_id):
		if GameManager.tutorial_step == GameManager.TutorialStep.ACCEPT_MISSION:
			GameManager.set_tutorial_step(GameManager.TutorialStep.WELCOME_CAPTAIN)
			_show_tutorial_complete_dialog(false)
		else:
			_instruction_label.text = tr("INSTRUCTION_MISSION_STARTED")
	_update_mission_markers()


func _on_mission_panel_dismissed() -> void:
	_open_mission_port_id = &""
	EventBus.port_selection_changed.emit(&"")
	if GameManager.tutorial_step == GameManager.TutorialStep.ACCEPT_MISSION:
		GameManager.set_tutorial_step(GameManager.TutorialStep.SELECT_MISSION_PORT)
	_update_tutorial_instruction()
	_update_tutorial_focus()


func _on_fleet_ship_selected(ship_id: StringName) -> void:
	EventBus.ship_tapped.emit(ship_id)
	if _selected_ship_id != ship_id:
		return
	var ship_node := FleetManager.get_ship_node(ship_id) as Node2D
	if ship_node != null:
		_world_camera.focus_world_position(ship_node.global_position)


func _on_speed_upgrade_requested(ship_id: StringName) -> void:
	if not GameManager.is_tutorial_completed():
		return
	GameManager.try_upgrade_ship_speed(ship_id)


func _on_capacity_upgrade_requested(ship_id: StringName) -> void:
	if not GameManager.is_tutorial_completed():
		return
	GameManager.try_upgrade_ship_capacity(ship_id)


func _on_automation_requested(ship_id: StringName) -> void:
	if not GameManager.is_tutorial_completed():
		return
	GameManager.try_toggle_ship_automation(ship_id)
	_refresh_fleet_panel()


func _on_ship_rename_requested(ship_id: StringName) -> void:
	if not GameManager.is_tutorial_completed() \
			or FleetManager.get_ship_name(ship_id).is_empty():
		return
	_renaming_ship_id = ship_id
	_ship_rename_error_key = ""
	_ship_name_input.text = FleetManager.get_ship_name(ship_id)
	_configure_ship_rename_dialog()
	_popup_ship_rename_dialog()
	call_deferred("_focus_ship_name_input")


func _configure_ship_rename_dialog() -> void:
	if _ship_rename_error_key == "SHIP_RENAME_LENGTH_ERROR":
		_instruction_label.text = tr(_ship_rename_error_key) % [
			FleetManager.MIN_SHIP_NAME_LENGTH,
			FleetManager.MAX_SHIP_NAME_LENGTH,
		]
	elif not _ship_rename_error_key.is_empty():
		_instruction_label.text = tr(_ship_rename_error_key)
	_ship_rename_save_button.text = tr("SHIP_RENAME_OK")
	_ship_rename_cancel_button.text = tr("SHIP_RENAME_CANCEL")
	_ship_name_input.placeholder_text = tr("SHIP_RENAME_PLACEHOLDER")
	_random_ship_name_button.tooltip_text = tr("SHIP_RENAME_RANDOM")


func _focus_ship_name_input() -> void:
	_ship_name_input.grab_focus()
	_ship_name_input.select_all()


func _popup_ship_rename_dialog() -> void:
	var viewport_width := get_viewport().get_visible_rect().size.x
	var popup_position := Vector2i(
		maxi(roundi((viewport_width - SHIP_RENAME_DIALOG_SIZE.x) * 0.5), 0),
		SHIP_RENAME_DIALOG_TOP_MARGIN
	)
	_ship_rename_dialog.size = SHIP_RENAME_DIALOG_SIZE
	_ship_rename_dialog.position = popup_position
	_ship_rename_dialog.popup()


func _on_random_ship_name_pressed() -> void:
	var previous_suggestion := _ship_name_input.text
	var suggestion := FleetManager.get_random_available_ship_name()
	for _attempt in range(4):
		if suggestion != previous_suggestion:
			break
		suggestion = FleetManager.get_random_available_ship_name()
	_ship_name_input.text = suggestion
	_ship_name_input.select_all()


func _on_ship_rename_confirmed() -> void:
	if _renaming_ship_id == &"":
		return
	var requested_name := _ship_name_input.text.strip_edges()
	if requested_name.length() < FleetManager.MIN_SHIP_NAME_LENGTH \
			or requested_name.length() > FleetManager.MAX_SHIP_NAME_LENGTH:
		_show_ship_rename_error("SHIP_RENAME_LENGTH_ERROR")
		return
	if not FleetManager.is_ship_name_available(requested_name, _renaming_ship_id):
		_show_ship_rename_error("SHIP_RENAME_DUPLICATE_ERROR")
		return
	if FleetManager.rename_ship(_renaming_ship_id, requested_name):
		_instruction_label.text = tr("INSTRUCTION_SHIP_RENAMED") % requested_name
		_refresh_fleet_panel()
		_ship_rename_dialog.hide()
		_renaming_ship_id = &""
		_ship_rename_error_key = ""


func _show_ship_rename_error(message_key: String) -> void:
	_ship_rename_error_key = message_key
	_configure_ship_rename_dialog()
	_focus_ship_name_input()


func _on_ship_rename_canceled() -> void:
	_ship_rename_dialog.hide()
	_renaming_ship_id = &""
	_ship_rename_error_key = ""


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


func _on_ship_automation_changed(
		_ship_id: StringName,
		_unlocked: bool,
		_enabled: bool
) -> void:
	_refresh_fleet_panel()


func _on_ship_upgrade_failed(ship_id: StringName, required_amount: int, current_amount: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_UPGRADE_SHORT") % [
		_translated_ship_name(ship_id),
		required_amount - current_amount,
	]


func _on_fleet_capacity_reached(current_count: int, maximum_count: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_FLEET_FULL") % [current_count, maximum_count]


func _on_ship_tapped(ship_id: StringName) -> void:
	if not GameManager.is_tutorial_completed() \
			and GameManager.tutorial_step != GameManager.TutorialStep.SELECT_SHIP:
		_update_tutorial_instruction()
		_update_tutorial_focus()
		return
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
	if not GameManager.is_tutorial_completed() \
			and GameManager.tutorial_step != GameManager.TutorialStep.SELECT_MISSION_PORT:
		_update_tutorial_instruction()
		_update_tutorial_focus()
		return
	_collapse_management_panels()
	_company_progress_panel.close_panel()
	if not GameManager.is_tutorial_completed() and not PortManager.is_unlocked(port_id):
		_update_tutorial_instruction()
		_update_tutorial_focus()
		return
	if not PortManager.is_unlocked(port_id):
		_open_mission_port_id = &""
		_mission_offer_panel.close_panel()
		EventBus.port_selection_changed.emit(port_id)
		_show_port_unlock_panel(port_id)
		return
	_port_unlock_panel.close_panel()
	EventBus.port_selection_changed.emit(port_id)
	if _selected_ship_id == &"":
		_show_port_upgrade_panel(port_id)
		return
	_show_port_offers(port_id)
	if _open_mission_port_id == port_id \
			and GameManager.tutorial_step == GameManager.TutorialStep.SELECT_MISSION_PORT:
		GameManager.set_tutorial_step(GameManager.TutorialStep.ACCEPT_MISSION)
	_update_tutorial_instruction()
	_update_tutorial_focus()


func _update_tutorial_instruction() -> bool:
	match GameManager.tutorial_step:
		GameManager.TutorialStep.OPEN_SHIP_SHOP:
			_instruction_label.text = tr("TUTORIAL_1_OPEN_SHOP")
			return true
		GameManager.TutorialStep.PURCHASE_SHIP:
			_instruction_label.text = tr("TUTORIAL_2_PURCHASE")
			return true
		GameManager.TutorialStep.OPEN_COMPANY_PROGRESS:
			_instruction_label.text = tr("TUTORIAL_3_OPEN_COMPANY_PROGRESS")
			return true
		GameManager.TutorialStep.READ_COMPANY_VALUE_INFO:
			if _company_progress_panel.is_open():
				_instruction_label.text = tr("TUTORIAL_4_READ_COMPANY_VALUE")
			else:
				_instruction_label.text = tr("TUTORIAL_4_REOPEN_COMPANY_PROGRESS")
			return true
		GameManager.TutorialStep.SELECT_SHIP:
			_instruction_label.text = tr("TUTORIAL_5_SELECT_SHIP")
			return true
		GameManager.TutorialStep.SELECT_MISSION_PORT:
			if _selected_ship_id == &"":
				_instruction_label.text = tr("TUTORIAL_6_NO_SHIP")
			else:
				_instruction_label.text = tr("TUTORIAL_6_SELECT_PORT")
			return true
		GameManager.TutorialStep.ACCEPT_MISSION:
			if _open_mission_port_id == &"":
				_instruction_label.text = tr("TUTORIAL_7_NO_PORT")
			else:
				_instruction_label.text = tr("TUTORIAL_7_ACCEPT")
			return true
		GameManager.TutorialStep.WELCOME_CAPTAIN:
			_instruction_label.text = tr("TUTORIAL_8_WELCOME")
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
	var ship_data := _get_first_expansion_ship_model()
	if ship_data != null:
		var ship_price := FleetManager.get_ship_purchase_price(ship_data.id)
		_next_goal_label.text = tr("NEXT_GOAL_BUY_SHIP") % [
			_translated_ship_model_name(ship_data),
			mini(GameManager.money, ship_price),
			ship_price,
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


func _on_port_leveled_up(port_id: StringName, new_level: int) -> void:
	_instruction_label.text = tr("INSTRUCTION_PORT_UPGRADED") % [
		_translated_port_name(port_id),
		new_level,
	]
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
	var delivery_position := _get_headquarters_delivery_position(ship_id)
	_spawn_ship(
		ship_id,
		ship_data,
		home_port_id,
		_get_headquarters_delivery_approach_position(ship_id),
		true,
		delivery_position
	)
	if not _update_tutorial_instruction():
		_instruction_label.text = tr("INSTRUCTION_SHIP_JOINED") % \
			_translated_ship_name(ship_id)
	_refresh_fleet_panel()
	_update_tutorial_focus()
	_update_next_goal()


func _on_game_loaded() -> void:
	_port_unlock_panel.close_panel()
	_company_progress_panel.close_panel()
	if SaveManager.loaded_existing_save:
		for existing_ship_id in FleetManager.get_all_ship_ids():
			var existing_ship := FleetManager.get_ship_node(existing_ship_id) as Ship
			if existing_ship == null:
				continue
			if FleetManager.is_awaiting_headquarters_dispatch(existing_ship_id):
				existing_ship.hold_at_world_position(
					_get_headquarters_delivery_position(existing_ship_id)
				)
			else:
				existing_ship.clear_initial_world_position_override()
	for ship_id in FleetManager.get_all_ship_ids():
		if FleetManager.get_ship_node(ship_id) != null:
			continue
		var ship_data := FleetManager.get_ship_data(ship_id)
		var home_port_id := FleetManager.get_ship_current_port(ship_id)
		var awaiting_dispatch := FleetManager.is_awaiting_headquarters_dispatch(ship_id)
		var dispatch_active := FleetManager.is_headquarters_dispatch_active(ship_id)
		var headquarters_position := _get_headquarters_delivery_position(ship_id)
		_spawn_ship(
			ship_id,
			ship_data,
			home_port_id,
			headquarters_position,
			awaiting_dispatch or dispatch_active,
			headquarters_position if awaiting_dispatch else Vector2.ZERO
		)
	_update_money(GameManager.money)
	_update_company_progress()
	_update_next_goal()
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()
	_update_tutorial_instruction()


func _on_offline_progress_applied(
		elapsed_sec: float,
		completed_missions: int,
		earned_cash: int
) -> void:
	if elapsed_sec >= 60.0:
		_instruction_label.text = tr("INSTRUCTION_OFFLINE") % floori(elapsed_sec / 60.0)
	if completed_missions <= 0:
		return
	_offline_completed_missions = completed_missions
	_offline_earned_cash = maxi(earned_cash, 0)
	_show_offline_summary()


func _show_offline_summary() -> void:
	_offline_summary_dialog.title = tr("OFFLINE_SUMMARY_TITLE")
	_offline_summary_dialog.dialog_text = tr("OFFLINE_SUMMARY_MESSAGE") % [
		_offline_completed_missions,
		_offline_earned_cash,
	]
	var message_label := _offline_summary_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(300, 0)
	message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_offline_summary_dialog.get_ok_button().text = tr("OFFLINE_SUMMARY_OK")
	_offline_summary_dialog.popup_centered(Vector2i(350, 150))


func _spawn_ship(
		ship_id: StringName,
		ship_data: ShipData,
		home_port_id: StringName,
		initial_world_position := Vector2.ZERO,
		use_initial_world_position := false,
		headquarters_berth_position := Vector2.ZERO
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
		if headquarters_berth_position != Vector2.ZERO:
			ship.set_headquarters_delivery(
				initial_world_position,
				headquarters_berth_position
			)
		else:
			ship.set_initial_world_position(initial_world_position)
	add_child(ship)


func _get_headquarters_delivery_position(ship_id: StringName) -> Vector2:
	return _company_headquarters.get_delivery_position(
		FleetManager.get_ship_headquarters_slot_index(ship_id)
	)


func _get_headquarters_delivery_approach_position(ship_id: StringName) -> Vector2:
	return _company_headquarters.get_delivery_approach_position(
		FleetManager.get_ship_headquarters_slot_index(ship_id)
	)


func _on_ship_dock_slot_changed(
		ship_id: StringName,
		_port_id: StringName,
		_previous_slot_index: int,
		_new_slot_index: int
) -> void:
	if not FleetManager.is_awaiting_headquarters_dispatch(ship_id):
		return
	var ship := FleetManager.get_ship_node(ship_id) as Ship
	if ship != null:
		ship.hold_at_world_position(_get_headquarters_delivery_position(ship_id))


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
		var route_text := tr("COMPANY_HEADQUARTERS") \
			if FleetManager.is_awaiting_headquarters_dispatch(ship_id) \
			else tr("AT_PORT") % _translated_port_name(
				FleetManager.get_ship_current_port(ship_id)
			)
		var cargo_text := tr("NO_CARGO")
		if mission != null:
			var total_duration := maxf(mission.estimated_duration_sec, 0.001)
			progress = clampf(1.0 - remaining_sec / total_duration, 0.0, 1.0)
			route_text = _get_mission_route_text(mission)
			cargo_text = tr("CARGO_LABEL") % _translated_cargo_name(mission.cargo_type_id)
			if mission.is_large_contract():
				cargo_text = "%s · %s" % [
					tr("MISSION_CONTRACT_PROGRESS") % [
						mission.get_completed_delivery_count() + 1,
						mission.get_delivery_count(),
					],
					cargo_text,
				]
		entries.append({
			"ship_id": String(ship_id),
			"ship_name": FleetManager.get_ship_name(ship_id),
			"model_name": _translated_ship_model_name(ship_data) \
				if ship_data != null else String(ship_id),
			"state_text": _get_ship_state_text(state),
			"route_text": route_text,
			"cargo_text": cargo_text,
			"remaining_sec": remaining_sec,
			"progress": progress,
			"has_mission": has_mission,
			"completed_mission_count": \
				FleetManager.get_ship_completed_mission_count(ship_id),
			"completed_large_contract_count": \
				FleetManager.get_ship_completed_large_contract_count(ship_id),
			"total_net_earnings": FleetManager.get_ship_total_net_earnings(ship_id),
			"speed_level": FleetManager.get_ship_speed_level(ship_id),
			"effective_speed": FleetManager.get_ship_effective_speed(ship_id),
			"speed_upgrade_cost": FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"can_afford_speed_upgrade": GameManager.money >= FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"capacity_level": FleetManager.get_ship_capacity_level(ship_id),
			"effective_capacity": FleetManager.get_ship_effective_capacity(ship_id),
			"capacity_upgrade_cost": FleetManager.get_ship_capacity_upgrade_cost(ship_id),
			"can_afford_capacity_upgrade": GameManager.money >= FleetManager.get_ship_capacity_upgrade_cost(ship_id),
			"automation_visible": FleetManager.is_ship_automation_unlocked(ship_id) \
				or CompanyManager.company_level \
					>= GameManager.AUTOMATION_REQUIRED_COMPANY_LEVEL - 1,
			"automation_unlocked": FleetManager.is_ship_automation_unlocked(ship_id),
			"automation_enabled": FleetManager.is_ship_automation_enabled(ship_id),
			"company_level": CompanyManager.company_level,
			"automation_required_company_level": \
				GameManager.AUTOMATION_REQUIRED_COMPANY_LEVEL,
			"automation_required_large_contracts": \
				GameManager.AUTOMATION_REQUIRED_LARGE_CONTRACTS,
			"automation_unlock_cost": GameManager.AUTOMATION_UNLOCK_COST,
			"can_afford_automation": \
				GameManager.money >= GameManager.AUTOMATION_UNLOCK_COST,
		})
	var fleet_capacity := FleetManager.get_fleet_capacity()
	_fleet_status_panel.set_fleet_data(entries, _selected_ship_id, fleet_capacity)
	_management_dock.set_fleet_count(entries.size(), fleet_capacity)


func _get_mission_route_text(mission: Mission) -> String:
	if mission == null:
		return ""
	if not mission.is_large_contract():
		return "%s → %s" % [
			_translated_port_name(mission.pickup_port_id),
			_translated_port_name(mission.delivery_port_id),
		]
	var names: PackedStringArray = []
	for port_id in mission.contract_port_ids:
		names.append(_translated_port_name(port_id))
	return " → ".join(names)


func _show_port_offers(port_id: StringName) -> void:
	_collapse_management_panels()
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
		CompanyManager.company_level,
		PortManager.get_dock_slot_count_for_level(port_id, 1)
	)


func _show_port_upgrade_panel(port_id: StringName) -> void:
	var port_data := PortManager.get_port_data(port_id)
	if port_data == null or not PortManager.is_unlocked(port_id):
		return
	var current_level := PortManager.get_level(port_id)
	var upgrade_cost := port_data.get_upgrade_cost(current_level)
	var benefit_level := current_level + 1 if upgrade_cost >= 0 else current_level
	var company_value := port_data.get_upgrade_company_value(current_level) \
		if upgrade_cost >= 0 else port_data.get_company_value(current_level)
	var reward_bonus_percent := roundi(
		(port_data.get_reward_multiplier(benefit_level) - 1.0) * 100.0
	)
	var handling_reduction_percent := roundi(
		(1.0 - port_data.get_handling_duration_multiplier(benefit_level)) * 100.0
	)
	_port_unlock_panel.show_upgrade_port(
		port_id,
		port_data.display_name,
		current_level,
		upgrade_cost,
		company_value,
		GameManager.money,
		reward_bonus_percent,
		handling_reduction_percent,
		PortManager.get_dock_slot_count_for_level(port_id, current_level),
		PortManager.get_dock_slot_count_for_level(port_id, benefit_level)
	)


func _on_port_unlock_requested(port_id: StringName) -> void:
	if not GameManager.is_tutorial_completed():
		_update_tutorial_instruction()
		return
	GameManager.try_unlock_port(port_id)
	_port_unlock_panel.update_status(GameManager.money, CompanyManager.company_level)


func _on_port_upgrade_requested(port_id: StringName) -> void:
	if not GameManager.is_tutorial_completed():
		_update_tutorial_instruction()
		return
	if GameManager.try_upgrade_port(port_id):
		_show_port_upgrade_panel(port_id)
	else:
		_port_unlock_panel.update_status(GameManager.money, CompanyManager.company_level)


func _on_port_unlock_panel_closed() -> void:
	EventBus.port_selection_changed.emit(&"")


func _on_company_progress_pressed() -> void:
	if not GameManager.is_tutorial_completed() \
			and GameManager.tutorial_step != GameManager.TutorialStep.OPEN_COMPANY_PROGRESS \
			and GameManager.tutorial_step != GameManager.TutorialStep.READ_COMPANY_VALUE_INFO:
		_update_tutorial_instruction()
		return
	_collapse_management_panels()
	if _company_progress_panel.is_open():
		_company_progress_panel.close_panel()
		return
	_mission_offer_panel.close_panel()
	_port_unlock_panel.close_panel()
	_show_company_progress_panel()
	if GameManager.tutorial_step == GameManager.TutorialStep.OPEN_COMPANY_PROGRESS:
		GameManager.set_tutorial_step(GameManager.TutorialStep.READ_COMPANY_VALUE_INFO)


func _on_company_progress_panel_closed() -> void:
	_update_tutorial_instruction()
	_update_tutorial_focus()


func _on_company_value_info_confirmed() -> void:
	if GameManager.tutorial_step == GameManager.TutorialStep.READ_COMPANY_VALUE_INFO:
		_company_progress_panel.close_panel()
		GameManager.set_tutorial_step(GameManager.TutorialStep.SELECT_SHIP)


func _on_ship_shop_expanded() -> void:
	if GameManager.tutorial_step == GameManager.TutorialStep.OPEN_SHIP_SHOP:
		GameManager.set_tutorial_step(GameManager.TutorialStep.PURCHASE_SHIP)


func _on_skip_tutorial_pressed() -> void:
	_show_tutorial_complete_dialog(true)


func _show_tutorial_complete_dialog(skipped: bool) -> void:
	_tutorial_completion_skipped = skipped
	_tutorial_complete_dialog.title = tr("TUTORIAL_COMPLETE_TITLE")
	_tutorial_complete_dialog.dialog_text = tr(
		"TUTORIAL_SKIP_CAPTAIN_MESSAGE" if skipped else "TUTORIAL_COMPLETE_MESSAGE"
	)
	var message_label := _tutorial_complete_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(320, 0)
	message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tutorial_complete_dialog.get_ok_button().text = tr("TUTORIAL_COMPLETE_OK")
	_tutorial_complete_dialog.popup_centered(Vector2i(370, 170))


func _on_tutorial_complete_confirmed() -> void:
	if not _tutorial_completion_skipped \
			and GameManager.tutorial_step != GameManager.TutorialStep.WELCOME_CAPTAIN:
		return
	GameManager.set_tutorial_step(GameManager.TutorialStep.COMPLETED)
	_instruction_label.text = tr(
		"INSTRUCTION_TUTORIAL_SKIPPED" \
		if _tutorial_completion_skipped else "INSTRUCTION_TUTORIAL_COMPLETE"
	)
	_tutorial_completion_skipped = false
	_update_tutorial_focus()
	_update_next_goal()


func _refresh_skip_tutorial_ui() -> void:
	_skip_tutorial_button.visible = not GameManager.is_tutorial_completed() \
		and GameManager.tutorial_step != GameManager.TutorialStep.WELCOME_CAPTAIN
	_skip_tutorial_button.text = tr("TUTORIAL_SKIP")
	_tutorial_complete_dialog.title = tr("TUTORIAL_COMPLETE_TITLE")
	_tutorial_complete_dialog.dialog_text = tr(
		"TUTORIAL_SKIP_CAPTAIN_MESSAGE" \
		if _tutorial_completion_skipped else "TUTORIAL_COMPLETE_MESSAGE"
	)
	_tutorial_complete_dialog.get_ok_button().text = tr("TUTORIAL_COMPLETE_OK")


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
	if FleetManager.get_fleet_capacity_for_company_level(next_level) \
			> FleetManager.get_fleet_capacity_for_company_level(next_level - 1):
		unlocks.append(tr("COMPANY_PANEL_FLEET_CAPACITY") % \
			FleetManager.get_fleet_capacity_for_company_level(next_level))
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
	var tutorial_completed := GameManager.is_tutorial_completed()
	var shop_step := GameManager.tutorial_step == GameManager.TutorialStep.OPEN_SHIP_SHOP \
		or GameManager.tutorial_step == GameManager.TutorialStep.PURCHASE_SHIP
	_ship_shop_panel.set_interaction_enabled(tutorial_completed or shop_step)
	_fleet_status_panel.set_interaction_enabled(tutorial_completed)
	_management_dock.set_shop_interaction_enabled(tutorial_completed or shop_step)
	_management_dock.set_fleet_interaction_enabled(tutorial_completed)
	_management_dock.set_shop_tutorial_focus(shop_step)
	_company_progress_label.disabled = not tutorial_completed \
		and GameManager.tutorial_step != GameManager.TutorialStep.OPEN_COMPANY_PROGRESS \
		and GameManager.tutorial_step != GameManager.TutorialStep.READ_COMPANY_VALUE_INFO
	_update_debug_buttons()
	_ship_shop_panel.set_tutorial_focus(
		shop_step
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
	_company_progress_panel.set_info_tutorial_focus(
		GameManager.tutorial_step == GameManager.TutorialStep.READ_COMPANY_VALUE_INFO \
		and _company_progress_panel.is_open()
	)


func _update_company_progress_tutorial_visual(delta: float) -> void:
	if GameManager.tutorial_step != GameManager.TutorialStep.OPEN_COMPANY_PROGRESS:
		_company_progress_tutorial_elapsed = 0.0
		_company_progress_label.modulate = Color.WHITE
		_company_progress_label.scale = Vector2.ONE
		return
	_company_progress_tutorial_elapsed += delta
	var pulse := (sin(_company_progress_tutorial_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	_company_progress_label.pivot_offset = _company_progress_label.size * 0.5
	_company_progress_label.scale = Vector2.ONE * lerpf(1.0, 1.04, pulse)
	_company_progress_label.modulate = Color.WHITE.lerp(
		Color(1.0, 0.78, 0.28, 1.0),
		lerpf(0.15, 0.45, pulse)
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
	var custom_name := FleetManager.get_ship_name(ship_id)
	if not custom_name.is_empty():
		return custom_name
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
