extends Node2D

@onready var _money_label: Label = $UI/MoneyLabel
@onready var _instruction_label: Label = $UI/InstructionLabel
@onready var _mission_offer_panel: MissionOfferPanel = $UI/MissionOfferPanel
@onready var _fleet_status_panel: FleetStatusPanel = $UI/FleetStatusPanel
@onready var _world_camera: WorldCamera = $Camera2D

var _selected_ship_id: StringName = &""
var _open_mission_port_id: StringName = &""
var _mission_offers: Array[Mission] = []
var _fleet_refresh_elapsed := 0.0

const MAP_SHIP_TAP_RADIUS_PX := 48.0


func _input(event: InputEvent) -> void:
	var screen_position := Vector2.ZERO
	var is_pointer_press := false
	if event is InputEventMouseButton:
		is_pointer_press = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		screen_position = event.position
	elif event is InputEventScreenTouch:
		is_pointer_press = event.pressed
		screen_position = event.position
	if not is_pointer_press or _is_ui_at_screen_position(screen_position):
		return
	if try_select_ship_at_screen_position(screen_position):
		get_viewport().set_input_as_handled()


func try_select_ship_at_screen_position(screen_position: Vector2) -> bool:
	var canvas_transform := get_viewport().get_canvas_transform()
	var nearest_ship_id: StringName = &""
	var nearest_distance_squared := MAP_SHIP_TAP_RADIUS_PX * MAP_SHIP_TAP_RADIUS_PX
	for ship_id in FleetManager.get_all_ship_ids():
		var ship_node := FleetManager.get_ship_node(ship_id) as Ship
		if ship_node == null or not ship_node.is_visible_in_tree():
			continue
		var ship_screen_position := canvas_transform * ship_node.global_position
		var distance_squared := screen_position.distance_squared_to(ship_screen_position)
		if distance_squared <= nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_ship_id = ship_id
	if nearest_ship_id == &"":
		return false
	EventBus.ship_tapped.emit(nearest_ship_id)
	return true


func _is_ui_at_screen_position(screen_position: Vector2) -> bool:
	for candidate in $UI.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control != null and control.is_visible_in_tree() \
				and control.mouse_filter != Control.MOUSE_FILTER_IGNORE \
				and control.get_global_rect().has_point(screen_position):
			return true
	return false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#256BB8"))
	# Ships and ports can occupy the same dock position. Sorted, first-only
	# picking guarantees that the higher-z ship receives the tap.
	get_viewport().physics_object_picking_sort = true
	get_viewport().physics_object_picking_first_only = true

	EventBus.money_changed.connect(_on_money_changed)
	EventBus.mission_offers_updated.connect(_on_mission_offers_updated)
	EventBus.port_unlocked.connect(_on_port_unlocked)
	EventBus.port_unlock_failed.connect(_on_port_unlock_failed)
	EventBus.port_tapped.connect(_on_port_tapped)
	EventBus.ship_purchased.connect(_on_ship_purchased)
	EventBus.ship_tapped.connect(_on_ship_tapped)
	EventBus.ship_speed_upgraded.connect(_on_ship_speed_upgraded)
	EventBus.ship_capacity_upgraded.connect(_on_ship_capacity_upgraded)
	EventBus.ship_upgrade_failed.connect(_on_ship_upgrade_failed)
	EventBus.fleet_capacity_reached.connect(_on_fleet_capacity_reached)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.offline_progress_applied.connect(_on_offline_progress_applied)
	_mission_offer_panel.offer_accepted.connect(_on_offer_accepted)
	_mission_offer_panel.dismissed.connect(_on_mission_panel_dismissed)
	_fleet_status_panel.ship_selected.connect(_on_fleet_ship_selected)
	_fleet_status_panel.speed_upgrade_requested.connect(_on_speed_upgrade_requested)
	_fleet_status_panel.capacity_upgrade_requested.connect(_on_capacity_upgrade_requested)

	_update_money(GameManager.money)
	_instruction_label.text = "Görevleri görmek için haritadaki veya filo panelindeki bir gemiyi seç."
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()


func _process(delta: float) -> void:
	_fleet_refresh_elapsed += delta
	if _fleet_refresh_elapsed < 0.25:
		return
	_fleet_refresh_elapsed = 0.0
	_refresh_fleet_panel()


func _on_money_changed(new_amount: int, _delta: int) -> void:
	_update_money(new_amount)


func _on_mission_offers_updated(offers: Array) -> void:
	_mission_offers.clear()
	for offer in offers:
		if offer is Mission:
			_mission_offers.append(offer)
	_update_mission_markers()
	if _open_mission_port_id != &"":
		_show_port_offers(_open_mission_port_id)


func _on_offer_accepted(offer_id: String) -> void:
	_open_mission_port_id = &""
	_mission_offer_panel.close_panel()
	if MissionManager.accept_offer(offer_id):
		_instruction_label.text = "Görev başladı. Gemi rotasına otomatik ilerliyor."
	_update_mission_markers()


func _on_mission_panel_dismissed() -> void:
	_open_mission_port_id = &""


func _on_fleet_ship_selected(ship_id: StringName) -> void:
	EventBus.ship_tapped.emit(ship_id)


func _on_speed_upgrade_requested(ship_id: StringName) -> void:
	GameManager.try_upgrade_ship_speed(ship_id)


func _on_capacity_upgrade_requested(ship_id: StringName) -> void:
	GameManager.try_upgrade_ship_capacity(ship_id)


func _on_ship_speed_upgraded(ship_id: StringName, new_level: int, new_speed: float) -> void:
	_instruction_label.text = "%s hız seviyesi %d oldu (%.0f hız)." % [ship_id, new_level, new_speed]
	_refresh_fleet_panel()


func _on_ship_capacity_upgraded(ship_id: StringName, new_level: int, new_capacity: int) -> void:
	_instruction_label.text = "%s kapasite seviyesi %d oldu (%d birim)." % [
		ship_id,
		new_level,
		new_capacity,
	]
	_refresh_fleet_panel()


func _on_ship_upgrade_failed(ship_id: StringName, required_amount: int, current_amount: int) -> void:
	_instruction_label.text = "%s geliştirmesi için %d ₺ eksik." % [
		ship_id,
		required_amount - current_amount,
	]


func _on_fleet_capacity_reached(current_count: int, maximum_count: int) -> void:
	_instruction_label.text = "Filo kapasitesi dolu: %d/%d gemi." % [current_count, maximum_count]


func _on_ship_tapped(ship_id: StringName) -> void:
	_selected_ship_id = ship_id
	_open_mission_port_id = &""
	_mission_offer_panel.close_panel()
	_fleet_status_panel.select_ship(ship_id)
	_refresh_fleet_panel()
	_update_mission_markers()
	var ship_data := FleetManager.get_ship_data(ship_id)
	var ship_name := ship_data.display_name if ship_data != null else String(ship_id)
	if FleetManager.get_ship_state(ship_id) == ShipRuntimeState.State.IDLE:
		_instruction_label.text = "%s seçildi. Görev işareti bulunan bir limana dokun." % ship_name
	else:
		_instruction_label.text = "%s şu anda görevde." % ship_name


func _on_port_tapped(port_id: StringName) -> void:
	if not PortManager.is_unlocked(port_id):
		return
	if _selected_ship_id == &"":
		_instruction_label.text = "Önce görev vereceğin gemiyi seç."
		return
	_show_port_offers(port_id)


func _update_money(amount: int) -> void:
	_money_label.text = "%d ₺" % amount


func _on_port_unlocked(port_id: StringName) -> void:
	var port_data: PortData = PortManager.get_port_data(port_id)
	var port_name := port_data.display_name if port_data != null else String(port_id)
	_instruction_label.text = "%s limanı açıldı!" % port_name
	_update_mission_markers()


func _on_port_unlock_failed(port_id: StringName, required_amount: int, current_amount: int) -> void:
	var port_data: PortData = PortManager.get_port_data(port_id)
	var port_name := port_data.display_name if port_data != null else String(port_id)
	_instruction_label.text = "%s için %d ₺ gerekli. Eksik: %d ₺" % [
		port_name,
		required_amount,
		required_amount - current_amount,
	]


func _on_ship_purchased(
		ship_id: StringName,
		ship_data: ShipData,
		home_port_id: StringName
) -> void:
	_spawn_ship(ship_id, ship_data, home_port_id)
	_instruction_label.text = "%s filoya katıldı!" % ship_data.display_name
	_refresh_fleet_panel()


func _on_game_loaded() -> void:
	for ship_id in FleetManager.get_all_ship_ids():
		if FleetManager.get_ship_node(ship_id) != null:
			continue
		var ship_data := FleetManager.get_ship_data(ship_id)
		var home_port_id := FleetManager.get_ship_current_port(ship_id)
		_spawn_ship(ship_id, ship_data, home_port_id)
	_update_money(GameManager.money)
	_on_mission_offers_updated(MissionManager.get_offers())
	_refresh_fleet_panel()


func _on_offline_progress_applied(elapsed_sec: float) -> void:
	if elapsed_sec >= 60.0:
		_instruction_label.text = "Çevrimdışı ilerleme uygulandı: %d dakika." % floori(elapsed_sec / 60.0)


func _spawn_ship(
		ship_id: StringName,
		ship_data: ShipData,
		home_port_id: StringName
) -> void:
	if FleetManager.get_ship_node(ship_id) != null:
		return
	if ship_data == null or ship_data.scene == null:
		return
	var ship := ship_data.scene.instantiate() as Ship
	if ship == null:
		return
	ship.name = String(ship_id)
	ship.ship_id = ship_id
	ship.ship_data = ship_data
	ship.home_port_id = home_port_id
	add_child(ship)


func _refresh_fleet_panel() -> void:
	var entries: Array[Dictionary] = []
	var ship_ids := FleetManager.get_all_ship_ids()

	for ship_id in ship_ids:
		var ship_data := FleetManager.get_ship_data(ship_id)
		var state := FleetManager.get_ship_state(ship_id)
		var mission := FleetManager.get_ship_mission(ship_id)
		var remaining_sec := FleetManager.get_ship_mission_remaining_sec(ship_id)
		var has_mission := mission != null
		var progress := 0.0
		var route_text := "Limanda: %s" % String(FleetManager.get_ship_current_port(ship_id))
		var cargo_text := "Yük yok"
		if mission != null:
			var total_duration := maxf(mission.estimated_duration_sec, 0.001)
			progress = clampf(1.0 - remaining_sec / total_duration, 0.0, 1.0)
			route_text = "%s → %s" % [mission.pickup_port_id, mission.delivery_port_id]
			cargo_text = "Kargo: %s" % String(mission.cargo_type_id)
		entries.append({
			"ship_id": String(ship_id),
			"display_name": ship_data.display_name if ship_data != null else String(ship_id),
			"state_text": _get_ship_state_text(state),
			"route_text": route_text,
			"cargo_text": cargo_text,
			"remaining_sec": remaining_sec,
			"progress": progress,
			"has_mission": has_mission,
			"speed_level": FleetManager.get_ship_speed_level(ship_id),
			"effective_speed": FleetManager.get_ship_effective_speed(ship_id),
			"speed_upgrade_cost": FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"can_afford_speed_upgrade": GameManager.money >= FleetManager.get_ship_speed_upgrade_cost(ship_id),
			"capacity_level": FleetManager.get_ship_capacity_level(ship_id),
			"effective_capacity": FleetManager.get_ship_effective_capacity(ship_id),
			"capacity_upgrade_cost": FleetManager.get_ship_capacity_upgrade_cost(ship_id),
			"can_afford_capacity_upgrade": GameManager.money >= FleetManager.get_ship_capacity_upgrade_cost(ship_id),
		})
	_fleet_status_panel.set_fleet_data(entries, _selected_ship_id)


func _show_port_offers(port_id: StringName) -> void:
	var matching_offers: Array[Mission] = []
	for offer in _mission_offers:
		if offer.offered_ship_id == _selected_ship_id and offer.pickup_port_id == port_id:
			matching_offers.append(offer)
	if matching_offers.is_empty():
		_open_mission_port_id = &""
		_mission_offer_panel.close_panel()
		_instruction_label.text = "Seçili gemi için bu limanda uygun görev yok."
		return
	_open_mission_port_id = port_id
	var title := "%s limanındaki yükler" % String(port_id)
	_mission_offer_panel.show_offers(matching_offers, title)


func _update_mission_markers() -> void:
	for port_id in PortManager.get_all_port_ids():
		var offer_count := 0
		if _selected_ship_id != &"":
			for offer in _mission_offers:
				if offer.offered_ship_id == _selected_ship_id and offer.pickup_port_id == port_id:
					offer_count += 1
		var port_node := PortManager.get_port_node(port_id) as Port
		if port_node != null:
			port_node.set_mission_offer_count(offer_count)


func _get_ship_state_text(state: ShipRuntimeState.State) -> String:
	match state:
		ShipRuntimeState.State.SAILING_TO_PICKUP:
			return "Yük almaya gidiyor"
		ShipRuntimeState.State.LOADING:
			return "Yükleniyor"
		ShipRuntimeState.State.SAILING_TO_DELIVERY:
			return "Teslimata gidiyor"
		ShipRuntimeState.State.UNLOADING:
			return "Boşaltılıyor"
		_:
			return "Boşta"
