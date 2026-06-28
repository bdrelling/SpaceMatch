class_name Stat
## The ship stats a module contributes to. A module's contribution is authored as a [StarshipStats];
## a ship's profile is the sum of its slotted modules' blocks.

## DAMAGE backs the attack tile — it's the ship's combat stat. Scrap and Warp are not ship stats: the scrap
## tile banks to the wallet (currency) and the warp tile charges the encounter meter — neither a ship profile.
## ENERGY is the powering budget: reactors generate it, powered modules consume it (shown as used/generated).
enum Type { POWER, SPEED, CARGO, FUEL, ARMOR, SHIELDS, SENSORS, LIFE_SUPPORT, DAMAGE, ENERGY }

## The ship stat a match tile [param kind] is bound to, or -1 when the tile carries no stat (scrap, warp).
## The four colored stat tiles each boost the resource they bank; the damage tile boosts the hit it deals.
static func for_tile(kind: int) -> int:
	match kind:
		0: return Type.POWER     # combat / red
		1: return Type.SPEED     # propulsion / yellow
		2: return Type.SENSORS   # science / green
		3: return Type.SHIELDS   # defense / blue
		6: return Type.DAMAGE    # damage
	return -1
