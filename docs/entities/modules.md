# Modules

Working reference for the component and module catalogs — what atoms exist and the reasoning behind each cut. In-flux; not canon.

## Propulsion

- Engine (main drive)
- Thruster (maneuvering jets, RCS)
- Fuel tank (fuel cell, propellant tank)
- Jump drive (FTL, warp, hyperdrive)

## Power

- Reactor (power core, generator)
- Capacitor bank (battery bank, cell array)
- Power distribution (bus, harness, junction)

## Defense

- Shield generator (deflector, shielding)
- Armor plating (hull plating, ablative layer)

## Crew & Habitation

- Cockpit (bridge, helm)
- Life support (air recycler, atmosphere)
- Quarters (cabin, berth)
- Airlock (hatch, lock)

## Sensors & Navigation

- Sensor array (scanner suite, detector pod)
- Nav computer (autopilot, plotter)
- Comms (antenna, transponder, radio)

## Thermal

- Coolant system (radiator, heat sink, loop)

## Cargo & Docking

- Cargo bay (hold, storage rack)
- Docking port (clamp, collar)
- Landing gear (skids, struts, legs)

## Utility (salvage-themed)

- Tractor beam (grapple, towing array)
- Salvage arm (cutter, manipulator)
- Mining laser (drill, extractor)

## Other

- Gravity plating (grav generator)
- Repair bay (drone bay)

## Stat-vector model (tentative)

> Tentative working model — not locked.

A module is a **stat vector**, not a single stat: each contributes several stats, positive and negative (e.g. Thruster = +3 Speed / −1 Fuel). The tradeoffs are the point.

Modules group into **families by primary (headline) stat**. A family holds several modules; the secondary contributions and penalties differentiate them. One-to-many, not one-to-one.

| Primary stat | Family modules (example tradeoff) |
| --- | --- |
| Power | Reactor (big +Power, heavy), Battery (small +Power buffer) |
| Speed | Engine (+Speed, −Power), Thruster (+Speed, −Fuel) |
| Fuel | Fuel Tank (+Fuel, −Speed when full) |
| Cargo | Cargo Bay (+Cargo, −Speed) |
| Armor | Armor Plating (+Armor, −Speed) |
| Shields | Shield Generator (+Shields, −Power) |
| Sensors | Sensor Array (+Sensors, −Power) |
| Life Support | Air Recycler, Hydroponics Bay, Oxygen Tank (+Life Support; e.g. Hydroponics −Cargo) |

Life Support is the atmospheric/biological systems (oxygen, hydrogen, hydroponics, botanicals), not crew quarters. Quarters/Cockpit are habitation, separate from this stat.
