class_name PanelState
extends State

@export var pause_menu: PauseMenu

func _open_main() -> void:
	transitioned.emit(&"MainPanelState")
