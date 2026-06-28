class_name DamageStep
extends Resource
## One transform a status applies to a [DamagePacket] passing through it (Block absorb, Vulnerable amplify,
## armor mitigation, Intangible clamp). Steps are authored on a [Status]; the engine never hardcodes a stat
## name like "armor" — a step that mitigates names the stat it reads. The subclasses below are defaults;
## games keep the ones they want and add their own, exactly like [Action] and [Target].
##
## The [enum Phase] a step belongs to fixes WHEN it runs, independent of authoring order: the
## [DamagePipeline] runs every step in [constant AMPLIFY] before any in [constant MITIGATE], and so on. That
## fixed order is a balance decision baked into the engine, so a Vulnerable multiplier always applies before
## armor subtraction no matter how the data was authored.

enum Phase {
	AMPLIFY,   ## Scale the raw amount up or down (Vulnerable, Weak, empower).
	MITIGATE,  ## Subtract flat defense (armor).
	ABSORB,    ## Drain a depletable pool before damage reaches vitality (Block, shields).
	CLAMP,     ## Bound the result (Intangible caps it; a floor keeps it non-negative).
}

## Which phase this step runs in. Subclasses override; the base runs in [constant AMPLIFY].
func phase() -> Phase:
	return Phase.AMPLIFY

## Mutates [param packet] in place. The base does nothing.
func modify(_packet: DamagePacket, _context: ResolutionContext) -> void:
	pass
