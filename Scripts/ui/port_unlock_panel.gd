class_name PortUnlockPanel
extends PanelContainer

signal unlock_requested(port_id: StringName)
signal upgrade_requested(port_id: StringName)
signal closed()

enum PanelMode { UNLOCK, UPGRADE }

@onready var _title: Label = $Margin/VBox/Title
@onready var _description: Label = $Margin/VBox/Description
@onready var _level_label: Label = $Margin/VBox/LevelRequirement
@onready var _cost_label: Label = $Margin/VBox/Cost
@onready var _value_label: Label = $Margin/VBox/CompanyValue
@onready var _unlock_button: Button = $Margin/VBox/Buttons/UnlockButton
@onready var _cancel_button: Button = $Margin/VBox/Buttons/CancelButton

var _port_id: StringName = &""
var _port_name := ""
var _description_text := ""
var _unlock_cost := 0
var _company_value := 0
var _required_level := 1
var _current_money := 0
var _current_level := 1
var _port_level := 1
var _reward_bonus_percent := 0
var _handling_reduction_percent := 0
var _mode := PanelMode.UNLOCK


func _ready() -> void:
	_unlock_button.pressed.connect(_on_unlock_pressed)
	_cancel_button.pressed.connect(close_panel)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	hide()


func show_port(
		port_id: StringName,
		port_name: String,
		description: String,
		unlock_cost: int,
		company_value: int,
		required_level: int,
		current_money: int,
		current_level: int
) -> void:
	_mode = PanelMode.UNLOCK
	_port_id = port_id
	_port_name = port_name
	_description_text = description
	_unlock_cost = maxi(unlock_cost, 0)
	_company_value = maxi(company_value, 0)
	_required_level = maxi(required_level, 1)
	_current_money = maxi(current_money, 0)
	_current_level = maxi(current_level, 1)
	_refresh()
	show()


func show_upgrade_port(
		port_id: StringName,
		port_name: String,
		current_port_level: int,
		upgrade_cost: int,
		company_value: int,
		current_money: int,
		reward_bonus_percent: int,
		handling_reduction_percent: int
) -> void:
	_mode = PanelMode.UPGRADE
	_port_id = port_id
	_port_name = port_name
	_port_level = maxi(current_port_level, 1)
	_unlock_cost = upgrade_cost
	_company_value = maxi(company_value, 0)
	_current_money = maxi(current_money, 0)
	_reward_bonus_percent = maxi(reward_bonus_percent, 0)
	_handling_reduction_percent = maxi(handling_reduction_percent, 0)
	_refresh()
	show()


func update_status(current_money: int, current_level: int) -> void:
	_current_money = maxi(current_money, 0)
	_current_level = maxi(current_level, 1)
	if visible:
		_refresh()


func close_panel() -> void:
	if not visible:
		return
	hide()
	_port_id = &""
	closed.emit()


func is_open_for(port_id: StringName) -> bool:
	return visible and _port_id == port_id


func _on_unlock_pressed() -> void:
	if _port_id == &"" or _unlock_button.disabled:
		return
	if _mode == PanelMode.UPGRADE:
		upgrade_requested.emit(_port_id)
	else:
		unlock_requested.emit(_port_id)


func _on_language_changed(_locale: String) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _mode == PanelMode.UPGRADE:
		_refresh_upgrade()
		return
	_title.text = tr("PORT_UNLOCK_TITLE") % _translated_port_name()
	_description.text = _translated_description()
	_level_label.text = tr("PORT_UNLOCK_LEVEL") % [_required_level, _current_level]
	_cost_label.text = tr("PORT_UNLOCK_COST") % [_unlock_cost, _current_money]
	_value_label.text = tr("PORT_UNLOCK_VALUE") % _company_value
	_cancel_button.text = tr("PORT_UNLOCK_CANCEL")

	var level_blocked := _current_level < _required_level
	var money_short := maxi(_unlock_cost - _current_money, 0)
	_unlock_button.disabled = level_blocked or money_short > 0
	if level_blocked:
		_unlock_button.text = tr("PORT_UNLOCK_LEVEL_BLOCKED") % _required_level
	elif money_short > 0:
		_unlock_button.text = tr("PORT_UNLOCK_MONEY_BLOCKED") % money_short
	else:
		_unlock_button.text = tr("PORT_UNLOCK_CONFIRM") % _unlock_cost


func _refresh_upgrade() -> void:
	var has_upgrade := _unlock_cost >= 0
	_title.text = tr("PORT_UPGRADE_TITLE") % [_translated_port_name(), _port_level]
	_cancel_button.text = tr("PORT_UPGRADE_CLOSE")
	if not has_upgrade:
		_description.text = tr("PORT_UPGRADE_MAX_BENEFITS") % [
			_reward_bonus_percent,
			_handling_reduction_percent,
		]
		_level_label.text = tr("PORT_UPGRADE_MAX_LEVEL") % _port_level
		_cost_label.text = tr("PORT_UPGRADE_COMPLETE")
		_value_label.text = tr("PORT_UPGRADE_TOTAL_VALUE") % _company_value
		_unlock_button.text = tr("PORT_UPGRADE_MAX_BUTTON")
		_unlock_button.disabled = true
		return

	_description.text = tr("PORT_UPGRADE_BENEFITS") % [
		_reward_bonus_percent,
		_handling_reduction_percent,
	]
	_level_label.text = tr("PORT_UPGRADE_LEVEL") % [_port_level, _port_level + 1]
	_cost_label.text = tr("PORT_UPGRADE_COST") % [_unlock_cost, _current_money]
	_value_label.text = tr("PORT_UPGRADE_VALUE") % _company_value
	var money_short := maxi(_unlock_cost - _current_money, 0)
	_unlock_button.disabled = money_short > 0
	_unlock_button.text = tr("PORT_UPGRADE_MONEY_BLOCKED") % money_short \
		if money_short > 0 else tr("PORT_UPGRADE_CONFIRM") % _unlock_cost


func _translated_port_name() -> String:
	var key := StringName("PORT_%s" % String(_port_id).to_upper())
	var translated := TranslationServer.translate(key)
	return _port_name if translated == String(key) else translated


func _translated_description() -> String:
	var key := StringName("PORT_DESCRIPTION_%s" % String(_port_id).to_upper())
	var translated := TranslationServer.translate(key)
	if translated != String(key):
		return translated
	return _description_text if not _description_text.is_empty() \
		else tr("PORT_UNLOCK_DESCRIPTION_DEFAULT")
