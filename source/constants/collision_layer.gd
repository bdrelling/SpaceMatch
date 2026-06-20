## Collision Layer
##
## Instructions:
## 1. Check project.godot [layer_names] section for 3d_physics/layer_X definitions
## 2. Layer numbers use powers of 2: layer 1=1, layer 2=2, layer 3=4, layer 4=8, etc.
## 3. Update enum values to match the layer definitions in project.godot

class_name CollisionLayer

enum {
	WORLD = 1 << 0,
	PLAYERS = 1 << 1,
	PROPS = 1 << 2,
	INTERACTION = 1 << 3,
	STRUCTURES = 1 << 4,
}
