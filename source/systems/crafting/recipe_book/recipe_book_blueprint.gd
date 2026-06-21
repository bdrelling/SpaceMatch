class_name RecipeBookBlueprint
extends Resource
## Authored set of [RecipeBlueprint]s — the composite blueprint a [RecipeBook] is built from.
## Shared, read-only type data, so one book can back many recipe books.
##
## Books compose: [member books] nests other [RecipeBookBlueprint]s, and the [RecipeBook] built from
## this one flattens itself plus every nested book into a single de-duplicated recipe list.

## Recipes authored directly on this book.
@export var recipes: Array[RecipeBlueprint] = []
## Nested books folded into this one. The built [RecipeBook] flattens these recursively; a recipe
## shared by several books appears once, and cyclic nesting is tolerated (each book visited once).
@export var books: Array[RecipeBookBlueprint] = []
