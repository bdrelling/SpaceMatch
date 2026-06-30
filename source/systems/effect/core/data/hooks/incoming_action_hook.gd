class_name IncomingActionHook
extends Hook
## Raised on the entity an action targeted — the subject side, regardless of whether a stat changed (a hit that
## was fully absorbed still lands as an incoming action). For "a stat of mine changed" use [StatModifiedHook].
## [member tag] mirrors the action's tag; empty matches any. Who acted comes from [member
## ResolutionContext.instigator].

## The action's tag. Empty matches any; set it to match one kind.
@export var tag: StringName
