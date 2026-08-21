class_name CompanyHeadquarters
extends Node2D

@onready var _delivery_berth: Marker2D = $DeliveryBerth
@onready var _label: Label = $Label


func _ready() -> void:
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	_refresh_label()


func get_delivery_position() -> Vector2:
	return _delivery_berth.global_position


func _on_language_changed(_locale: String) -> void:
	_refresh_label()


func _refresh_label() -> void:
	_label.text = tr("COMPANY_HEADQUARTERS")
