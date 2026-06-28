class_name StarshipStats
extends StatBlock
## A vector of starship-stat contributions. A module authors one as its +/- effect when slotted; summing
## the blocks of a starship's slotted modules ([method add]) gives the starship's stat profile.

@export var power: int = 0
@export var speed: int = 0
@export var cargo: int = 0
@export var fuel: int = 0
@export var armor: int = 0
@export var shields: int = 0
@export var sensors: int = 0
@export var life_support: int = 0
@export var damage: int = 0
@export var energy: int = 0
## Bars of warp meter a starship can hold — its warp-bar capacity, granted by a warp-core module. Zero means the
## starship can't warp at all (no Jump, and warp tiles don't spawn for it). Summed from modules like any stat, so
## a bigger or second core raises it; not bound to a [Stat.Type] tile (warp is the encounter meter, not a
## banked resource).
@export var warp_capacity: int = 0
## Hit points this block contributes — the starship's hull. A starship's base block carries its starting health; a
## hull/armor module can add more. The encounter's starting max health is seeded from the effective total, so
## HP is starship-driven (chosen starship + its modules) rather than a fixed constant.
@export var health: int = 0

## This block's value for [param stat].
func value(stat: Stat.Type) -> int:
	match stat:
		Stat.Type.POWER: return power
		Stat.Type.SPEED: return speed
		Stat.Type.CARGO: return cargo
		Stat.Type.FUEL: return fuel
		Stat.Type.ARMOR: return armor
		Stat.Type.SHIELDS: return shields
		Stat.Type.SENSORS: return sensors
		Stat.Type.LIFE_SUPPORT: return life_support
		Stat.Type.DAMAGE: return damage
		Stat.Type.ENERGY: return energy
	return 0

## Adds [param amount] to this block's [param stat] (negative subtracts). The mutating counterpart of
## [method value] — used to layer a temporary buff/debuff onto a stat.
func add_value(stat: Stat.Type, amount: int) -> void:
	match stat:
		Stat.Type.POWER: power += amount
		Stat.Type.SPEED: speed += amount
		Stat.Type.CARGO: cargo += amount
		Stat.Type.FUEL: fuel += amount
		Stat.Type.ARMOR: armor += amount
		Stat.Type.SHIELDS: shields += amount
		Stat.Type.SENSORS: sensors += amount
		Stat.Type.LIFE_SUPPORT: life_support += amount
		Stat.Type.DAMAGE: damage += amount
		Stat.Type.ENERGY: energy += amount

## Sums [param other]'s contributions into this block.
func add(other: StarshipStats) -> void:
	if other == null:
		return
	power += other.power
	speed += other.speed
	cargo += other.cargo
	fuel += other.fuel
	armor += other.armor
	shields += other.shields
	sensors += other.sensors
	life_support += other.life_support
	damage += other.damage
	energy += other.energy
	warp_capacity += other.warp_capacity
	health += other.health
