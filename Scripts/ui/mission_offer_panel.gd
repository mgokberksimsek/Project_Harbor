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


func _ready() -> void:
	for index in range(_buttons.size()):
		_buttons[index].pressed.connect(_on_offer_pressed.bind(index))
	_close_button.pressed.connect(_on_close_pressed)
	set_offers([], false)
	hide()


func show_offers(offers: Array, title: String) -> void:
	_title.text = title
	set_offers(offers, true)
	show()


func close_panel() -> void:
	hide()


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
		button.text = _format_offer(_offers[index]) if has_offer else "Görev bekleniyor..."


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
	return "%s → %s    %d ₺\n%s ×%d · %s" % [
		String(mission.pickup_port_id),
		String(mission.delivery_port_id),
		mission.reward,
		String(mission.cargo_type_id),
		mission.cargo_amount,
		_format_duration(mission.estimated_duration_sec),
	]


func _format_duration(duration_sec: float) -> String:
	var total_seconds := maxi(ceili(duration_sec), 0)
	if total_seconds < 60:
		return "%d sn" % total_seconds
	return "%d dk %02d sn" % [total_seconds / 60, total_seconds % 60]
