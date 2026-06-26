class_name GameScreen
extends Control
## A page in the [Game]'s pager. The shell calls [method bind] when mounting it; the page reads the running
## game from the [code]GameSession[/code] autoload. Its [member title] labels the page's tab. Subclasses
## override [method bind] to wire their views; the base is inert.

@export var title: String = ""

func bind() -> void:
	pass
