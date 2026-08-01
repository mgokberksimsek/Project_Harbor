class_name Port
extends Area2D

@export var port_data: PortData

@onready var _icon: Sprite2D = $Icon
@onready var _selection_outline: Sprite2D = $Icon/SelectionOutline
@onready var _name_label: Label = $NameLabel
@onready var _status_label: Label = $StatusLabel
@onready var _mission_badge: Button = $MissionBadge

const LOCKED_TINT := Color(0.35, 0.35, 0.35)
const SELECTED_SCALE_MULTIPLIER := 1.05
const SELECTION_SCALE_TWEEN_SEC := 0.16

var _base_icon_scale := Vector2.ONE
var _selection_scale_tween: Tween = null


func _ready() -> void:
	if port_data == null:
		push_error("Port instance '%s' has no PortData assigned in the Inspector." % name)
		return

	if port_data.icon != null:
		_icon.texture = port_data.icon
	_base_icon_scale = _icon.scale
	_selection_outline.texture = _icon.texture
	_name_label.text = port_data.display_name

	PortManager.register_port(port_data, self)

	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_leveled_up.connect(_on_port_leveled_up)
	EventBus.port_selection_changed.connect(_on_port_selection_changed)
	input_event.connect(_on_input_event)
	_mission_badge.pressed.connect(_on_mission_badge_pressed)

	_refresh_visuals()


func _on_port_unlocked(port_id: StringName) -> void:
	if port_id == port_data.id:
		_refresh_visuals()


func _on_port_leveled_up(port_id: StringName, _new_level: int) -> void:
	if port_id == port_data.id:
		_refresh_visuals()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var touch_pressed: bool = event is InputEventScreenTouch and event.pressed
	var mouse_pressed: bool = event is InputEventMouseButton and event.pressed
	if touch_pressed or mouse_pressed:
		EventBus.port_tapped.emit(port_data.id)


func _on_mission_badge_pressed() -> void:
	EventBus.port_tapped.emit(port_data.id)


func _on_port_selection_changed(selected_port_id: StringName) -> void:
	var is_selected := selected_port_id == port_data.id
	_selection_outline.visible = is_selected
	if _selection_scale_tween != null and _selection_scale_tween.is_valid():
		_selection_scale_tween.kill()
	var target_scale := _base_icon_scale * (
		SELECTED_SCALE_MULTIPLIER if is_selected else 1.0
	)
	_selection_scale_tween = create_tween()
	_selection_scale_tween.set_trans(Tween.TRANS_QUAD)
	_selection_scale_tween.set_ease(Tween.EASE_OUT)
	_selection_scale_tween.tween_property(
		_icon,
		"scale",
		target_scale,
		SELECTION_SCALE_TWEEN_SEC
	)


func set_mission_offer_count(count: int) -> void:
	var safe_count := maxi(count, 0)
	_mission_badge.visible = safe_count > 0
	_mission_badge.text = str(safe_count)


func _refresh_visuals() -> void:
	var unlocked := PortManager.is_unlocked(port_data.id)
	_icon.modulate = Color.WHITE if unlocked else LOCKED_TINT

	if unlocked:
		_status_label.text = "Lv. %d" % PortManager.get_level(port_data.id)
	else:
		_status_label.text = "Locked - %d" % port_data.base_unlock_cost
