class_name FleetStatusPanel
extends PanelContainer

signal ship_selected(ship_id: StringName)
signal speed_upgrade_requested(ship_id: StringName)
signal capacity_upgrade_requested(ship_id: StringName)
signal automation_requested(ship_id: StringName)
signal rename_requested(ship_id: StringName)

@export var start_expanded := false

@onready var _toggle_button: Button = $Margin/VBox/Header/ToggleButton
@onready var _summary: Label = $Margin/VBox/Header/Summary
@onready var _info_button: Button = $Margin/VBox/Header/InfoButton
@onready var _body: HBoxContainer = $Margin/VBox/Body
@onready var _list_title: Label = $Margin/VBox/Body/ListColumn/ListTitle
@onready var _list: VBoxContainer = $Margin/VBox/Body/ListColumn/Scroll/List
@onready var _selected_title: Label = $Margin/VBox/Body/Details/SelectedTitle
@onready var _selected_state: Label = $Margin/VBox/Body/Details/SelectedState
@onready var _selected_route: Label = $Margin/VBox/Body/Details/SelectedRoute
@onready var _selected_cargo: Label = $Margin/VBox/Body/Details/SelectedCargo
@onready var _progress: ProgressBar = $Margin/VBox/Body/Details/Progress
@onready var _stats: Label = $Margin/VBox/Body/Details/Stats
@onready var _speed_button: Button = $Margin/VBox/Body/Details/Actions/SpeedButton
@onready var _capacity_button: Button = \
	$Margin/VBox/Body/Details/Actions/CapacityButton
@onready var _automation_button: Button = \
	$Margin/VBox/Body/Details/Actions/AutomationButton
@onready var _rename_button: Button = $Margin/VBox/Body/Details/Actions/RenameButton
@onready var _help_dialog: AcceptDialog = $HelpDialog

const COLLAPSED_HEIGHT := 56.0
const EXPANDED_HEIGHT := 290.0

var _cards: Dictionary = {}
var _entries: Dictionary = {}
var _selected_ship_id: StringName = &""
var _fleet_capacity := 0
var _expanded := false
var _embedded_mode := false
var _interaction_enabled := true


func _ready() -> void:
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_info_button.pressed.connect(_show_help_dialog)
	_speed_button.pressed.connect(_on_speed_upgrade_pressed)
	_capacity_button.pressed.connect(_on_capacity_upgrade_pressed)
	_automation_button.pressed.connect(_on_automation_pressed)
	_rename_button.pressed.connect(_on_rename_pressed)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	_refresh_help_dialog()
	set_expanded(start_expanded)


func set_embedded_mode(enabled: bool) -> void:
	_embedded_mode = enabled
	_toggle_button.visible = not enabled
	_summary.visible = enabled
	if enabled:
		set_expanded(false)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body.visible = expanded
	_toggle_button.text = "%s %s" % [tr("FLEET_TITLE"), "▼" if expanded else "▶"]
	if _embedded_mode:
		visible = expanded
		return
	offset_bottom = offset_top + (EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT)


func is_expanded() -> bool:
	return _expanded


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_toggle_button.disabled = not enabled
	_info_button.disabled = not enabled
	if not enabled:
		_help_dialog.hide()
		if not _embedded_mode:
			set_expanded(false)
	_refresh_card_interactions()


func set_fleet_data(
		entries: Array,
		selected_ship_id: StringName,
		fleet_capacity: int = -1
) -> void:
	_selected_ship_id = selected_ship_id
	if fleet_capacity >= 0:
		_fleet_capacity = fleet_capacity
	var active_ids: Array[StringName] = []
	_entries.clear()
	for entry in entries:
		var ship_id := StringName(entry.get("ship_id", ""))
		if ship_id == &"":
			continue
		active_ids.append(ship_id)
		_entries[ship_id] = entry
		if not _cards.has(ship_id):
			_cards[ship_id] = _create_card(ship_id)
		_update_card(_cards[ship_id], entry, ship_id == selected_ship_id)

	for ship_id in _cards.keys():
		if active_ids.has(ship_id):
			continue
		var card: Button = _cards[ship_id]
		card.queue_free()
		_cards.erase(ship_id)
	_update_summary(entries)
	_update_selected_details()


func select_ship(ship_id: StringName) -> void:
	_selected_ship_id = ship_id
	for card_ship_id in _cards.keys():
		var button: Button = _cards[card_ship_id]
		button.modulate = Color("#BDE3FF") if card_ship_id == ship_id else Color.WHITE
	_update_selected_details()


func _create_card(ship_id: StringName) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_card_pressed.bind(ship_id))
	_list.add_child(button)
	return button


func _update_card(button: Button, entry: Dictionary, selected: bool) -> void:
	var remaining_text: String = tr("REMAINING") % _format_duration(
		float(entry.get("remaining_sec", 0.0))
	) if bool(entry.get("has_mission", false)) else String(
		entry.get("state_text", "")
	)
	button.text = "%s · %s\n%s" % [
		entry.get("ship_name", entry.get("ship_id", tr("SHIP_DEFAULT"))),
		entry.get("model_name", tr("SHIP_DEFAULT")),
		remaining_text,
	]
	button.tooltip_text = "%s · %s" % [
		entry.get("route_text", ""),
		entry.get("cargo_text", tr("NO_CARGO")),
	]
	button.modulate = Color("#BDE3FF") if selected else Color.WHITE
	button.disabled = not _interaction_enabled


func _update_summary(entries: Array) -> void:
	var idle_count := 0
	for entry in entries:
		if not bool(entry.get("has_mission", false)):
			idle_count += 1
	_summary.text = tr("FLEET_SUMMARY") % [
		entries.size(),
		maxi(_fleet_capacity, entries.size()),
		idle_count,
		entries.size() - idle_count,
	]
	_list_title.text = tr("FLEET_LIST_TITLE")


func _update_selected_details() -> void:
	var entry: Dictionary = _entries.get(_selected_ship_id, {})
	if entry.is_empty():
		_selected_title.text = tr("FLEET_SELECT_HINT")
		_selected_state.text = ""
		_selected_route.text = ""
		_selected_cargo.text = ""
		_progress.visible = false
		_stats.text = ""
		_automation_button.visible = false
		_set_detail_actions_enabled(false)
		return

	_selected_title.text = "%s · %s" % [
		entry.get("ship_name", entry.get("ship_id", tr("SHIP_DEFAULT"))),
		entry.get("model_name", tr("SHIP_DEFAULT")),
	]
	_selected_state.text = entry.get("state_text", "")
	_selected_route.text = tr("FLEET_CURRENT_ROUTE") % entry.get("route_text", "")
	_selected_cargo.text = tr("FLEET_CURRENT_CARGO") % entry.get(
		"cargo_text",
		tr("NO_CARGO")
	)
	_progress.value = clampf(float(entry.get("progress", 0.0)) * 100.0, 0.0, 100.0)
	_progress.visible = bool(entry.get("has_mission", false))
	_stats.text = tr("FLEET_LIFETIME_STATS") % [
		int(entry.get("completed_mission_count", 0)),
		int(entry.get("total_net_earnings", 0)),
	]
	_update_detail_actions(entry)


func _update_detail_actions(entry: Dictionary) -> void:
	var speed_cost := int(entry.get("speed_upgrade_cost", -1))
	if speed_cost < 0:
		_speed_button.text = tr("SPEED_MAX") % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
		]
		_speed_button.disabled = true
	else:
		_speed_button.text = tr("SPEED_UPGRADE") % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
			speed_cost,
		]
		_speed_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_speed_upgrade", false))

	var capacity_cost := int(entry.get("capacity_upgrade_cost", -1))
	if capacity_cost < 0:
		_capacity_button.text = tr("CAPACITY_MAX") % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
		]
		_capacity_button.disabled = true
	else:
		_capacity_button.text = tr("CAPACITY_UPGRADE") % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
			capacity_cost,
		]
		_capacity_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_capacity_upgrade", false))

	_automation_button.visible = bool(entry.get("automation_visible", false))
	if not _automation_button.visible:
		_automation_button.disabled = true
	elif bool(entry.get("automation_unlocked", false)):
		_automation_button.text = tr(
			"AUTOMATION_ON" if bool(entry.get("automation_enabled", false)) \
			else "AUTOMATION_OFF"
		)
		_automation_button.disabled = not _interaction_enabled
	elif int(entry.get("company_level", 1)) \
			< int(entry.get("automation_required_company_level", 1)):
		_automation_button.text = tr("AUTOMATION_LEVEL_REQUIRED") % int(
			entry.get("automation_required_company_level", 1)
		)
		_automation_button.disabled = true
	elif int(entry.get("total_upgrade_levels", 0)) \
			< int(entry.get("automation_required_upgrade_levels", 0)):
		_automation_button.text = tr("AUTOMATION_UPGRADES_REQUIRED") % [
			int(entry.get("total_upgrade_levels", 0)),
			int(entry.get("automation_required_upgrade_levels", 0)),
		]
		_automation_button.disabled = true
	else:
		_automation_button.text = tr("AUTOMATION_UNLOCK") % int(
			entry.get("automation_unlock_cost", 0)
		)
		_automation_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_automation", false))

	_rename_button.text = tr("FLEET_RENAME_ACTION")
	_rename_button.disabled = not _interaction_enabled


func _set_detail_actions_enabled(enabled: bool) -> void:
	_speed_button.disabled = not enabled
	_capacity_button.disabled = not enabled
	_automation_button.disabled = not enabled
	_rename_button.disabled = not enabled


func _on_card_pressed(ship_id: StringName) -> void:
	ship_selected.emit(ship_id)


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _on_language_changed(_locale: String) -> void:
	set_expanded(_expanded)
	_refresh_help_dialog()
	for ship_id in _entries.keys():
		_update_card(_cards[ship_id], _entries[ship_id], ship_id == _selected_ship_id)
	_update_summary(_entries.values())
	_update_selected_details()


func _show_help_dialog() -> void:
	_refresh_help_dialog()
	var message_label := _help_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(340, 0)
	message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_help_dialog.popup_centered(Vector2i(400, 190))


func _refresh_help_dialog() -> void:
	_help_dialog.title = tr("FLEET_HELP_TITLE")
	_help_dialog.dialog_text = tr("FLEET_HELP_MESSAGE")
	_help_dialog.get_ok_button().text = tr("FLEET_HELP_OK")


func _on_speed_upgrade_pressed() -> void:
	if _selected_ship_id != &"":
		speed_upgrade_requested.emit(_selected_ship_id)


func _on_capacity_upgrade_pressed() -> void:
	if _selected_ship_id != &"":
		capacity_upgrade_requested.emit(_selected_ship_id)


func _on_automation_pressed() -> void:
	if _selected_ship_id != &"":
		automation_requested.emit(_selected_ship_id)


func _on_rename_pressed() -> void:
	if _selected_ship_id != &"":
		rename_requested.emit(_selected_ship_id)


func _refresh_card_interactions() -> void:
	for button: Button in _cards.values():
		button.disabled = not _interaction_enabled
	_update_selected_details()


func _format_duration(duration_sec: float) -> String:
	var total_seconds := maxi(ceili(duration_sec), 0)
	if total_seconds < 60:
		return tr("DURATION_SECONDS") % total_seconds
	return tr("DURATION_MINUTES") % [total_seconds / 60, total_seconds % 60]
