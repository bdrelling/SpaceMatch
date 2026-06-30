class_name SetStatAction
extends Action
## Sets the target's [member stat] to an absolute value. Unlike [ModifyStatAction], this writes the value
## directly and does NOT run through the [ModificationPipeline] — there is no change to amplify, absorb, or
## mitigate, only a new reading ("set hull to 1", "refill shields to [code]max_shields[/code]").

## The stat to overwrite.
@export var stat: Stat
## The value to set it to.
@export var amount: Amount


## Writes [member amount]'s evaluated value to the target's [member stat].
func resolve(context: ResolutionContext, target: Entity) -> void:
	if target == null or target.current_stats == null:
		return
	var value := amount.evaluate(context) if amount != null else 0
	target.current_stats.set_stat(stat, value)
