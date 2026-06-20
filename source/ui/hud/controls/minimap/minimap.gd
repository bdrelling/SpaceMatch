class_name Minimap
extends Control
## HUD compass widget — a small [CompassRose]. Styling and heading tracking live in
## [CompassRose]; this just hosts it and forwards the player binding.

@onready var _compass_rose: CompassRose = %CompassRose

func bind_player(player: Player) -> void:
	_compass_rose.bind_player(player)
