class_name SeaRouteData
extends Resource

## Static designer-authored sea corridor between two ports. Waypoints do not
## include the port positions; those are resolved from PortManager at runtime.
@export var from_port_id: StringName = &""
@export var to_port_id: StringName = &""
@export var waypoints: PackedVector2Array = PackedVector2Array()

## Explicit operating distance for the route. The visual map is stylized, so
## future foreign routes can be geographically far without placing their port
## nodes thousands of pixels apart. A value of 0 falls back to measured map
## distance. Duration, reward and cost all use this same value.
@export_range(0.0, 50000.0, 1.0) var gameplay_distance: float = 0.0


func is_valid() -> bool:
	return from_port_id != &"" and to_port_id != &"" and from_port_id != to_port_id
