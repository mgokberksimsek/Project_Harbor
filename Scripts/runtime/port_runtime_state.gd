class_name PortRuntimeState
extends RefCounted
## The part of a port's state that changes during play and must survive
## save/load: is it unlocked, what level is it. Everything else about a
## port (name, icon, unlock cost, upgrade table) lives on the read-only
## PortData resource instead — this class never duplicates that data.

var port_id: StringName
var unlocked: bool = false
var level: int = 1


func to_dict() -> Dictionary:
	return {
		"port_id": String(port_id),
		"unlocked": unlocked,
		"level": level,
	}


static func from_dict(data: Dictionary) -> PortRuntimeState:
	var state := PortRuntimeState.new()
	state.port_id = StringName(data.get("port_id", ""))
	state.unlocked = data.get("unlocked", false)
	state.level = data.get("level", 1)
	return state
