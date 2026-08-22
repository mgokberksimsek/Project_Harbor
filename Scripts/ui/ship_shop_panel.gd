extends PanelContainer

@export var model_id: StringName = &"refrigerated_freighter"
@export var home_port_id: StringName = &"mersin"
@export var start_expanded := false

@onready var _toggle_button: Button = $Margin/VBox/ToggleButton
@onready var _body: VBoxContainer = $Margin/VBox/Body
@onready var _title: Label = $Margin/VBox/Body/Title
@onready var _previous_button: Button = $Margin/VBox/Body/ModelSelector/PreviousButton
@onready var _model_position_label: Label = $Margin/VBox/Body/ModelSelector/PositionLabel
@onready var _next_button: Button = $Margin/VBox/Body/ModelSelector/NextButton
@onready var _details: Label = $Margin/VBox/Body/Details
@onready var _buy_button: Button = $Margin/VBox/Body/BuyButton
@onready var _status: Label = $Margin/VBox/Body/Status

const COLLAPSED_HEIGHT := 56.0
const EXPANDED_HEIGHT := 230.0
const TUTORIAL_PULSE_SPEED := 4.0

var _ship_data: ShipData
var _expanded := false
var _tutorial_focused := false
var _tutorial_pulse_elapsed := 0.0
var _default_model_id: StringName


func _ready() -> void:
	_default_model_id = model_id
	_select_model_for_fleet_state()
	_toggle_button.pressed.connect(_on_toggle_pressed)
	_previous_button.pressed.connect(_on_previous_model_pressed)
	_next_button.pressed.connect(_on_next_model_pressed)
	_buy_button.pressed.connect(_on_buy_pressed)
	var event_bus := get_node("/root/EventBus")
	event_bus.money_changed.connect(_on_money_changed)
	event_bus.company_level_changed.connect(_on_company_level_changed)
	event_bus.ship_purchased.connect(_on_ship_purchased)
	event_bus.ship_purchase_failed.connect(_on_ship_purchase_failed)
	event_bus.fleet_capacity_reached.connect(_on_fleet_capacity_reached)
	event_bus.language_changed.connect(_on_language_changed)
	event_bus.game_loaded.connect(_on_game_loaded)
	set_expanded(start_expanded)
	_refresh()


func _process(delta: float) -> void:
	if not _tutorial_focused:
		return
	_tutorial_pulse_elapsed += delta
	var pulse := (sin(_tutorial_pulse_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	_buy_button.modulate = Color(1.0, 0.78 + pulse * 0.22, 0.5, 0.8 + pulse * 0.2)


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	_body.visible = expanded
	_toggle_button.text = "%s %s" % [tr("SHIP_SHOP_TITLE"), "▼" if expanded else "▶"]
	offset_top = offset_bottom - (EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT)


func is_expanded() -> bool:
	return _expanded


func _refresh() -> void:
	if _ship_data == null:
		_title.text = tr("SHOP_NOT_FOUND")
		_buy_button.disabled = true
		_refresh_model_selector()
		return
	_title.text = _translated_ship_name(_ship_data)
	var details_key := "SHOP_DETAILS_GENERAL"
	if _ship_data.cargo_capabilities.has(&"refrigerated"):
		details_key = "SHOP_DETAILS_REFRIGERATED"
	elif _ship_data.cargo_capabilities.has(&"bulk"):
		details_key = "SHOP_DETAILS_BULK"
	_details.text = tr(details_key) % [
		roundi(_ship_data.base_speed),
		_ship_data.cargo_capacity,
	]
	var current_price := FleetManager.get_ship_purchase_price(model_id)
	var owned_count := FleetManager.get_owned_model_count(model_id)
	if CompanyManager.company_level < _ship_data.required_company_level:
		_buy_button.text = tr("SHOP_LEVEL_REQUIRED") % _ship_data.required_company_level
		_buy_button.disabled = true
		_status.text = tr("SHOP_CURRENT_LEVEL") % CompanyManager.company_level
	elif FleetManager.is_fleet_at_capacity():
		_buy_button.text = tr("SHOP_FLEET_FULL")
		_buy_button.disabled = true
		_status.text = tr("SHOP_FLEET_COUNT") % [
			FleetManager.get_all_ship_ids().size(),
			FleetManager.get_fleet_capacity(),
		]
	else:
		_buy_button.text = tr("SHOP_BUY") % current_price
		_buy_button.disabled = GameManager.money < current_price
		_status.text = tr("SHOP_OWNED") % owned_count
	_refresh_model_selector()


func _on_buy_pressed() -> void:
	# Re-evaluate price/capacity immediately before the transaction as a
	# defensive guard against any same-frame save/load state change.
	_refresh()
	if _ship_data == null or _buy_button.disabled:
		return
	GameManager.try_purchase_ship(model_id, home_port_id)


func _on_toggle_pressed() -> void:
	set_expanded(not _expanded)


func _on_previous_model_pressed() -> void:
	_shift_model(-1)


func _on_next_model_pressed() -> void:
	_shift_model(1)


func _on_money_changed(_new_amount: int, _delta: int) -> void:
	_refresh()


func _on_company_level_changed(_new_level: int, _previous_level: int) -> void:
	_refresh()


func _on_ship_purchased(
		_ship_id: StringName,
		purchased_data: ShipData,
		_home_port_id: StringName
) -> void:
	if purchased_data.id == model_id:
		_status.text = tr("SHOP_SUCCESS")
	if FleetManager.get_all_ship_ids().size() == 1 and purchased_data.unlocked_by_default:
		_ship_data = FleetManager.get_ship_model(_default_model_id)
		if _ship_data != null:
			model_id = _ship_data.id
	_refresh()


func _on_ship_purchase_failed(
		failed_model_id: StringName,
		required_amount: int,
		current_amount: int
) -> void:
	if failed_model_id == model_id:
		_status.text = tr("SHOP_INSUFFICIENT") % (required_amount - current_amount)


func _on_fleet_capacity_reached(_current_count: int, _maximum_count: int) -> void:
	_refresh()


func _on_game_loaded() -> void:
	_select_model_for_fleet_state()
	_refresh()


func _on_language_changed(_locale: String) -> void:
	set_expanded(_expanded)
	_refresh()


func _translated_ship_name(ship_data: ShipData) -> String:
	var key := StringName("SHIP_%s" % String(ship_data.id).to_upper())
	var translated := TranslationServer.translate(key)
	return ship_data.display_name if translated == String(key) else translated


func set_tutorial_focus(enabled: bool) -> void:
	var was_focused := _tutorial_focused
	_tutorial_focused = enabled
	if enabled:
		set_expanded(true)
	elif was_focused:
		_tutorial_pulse_elapsed = 0.0
		_buy_button.modulate = Color.WHITE
		set_expanded(false)


func is_tutorial_focused() -> bool:
	return _tutorial_focused


func _select_model_for_fleet_state() -> void:
	if FleetManager.get_all_ship_ids().is_empty():
		_ship_data = FleetManager.get_initial_ship_model()
		if _ship_data != null:
			model_id = _ship_data.id
		return
	if _ship_data != null and FleetManager.get_ship_model(model_id) != null:
		return
	_ship_data = FleetManager.get_ship_model(_default_model_id)
	if _ship_data != null:
		model_id = _ship_data.id


func _shift_model(direction: int) -> void:
	var models := _get_shop_models()
	if models.size() <= 1:
		return
	var current_index := _find_model_index(models, model_id)
	if current_index < 0:
		current_index = 0
	var next_index := posmod(current_index + direction, models.size())
	_ship_data = models[next_index]
	model_id = _ship_data.id
	_refresh()


func _refresh_model_selector() -> void:
	var models := _get_shop_models()
	var model_index := _find_model_index(models, model_id)
	_model_position_label.text = "%d / %d" % [
		model_index + 1 if model_index >= 0 else 0,
		models.size(),
	]
	var navigation_disabled := models.size() <= 1
	_previous_button.disabled = navigation_disabled
	_next_button.disabled = navigation_disabled


func _get_shop_models() -> Array[ShipData]:
	if FleetManager.get_all_ship_ids().is_empty():
		var initial_model := FleetManager.get_initial_ship_model()
		var initial_models: Array[ShipData] = []
		if initial_model != null:
			initial_models.append(initial_model)
		return initial_models
	var models := FleetManager.get_purchasable_ship_models()
	models.sort_custom(_is_ship_model_before)
	return models


func _find_model_index(models: Array[ShipData], target_model_id: StringName) -> int:
	for model_index in range(models.size()):
		if models[model_index].id == target_model_id:
			return model_index
	return -1


func _is_ship_model_before(left: ShipData, right: ShipData) -> bool:
	if left.required_company_level != right.required_company_level:
		return left.required_company_level < right.required_company_level
	if left.purchase_cost != right.purchase_cost:
		return left.purchase_cost < right.purchase_cost
	return String(left.id) < String(right.id)
