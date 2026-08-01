class_name PortData
extends Resource
## Static, designer-authored definition of a single port. One .tres resource
## per port, created via the Godot editor (right-click FileSystem > New
## Resource > PortData). This is what makes "no hardcoded PortA/PortB" real:
## adding a new port to the game is "create a new .tres and drag it onto a
## Port scene instance in the World" — zero new code, zero new branches.

## Unique, stable identifier used for save data and manager lookups.
## Do NOT rename this after release; it is the save-compatible key.
## Convention: lowercase_snake_case, e.g. &"rotterdam".
@export var id: StringName = &""

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## Currency cost to unlock this port for the first time.
@export var base_unlock_cost: int = 0

## If true, this port starts unlocked on a brand new game
## (this is how "player starts with 2 unlocked ports" is expressed —
## as data, not as code).
@export var unlocked_by_default: bool = false

## Cost to upgrade FROM level N TO level N+1.
## Index 0 = cost of the 1st upgrade (level 1 -> 2), index 1 = 2nd, etc.
## A short/empty array simply means "no further upgrades authored yet" —
## that's a valid, permanent state for a port if you want, not an error.
@export var level_upgrade_costs: Array[int] = []

## Reward multiplier applied by EconomyManager for missions touching this
## port, indexed by level. Index 0 = level 1. Extend as upgrade tiers grow.
@export var level_reward_multipliers: Array[float] = [1.0]

## Local offsets for ships waiting at this port. Author these on the water
## side of the coast. FleetManager assigns docked ships deterministically by
## ship id, so slot indexes never need to enter save data.
@export var dock_slot_offsets: PackedVector2Array = PackedVector2Array()


## Returns the cost to upgrade from current_level to current_level + 1,
## or -1 if no further upgrade is defined for this port.
func get_upgrade_cost(current_level: int) -> int:
	var index := current_level - 1
	if index < 0 or index >= level_upgrade_costs.size():
		return -1
	return level_upgrade_costs[index]


## Returns the reward multiplier for the given level, clamped to the last
## authored tier if the level exceeds the array (so it degrades gracefully
## instead of erroring if you add levels before adding multiplier data).
func get_reward_multiplier(level: int) -> float:
	if level_reward_multipliers.is_empty():
		return 1.0
	var index := clampi(level - 1, 0, level_reward_multipliers.size() - 1)
	return level_reward_multipliers[index]


func get_dock_slot_offset(slot_index: int) -> Vector2:
	if dock_slot_offsets.is_empty():
		return Vector2.ZERO
	return dock_slot_offsets[clampi(slot_index, 0, dock_slot_offsets.size() - 1)]
