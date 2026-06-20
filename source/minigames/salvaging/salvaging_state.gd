class_name SalvagingState
extends Resource
## Salvaging's saved field — the arcade session's world/exploration state (a 2D stand-in for 3D
## exploration), not a crafting station. The dug field as flat per-cell arrays (indexed y * width + x)
## plus the run flags, so a partly-stripped field can't be re-rolled by leaving and returning. Created
## at runtime, serialized into saves.

@export var mode: int = 0

#region Field
@export var width: int = 0
@export var height: int = 0
@export var object_count: int = 0
@export var objects: PackedByteArray = PackedByteArray()
@export var revealed: PackedByteArray = PackedByteArray()
@export var flagged: PackedByteArray = PackedByteArray()
@export var adjacent: PackedInt32Array = PackedInt32Array()
@export var revealed_safe: int = 0
#endregion

#region Run
@export var playable: bool = true
@export var lost: bool = false
@export var won: bool = false
@export var actions_used: int = 0
@export var found_this_field: int = 0
#endregion

## True once a field has been captured — distinguishes a saved field from a never-bound state.
func has_field() -> bool:
	return width > 0 and height > 0 and objects.size() == width * height
