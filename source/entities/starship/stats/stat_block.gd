class_name StatBlock
extends Resource
## A vector of ship-stat contributions. A module authors one as its +/- effect when slotted; summing
## the blocks of a ship's slotted modules ([method add]) gives the ship's stat profile.

@export var power: int = 0
@export var speed: int = 0
@export var cargo: int = 0
@export var fuel: int = 0
@export var armor: int = 0
@export var shields: int = 0
@export var sensors: int = 0
@export var life_support: int = 0
@export var damage: int = 0
@export var scrap: int = 0
@export var anomaly: int = 0

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
		Stat.Type.SCRAP: return scrap
		Stat.Type.ANOMALY: return anomaly
	return 0

## Sums [param other]'s contributions into this block.
func add(other: StatBlock) -> void:
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
	scrap += other.scrap
	anomaly += other.anomaly
