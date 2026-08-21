extends Node
## Owns the player's permanent company progression. Company Value is derived
## only from authored asset values; Cash deliberately does not contribute.

const LEVEL_THRESHOLDS: Array[int] = [
	0,
	1000,
	2400,
	4800,
	8000,
	13000,
	20000,
	30000,
	43000,
	60000,
	82000,
	109000,
	142000,
	183000,
	235000,
]

var company_value: int = 0
var company_level: int = 1
var peak_company_value: int = 0


func _ready() -> void:
	EventBus.ship_registered.connect(_on_assets_changed)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_leveled_up.connect(_on_port_leveled_up)
	EventBus.game_loaded.connect(recalculate)
	call_deferred("recalculate")


func recalculate() -> void:
	var previous_value := company_value
	var previous_level := company_level
	company_value = _calculate_asset_value()
	peak_company_value = maxi(peak_company_value, company_value)
	company_level = maxi(company_level, _calculate_level(peak_company_value))

	if company_value != previous_value:
		EventBus.company_value_changed.emit(
			company_value,
			company_value - previous_value
		)
	if company_level != previous_level:
		EventBus.company_level_changed.emit(company_level, previous_level)


func get_next_level_threshold() -> int:
	if company_level >= LEVEL_THRESHOLDS.size():
		return -1
	return LEVEL_THRESHOLDS[company_level]


func get_level_threshold(level: int) -> int:
	if level < 1 or level > LEVEL_THRESHOLDS.size():
		return -1
	return LEVEL_THRESHOLDS[level - 1]


func get_max_level() -> int:
	return LEVEL_THRESHOLDS.size()


func get_fleet_asset_value() -> int:
	var total := 0
	for ship_id in FleetManager.get_all_ship_ids():
		var ship_data := FleetManager.get_ship_data(ship_id)
		if ship_data == null:
			continue
		total += ship_data.get_company_value(
			FleetManager.get_ship_speed_level(ship_id),
			FleetManager.get_ship_capacity_level(ship_id)
		)
	return maxi(total, 0)


func get_port_asset_value() -> int:
	var total := 0
	for port_id in PortManager.get_unlocked_port_ids():
		var port_data := PortManager.get_port_data(port_id)
		if port_data == null:
			continue
		total += port_data.get_company_value(PortManager.get_level(port_id))
	return maxi(total, 0)


func get_save_state() -> Dictionary:
	return {
		"peak_company_value": peak_company_value,
		"company_level": company_level,
	}


func apply_save_state(saved: Dictionary) -> void:
	var previous_value := company_value
	var previous_level := company_level
	company_value = _calculate_asset_value()
	peak_company_value = maxi(
		maxi(int(saved.get("peak_company_value", 0)), company_value),
		0
	)
	company_level = maxi(
		clampi(int(saved.get("company_level", 1)), 1, get_max_level()),
		_calculate_level(peak_company_value)
	)
	EventBus.company_value_changed.emit(
		company_value,
		company_value - previous_value
	)
	if company_level != previous_level:
		EventBus.company_level_changed.emit(company_level, previous_level)


func reset_state() -> void:
	var previous_value := company_value
	var previous_level := company_level
	company_value = 0
	peak_company_value = 0
	company_level = 1
	EventBus.company_value_changed.emit(0, -previous_value)
	if previous_level != company_level:
		EventBus.company_level_changed.emit(company_level, previous_level)


func _calculate_asset_value() -> int:
	return get_fleet_asset_value() + get_port_asset_value()


func _calculate_level(value: int) -> int:
	var result := 1
	for threshold_index in range(LEVEL_THRESHOLDS.size()):
		if value < LEVEL_THRESHOLDS[threshold_index]:
			break
		result = threshold_index + 1
	return result


func _on_assets_changed(_ship_id: StringName) -> void:
	recalculate()


func _on_ship_purchased(
		_ship_id: StringName,
		_ship_data: ShipData,
		_home_port_id: StringName
) -> void:
	recalculate()


func _on_ship_speed_upgraded(
		_ship_id: StringName,
		_new_level: int,
		_new_speed: float
) -> void:
	recalculate()


func _on_ship_capacity_upgraded(
		_ship_id: StringName,
		_new_level: int,
		_new_capacity: int
) -> void:
	recalculate()


func _on_port_unlocked(_port_id: StringName) -> void:
	recalculate()


func _on_port_leveled_up(_port_id: StringName, _new_level: int) -> void:
	recalculate()
