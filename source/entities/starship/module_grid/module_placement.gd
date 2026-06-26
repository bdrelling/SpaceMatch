class_name ModulePlacement
extends Resource
## One authored module in a [ModuleGridBlueprint]: which [ModuleBlueprint], where its shape's origin
## sits, and its clockwise rotation. [method ModuleGrid.create] stamps these into the built grid.

@export var module: ModuleBlueprint
## Top-left cell the shape's bounding box is placed at (see [method PieceShape.cells_at]).
@export var origin: Vector2i = Vector2i.ZERO
## Clockwise quarter-turns applied to the shape before placement.
@export var rotation: int = 0
