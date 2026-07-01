class_name DodgeAction
extends Action
## Arms the target's dodge — negates the next attack against them — via [method EncounterState.set_dodge]. Carries
## no amount: a dodge is all-or-nothing.


static func make() -> DodgeAction:
	return DodgeAction.new()


func resolve(context: ResolutionContext, target: Entity) -> void:
	var match_context := context as MatchResolutionContext
	var combatant := target as Combatant
	if match_context == null or match_context.encounter == null or combatant == null:
		return
	match_context.encounter.set_dodge(combatant, true)
	match_context.add_visual({"kind": &"dodge", "target": combatant})


func describe() -> String:
	return "Dodge the next attack"
