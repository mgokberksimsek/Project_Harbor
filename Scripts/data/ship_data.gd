class_name ShipData
extends Resource
## Static definition of a ship "model". Even though the game launches with a
## single starting ship, defining this as data now means "add a second,
## faster ship type later" is a new .tres file assigned to a FleetManager
## purchase entry — not a refactor of Ship.gd.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

## Direction the authored sprite's bow faces at zero rotation, measured from
## the positive X axis. Current ship art faces down, which is PI / 2.
@export var sprite_forward_angle_rad: float = PI / 2.0

## Visual scale is independent from the ship's generous mobile tap area.
@export_range(0.1, 2.0, 0.05) var sprite_scale: float = 0.8

## The Ship scene to instantiate for this ship model. Keeping this as data
## (rather than always instancing the same Ship.tscn) is what lets
## visually/mechanically distinct ship models exist side by side later.
@export var scene: PackedScene

@export var base_speed: float = 100.0 ## px/sec at world map scale.
@export var speed_upgrade_base_cost: int = 250
@export var max_speed_level: int = 5
@export var cargo_capacity: int = 1
@export var capacity_upgrade_base_cost: int = 300
@export var max_capacity_level: int = 3

## Capability tags decide which cargo classes this ship can carry.
## They deliberately use data IDs rather than a hardcoded enum so new cargo
## classes can be added without changing game code.
@export var cargo_capabilities: Array[StringName] = [&"general"]

## Reserved for the future fuel system. 0 = unlimited/not yet in use, so
## existing ship data stays valid the day fuel is switched on.
@export var fuel_capacity: float = 0.0
@export var fuel_consumption_per_distance: float = 0.0

## Cost to purchase/unlock this ship model, if it isn't owned from the start.
@export var purchase_cost: int = 0
@export var unlocked_by_default: bool = false

## Company progression values are authored independently from Cash prices so
## price inflation never causes Company Value inflation.
@export var base_company_value: int = 0
@export var speed_upgrade_company_value: int = 0
@export var capacity_upgrade_company_value: int = 0
@export_range(1, 15, 1) var required_company_level: int = 1


func can_carry(cargo_type: CargoTypeData) -> bool:
	if cargo_type == null:
		return false
	for requirement in cargo_type.required_capabilities:
		if not cargo_capabilities.has(requirement):
			return false
	return true


func get_company_value(speed_level: int, capacity_level: int) -> int:
	return maxi(base_company_value, 0) \
		+ maxi(speed_level, 0) * maxi(speed_upgrade_company_value, 0) \
		+ maxi(capacity_level, 0) * maxi(capacity_upgrade_company_value, 0)
