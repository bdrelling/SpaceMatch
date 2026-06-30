class_name OnRemoveHook
extends Hook
## Raised when a status is removed from an entity (dispelled, cleansed, or forced off — not natural decay; see
## [OnExpireHook]). Raised after the status is gone, so other statuses observe the removal; the removed status's
## own reactions no longer fire. Leave [member status] empty to match any removal, or set it to react to one
## named status falling off.

## The name of the status that was removed. Empty matches any removal.
@export var status: StringName
