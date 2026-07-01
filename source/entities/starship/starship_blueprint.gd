class_name StarshipBlueprint
extends Resource
## Authored preset for a starship: its name and module-grid layout. Pure data — [method Starship.create]
## reads it to build a [Starship] (and its [StarshipState]).

@export var name: String = ""
## The starship's own base stats — what it brings before any modules: its starting health and any intrinsic
## bonuses or restrictions unique to this hull (you can't add or remove these the way you do modules). A
## [StarshipState]'s effective stats are this block plus its slotted modules' blocks.
@export var stats: StarshipStats
@export var module_grid: ModuleGridBlueprint
## The starship's phase rules (its extra-turn rule, hull behaviour). Left null, [method Starship.apply_blueprint] gives
## the starship the standard hull kit. Author a [Ruleset] here to give a hull its own rules.
@export var ruleset: Ruleset
## The starship's hull abilities. Left empty, [method Starship.apply_blueprint] grants the standard set. Modules add more on top
## (see [member ModuleBlueprint.abilities]). Author here to give a hull its own kit.
@export var abilities: Array[Ability] = []
