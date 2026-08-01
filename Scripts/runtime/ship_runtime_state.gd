class_name ShipRuntimeState
extends RefCounted
## Per-ship runtime state, owned by FleetManager. Plays the same role for
## ships that PortRuntimeState plays for ports: the part of a ship that
## changes during play (what it's doing, where it is, what it's carrying),
## while the ship's fixed traits (speed, capacity, icon) stay on the
## read-only ShipData resource.

enum State {
	IDLE,                 ## Docked, unassigned, ready for a new mission.
	SAILING_TO_PICKUP,    ## En route to current_mission's pickup port.
	LOADING,              ## Docked at the pickup port, loading cargo.
	SAILING_TO_DELIVERY,  ## En route to current_mission's delivery port.
	UNLOADING,            ## Docked at the delivery port, unloading cargo.
}

var ship_id: StringName
var model_id: StringName
var speed_level: int = 0
var capacity_level: int = 0
var state: State = State.IDLE

## The port this ship is currently docked at (when IDLE/LOADING/UNLOADING)
## or departed from (the sailing leg's origin, while SAILING_*).
var current_port_id: StringName = &""

## The berth reserved for this ship. A sailing ship reserves its destination
## berth before departure, so ships already at that port never need to move
## when it arrives.
var dock_port_id: StringName = &""
var dock_slot_index: int = -1

## Null while IDLE. In Phase 4, MissionManager creates and owns Mission
## instances; FleetManager only holds a reference while a ship is working
## one, exactly like a real job being "checked out" by whichever ship
## picked it up.
var current_mission: Mission = null


func to_dict() -> Dictionary:
	return {
		"ship_id": String(ship_id),
		"model_id": String(model_id),
		"speed_level": speed_level,
		"capacity_level": capacity_level,
		"state": state,
		"current_port_id": String(current_port_id),
		"dock_port_id": String(dock_port_id),
		"dock_slot_index": dock_slot_index,
		"current_mission": (current_mission.to_dict() if current_mission != null else null),
	}


static func from_dict(data: Dictionary) -> ShipRuntimeState:
	var s := ShipRuntimeState.new()
	s.ship_id = StringName(data.get("ship_id", ""))
	s.model_id = StringName(data.get("model_id", ""))
	s.speed_level = maxi(int(data.get("speed_level", 0)), 0)
	s.capacity_level = maxi(int(data.get("capacity_level", 0)), 0)
	s.state = data.get("state", State.IDLE) as State
	s.current_port_id = StringName(data.get("current_port_id", ""))
	# Older saves have no berth fields. FleetManager assigns their first free
	# berth after all ships have been restored.
	s.dock_port_id = StringName(data.get("dock_port_id", s.current_port_id))
	s.dock_slot_index = int(data.get("dock_slot_index", -1))
	var mission_data = data.get("current_mission", null)
	s.current_mission = Mission.from_dict(mission_data) if mission_data != null else null
	return s
