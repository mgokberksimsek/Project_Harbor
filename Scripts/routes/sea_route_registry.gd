class_name SeaRouteRegistry
extends Node

@export var routes: Array[SeaRouteData] = []


func _enter_tree() -> void:
	for route in routes:
		PortManager.register_sea_route(route)
