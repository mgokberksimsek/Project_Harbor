class_name FleetStatusPanel
extends PanelContainer

signal ship_selected(ship_id: StringName)
signal speed_upgrade_requested(ship_id: StringName)
signal capacity_upgrade_requested(ship_id: StringName)

@export var start_expanded := false

@onready var _toggle_button: Button = $Margin/VBox/ToggleButton
@onready var _body: VBoxContainer = $Margin/VBox/Body
@onready var _list: VBoxContainer = $Margin/VBox/Body/Scroll/List

const COLLAPSED_HEIGHT := 64.0
const EXPANDED_HEIGHT := 330.0

var _cards: Dictionary = {}
var _expanded := false


func _ready() -> void:
	_toggle_button.pressed.connect(_on_toggle_pressed)
	set_expanded(start_expanded)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body.visible = expanded
	_toggle_button.text = "Filo Durumu ▼" if expanded else "Filo Durumu ▶"
	offset_bottom = offset_top + (EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT)


func is_expanded() -> bool:
	return _expanded


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
	root.add_theme_constant_override("separation", 3)
	_list.add_child(root)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_card_pressed.bind(ship_id))
	root.add_child(button)

	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 12)
	progress.show_percentage = false
	root.add_child(progress)

	var upgrade_button := Button.new()
	upgrade_button.custom_minimum_size = Vector2(0, 34)
	upgrade_button.pressed.connect(_on_speed_upgrade_pressed.bind(ship_id))
	root.add_child(upgrade_button)

	var capacity_button := Button.new()
	capacity_button.custom_minimum_size = Vector2(0, 34)
	capacity_button.pressed.connect(_on_capacity_upgrade_pressed.bind(ship_id))
	root.add_child(capacity_button)

	return {
		"root": root,
		"button": button,
		"progress": progress,
		"upgrade_button": upgrade_button,
		"capacity_button": capacity_button,
	}


func _update_card(card: Dictionary, entry: Dictionary, selected: bool) -> void:
	var button: Button = card["button"]
	var progress: ProgressBar = card["progress"]
	var upgrade_button: Button = card["upgrade_button"]
	var capacity_button: Button = card["capacity_button"]
	button.text = "%s · %s\n%s\n%s · Kalan: %s" % [
		entry.get("display_name", entry.get("ship_id", "Gemi")),
		entry.get("state_text", ""),
		entry.get("route_text", "Limanda"),
		entry.get("cargo_text", "Yük yok"),
		_format_duration(float(entry.get("remaining_sec", 0.0))),
	]
	button.modulate = Color("#BDE3FF") if selected else Color.WHITE
	progress.value = clampf(float(entry.get("progress", 0.0)) * 100.0, 0.0, 100.0)
	progress.visible = bool(entry.get("has_mission", false))
	var upgrade_cost := int(entry.get("speed_upgrade_cost", -1))
	if upgrade_cost < 0:
		upgrade_button.text = "Hız maksimum · Lv.%d · %.0f hız" % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
		]
		upgrade_button.disabled = true
	else:
		upgrade_button.text = "Hız Lv.%d · %.0f hız · %d ₺" % [
			int(entry.get("speed_level", 0)),
			float(entry.get("effective_speed", 0.0)),
			upgrade_cost,
		]
		upgrade_button.disabled = not bool(entry.get("can_afford_speed_upgrade", false))

	var capacity_cost := int(entry.get("capacity_upgrade_cost", -1))
	if capacity_cost < 0:
		capacity_button.text = "Kapasite maksimum · Lv.%d · %d birim" % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
		]
		capacity_button.disabled = true
	else:
		capacity_button.text = "Kapasite Lv.%d · %d birim · %d ₺" % [
			int(entry.get("capacity_level", 0)),
			int(entry.get("effective_capacity", 0)),
			capacity_cost,
		]
		capacity_button.disabled = not bool(entry.get("can_afford_capacity_upgrade", false))


func _on_card_pressed(ship_id: StringName) -> void:
	ship_selected.emit(ship_id)


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _on_speed_upgrade_pressed(ship_id: StringName) -> void:
	speed_upgrade_requested.emit(ship_id)


func _on_capacity_upgrade_pressed(ship_id: StringName) -> void:
	capacity_upgrade_requested.emit(ship_id)


func _format_duration(duration_sec: float) -> String:
	var total_seconds := maxi(ceili(duration_sec), 0)
	if total_seconds < 60:
		return "%d sn" % total_seconds
	return "%d dk %02d sn" % [total_seconds / 60, total_seconds % 60]
