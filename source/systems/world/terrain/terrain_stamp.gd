@tool
class_name TerrainStamp
extends Node3D
## Scene-placeable node for a TerrainStampData resource. Position the node in
## the 3D editor to set the stamp's world XZ center; the level walks its own
## subtree during regenerate_terrain and bakes every TerrainStamp it finds into
## the heightmap.
##
## world_position on the resource is ignored — the node's global_position is
## used instead. rotation_deg and scale on the resource still apply.

@export var stamp: TerrainStampData
