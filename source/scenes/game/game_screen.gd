class_name GameScreen
extends Control
## A page in the [Game]'s pager. The shell binds it to the running [GameSession] and the live
## shared [Inventory] when mounting, so every screen reads and writes the one economy; its
## [member title] labels the page's tab. Subclasses override [method bind] to wire their views; the
## base is inert.

@export var title: String = ""

func bind(_session: GameSession, _inventory: Inventory) -> void:
	pass
