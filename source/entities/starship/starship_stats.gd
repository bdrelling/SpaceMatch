class_name StarshipStats
extends EntityStats
## A starship's stat profile — an [EntityStats] with typed sugar for the starship's stats. The
## [member EntityStats.values] dictionary is the storage and the math ([method EntityStats.add],
## [method EntityStats.get_stat]); these typed accessors are convenience over it. A module authors one as its +/-
## contribution when slotted; summing the blocks of a starship's slotted modules ([method EntityStats.add]) gives
## the starship's stat profile.

var power: int:
	get:
		var value: int = values.get(&"power", 0)
		return value
	set(value):
		values[&"power"] = value
var speed: int:
	get:
		var value: int = values.get(&"speed", 0)
		return value
	set(value):
		values[&"speed"] = value
var cargo: int:
	get:
		var value: int = values.get(&"cargo", 0)
		return value
	set(value):
		values[&"cargo"] = value
var fuel: int:
	get:
		var value: int = values.get(&"fuel", 0)
		return value
	set(value):
		values[&"fuel"] = value
var armor: int:
	get:
		var value: int = values.get(&"armor", 0)
		return value
	set(value):
		values[&"armor"] = value
var shields: int:
	get:
		var value: int = values.get(&"shields", 0)
		return value
	set(value):
		values[&"shields"] = value
var sensors: int:
	get:
		var value: int = values.get(&"sensors", 0)
		return value
	set(value):
		values[&"sensors"] = value
var life_support: int:
	get:
		var value: int = values.get(&"life_support", 0)
		return value
	set(value):
		values[&"life_support"] = value
var damage: int:
	get:
		var value: int = values.get(&"damage", 0)
		return value
	set(value):
		values[&"damage"] = value
var energy: int:
	get:
		var value: int = values.get(&"energy", 0)
		return value
	set(value):
		values[&"energy"] = value
## Bars of warp meter a starship can hold — its warp-bar capacity, granted by a warp-core module. Zero means the
## starship can't warp at all (no Jump, and warp tiles don't spawn for it). Summed from modules like any stat.
var warp_capacity: int:
	get:
		var value: int = values.get(&"warp_capacity", 0)
		return value
	set(value):
		values[&"warp_capacity"] = value
## Hit points this block contributes — the starship's hull. A base block carries the starting health; a hull/armor
## module can add more. The encounter's starting max health is seeded from the effective total.
var health: int:
	get:
		var value: int = values.get(&"health", 0)
		return value
	set(value):
		values[&"health"] = value
