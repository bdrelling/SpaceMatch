class_name MatchRules
extends Resource
## Tunable, swappable rules for one match-3 encounter — the knobs that change how a board plays without
## touching its code. Author a `.tres` per encounter (or call [method default] for the standard
## SpaceMatch set) and hand it to [MatchMinigame] as [member MatchMinigame.rules]. Some rules are flat
## config (spawn weights, scoring formula); behavioural rules that fire at a phase of play live in
## [member ruleset] as plug-in [Rule]s (see [MatchPhase]).

## The match-scope rules that fire at phases of play: the baseline grant rules (resources, scrap, damage,
## warp on [constant MatchPhase.ON_CLEAR]) plus whatever the encounter adds (e.g. extra turns). A swappable
## [Ruleset] — drop, retune, or add rules per encounter, or at runtime mid-game. Seeded with the baseline
## on construction; replace it wholesale in a `.tres` to author a fundamentally different match.
@export var ruleset: Ruleset

func _init() -> void:
	# Seed the always-on baseline so a fresh ruleset already banks matches, deals damage and charges warp.
	# An authored .tres that stores its own ruleset overrides this.
	if ruleset == null:
		ruleset = baseline_ruleset()

## A ruleset carrying just the baseline ON_CLEAR grant rules — what every match does before any encounter-
## specific rules are layered on. Resources bank into the mover's tally, scrap into the wallet, damage into
## the foe, warp into the shared meter.
static func baseline_ruleset() -> Ruleset:
	var rules := Ruleset.new()
	rules.add(ResourceGrantRule.new())     # the four stat tiles -> the mover's tally
	rules.add(ScrapGrantRule.new())        # scrap -> the player's wallet
	rules.add(DamageRule.new())            # damage -> the opposing combatant's health
	rules.add(WarpRule.new())              # warp -> the shared warp meter
	# Turn-start knobs, seeded at their no-op defaults so the baseline plays exactly as before: a single action
	# per turn (an ability ends it), unlimited resources, one-to-one scoring. A mode or ship retunes these.
	rules.add(ActionBudgetRule.new())      # moves per turn + what an ability does to the turn
	rules.add(ResourceCapacityRule.new())  # per-resource hold limits (unlimited by default)
	rules.add(OffsetScoringRule.new())     # a match of N banks N minus an offset (zero by default)
	return rules

## How a match's tile count becomes its reward. The default [ScoringFormula] is one-to-one (a match of N
## is worth N); assign a [FibonacciScoringFormula] to make bigger matches pay off super-linearly. Applies
## to every banked kind (stat tiles, scrap, damage). Left null, scoring falls back to one-to-one.
@export var scoring: ScoringFormula

## When true, reloading a dead board first splits its tiles between the two combatants as resources
## (floor of half each, the odd one discarded) before the fresh board pours in — so a stalemate still pays
## out instead of vanishing. ("Optional but default on.")
@export var reload_splits_resources: bool = true

## The board's default tile-selection rule (swap / slide / path / teleport). Left unset, the board falls
## back to [MatchMinigame]'s legacy mode export. A starship's [member StarshipState.selection_override]
## takes precedence on that ship's turn, so selection can change with whoever is acting (see [SelectionRule]).
@export var default_selection: SelectionRule

## The standard SpaceMatch match-scope ruleset: the baseline economy (resource/scrap/damage/warp grants) plus
## scoring, with a spawn pool that favors the four stat tiles and makes warp the rarest find. Extra turns and
## abilities are NOT here — they belong to the starship (its hull kit and modules), composed in per turn over
## these defaults (see [method Starship.apply_blueprint] and [method MatchMinigame._effective_ruleset]).
static func default() -> MatchRules:
	var rules := MatchRules.new()  # _init seeded the baseline grant rules (which carry their own spawn weights)
	rules.scoring = ScoringFormula.new()  # one-to-one: a match of N is worth N
	rules.reload_splits_resources = true
	return rules

## The composed spawn pool: each enabled rule's declared tile weights merged into one {kind: weight} map.
## Rules own what spawns, so dropping or disabling a rule drops its tiles from the board — the same match
## engine makes a different game (other combat, a puzzle) by swapping which rules are in play. The host may
## still gate a kind on top of this (e.g. warp only rolls when a ship can warp).
func spawn_table() -> Dictionary:
	var table := {}
	if ruleset == null:
		return table
	for rule: Rule in ruleset.rules:
		if rule == null or not rule.enabled or not rule.has_method(&"spawn_contribution"):
			continue
		var contribution: Dictionary = rule.call(&"spawn_contribution")
		for kind: int in contribution:
			var added: int = contribution[kind]
			var running: int = table.get(kind, 0)
			table[kind] = running + added
	return table
