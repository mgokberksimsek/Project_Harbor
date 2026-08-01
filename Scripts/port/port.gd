class_name Port
extends Area2D

@export var port_data: PortData

@onready var _icon: Sprite2D = $Icon
@onready var _name_label: Label = $NameLabel
@onready var _status_label: Label = $StatusLabel
@onready var _mission_badge: Button = $MissionBadge

const LOCKED_TINT := Color(0.35, 0.35, 0.35)


func _ready() -> void:
	if port_data == null:
		push_error("Port instance '%s' has no PortData assigned in the Inspector." % name)
		return

	if port_data.icon != null:
		_icon.texture = port_data.icon
	_name_label.text = port_data.display_name

	PortManager.register_port(port_data, self)

	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_leveled_up.connect(_on_port_leveled_up)
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
