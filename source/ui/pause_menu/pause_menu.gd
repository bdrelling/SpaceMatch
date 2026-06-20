class_name PauseMenu
extends CanvasLayer

@onready var backdrop: ColorRect = %Backdrop
@onready var main_panel: PauseMainPanel = %MainPanel
@onready var settings_panel: PauseSettingsPanel = %SettingsPanel
@onready var _state_machine: StateMachine = %StateMachine

func _ready() -> void:
	_inject_self_into_states()
	PauseMonitor.paused.connect(_on_paused)
	PauseMonitor.unpaused.connect(_on_unpaused)

func _on_paused() -> void:
	_state_machine.on_child_transitioned(&"MainPanelState")

func _on_unpaused() -> void:
	_state_machine.on_child_transitioned(&"ClosedPanelState")

func _inject_self_into_states() -> void:
	for state: PanelState in _state_machine.get_children():
		state.pause_menu = self
