class_name SidesTarget
extends Target
## Entities within [member radius] of the owner (the game decides what "adjacent" means for it).

@export var radius: int = 1


## Allies within [member radius] list positions of the source (its neighbours in line order), excluding the
## source itself. Games with real geometry override this; the default treats [member ResolutionContext.allies]
## order as the layout.
func resolve(context: ResolutionContext) -> Array[Entity]:
	var source_index := context.allies.find(context.source)
	if source_index == -1:
		return []
	var neighbours: Array[Entity] = []
	for offset in range(-radius, radius + 1):
		if offset == 0:
			continue
		var index := source_index + offset
		if index >= 0 and index < context.allies.size():
			neighbours.append(context.allies[index])
	return neighbours
