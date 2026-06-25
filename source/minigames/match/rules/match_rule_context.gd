class_name MatchRuleContext
extends RuleContext
## The typed [[RuleContext]] the match encounter hands its rules — the encounter state, who is acting, the
## event payload for the firing phase, and the result fields a rule writes back. [MatchMinigame] fills the
## inputs, runs the phase, then reads the outputs (turn handover for MOVE_RESOLVED, visual events for ON_CLEAR).

## The live encounter (health, resources, turns, warp) the rules read and mutate.
var encounter: EncounterState
## The combatant this phase concerns ([enum EncounterState.Combatant]), or -1 when none.
var combatant: int = -1
## The acting combatant's effective stats (permanent module-grid profile + temporary buffs), filled by the
## host for ON_CLEAR. Rules read it to bonus their grant — the damage stat adds to the hit, each colored stat
## to the resource its tile banks. Null when no ship backs the mover (e.g. the standalone scene).
var actor_stats: StatBlock

# --- MOVE_RESOLVED inputs ---
## The largest match cleared during the move (what the extra-turn rule measures a "match-N" by).
var max_run: int = 0

# --- MOVE_RESOLVED results ---
## Set true to keep the board with the mover for another action instead of passing the turn.
var go_again: bool = false
## A short label for why the turn was kept ("Match-5"), shown in the status line.
var go_again_reason: String = ""

# --- ON_CLEAR inputs (one cascade step's cleared batch) ---
## Tiles cleared this batch, per kind: kind -> count. Typed so [member counts] subscripts read as ints (the
## scoring formula's [method reward_for] takes an int — an untyped Dictionary would feed it a Variant).
var counts: Dictionary[int, int] = {}
## The averaged board-local centre of each cleared kind, for spawning popups: kind -> Vector2.
var centers: Dictionary[int, Vector2] = {}
## The damage-kind cells cleared this batch (for the damage rule's fly-to-portrait).
var damage_cells: Array[Vector2i] = []
## Bars of warp this batch earns (precomputed: longest straight warp run minus two, floored at zero).
var warp_bars: int = 0
## The encounter's scoring formula (null = one-to-one). Use [method reward_for] rather than reading directly.
var scoring: ScoringFormula
## The player's wallet, when a session is bound (else null) — where scrap banks.
var wallet: Wallet

# --- ON_CLEAR results ---
## Visual events the rules emit for the host to render (popups, flying damage). Each is a Dictionary with a
## "type" key ("resource" / "warp" / "damage") and that type's payload — the host owns the actual nodes.
var visuals: Array[Dictionary] = []

## The reward for clearing [param quantity] tiles, per the encounter's scoring formula (one-to-one when unset).
func reward_for(quantity: int) -> int:
	return scoring.reward_for(quantity) if scoring != null else maxi(0, quantity)
