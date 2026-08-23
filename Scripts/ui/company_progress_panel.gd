class_name CompanyProgressPanel
extends PanelContainer

signal closed()
signal company_value_info_confirmed()

const TUTORIAL_PULSE_SPEED := 4.0

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _info_button: Button = $Margin/VBox/Header/InfoButton
@onready var _level_label: Label = $Margin/VBox/Level
@onready var _total_label: Label = $Margin/VBox/TotalValue
@onready var _fleet_label: Label = $Margin/VBox/Breakdown/FleetValue
@onready var _ports_label: Label = $Margin/VBox/Breakdown/PortValue
@onready var _progress_bar: ProgressBar = $Margin/VBox/ProgressBar
@onready var _progress_label: Label = $Margin/VBox/ProgressText
@onready var _next_unlocks_label: Label = $Margin/VBox/NextUnlocks
@onready var _close_button: Button = $Margin/VBox/CloseButton
@onready var _info_dialog: AcceptDialog = $InfoDialog

var _level := 1
var _value := 0
var _current_threshold := 0
var _next_threshold := -1
var _fleet_value := 0
var _port_value := 0
var _next_unlocks: Array[String] = []
var _info_tutorial_focused := false
var _info_tutorial_elapsed := 0.0


func _ready() -> void:
	_close_button.pressed.connect(close_panel)
	_info_button.pressed.connect(_show_company_value_info)
	_info_dialog.confirmed.connect(_on_company_value_info_confirmed)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	hide()


func _process(delta: float) -> void:
	if not _info_tutorial_focused or not visible:
		_info_tutorial_elapsed = 0.0
		_info_button.modulate = Color.WHITE
		_info_button.scale = Vector2.ONE
		return
	_info_tutorial_elapsed += delta
	var pulse := (sin(_info_tutorial_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	_info_button.pivot_offset = _info_button.size * 0.5
	_info_button.scale = Vector2.ONE * lerpf(1.0, 1.08, pulse)
	_info_button.modulate = Color.WHITE.lerp(
		Color(1.0, 0.78, 0.28, 1.0),
		lerpf(0.15, 0.5, pulse)
	)


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
	_info_dialog.hide()
	hide()
	closed.emit()


func is_open() -> bool:
	return visible


func set_info_tutorial_focus(enabled: bool) -> void:
	_info_tutorial_focused = enabled
	if not enabled:
		_info_tutorial_elapsed = 0.0
		_info_button.modulate = Color.WHITE
		_info_button.scale = Vector2.ONE


func is_info_tutorial_focused() -> bool:
	return _info_tutorial_focused


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
	_info_dialog.title = tr("COMPANY_VALUE_INFO_TITLE")
	_info_dialog.dialog_text = tr("COMPANY_PANEL_CV_EXPLANATION")
	_info_dialog.get_ok_button().text = tr("COMPANY_VALUE_INFO_OK")

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


func _show_company_value_info() -> void:
	_refresh()
	var message_label := _info_dialog.get_label()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(300, 0)
	message_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_info_dialog.popup_centered(Vector2i(340, 145))


func _on_company_value_info_confirmed() -> void:
	company_value_info_confirmed.emit()
