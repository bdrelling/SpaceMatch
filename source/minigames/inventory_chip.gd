class_name InventoryChip
extends RefCounted
## One entry in the game inventory strip: a label and a count. The shell renders it; the stage just
## lists what it holds.

var label: String
var quantity: int
## Swatch tint for an icon stand-in; a fully transparent color draws no swatch.
var color: Color

func _init(chip_label: String = "", chip_quantity: int = 0, chip_color: Color = Color(0, 0, 0, 0)) -> void:
	label = chip_label
	quantity = chip_quantity
	color = chip_color
