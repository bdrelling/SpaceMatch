class_name ScatterEntry
extends Resource
## One pickable member of a [ScatterConfig] pool: a terrain stamp, a scene, or
## both — a scene with the ground shaped beneath it.

@export var stamp: TerrainStampData

@export var scene: PackedScene

## Relative likelihood that a placement picks this entry over the pool's other
## entries. Zero removes the entry from the pool without deleting it.
@export_range(0.0, 100.0, 0.01, "or_greater") var weight: float = 1.0

func is_valid() -> bool:
	return (stamp != null or scene != null) and weight > 0.0
