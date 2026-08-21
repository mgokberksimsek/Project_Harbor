extends Node

enum TutorialStep {
	SELECT_SHIP,
	SELECT_MISSION_PORT,
	ACCEPT_MISSION,
	COMPLETED,
	PURCHASE_SHIP,
}

var money: int = 0
var tutorial_step: TutorialStep = TutorialStep.PURCHASE_SHIP


func _ready() -> void:
	money = _get_starting_cash()
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.ship_purchased.connect(_on_ship_purchased)


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


func _on_ship_purchased(
		_ship_id: StringName,
		_ship_data: ShipData,
		_home_port_id: StringName
) -> void:
	if tutorial_step == TutorialStep.PURCHASE_SHIP:
		set_tutorial_step(TutorialStep.SELECT_SHIP)


func set_tutorial_step(new_step: TutorialStep) -> void:
	if tutorial_step == new_step:
		return
	var previous := tutorial_step
	tutorial_step = new_step
	EventBus.tutorial_step_changed.emit(tutorial_step, previous)


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
	EventBus.money_changed.emit(money, money - previous)
	var default_tutorial_step := TutorialStep.PURCHASE_SHIP
	if not saved.is_empty() and not saved.has("tutorial_step"):
		# Existing saves created before the tutorial should not be forced back
		# through first-time onboarding.
		default_tutorial_step = TutorialStep.COMPLETED
	var saved_tutorial_step := int(saved.get("tutorial_step", default_tutorial_step))
	if saved_tutorial_step < TutorialStep.SELECT_SHIP \
			or saved_tutorial_step > TutorialStep.PURCHASE_SHIP:
		saved_tutorial_step = TutorialStep.PURCHASE_SHIP
	set_tutorial_step(saved_tutorial_step as TutorialStep)


func reset_state() -> void:
	apply_save_state({
		"money": _get_starting_cash(),
		"tutorial_step": TutorialStep.PURCHASE_SHIP,
	})


func _get_starting_cash() -> int:
	var initial_ship := FleetManager.get_initial_ship_model()
	return maxi(initial_ship.purchase_cost, 0) if initial_ship != null else 0
