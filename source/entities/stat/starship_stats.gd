class_name StarshipStats
extends StatBlock
## A starship's stat profile — a [StatBlock] with typed sugar for the starship's stats. The [member StatBlock.values]
## dictionary is the storage and the math ([method StatBlock.add], [method StatBlock.get_stat]); these typed
## accessors are convenience over it. A module authors one as its +/- contribution when slotted; summing the blocks
## of a starship's slotted modules ([method StatBlock.add]) gives the starship's stat profile.

var power: int:
	get:
		return values.get(&"power", 0)
	set(value):
		values[&"power"] = value
var speed: int:
	get:
		return values.get(&"speed", 0)
	set(value):
		values[&"speed"] = value
var cargo: int:
	get:
		return values.get(&"cargo", 0)
	set(value):
		values[&"cargo"] = value
var fuel: int:
	get:
		return values.get(&"fuel", 0)
	set(value):
		values[&"fuel"] = value
var armor: int:
	get:
		return values.get(&"armor", 0)
	set(value):
		values[&"armor"] = value
var shields: int:
	get:
		return values.get(&"shields", 0)
	set(value):
		values[&"shields"] = value
var sensors: int:
	get:
		return values.get(&"sensors", 0)
	set(value):
		values[&"sensors"] = value
var life_support: int:
	get:
		return values.get(&"life_support", 0)
	set(value):
		values[&"life_support"] = value
var damage: int:
	get:
		return values.get(&"damage", 0)
	set(value):
		values[&"damage"] = value
var energy: int:
	get:
		return values.get(&"energy", 0)
	set(value):
		values[&"energy"] = value
## Bars of warp meter a starship can hold — its warp-bar capacity, granted by a warp-core module. Zero means the
## starship can't warp at all (no Jump, and warp tiles don't spawn for it). Summed from modules like any stat.
var warp_capacity: int:
	get:
		return values.get(&"warp_capacity", 0)
	set(value):
		values[&"warp_capacity"] = value
## Hit points this block contributes — the starship's hull. A base block carries the starting health; a hull/armor
## module can add more. The encounter's starting max health is seeded from the effective total.
var health: int:
	get:
		return values.get(&"health", 0)
	set(value):
		values[&"health"] = value
