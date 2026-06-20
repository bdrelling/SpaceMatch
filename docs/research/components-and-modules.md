# Components and Modules

Working reference for the component and module catalogs — what atoms exist and the reasoning behind each cut. Fabricating packs **components → module**; outfitting packs **modules → ship**. In-flux; not canon.

## Components

A minimal palette of 4–6 components that can build all the other things.

### Potential

- Panels (plating, hull sheets, structural skin)
- Circuits (boards, chips)
- Wires (cables, leads, conduit)
- Fasteners (bolts, rivets, clips, screws)
- Tubes (tubing, hoses, lines, coolant line)
- Capacitor (power cell, cell, battery)
- Actuator (servo, motor, bearings, gears, springs)
- Connector (port, plug)
- Sensor (lens, optic, detector, scanner)
- Strut* (frame, brace)
- Gasket* (seal, o-ring)
- Insulation* (shielding)

### Candidate atoms (6) — each an irreducible functional role

- **Panel** — structure, housing, enclosure, armor (absorbs Strut, Insulation)
- **Wire** — power and signal transmission (absorbs Connector)
- **Circuit** — logic, control, computation
- **Capacitor** — energy storage / power
- **Actuator** — motion, mechanical work
- **Tube** — fluid, gas, thermal transport (absorbs Gasket)

### Don't pick — covered by an atom, or by crafting itself

- **Fasteners** — pure assembly glue, no role of its own; implied by building anything
- **Strut** — structure, same role as Panel
- **Connector** — terminus of a Wire
- **Gasket** — sealing, derives from Tube + Panel
- **Insulation** — isolation barrier, a treated Panel
- **Sensor** — a Circuit plus a simple optic; built rather than stocked

### Squeezing below six

- **Five:** drop Tube (handle coolant abstractly).
- **Four:** drop Actuator too — but then anything that moves (engine, thruster, landing gear, salvage arm) loses its distinguishing input and recipes start collapsing into each other. Four is below the natural floor.

### Open call

- **Sensor** is the riskiest cut. If sensor array / scanner / nav modules should feel different from generic electronics, keep Sensor as a seventh atom instead of deriving it from Circuit.

## Modules

### Propulsion

- Engine (main drive)
- Thruster (maneuvering jets, RCS)
- Fuel tank (fuel cell, propellant tank)
- Jump drive (FTL, warp, hyperdrive)

### Power

- Reactor (power core, generator)
- Capacitor bank (battery bank, cell array)
- Power distribution (bus, harness, junction)

### Defense

- Shield generator (deflector, shielding)
- Armor plating (hull plating, ablative layer)

### Crew & Habitation

- Cockpit (bridge, helm)
- Life support (air recycler, atmosphere)
- Quarters (cabin, berth)
- Airlock (hatch, lock)

### Sensors & Navigation

- Sensor array (scanner suite, detector pod)
- Nav computer (autopilot, plotter)
- Comms (antenna, transponder, radio)

### Thermal

- Coolant system (radiator, heat sink, loop)

### Cargo & Docking

- Cargo bay (hold, storage rack)
- Docking port (clamp, collar)
- Landing gear (skids, struts, legs)

### Utility (salvage-themed)

- Tractor beam (grapple, towing array)
- Salvage arm (cutter, manipulator)
- Mining laser (drill, extractor)

### Other

- Gravity plating (grav generator)
- Repair bay (drone bay, fabricator)

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
