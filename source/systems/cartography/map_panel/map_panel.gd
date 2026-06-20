class_name MapPanel
extends OverlayPanel
## Full-map overlay. Grows open from the HUD compass rose toward the screen centre on its
## toggle action and shrinks back into it on the next press — see
## [constant OverlayPanel.Transition.GROW_FROM_SOURCE], with [member grow_source] wired to
## the [Minimap]. This script only sizes the map square and forwards the player binding.
##
## The map is an aspect-ratio square, inset [constant PADDING] virtual px from the top
## and bottom of the screen and centred horizontally.

## Inset from the top and bottom screen edges, in virtual (1920×1080) pixels.
const PADDING := 32.0

## The player whose heading the map's compass tracks; wired in the editor.
@export var player: Player

func _ready() -> void:
	resized.connect(_layout_map)
	_layout_map()
	super._ready()
	if player and content and content.has_method(&"bind_player"):
		content.call(&"bind_player", player)

func _layout_map() -> void:
	if content == null:
		return
	var side := maxf(size.y - PADDING * 2.0, 0.0)
	content.size = Vector2(side, side)
	content.position = (size - content.size) / 2.0
	content.pivot_offset = content.size / 2.0
