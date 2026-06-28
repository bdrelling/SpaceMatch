class_name TimingDecayRule
extends DecayRule
## Removes [member quantity] stacks each time the encounter reaches [member phase].

## Phase at which decay happens, as a game-defined phase name (e.g. a [code]MatchPhase[/code] constant).
@export var phase: StringName
@export var quantity: int = 1
