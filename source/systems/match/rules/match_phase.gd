class_name MatchPhase
## The lifecycle phases the match encounter fires rules at — the host's phase vocabulary (the grid engine
## knows none of these; see [[Ruleset]]). A [Rule] sets its [member Rule.phase] to one of these and the
## encounter runs it when that moment arrives. Add a phase here, fire it from [MatchGame], and rules
## can hook it.

## The board has been built for the encounter — first chance to seed or alter starting state.
const SETUP := &"setup"
## The active combatant's turn has begun (before they act).
const TURN_START := &"turn_start"
## The active combatant's turn has ended (after they act, before it passes).
const TURN_END := &"turn_end"
## A batch of tiles has been cleared (fires once per cascade step) — the resource/scoring hook.
const ON_CLEAR := &"on_clear"
## A move and its whole cascade have settled — the extra-turn / end-of-move hook.
const MOVE_RESOLVED := &"move_resolved"
## A combatant has won the encounter.
const VICTORY := &"victory"
## A combatant has lost the encounter.
const DEFEAT := &"defeat"
