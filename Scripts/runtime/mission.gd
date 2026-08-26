class_name Mission
extends RefCounted
## Runtime record of a single cargo mission.
##
## Deliberately NOT a Resource. PortData/CargoTypeData/ShipData are static
## assets you author in the editor; a Mission is generated at runtime and
## needs to be saved/loaded as plain data (see to_dict/from_dict), so a
## lightweight RefCounted is the right tool — no editor-asset baggage,
## no accidental sharing of a single instance across multiple missions.
##
## Every port/cargo/ship reference below is an id (StringName), never a
## direct Node or Resource reference. That keeps Mission serializable and
## decoupled from however the World scene happens to be laid out.

enum Stage {
	AWAITING_PICKUP,     ## Generated, not yet accepted by a ship.
	SAILING_TO_PICKUP,   ## A ship has accepted it and is en route to pickup_port_id.
	LOADING,             ## Ship docked at pickup_port_id, loading cargo.
	SAILING_TO_DELIVERY, ## Cargo loaded, ship en route to delivery_port_id.
	UNLOADING,           ## Ship docked at delivery_port_id, unloading cargo.
	COMPLETED,           ## Delivered and paid out.
}

enum DurationClass {
	SHORT,
	MEDIUM,
	LONG,
}

var id: String
## Port where the offered ship was waiting when this mission was generated.
## This distinguishes a local pickup from an empty repositioning leg.
var origin_port_id: StringName
var pickup_port_id: StringName
var delivery_port_id: StringName
var cargo_type_id: StringName
var cargo_amount: int = 1
## Gross payment before the mission's operating cost is deducted.
var reward: int
var operating_cost: int = 0
var estimated_duration_sec: float = 0.0
## Time spent handling cargo at the pickup port center before departure.
var loading_duration_sec: float = 3.0
## Time spent handling cargo at the delivery port before moving to a berth.
var unloading_duration_sec: float = 3.0
var duration_class: DurationClass = DurationClass.SHORT
var stage: Stage = Stage.AWAITING_PICKUP

## Ship selected for this offer. This makes multi-ship offers explicit and
## keeps the estimated duration tied to the ship whose speed produced it.
var offered_ship_id: StringName = &""

## Empty StringName while the mission is still unassigned.
var assigned_ship_id: StringName = &""

## Unix timestamps for the CURRENT leg only (pickup or delivery, whichever is
## active). This is the piece that makes idle/offline income possible later:
## "where is this ship right now" is `leg_start_unix + elapsed` compared
## against `leg_duration_sec`, computable at any point in the future,
## including after the app was closed and reopened — no per-frame tick
## history required.
var leg_start_unix: float = 0.0
var leg_duration_sec: float = 0.0


func start_leg(duration_sec: float, start_unix: float = -1.0) -> void:
	leg_start_unix = Time.get_unix_time_from_system() if start_unix < 0 else start_unix
	leg_duration_sec = duration_sec


## Returns 0.0..1.0 progress through the current leg, clamped, based purely
## on wall-clock time — works identically whether the app was open the
## whole time or backgrounded for six hours.
func get_leg_progress() -> float:
	return get_leg_progress_at(Time.get_unix_time_from_system())


func get_leg_progress_at(unix_time: float) -> float:
	if leg_duration_sec <= 0.0:
		return 1.0
	var elapsed: float = unix_time - leg_start_unix
	return clampf(elapsed / leg_duration_sec, 0.0, 1.0)


func is_leg_complete() -> bool:
	return get_leg_progress() >= 1.0


func is_leg_complete_at(unix_time: float) -> bool:
	return get_leg_progress_at(unix_time) >= 1.0


func get_net_reward() -> int:
	return reward - operating_cost


func to_dict() -> Dictionary:
	return {
		"id": id,
		"origin_port_id": String(origin_port_id),
		"pickup_port_id": String(pickup_port_id),
		"delivery_port_id": String(delivery_port_id),
		"cargo_type_id": String(cargo_type_id),
		"cargo_amount": cargo_amount,
		"reward": reward,
		"operating_cost": operating_cost,
		"estimated_duration_sec": estimated_duration_sec,
		"loading_duration_sec": loading_duration_sec,
		"unloading_duration_sec": unloading_duration_sec,
		"duration_class": duration_class,
		"stage": stage,
		"offered_ship_id": String(offered_ship_id),
		"assigned_ship_id": String(assigned_ship_id),
		"leg_start_unix": leg_start_unix,
		"leg_duration_sec": leg_duration_sec,
	}


static func from_dict(data: Dictionary) -> Mission:
	var mission := Mission.new()
	mission.id = data.get("id", "")
	mission.origin_port_id = StringName(data.get("origin_port_id", ""))
	mission.pickup_port_id = StringName(data.get("pickup_port_id", ""))
	mission.delivery_port_id = StringName(data.get("delivery_port_id", ""))
	mission.cargo_type_id = StringName(data.get("cargo_type_id", ""))
	mission.cargo_amount = maxi(int(data.get("cargo_amount", 1)), 1)
	mission.reward = maxi(int(data.get("reward", 0)), 0)
	mission.operating_cost = maxi(int(data.get("operating_cost", 0)), 0)
	mission.estimated_duration_sec = data.get("estimated_duration_sec", 0.0)
	mission.loading_duration_sec = maxf(float(data.get("loading_duration_sec", 1.7)), 0.0)
	mission.unloading_duration_sec = maxf(
		float(data.get("unloading_duration_sec", 1.7)),
		0.0
	)
	mission.duration_class = data.get("duration_class", DurationClass.SHORT) as DurationClass
	mission.stage = data.get("stage", Stage.AWAITING_PICKUP) as Stage
	mission.offered_ship_id = StringName(data.get("offered_ship_id", ""))
	mission.assigned_ship_id = StringName(data.get("assigned_ship_id", ""))
	mission.leg_start_unix = float(data.get("leg_start_unix", 0.0))
	mission.leg_duration_sec = data.get("leg_duration_sec", 0.0)
	return mission
