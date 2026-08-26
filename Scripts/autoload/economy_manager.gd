extends Node
## Stateless economy formulas. This manager calculates values but owns no
## player state, which keeps balancing changes isolated and testable.

const SHIP_PRICE_GROWTH := 1.6
const SHIP_SPEED_PER_LEVEL := 0.15
const EMPTY_SHIP_SPEED_MULTIPLIER := 1.10
const LOADED_SPEED_PENALTY_PER_CARGO_UNIT := 0.05
const MAX_LOADED_SPEED_PENALTY := 0.20
const SHIP_SPEED_UPGRADE_COST_GROWTH := 1.7
const SHIP_CAPACITY_UPGRADE_COST_GROWTH := 1.8
const EXTRA_CARGO_REWARD_BONUS := 0.25
const PORT_TIER_REWARD_MULTIPLIERS: Array[float] = [1.0, 1.08, 1.16, 1.25]
## First balance target: operating costs should be visible in the mission
## choice without making any early offer unprofitable.
const FUEL_UNIT_PRICE := 2.5


func calculate_mission_reward(
		pickup_port_id: StringName,
		delivery_port_id: StringName,
		cargo_type: CargoTypeData,
		cargo_amount: int = 1
) -> int:
	var distance: float = PortManager.get_distance(pickup_port_id, delivery_port_id)
	var cargo_value: int = cargo_type.base_value if cargo_type != null else 100
	var port_pair_multiplier := _get_port_pair_reward_multiplier(
		pickup_port_id,
		delivery_port_id
	)
	var distance_reward: float = distance * 0.5
	var amount_multiplier := 1.0 + EXTRA_CARGO_REWARD_BONUS * maxi(cargo_amount - 1, 0)
	return maxi(roundi(
		(cargo_value + distance_reward)
		* amount_multiplier
		* port_pair_multiplier
	), 1)


func _get_port_pair_reward_multiplier(
		pickup_port_id: StringName,
		delivery_port_id: StringName
) -> float:
	var pickup_data: PortData = PortManager.get_port_data(pickup_port_id)
	var delivery_data: PortData = PortManager.get_port_data(delivery_port_id)
	if pickup_data == null or delivery_data == null:
		return 1.0

	# Average both ends and apply the result once. Multiplying the two ports
	# independently would make late-game tiers and upgrades grow too quickly.
	var tier_multiplier := (
		_get_port_tier_multiplier(pickup_data)
		+ _get_port_tier_multiplier(delivery_data)
	) * 0.5
	var upgrade_multiplier := (
		pickup_data.get_reward_multiplier(PortManager.get_level(pickup_port_id))
		+ delivery_data.get_reward_multiplier(PortManager.get_level(delivery_port_id))
	) * 0.5
	return tier_multiplier * upgrade_multiplier


func _get_port_tier_multiplier(port_data: PortData) -> float:
	var tier_index := clampi(
		port_data.economic_tier - 1,
		0,
		PORT_TIER_REWARD_MULTIPLIERS.size() - 1
	)
	return PORT_TIER_REWARD_MULTIPLIERS[tier_index]


func calculate_mission_operating_cost(
		origin_port_id: StringName,
		pickup_port_id: StringName,
		delivery_port_id: StringName,
		ship_data: ShipData
) -> int:
	if ship_data == null:
		return 0
	var total_distance := PortManager.get_distance(pickup_port_id, delivery_port_id)
	if origin_port_id != &"" and origin_port_id != pickup_port_id:
		total_distance += PortManager.get_distance(origin_port_id, pickup_port_id)
	var fuel_used := total_distance * maxf(ship_data.fuel_consumption_per_distance, 0.0)
	return maxi(roundi(fuel_used * FUEL_UNIT_PRICE), 0)


func calculate_ship_purchase_price(base_cost: int, owned_ship_count: int) -> int:
	var safe_base_cost := maxi(base_cost, 0)
	var safe_owned_count := maxi(owned_ship_count, 0)
	var raw_price := safe_base_cost * pow(SHIP_PRICE_GROWTH, safe_owned_count)
	return maxi(roundi(raw_price / 10.0) * 10, safe_base_cost)


func calculate_ship_speed(base_speed: float, speed_level: int) -> float:
	return maxf(base_speed, 1.0) * (1.0 + SHIP_SPEED_PER_LEVEL * maxi(speed_level, 0))


func calculate_ship_sailing_speed(effective_speed: float, cargo_amount: int) -> float:
	var safe_speed := maxf(effective_speed, 1.0)
	if cargo_amount <= 0:
		return safe_speed * EMPTY_SHIP_SPEED_MULTIPLIER
	var load_penalty := minf(
		maxi(cargo_amount, 0) * LOADED_SPEED_PENALTY_PER_CARGO_UNIT,
		MAX_LOADED_SPEED_PENALTY
	)
	return safe_speed * (1.0 - load_penalty)


func calculate_ship_speed_upgrade_cost(base_cost: int, speed_level: int) -> int:
	var safe_base_cost := maxi(base_cost, 0)
	var raw_cost := safe_base_cost * pow(
		SHIP_SPEED_UPGRADE_COST_GROWTH,
		maxi(speed_level, 0)
	)
	return maxi(roundi(raw_cost / 10.0) * 10, safe_base_cost)


func calculate_ship_capacity_upgrade_cost(base_cost: int, capacity_level: int) -> int:
	var safe_base_cost := maxi(base_cost, 0)
	var raw_cost := safe_base_cost * pow(
		SHIP_CAPACITY_UPGRADE_COST_GROWTH,
		maxi(capacity_level, 0)
	)
	return maxi(roundi(raw_cost / 10.0) * 10, safe_base_cost)
