class_name ResourceCost
extends Resource
## What using an [Ability] costs: an amount of one [AbilityResource]. An ability can list several to charge more
## than one resource. Affordability and spending run through [ResourceEngine], which matches the entity's pools to
## a cost by the resource's name.

@export var resource: AbilityResource
@export var amount: int = 0
