class_name FleetStatusPanel
extends PanelContainer

signal ship_selected(ship_id: StringName)
signal speed_upgrade_requested(ship_id: StringName)
signal capacity_upgrade_requested(ship_id: StringName)
signal automation_requested(ship_id: StringName)
signal rename_requested(ship_id: StringName)

@export var start_expanded := false

@onready var _toggle_button: Button = $Margin/VBox/Header/ToggleButton
@onready var _info_button: Button = $Margin/VBox/Header/InfoButton
@onready var _body: VBoxContainer = $Margin/VBox/Body
@onready var _list: VBoxContainer = $Margin/VBox/Body/Scroll/List
@onready var _help_dialog: AcceptDialog = $HelpDialog

const COLLAPSED_HEIGHT := 56.0
const EXPANDED_HEIGHT := 290.0

var _cards: Dictionary = {}
var _expanded := false
var _interaction_enabled := true


func _ready() -> void:
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_info_button.pressed.connect(_show_help_dialog)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	_refresh_help_dialog()
	set_expanded(start_expanded)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body.visible = expanded
	_toggle_button.text = "%s %s" % [tr("FLEET_TITLE"), "▼" if expanded else "▶"]
	offset_bottom = offset_top + (EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT)


func is_expanded() -> bool:
	return _expanded


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	_toggle_button.disabled = not enabled
	_info_button.disabled = not enabled
	if not enabled:
		_help_dialog.hide()
		set_expanded(false)
	for card in _cards.values():
		var button: Button = card["button"]
		button.disabled = not enabled
	_refresh_card_interactions()


func set_fleet_data(entries: Array, selected_ship_id: StringName) -> void:
	var active_ids: Array[StringName] = []
	for entry in entries:
		var ship_id := StringName(entry.get("ship_id", ""))
		if ship_id == &"":
			continue
		active_ids.append(ship_id)
		if not _cards.has(ship_id):
			_cards[ship_id] = _create_card(ship_id)
		_update_card(_cards[ship_id], entry, ship_id == selected_ship_id)

	for ship_id in _cards.keys():
		if active_ids.has(ship_id):
			continue
		var card: VBoxContainer = _cards[ship_id]["root"]
		card.queue_free()
		_cards.erase(ship_id)


func select_ship(ship_id: StringName) -> void:
	for card_ship_id in _cards.keys():
		var button: Button = _cards[card_ship_id]["button"]
		button.modulate = Color("#BDE3FF") if card_ship_id == ship_id else Color.WHITE


func _create_card(ship_id: StringName) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	_list.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 68)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_card_pressed.bind(ship_id))
	header.add_child(button)

	var rename_button := Button.new()
	rename_button.custom_minimum_size = Vector2(44, 68)
	rename_button.focus_mode = Control.FOCUS_NONE
	rename_button.mouse_filter = Control.MOUSE_FILTER_PASS
	rename_button.text = "✎"
	rename_button.tooltip_text = tr("SHIP_RENAME_BUTTON")
	rename_button.pressed.connect(_on_rename_pressed.bind(ship_id))
	header.add_child(rename_button)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 12)
	progress.show_percentage = false
	root.add_child(progress)

	var upgrade_button := Button.new()
	upgrade_button.custom_minimum_size = Vector2(0, 30)
	upgrade_button.focus_mode = Control.FOCUS_NONE
	upgrade_button.mouse_filter = Control.MOUSE_FILTER_PASS
	upgrade_button.pressed.connect(_on_speed_upgrade_pressed.bind(ship_id))
	root.add_child(upgrade_button)

	var capacity_button := Button.new()
	capacity_button.custom_minimum_size = Vector2(0, 30)
	capacity_button.focus_mode = Control.FOCUS_NONE
	capacity_button.mouse_filter = Control.MOUSE_FILTER_PASS
	capacity_button.pressed.connect(_on_capacity_upgrade_pressed.bind(ship_id))
	root.add_child(capacity_button)

	var automation_button := Button.new()
	automation_button.custom_minimum_size = Vector2(0, 30)
	automation_button.focus_mode = Control.FOCUS_NONE
	automation_button.mouse_filter = Control.MOUSE_FILTER_PASS
	automation_button.pressed.connect(_on_automation_pressed.bind(ship_id))
	root.add_child(automation_button)

	return {
		"root": root,
		"button": button,
		"rename_button": rename_button,
		"progress": progress,
		"upgrade_button": upgrade_button,
		"capacity_button": capacity_button,
		"automation_button": automation_button,
	}


func _update_card(card: Dictionary, entry: Dictionary, selected: bool) -> void:
	var button: Button = card["button"]
	var progress: ProgressBar = card["progress"]
	var rename_button: Button = card["rename_button"]
	var upgrade_button: Button = card["upgrade_button"]
	var capacity_button: Button = card["capacity_button"]
	var automation_button: Button = card["automation_button"]
	button.text = "%s · %s\n%s · %s\n%s · %s" % [
		entry.get("ship_name", entry.get("ship_id", tr("SHIP_DEFAULT"))),
		entry.get("model_name", tr("SHIP_DEFAULT")),
		entry.get("state_text", ""),
		entry.get("route_text", ""),
		entry.get("cargo_text", tr("NO_CARGO")),
		tr("REMAINING") % _format_duration(float(entry.get("remaining_sec", 0.0))),
	]
	button.modulate = Color("#BDE3FF") if selected else Color.WHITE
	button.disabled = not _interaction_enabled
	rename_button.disabled = not _interaction_enabled
	rename_button.tooltip_text = tr("SHIP_RENAME_BUTTON")
	progress.value = clampf(float(entry.get("progress", 0.0)) * 100.0, 0.0, 100.0)
	progress.visible = bool(entry.get("has_mission", false))
	var upgrade_cost := int(entry.get("speed_upgrade_cost", -1))
	if upgrade_cost < 0:
		upgrade_button.text = tr("SPEED_MAX") % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
		]
		upgrade_button.disabled = true
	else:
		upgrade_button.text = tr("SPEED_UPGRADE") % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
			upgrade_cost,
		]
		upgrade_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_speed_upgrade", false))

	var capacity_cost := int(entry.get("capacity_upgrade_cost", -1))
	if capacity_cost < 0:
		capacity_button.text = tr("CAPACITY_MAX") % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
		]
		capacity_button.disabled = true
	else:
		capacity_button.text = tr("CAPACITY_UPGRADE") % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
			capacity_cost,
		]
		capacity_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_capacity_upgrade", false))

	automation_button.visible = bool(entry.get("automation_visible", false))
	if not automation_button.visible:
		automation_button.disabled = true
	elif bool(entry.get("automation_unlocked", false)):
		automation_button.text = tr(
			"AUTOMATION_ON" if bool(entry.get("automation_enabled", false)) \
			else "AUTOMATION_OFF"
		)
		automation_button.disabled = not _interaction_enabled
	elif int(entry.get("company_level", 1)) \
			< int(entry.get("automation_required_company_level", 1)):
		automation_button.text = tr("AUTOMATION_LEVEL_REQUIRED") % int(
			entry.get("automation_required_company_level", 1)
		)
		automation_button.disabled = true
	elif int(entry.get("total_upgrade_levels", 0)) \
			< int(entry.get("automation_required_upgrade_levels", 0)):
		automation_button.text = tr("AUTOMATION_UPGRADES_REQUIRED") % [
			int(entry.get("total_upgrade_levels", 0)),
			int(entry.get("automation_required_upgrade_levels", 0)),
		]
		automation_button.disabled = true
	else:
		automation_button.text = tr("AUTOMATION_UNLOCK") % int(
			entry.get("automation_unlock_cost", 0)
		)
		automation_button.disabled = not _interaction_enabled \
			or not bool(entry.get("can_afford_automation", false))


func _on_card_pressed(ship_id: StringName) -> void:
	ship_selected.emit(ship_id)


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _on_language_changed(_locale: String) -> void:
	set_expanded(_expanded)
	_refresh_help_dialog()


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


func _on_speed_upgrade_pressed(ship_id: StringName) -> void:
	speed_upgrade_requested.emit(ship_id)


func _on_capacity_upgrade_pressed(ship_id: StringName) -> void:
	capacity_upgrade_requested.emit(ship_id)


func _on_automation_pressed(ship_id: StringName) -> void:
	automation_requested.emit(ship_id)


func _on_rename_pressed(ship_id: StringName) -> void:
	rename_requested.emit(ship_id)


func _refresh_card_interactions() -> void:
	for card in _cards.values():
		var button: Button = card["button"]
		var upgrade_button: Button = card["upgrade_button"]
		var capacity_button: Button = card["capacity_button"]
		var automation_button: Button = card["automation_button"]
		var rename_button: Button = card["rename_button"]
		button.disabled = not _interaction_enabled
		rename_button.disabled = not _interaction_enabled
		if not _interaction_enabled:
			upgrade_button.disabled = true
			capacity_button.disabled = true
			automation_button.disabled = true


func _format_duration(duration_sec: float) -> String:
	var total_seconds := maxi(ceili(duration_sec), 0)
	if total_seconds < 60:
		return tr("DURATION_SECONDS") % total_seconds
	return tr("DURATION_MINUTES") % [total_seconds / 60, total_seconds % 60]
