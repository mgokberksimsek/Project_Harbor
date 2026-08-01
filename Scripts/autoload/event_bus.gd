extends Node
## Global signal bus (register as an autoload named "EventBus").
##
## Rule for the whole project: managers EMIT here, they never call each
## other's methods directly. UI, stats tracking, and future systems
## (WeatherManager, AchievementManager, ...) subscribe here instead of being
## wired into MissionManager/FleetManager/etc. by hand. This is the one
## piece of plumbing that keeps "add a new system" from turning into
## "edit five existing files".
##
## Register this BEFORE any other autoload in Project Settings > Autoload —
## everything else assumes EventBus already exists.

# --- Economy -----------------------------------------------------------
signal money_changed(new_amount: int, delta: int)

# --- Ports ---------------------------------------------------------------
signal port_unlocked(port_id: StringName)
signal port_unlock_failed(port_id: StringName, required_amount: int, current_amount: int)
signal port_leveled_up(port_id: StringName, new_level: int)
signal port_tapped(port_id: StringName) ## Player tapped a port on the map.
signal port_selection_changed(port_id: StringName)

# --- Missions --------------------------------------------------------------
signal mission_offers_changed(offers: Array)
signal mission_offers_updated(offers: Array)
signal mission_generated(mission: Mission)
signal mission_stage_changed(mission: Mission)
signal mission_completed(mission: Mission)

# --- Fleet / ships ---------------------------------------------------------
signal ship_tapped(ship_id: StringName)
signal ship_selection_changed(ship_id: StringName)
signal ship_registered(ship_id: StringName)
signal ship_purchased(ship_id: StringName, ship_data: ShipData, home_port_id: StringName)
signal ship_purchase_failed(model_id: StringName, required_amount: int, current_amount: int)
signal fleet_capacity_reached(current_count: int, maximum_count: int)
signal ship_speed_upgraded(ship_id: StringName, new_level: int, new_speed: float)
signal ship_upgrade_failed(ship_id: StringName, required_amount: int, current_amount: int)
signal ship_capacity_upgraded(ship_id: StringName, new_level: int, new_capacity: int)
signal ship_arrived_at_port(ship_id: StringName, port_id: StringName)
signal ship_state_changed(ship_id: StringName, previous_state: int, new_state: int)
signal ship_dock_slot_changed(
	ship_id: StringName,
	port_id: StringName,
	previous_slot_index: int,
	new_slot_index: int
)

# --- Game flow ---------------------------------------------------------
signal game_loaded()
signal game_saved()
signal offline_progress_applied(elapsed_sec: float)
