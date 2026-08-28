class_name ManagementDock
extends PanelContainer

signal shop_opened()

@onready var fleet_panel: FleetStatusPanel = \
	$Margin/VBox/Content/FleetStatusPanel
@onready var ship_shop_panel: PanelContainer = \
	$Margin/VBox/Content/ShipShopPanel
@onready var _content: Control = $Margin/VBox/Content
@onready var _fleet_tab_button: Button = $Margin/VBox/Tabs/FleetTabButton
@onready var _shop_tab_button: Button = $Margin/VBox/Tabs/ShopTabButton

const COLLAPSED_HEIGHT := 58.0
const EXPANDED_HEIGHT := 286.0
const TUTORIAL_PULSE_SPEED := 4.0

var _fleet_open := false
var _shop_open := false
var _fleet_interaction_enabled := true
var _shop_interaction_enabled := true
var _shop_tutorial_focused := false
var _tutorial_pulse_elapsed := 0.0
var _fleet_count := 0
var _fleet_capacity := 0


func _ready() -> void:
	fleet_panel.set_embedded_mode(true)
	ship_shop_panel.set_embedded_mode(true)
	_fleet_tab_button.pressed.connect(_on_fleet_tab_pressed)
	_shop_tab_button.pressed.connect(_on_shop_tab_pressed)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	_refresh_open_panels()
	_refresh_tab_text()


func _process(delta: float) -> void:
	if not _shop_tutorial_focused or _shop_open:
		_tutorial_pulse_elapsed = 0.0
		_shop_tab_button.modulate = Color.WHITE
		_shop_tab_button.scale = Vector2.ONE
		return
	_tutorial_pulse_elapsed += delta
	var pulse := (sin(_tutorial_pulse_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	_shop_tab_button.pivot_offset = _shop_tab_button.size * 0.5
	_shop_tab_button.scale = Vector2.ONE * lerpf(1.0, 1.05, pulse)
	_shop_tab_button.modulate = Color(
		1.0,
		0.78 + pulse * 0.22,
		0.5,
		0.8 + pulse * 0.2
	)


func collapse() -> void:
	_fleet_open = false
	_shop_open = false
	_refresh_open_panels()


func is_expanded() -> bool:
	return _fleet_open or _shop_open


func is_fleet_open() -> bool:
	return _fleet_open


func is_shop_open() -> bool:
	return _shop_open


func open_fleet() -> void:
	if _fleet_interaction_enabled:
		_fleet_open = true
		_refresh_open_panels()


func open_shop() -> void:
	if _shop_interaction_enabled:
		var was_open := _shop_open
		_shop_open = true
		_refresh_open_panels()
		if not was_open:
			shop_opened.emit()


func set_fleet_interaction_enabled(enabled: bool) -> void:
	_fleet_interaction_enabled = enabled
	_fleet_tab_button.disabled = not enabled
	if not enabled and _fleet_open:
		_fleet_open = false
		_refresh_open_panels()


func set_shop_interaction_enabled(enabled: bool) -> void:
	_shop_interaction_enabled = enabled
	_shop_tab_button.disabled = not enabled
	if not enabled and _shop_open:
		_shop_open = false
		_refresh_open_panels()


func set_shop_tutorial_focus(enabled: bool) -> void:
	_shop_tutorial_focused = enabled
	if not enabled:
		_tutorial_pulse_elapsed = 0.0
		_shop_tab_button.modulate = Color.WHITE
		_shop_tab_button.scale = Vector2.ONE


func set_fleet_count(current_count: int, capacity: int) -> void:
	_fleet_count = maxi(current_count, 0)
	_fleet_capacity = maxi(capacity, 0)
	_refresh_tab_text()


func _refresh_open_panels() -> void:
	_content.visible = is_expanded()
	fleet_panel.set_expanded(_fleet_open)
	ship_shop_panel.set_expanded(_shop_open)
	_fleet_tab_button.button_pressed = _fleet_open
	_shop_tab_button.button_pressed = _shop_open
	offset_top = offset_bottom - (
		EXPANDED_HEIGHT if is_expanded() else COLLAPSED_HEIGHT
	)


func _on_fleet_tab_pressed() -> void:
	if not _fleet_interaction_enabled:
		return
	_fleet_open = not _fleet_open
	_refresh_open_panels()


func _on_shop_tab_pressed() -> void:
	if not _shop_interaction_enabled:
		return
	var opening := not _shop_open
	_shop_open = opening
	_refresh_open_panels()
	if opening:
		shop_opened.emit()


func _on_language_changed(_locale: String) -> void:
	_refresh_tab_text()


func _refresh_tab_text() -> void:
	_fleet_tab_button.text = tr("FLEET_TAB_TITLE") % [
		_fleet_count,
		_fleet_capacity,
	]
	_shop_tab_button.text = tr("SHIP_SHOP_TITLE")
