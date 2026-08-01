class_name CargoTypeData
extends Resource
## Static, designer-authored definition of a cargo type. Add a new cargo
## type (containers, oil, livestock, whatever) by creating a new .tres —
## no code changes, no enum to extend, no switch statement to update.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D

## Base value used by EconomyManager as an input to the reward formula.
@export var base_value: int = 100

## Relative spawn weight when MissionManager rolls a random cargo type for
## a new mission. Higher = more common. Set to 0 to temporarily disable a
## cargo type (e.g. gate it behind a later unlock) without deleting it.
@export var spawn_weight: float = 1.0

## Data-driven ship requirements such as &"general", &"refrigerated",
## &"liquid", &"hazardous", or &"heavy". A cargo may require more than one.
@export var required_capabilities: Array[StringName] = [&"general"]
