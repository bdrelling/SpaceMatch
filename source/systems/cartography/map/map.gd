class_name Map
extends Control
## The full-screen map surface. For now it is just an enlarged [CompassRose]; world
## detail layers in on top later. Sized and animated by [MapPanel].

@onready var _compass_rose: CompassRose = %CompassRose

## Forwards to the embedded [CompassRose] so the big map tracks the same heading as the
## HUD minimap.
func bind_player(player: Player) -> void:
	_compass_rose.bind_player(player)
