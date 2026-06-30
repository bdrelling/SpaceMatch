class_name EntityStat
extends Resource
## A stat an entity can have — identified by its key. The neutral stat definition the whole system references,
## exactly parallel to [AbilityResource]: games author one [code].tres[/code] per stat and refer to it everywhere a
## stat is named, instead of an enum or a raw [StringName]. A [EntityStats] stores values keyed by [member name], so
## two [EntityStat] instances with the same name address the same value.

## Identifies this stat — the key a [EntityStats] stores its value under, and what [Modifier]s and actions reference.
@export var name: StringName
