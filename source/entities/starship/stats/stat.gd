class_name Stat
## The ship stats a module contributes to. A module's contribution is authored as a [StatBlock];
## a ship's profile is the sum of its slotted modules' blocks.

## DAMAGE, SCRAP, and ANOMALY back the three non-stat match tiles so every tile kind links to a stat:
## damage feeds the attack tile, scrap the currency tile, anomaly the (still-inert) anomaly tile.
enum Type { POWER, SPEED, CARGO, FUEL, ARMOR, SHIELDS, SENSORS, LIFE_SUPPORT, DAMAGE, SCRAP, ANOMALY }
