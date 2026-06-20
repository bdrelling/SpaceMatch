class_name ScatterPlacement
extends RefCounted
## A planned scatter instance: which pool entry lands where, with what Y-axis
## rotation and uniform scale.

var entry: ScatterEntry
var position: Vector3
var rotation_degrees: float = 0.0
var scale: float = 1.0

## Stamp ready for the blit pass: the entry's stamp duplicated with this
## placement's transform applied. Null when the entry carries no stamp.
func make_stamp() -> TerrainStampData:
	if entry == null or entry.stamp == null:
		return null
	var stamp: TerrainStampData = entry.stamp.duplicate() as TerrainStampData
	stamp.world_position = Vector3(position.x, 0.0, position.z)
	stamp.rotation_degrees = rotation_degrees
	stamp.scale = scale
	return stamp
