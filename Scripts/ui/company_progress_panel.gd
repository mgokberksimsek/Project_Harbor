class_name CompanyProgressPanel
extends PanelContainer

signal closed()

@onready var _title: Label = $Margin/VBox/Title
@onready var _level_label: Label = $Margin/VBox/Level
@onready var _total_label: Label = $Margin/VBox/TotalValue
@onready var _fleet_label: Label = $Margin/VBox/Breakdown/FleetValue
@onready var _ports_label: Label = $Margin/VBox/Breakdown/PortValue
@onready var _progress_bar: ProgressBar = $Margin/VBox/ProgressBar
@onready var _progress_label: Label = $Margin/VBox/ProgressText
@onready var _next_unlocks_label: Label = $Margin/VBox/NextUnlocks
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _level := 1
var _value := 0
var _current_threshold := 0
var _next_threshold := -1
var _fleet_value := 0
var _port_value := 0
var _next_unlocks: Array[String] = []


func _ready() -> void:
	_close_button.pressed.connect(close_panel)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	hide()


func show_progress(
		level: int,
		value: int,
		current_threshold: int,
		next_threshold: int,
		fleet_value: int,
		port_value: int,
		next_unlocks: Array[String]
) -> void:
	_level = maxi(level, 1)
	_value = maxi(value, 0)
	_current_threshold = maxi(current_threshold, 0)
	_next_threshold = next_threshold
	_fleet_value = maxi(fleet_value, 0)
	_port_value = maxi(port_value, 0)
	_next_unlocks = next_unlocks.duplicate()
	_refresh()
	show()


func close_panel() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func _on_language_changed(_locale: String) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_title.text = tr("COMPANY_PANEL_TITLE")
	_level_label.text = tr("COMPANY_PANEL_LEVEL") % _level
	_total_label.text = tr("COMPANY_PANEL_TOTAL") % _value
	_fleet_label.text = tr("COMPANY_PANEL_FLEET") % _fleet_value
	_ports_label.text = tr("COMPANY_PANEL_PORTS") % _port_value
	_close_button.text = tr("COMPANY_PANEL_CLOSE")

	if _next_threshold < 0:
		_progress_bar.min_value = 0
		_progress_bar.max_value = 1
		_progress_bar.value = 1
		_progress_label.text = tr("COMPANY_PANEL_MAX")
		_next_unlocks_label.text = tr("COMPANY_PANEL_ALL_UNLOCKED")
		return

	_progress_bar.min_value = _current_threshold
	_progress_bar.max_value = maxi(_next_threshold, _current_threshold + 1)
	_progress_bar.value = clampi(_value, _current_threshold, _next_threshold)
	_progress_label.text = tr("COMPANY_PANEL_PROGRESS") % [
		_value,
		_next_threshold,
		maxi(_next_threshold - _value, 0),
	]
	if _next_unlocks.is_empty():
		_next_unlocks_label.text = tr("COMPANY_PANEL_NEXT_NONE") % (_level + 1)
	else:
		_next_unlocks_label.text = tr("COMPANY_PANEL_NEXT_UNLOCKS") % [
			_level + 1,
			", ".join(_next_unlocks),
		]
