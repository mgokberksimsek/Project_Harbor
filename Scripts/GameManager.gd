extends Node

enum TutorialStep {
	SELECT_SHIP,
	SELECT_MISSION_PORT,
	ACCEPT_MISSION,
	COMPLETED,
	PURCHASE_SHIP,
	OPEN_COMPANY_PROGRESS,
	READ_COMPANY_VALUE_INFO,
	OPEN_SHIP_SHOP,
	WELCOME_CAPTAIN,
}

var money: int = 0
var tutorial_step: TutorialStep = TutorialStep.OPEN_SHIP_SHOP

@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _port_manager: Node = get_node("/root/PortManager")
@onready var _fleet_manager: Node = get_node("/root/FleetManager")
@onready var _company_manager: Node = get_node("/root/CompanyManager")


func _ready() -> void:
	money = _get_starting_cash()
	_event_bus.mission_completed.connect(_on_mission_completed)
	_event_bus.ship_purchased.connect(_on_ship_purchased)


func add_money(amount: int) -> void:
	if amount == 0:
		return
	money += amount
	_event_bus.money_changed.emit(money, amount)


func spend_money(amount: int) -> bool:
	if amount < 0 or money < amount:
		return false
	money -= amount
	_event_bus.money_changed.emit(money, -amount)
	return true


func try_unlock_port(port_id: StringName) -> bool:
	var port_data: PortData = _port_manager.get_port_data(port_id)
	if port_data == null or _port_manager.is_unlocked(port_id):
		return false
	if _company_manager.company_level < port_data.required_company_level:
		_event_bus.company_level_requirement_failed.emit(
			&"port",
			port_id,
			port_data.required_company_level,
			_company_manager.company_level
		)
		return false

	var cost := maxi(port_data.base_unlock_cost, 0)
	if not spend_money(cost):
		_event_bus.port_unlock_failed.emit(port_id, cost, money)
		return false

	if _port_manager.unlock_port(port_id):
		return true

	# Keep the transaction atomic if the port could not be unlocked.
	add_money(cost)
	return false


func try_purchase_ship(model_id: StringName, home_port_id: StringName) -> bool:
	if _fleet_manager.is_fleet_at_capacity():
		_event_bus.fleet_capacity_reached.emit(
			_fleet_manager.get_all_ship_ids().size(),
			_fleet_manager.get_fleet_capacity()
		)
		return false
	var ship_data = _fleet_manager.get_ship_model(model_id)
	if ship_data == null:
		return false
	if _company_manager.company_level < ship_data.required_company_level:
		_event_bus.company_level_requirement_failed.emit(
			&"ship",
			model_id,
			ship_data.required_company_level,
			_company_manager.company_level
		)
		return false
	var cost: int = _fleet_manager.get_ship_purchase_price(model_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		_event_bus.ship_purchase_failed.emit(model_id, cost, money)
		return false

	var ship_id: StringName = _fleet_manager.purchase_ship(model_id, home_port_id)
	if ship_id != &"":
		return true

	add_money(cost)
	return false


func try_upgrade_ship_speed(ship_id: StringName) -> bool:
	var cost: int = _fleet_manager.get_ship_speed_upgrade_cost(ship_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		_event_bus.ship_upgrade_failed.emit(ship_id, cost, money)
		return false
	if _fleet_manager.upgrade_ship_speed(ship_id):
		return true
	add_money(cost)
	return false


func try_upgrade_ship_capacity(ship_id: StringName) -> bool:
	var cost: int = _fleet_manager.get_ship_capacity_upgrade_cost(ship_id)
	if cost < 0:
		return false
	if not spend_money(cost):
		_event_bus.ship_upgrade_failed.emit(ship_id, cost, money)
		return false
	if _fleet_manager.upgrade_ship_capacity(ship_id):
		return true
	add_money(cost)
	return false


func _on_mission_completed(mission: Mission) -> void:
	add_money(mission.reward)


func _on_ship_purchased(
	_ship_id: StringName,
	_ship_data: ShipData,
	_home_port_id: StringName
) -> void:
	if tutorial_step == TutorialStep.PURCHASE_SHIP:
		set_tutorial_step(TutorialStep.OPEN_COMPANY_PROGRESS)


func set_tutorial_step(new_step: TutorialStep) -> void:
	if tutorial_step == new_step:
		return
	var previous := tutorial_step
	tutorial_step = new_step
	_event_bus.tutorial_step_changed.emit(tutorial_step, previous)


func is_tutorial_completed() -> bool:
	return tutorial_step == TutorialStep.COMPLETED


func get_save_state() -> Dictionary:
	return {
		"money": money,
		"tutorial_step": tutorial_step,
	}


func apply_save_state(saved: Dictionary) -> void:
	var previous := money
	money = maxi(int(saved.get("money", 0)), 0)
	_event_bus.money_changed.emit(money, money - previous)
	var default_tutorial_step := TutorialStep.OPEN_SHIP_SHOP
	if not saved.is_empty() and not saved.has("tutorial_step"):
		# Existing saves created before the tutorial should not be forced back
		# through first-time onboarding.
		default_tutorial_step = TutorialStep.COMPLETED
	var saved_tutorial_step := int(saved.get("tutorial_step", default_tutorial_step))
	if saved_tutorial_step < TutorialStep.SELECT_SHIP \
			or saved_tutorial_step > TutorialStep.WELCOME_CAPTAIN:
		saved_tutorial_step = TutorialStep.OPEN_SHIP_SHOP
	set_tutorial_step(saved_tutorial_step as TutorialStep)


func reset_state() -> void:
	apply_save_state({
		"money": _get_starting_cash(),
		"tutorial_step": TutorialStep.OPEN_SHIP_SHOP,
	})


func _get_starting_cash() -> int:
	var initial_ship = _fleet_manager.get_initial_ship_model()
	return maxi(initial_ship.purchase_cost, 0) if initial_ship != null else 0
