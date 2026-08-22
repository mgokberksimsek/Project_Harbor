class_name CompanyHeadquarters
extends Node2D

const TIER_MIN_LEVELS: Array[int] = [1, 3, 6, 10]
const TIER_HEIGHTS: Array[float] = [124.0, 172.0, 232.0, 300.0]
const TIER_WIDTHS: Array[float] = [176.0, 184.0, 164.0, 148.0]
const TIER_WINDOW_ROWS: Array[int] = [1, 2, 4, 6]
const BUILDING_BOTTOM := 62.0
const WINDOW_SIZE := Vector2(34.0, 28.0)
const WINDOW_COLOR := Color(0.38, 0.72, 0.86, 1.0)
const PIER_WIDTHS: Array[float] = [28.0, 32.0, 36.0, 40.0]
const PIER_CONNECTION_Y := 25.0
const PIER_MIDDLE_OFFSET := Vector2(55.0, -70.0)
const PIER_DELIVERY_POSITION := Vector2(155.0, -180.0)

@onready var _delivery_berth: Marker2D = $DeliveryBerth
@onready var _label: Label = $Label
@onready var _building_shadow: Polygon2D = $BuildingShadow
@onready var _building: Polygon2D = $Building
@onready var _roof: Polygon2D = $Roof
@onready var _door: Polygon2D = $Door
@onready var _window_layer: Node2D = $WindowLayer
@onready var _pier: Line2D = $Pier
@onready var _pier_edge: Line2D = $PierEdge

var _visual_tier := 1


func _ready() -> void:
	var event_bus := get_node("/root/EventBus")
	event_bus.language_changed.connect(_on_language_changed)
	event_bus.company_level_changed.connect(_on_company_level_changed)
	_apply_company_level(CompanyManager.company_level)
	_refresh_label()


func get_delivery_position() -> Vector2:
	return _delivery_berth.global_position


func get_visual_tier() -> int:
	return _visual_tier


func _on_language_changed(_locale: String) -> void:
	_refresh_label()


func _on_company_level_changed(new_level: int, _previous_level: int) -> void:
	_apply_company_level(new_level)
	_refresh_label()


func _refresh_label() -> void:
	_label.text = tr("COMPANY_HEADQUARTERS_LEVEL") % CompanyManager.company_level


func _apply_company_level(company_level: int) -> void:
	_visual_tier = _get_tier_for_level(company_level)
	var tier_index := _visual_tier - 1
	var width := TIER_WIDTHS[tier_index]
	var top := BUILDING_BOTTOM - TIER_HEIGHTS[tier_index]
	var half_width := width * 0.5
	var building_polygon := PackedVector2Array([
		Vector2(-half_width, top),
		Vector2(half_width, top),
		Vector2(half_width, BUILDING_BOTTOM),
		Vector2(-half_width, BUILDING_BOTTOM),
	])
	_building.polygon = building_polygon
	_building_shadow.polygon = building_polygon
	_building.color = Color(0.86, 0.88, 0.82).lerp(
		Color(0.76, 0.84, 0.88),
		float(tier_index) / float(TIER_MIN_LEVELS.size() - 1)
	)
	_roof.position = Vector2.ZERO
	_roof.polygon = PackedVector2Array([
		Vector2(-half_width - 16.0, top),
		Vector2(0.0, top - 54.0),
		Vector2(half_width + 16.0, top),
		Vector2(half_width - 10.0, top + 24.0),
		Vector2(-half_width + 10.0, top + 24.0),
	])
	_door.position = Vector2(0.0, 25.0)
	_rebuild_windows(width, TIER_WINDOW_ROWS[tier_index])
	_update_delivery_pier(width, tier_index)


func _get_tier_for_level(company_level: int) -> int:
	var result := 1
	for tier_index in range(TIER_MIN_LEVELS.size()):
		if company_level < TIER_MIN_LEVELS[tier_index]:
			break
		result = tier_index + 1
	return result


func _rebuild_windows(building_width: float, row_count: int) -> void:
	for child in _window_layer.get_children():
		child.free()
	var horizontal_offset := building_width * 0.28
	for row_index in range(row_count):
		var window_y := 4.0 - float(row_index) * 43.0
		_add_window(Vector2(-horizontal_offset, window_y))
		_add_window(Vector2(horizontal_offset, window_y))


func _update_delivery_pier(building_width: float, tier_index: int) -> void:
	var half_width := building_width * 0.5
	var pier_start := Vector2(
		half_width - 10.0,
		PIER_CONNECTION_Y
	)
	var pier_points := PackedVector2Array([
		pier_start,
		pier_start + PIER_MIDDLE_OFFSET,
		PIER_DELIVERY_POSITION,
	])
	_pier.points = pier_points
	_pier_edge.points = pier_points
	_pier.width = PIER_WIDTHS[tier_index]
	_pier_edge.width = maxf(4.0, _pier.width * 0.14)
	_delivery_berth.position = pier_points[pier_points.size() - 1]


func _add_window(window_position: Vector2) -> void:
	var window := Polygon2D.new()
	var half_size := WINDOW_SIZE * 0.5
	window.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	window.position = window_position
	window.color = WINDOW_COLOR
	_window_layer.add_child(window)
