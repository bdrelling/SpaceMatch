class_name MenuScreen
extends ArcadeScreen
## Placeholder menu/settings page — a centered title until real settings (the existing settings
## panel) move in. Stands in for the old pause overlay now that the menu is just another tab.

@onready var _label: Label = $Label

func _ready() -> void:
	_label.text = title
