class_name PauseSettingsPanel
extends PanelContainer

signal back_pressed

const CAMERA_MODE_LABELS: Dictionary = {
	PlayerCamera.Mode.LOCKED_YAW: "Locked",
	PlayerCamera.Mode.ORBIT: "Orbit",
	PlayerCamera.Mode.CHASE: "Chase",
	PlayerCamera.Mode.ORBIT_AND_CHASE: "Orbit + Chase",
}

const SPRINT_MODE_LABELS: Dictionary = {
	Player.SprintMode.TOGGLE: "Toggle",
	Player.SprintMode.HOLD: "Hold",
}

@onready var _back_button: Button = %BackButton
@onready var _controls_button: Button = %ControlsButton
@onready var _camera_button: Button = %CameraButton
@onready var _controls_content: VBoxContainer = %ControlsContent
@onready var _camera_content: VBoxContainer = %CameraContent
@onready var _camera_mode_option: OptionButton = %CameraModeOption
@onready var _invert_y_check: CheckButton = %InvertYCheck
@onready var _sprint_mode_option: OptionButton = %SprintModeOption
@onready var _reset_camera_mode_button: Button = %ResetCameraMode
@onready var _reset_invert_y_button: Button = %ResetInvertY
@onready var _reset_sprint_mode_button: Button = %ResetSprintMode
@onready var _reset_all_button: Button = %ResetAllButton

func _ready() -> void:
	_back_button.pressed.connect(back_pressed.emit)
	_controls_button.pressed.connect(_show_controls)
	_camera_button.pressed.connect(_show_camera)
	_populate_camera_modes()
	_populate_sprint_modes()
	_camera_mode_option.item_selected.connect(_on_camera_mode_selected)
	_invert_y_check.toggled.connect(_on_invert_y_toggled)
	_sprint_mode_option.item_selected.connect(_on_sprint_mode_selected)
	_reset_camera_mode_button.pressed.connect(_on_reset_camera_mode_pressed)
	_reset_invert_y_button.pressed.connect(_on_reset_invert_y_pressed)
	_reset_sprint_mode_button.pressed.connect(_on_reset_sprint_mode_pressed)
	_reset_all_button.pressed.connect(_on_reset_all_pressed)
	Settings.game.changed.connect(_sync_from_settings)
	_sync_from_settings()
	_show_controls()

func grab_initial_focus() -> void:
	_controls_button.grab_focus.call_deferred()

func _show_controls() -> void:
	_controls_content.visible = true
	_camera_content.visible = false

func _show_camera() -> void:
	_controls_content.visible = false
	_camera_content.visible = true

func _on_camera_mode_selected(index: int) -> void:
	var mode: PlayerCamera.Mode = _camera_mode_option.get_item_id(index) as PlayerCamera.Mode
	if mode == Settings.game.get_default(GameSettings.KEY_CAMERA_MODE):
		Settings.game.clear(GameSettings.KEY_CAMERA_MODE)
	else:
		Settings.game.camera_mode = mode

func _on_invert_y_toggled(enabled: bool) -> void:
	Settings.game.invert_y_axis = enabled

func _on_sprint_mode_selected(index: int) -> void:
	var mode: Player.SprintMode = _sprint_mode_option.get_item_id(index) as Player.SprintMode
	if mode == Settings.game.get_default(GameSettings.KEY_SPRINT_MODE):
		Settings.game.clear(GameSettings.KEY_SPRINT_MODE)
	else:
		Settings.game.sprint_mode = mode

func _on_reset_camera_mode_pressed() -> void:
	Settings.game.clear(GameSettings.KEY_CAMERA_MODE)
	_sync_from_settings()

func _on_reset_invert_y_pressed() -> void:
	Settings.game.clear(GameSettings.KEY_INVERT_Y_AXIS)
	_sync_from_settings()

func _on_reset_sprint_mode_pressed() -> void:
	Settings.game.clear(GameSettings.KEY_SPRINT_MODE)
	_sync_from_settings()

func _on_reset_all_pressed() -> void:
	Settings.game.clear_all()
	_sync_from_settings()

func _populate_camera_modes() -> void:
	var default_mode: Variant = Settings.game.get_default(GameSettings.KEY_CAMERA_MODE)
	for mode: PlayerCamera.Mode in CAMERA_MODE_LABELS:
		var label: String = CAMERA_MODE_LABELS[mode]
		if mode == default_mode:
			label += " (default)"
		_camera_mode_option.add_item(label, mode)

func _populate_sprint_modes() -> void:
	var default_mode: Variant = Settings.game.get_default(GameSettings.KEY_SPRINT_MODE)
	for mode: Player.SprintMode in SPRINT_MODE_LABELS:
		var label: String = SPRINT_MODE_LABELS[mode]
		if mode == default_mode:
			label += " (default)"
		_sprint_mode_option.add_item(label, mode)

func _sync_from_settings() -> void:
	_camera_mode_option.select(_camera_mode_option.get_item_index(Settings.game.camera_mode))
	_invert_y_check.set_pressed_no_signal(Settings.game.invert_y_axis)
	_sprint_mode_option.select(_sprint_mode_option.get_item_index(Settings.game.sprint_mode))
	var camera_mode_is_default: bool = Settings.game.is_default(GameSettings.KEY_CAMERA_MODE)
	var invert_y_is_default: bool = Settings.game.is_default(GameSettings.KEY_INVERT_Y_AXIS)
	var sprint_mode_is_default: bool = Settings.game.is_default(GameSettings.KEY_SPRINT_MODE)
	_reset_camera_mode_button.visible = not camera_mode_is_default
	_reset_invert_y_button.visible = not invert_y_is_default
	_reset_sprint_mode_button.visible = not sprint_mode_is_default
	_reset_all_button.disabled = camera_mode_is_default and invert_y_is_default and sprint_mode_is_default
