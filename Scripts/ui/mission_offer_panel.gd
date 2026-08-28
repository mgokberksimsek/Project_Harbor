class_name MissionOfferPanel
extends PanelContainer

signal offer_accepted(offer_id: String)
signal dismissed()

@onready var _title: Label = $Margin/VBox/Header/Title
@onready var _close_button: Button = $Margin/VBox/Header/CloseButton
@onready var _buttons: Array[Button] = [
	$Margin/VBox/Cards/Offer1,
	$Margin/VBox/Cards/Offer2,
	$Margin/VBox/Cards/Offer3,
]

var _offers: Array[Mission] = []
var _tutorial_focused := false
var _tutorial_pulse_elapsed := 0.0

const TUTORIAL_PULSE_SPEED := 4.0


func _ready() -> void:
	for index in range(_buttons.size()):
		_buttons[index].pressed.connect(_on_offer_pressed.bind(index))
	_close_button.pressed.connect(_on_close_pressed)
	get_node("/root/EventBus").language_changed.connect(_on_language_changed)
	set_offers([], false)
	hide()


func _process(delta: float) -> void:
	if not _tutorial_focused or not visible:
		return
	_tutorial_pulse_elapsed += delta
	var pulse := (sin(_tutorial_pulse_elapsed * TUTORIAL_PULSE_SPEED) + 1.0) * 0.5
	var focus_color := Color(1.0, 0.78 + pulse * 0.22, 0.5, 0.78 + pulse * 0.22)
	for button in _buttons:
		if not button.disabled:
			button.modulate = focus_color


func show_offers(offers: Array, title: String) -> void:
	_title.text = title
	set_offers(offers, true)
	show()


func close_panel() -> void:
	hide()
	set_tutorial_focus(false)


func set_offers(offers: Array, has_idle_ship: bool) -> void:
	_offers.clear()
	for offer in offers:
		if offer is Mission:
			_offers.append(offer)

	for index in range(_buttons.size()):
		var button := _buttons[index]
		var has_offer := index < _offers.size()
		button.disabled = not has_idle_ship or not has_offer
		button.modulate = Color.WHITE if not button.disabled else Color(1.0, 1.0, 1.0, 0.5)
		button.text = _format_offer(_offers[index]) if has_offer else tr("MISSION_WAITING")


func set_tutorial_focus(enabled: bool) -> void:
	_tutorial_focused = enabled
	if not enabled:
		_tutorial_pulse_elapsed = 0.0
		for button in _buttons:
			button.modulate = Color.WHITE if not button.disabled \
				else Color(1.0, 1.0, 1.0, 0.5)


func is_tutorial_focused() -> bool:
	return _tutorial_focused


func _on_language_changed(_locale: String) -> void:
	set_offers(_offers.duplicate(), true)


func _on_offer_pressed(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	for button in _buttons:
		button.disabled = true
	offer_accepted.emit(_offers[index].id)


func _on_close_pressed() -> void:
	hide()
	dismissed.emit()


func _format_offer(mission: Mission) -> String:
	var pickup_data := PortManager.get_port_data(mission.pickup_port_id)
	var delivery_data := PortManager.get_port_data(mission.delivery_port_id)
	var cargo_data := MissionManager.get_cargo_type(mission.cargo_type_id)
	var route_text := "%s → %s" % [
		_translate_entity("PORT", mission.pickup_port_id, pickup_data.display_name),
		_translate_entity("PORT", mission.delivery_port_id, delivery_data.display_name),
	]
	var contract_label := ""
	if mission.is_large_contract():
		var route_names: PackedStringArray = []
		for port_id in mission.contract_port_ids:
			var port_data := PortManager.get_port_data(port_id)
			if port_data != null:
				route_names.append(_translate_entity(
					"PORT",
					port_id,
					port_data.display_name
				))
		route_text = " → ".join(route_names)
		contract_label = "%s\n" % [
			tr("MISSION_LARGE_CONTRACT") % mission.get_delivery_count()
		]
	return "%s%s\n%s ×%d · %s\n%s" % [
		contract_label,
		route_text,
		_translate_entity("CARGO", mission.cargo_type_id, cargo_data.display_name),
		mission.cargo_amount,
		_format_duration(mission.estimated_duration_sec),
		tr("MISSION_FINANCIALS") % [
			mission.get_net_reward(),
			mission.reward,
			mission.operating_cost,
		],
	]


func _format_duration(duration_sec: float) -> String:
	var total_seconds := maxi(ceili(duration_sec), 0)
	if total_seconds < 60:
		return tr("DURATION_SECONDS") % total_seconds
	return tr("DURATION_MINUTES") % [total_seconds / 60, total_seconds % 60]


func _translate_entity(prefix: String, entity_id: StringName, fallback: String) -> String:
	var key := StringName("%s_%s" % [prefix, String(entity_id).to_upper()])
	var translated := TranslationServer.translate(key)
	return fallback if translated == String(key) else translated
