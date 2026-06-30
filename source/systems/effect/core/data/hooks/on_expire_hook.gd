class_name OnExpireHook
extends Hook
## Raised when a status's last stack falls off through decay (its count reached zero), as opposed to being
## removed outright (see [OnRemoveHook]). Raised after the status is gone, so other statuses observe the expiry;
## the expired status's own reactions no longer fire. Leave [member status] empty to match any expiry, or set it
## to react to one named status running out.

## The name of the status that expired. Empty matches any expiry.
@export var status: StringName
