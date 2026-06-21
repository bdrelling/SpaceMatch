class_name StageScreen
extends GameScreen
## A placeholder production-stage page: just a centered [member title], standing in until a stage gets
## its real minigame. [member title] is inherited from [GameScreen].

var _title_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	_title_label = Label.new()
	_title_label.text = title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)

## The page's readout text, for tests and hosts.
func summary() -> String:
	return _title_label.text if _title_label != null else ""
