## Collision Layer
##
## Mirror of project.godot's [layer_names] section — keep the two in sync.
## To add a layer:
## 1. Name it under [layer_names] as 2d_physics/layer_X in project.godot.
## 2. Add a matching entry here. Values are powers of two: layer 1=1, layer 2=2, layer 3=4, etc.
##
## Only the physics-heap mini-game ([MatchGravity]) uses these today: dropped tiles collide with each
## other and with the board walls.

class_name CollisionLayer

enum {
	TILES = 1 << 0,
	WALLS = 1 << 1,
}
