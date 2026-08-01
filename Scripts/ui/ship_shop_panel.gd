extends PanelContainer

@export var model_id: StringName = &"refrigerated_freighter"
@export var home_port_id: StringName = &"mersin"

@onready var _title: Label = $Margin/VBox/Title
@onready var _details: Label = $Margin/VBox/Details
@onready var _buy_button: Button = $Margin/VBox/BuyButton
@onready var _status: Label = $Margin/VBox/Status

var _ship_data: ShipData


func _ready() -> void:
	_ship_data = FleetManager.get_ship_model(model_id)
	_buy_button.pressed.connect(_on_buy_pressed)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_purchase_failed.connect(_on_ship_purchase_failed)
	EventBus.fleet_capacity_reached.connect(_on_fleet_capacity_reached)
	EventBus.game_loaded.connect(_on_game_loaded)
	_refresh()


func _refresh() -> void:
	if _ship_data == null:
		_title.text = "Gemi bulunamadı"
		_buy_button.disabled = true
		return
	_title.text = _ship_data.display_name
	_details.text = "Hız: %d · Kapasite: %d\nGenel + Soğutmalı yük" % [
		roundi(_ship_data.base_speed),
		_ship_data.cargo_capacity,
	]
	var current_price := FleetManager.get_ship_purchase_price(model_id)
	var owned_count := FleetManager.get_owned_model_count(model_id)
	if FleetManager.is_fleet_at_capacity():
		_buy_button.text = "Filo kapasitesi dolu"
		_buy_button.disabled = true
		_status.text = "Filo: %d/%d" % [
			FleetManager.get_all_ship_ids().size(),
			FleetManager.get_fleet_capacity(),
		]
	else:
		_buy_button.text = "Satın Al · %d ₺" % current_price
		_buy_button.disabled = GameManager.money < current_price
		_status.text = "Filoda: %d · Sonraki fiyat artar" % owned_count


func _on_buy_pressed() -> void:
	# Re-evaluate price/capacity immediately before the transaction as a
	# defensive guard against any same-frame save/load state change.
	_refresh()
	if _ship_data == null or _buy_button.disabled:
		return
	GameManager.try_purchase_ship(model_id, home_port_id)


func _on_money_changed(_new_amount: int, _delta: int) -> void:
	_refresh()


func _on_ship_purchased(
		_ship_id: StringName,
		purchased_data: ShipData,
		_home_port_id: StringName
) -> void:
	if purchased_data.id == model_id:
		_status.text = "Satın alma başarılı."
	_refresh()


func _on_ship_purchase_failed(
		failed_model_id: StringName,
		required_amount: int,
		current_amount: int
) -> void:
	if failed_model_id == model_id:
		_status.text = "Yetersiz bakiye: %d ₺ eksik" % (required_amount - current_amount)


func _on_fleet_capacity_reached(_current_count: int, _maximum_count: int) -> void:
	_refresh()


func _on_game_loaded() -> void:
	_ship_data = FleetManager.get_ship_model(model_id)
	_refresh()
