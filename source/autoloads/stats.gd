# AUTOLOAD: Stats
extends Node
## Typed handles to the authored starship stats (res://data/stats/*.tres) — the type-safe replacement for the old
## Stat.Type enum. Code refers to stats as Stats.power, Stats.damage, ... and binds a match tile kind to its stat
## via [method for_tile]. Each handle is the same [StarshipStat] instance the rest of the game references.

var power: StarshipStat = preload("res://data/stats/power.tres")
var speed: StarshipStat = preload("res://data/stats/speed.tres")
var cargo: StarshipStat = preload("res://data/stats/cargo.tres")
var fuel: StarshipStat = preload("res://data/stats/fuel.tres")
var armor: StarshipStat = preload("res://data/stats/armor.tres")
var shields: StarshipStat = preload("res://data/stats/shields.tres")
var sensors: StarshipStat = preload("res://data/stats/sensors.tres")
var life_support: StarshipStat = preload("res://data/stats/life_support.tres")
var damage: StarshipStat = preload("res://data/stats/damage.tres")
var energy: StarshipStat = preload("res://data/stats/energy.tres")
var warp_capacity: StarshipStat = preload("res://data/stats/warp_capacity.tres")
var health: StarshipStat = preload("res://data/stats/health.tres")


## Every starship stat, for catalog-style listing.
func all() -> Array[StarshipStat]:
	return [power, speed, cargo, fuel, armor, shields, sensors, life_support, damage, energy, warp_capacity, health]


## The stat a match tile [param kind] banks toward, or null when the tile carries no stat (scrap, warp).
func for_tile(kind: int) -> StarshipStat:
	match kind:
		0: return power
		1: return speed
		2: return sensors
		3: return shields
		6: return damage
	return null
