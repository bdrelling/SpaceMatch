class_name WhenHitHook
extends Hook
## Raised by the host on the target of an attempted hit — before, after, or around the damage — regardless of
## whether any stat actually changed (a hit a dodge negated whole still counts as a hit). Statuses that react to
## "I was hit" listen for this: dodge consumes a stack on it via a [TriggerDecayRule]. Who struck comes from
## [member ResolutionContext.instigator]. Distinct from [StatModifiedHook] (which fires only when a stat moved)
## and [IncomingActionHook] (raised inside an action's own resolution).
