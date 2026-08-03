class_name CompanyHeadquarters
extends Node2D

@onready var _delivery_berth: Marker2D = $DeliveryBerth


func get_delivery_position() -> Vector2:
	return _delivery_berth.global_position
