class_name SeaRouteData
extends Resource

## Static designer-authored sea corridor between two ports. Waypoints do not
## include the port positions; those are resolved from PortManager at runtime.
@export var from_port_id: StringName = &""
@export var to_port_id: StringName = &""
@export var waypoints: PackedVector2Array = PackedVector2Array()


func is_valid() -> bool:
	return from_port_id != &"" and to_port_id != &"" and from_port_id != to_port_id
