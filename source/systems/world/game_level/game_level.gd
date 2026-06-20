class_name GameLevel
extends Node3D

## The node the terrain streams chunks around (e.g. the camera). Injected by
## whatever owns the level; the level never reaches back into it.
@export var tracking_target: Node3D

## Where the player should spawn in this level. Every level scene provides a
## node named "SpawnPoint" (accessible as a unique name).
@onready var spawn_marker: Marker3D = %SpawnPoint
