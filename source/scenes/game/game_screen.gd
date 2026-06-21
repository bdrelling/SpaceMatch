class_name GameScreen
extends Control
## A page in the [Game]'s pager. The shell binds it to the running [GameSession] when mounting; its
## [member title] labels the page's tab. Subclasses override [method bind] to wire their views; the
## base is inert.

@export var title: String = ""

func bind(_session: GameSession) -> void:
	pass
