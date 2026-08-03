extends Node

var money: int = 0


func _ready() -> void:
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.port_tapped.connect(_on_port_tapped)


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	EventBus.money_changed.emit(money, amount)


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	EventBus.money_changed.emit(money, -amount)
	return true


func try_unlock_port(port_id: StringName) -> bool:
	var port_data: PortData = PortManager.get_port_data(port_id)
	if port_data == null or PortManager.is_unlocked(port_id):
		return false
	if CompanyManager.company_level < port_data.required_company_level:
		EventBus.company_level_requirement_failed.emit(
			&"port",
			port_id,
			port_data.required_company_level,
			CompanyManager.company_level
		)
		return false

	var cost := maxi(port_data.base_unlock_cost, 0)
	if not spend_money(cost):
		EventBus.port_unlock_failed.emit(port_id, cost, money)
		return false

	if PortManager.unlock_port(port_id):
		return true

	# Keep the transaction atomic if the port could not be unlocked.
	add_money(cost)
	return false


func try_purchase_ship(model_id: StringName, home_port_id: StringName) -> bool:
	if FleetManager.is_fleet_at_capacity():
		EventBus.fleet_capacity_reached.emit(
			FleetManager.get_all_ship_ids().size(),
			FleetManager.get_fleet_capacity()
		)
		return false
	var ship_data := FleetManager.get_ship_model(model_id)
	if ship_data == null:
		return false
	if CompanyManager.company_level < ship_data.required_company_level:
		EventBus.company_level_requirement_failed.emit(
			&"ship",
			model_id,
			ship_data.required_company_level,
			CompanyManager.company_level
		)
		return false
	var cost := FleetManager.get_ship_purchase_price(model_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		EventBus.ship_purchase_failed.emit(model_id, cost, money)
		return false

	var ship_id := FleetManager.purchase_ship(model_id, home_port_id)
	if ship_id != &"":
		return true

	add_money(cost)
	return false


func try_upgrade_ship_speed(ship_id: StringName) -> bool:
	var cost := FleetManager.get_ship_speed_upgrade_cost(ship_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		EventBus.ship_upgrade_failed.emit(ship_id, cost, money)
		return false
	if FleetManager.upgrade_ship_speed(ship_id):
		return true
	add_money(cost)
	return false


func try_upgrade_ship_capacity(ship_id: StringName) -> bool:
	var cost := FleetManager.get_ship_capacity_upgrade_cost(ship_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		EventBus.ship_upgrade_failed.emit(ship_id, cost, money)
		return false
	if FleetManager.upgrade_ship_capacity(ship_id):
		return true
	add_money(cost)
	return false


func _on_mission_completed(mission: Mission) -> void:
	add_money(mission.reward)


func _on_port_tapped(port_id: StringName) -> void:
	if not PortManager.is_unlocked(port_id):
		try_unlock_port(port_id)


func get_save_state() -> Dictionary:
	return {"money": money}


func apply_save_state(saved: Dictionary) -> void:
	var previous := money
	money = maxi(int(saved.get("money", 0)), 0)
	EventBus.money_changed.emit(money, money - previous)


func reset_state() -> void:
	apply_save_state({"money": 0})
