class_name StarshipBlueprint
extends Resource
## Authored data for a [Starship] — which hull it flies as. One blueprint per ship model;
## the fleet grows by authoring more of these.

## Scene instanced under the ship's model root.
@export var model_scene: PackedScene
