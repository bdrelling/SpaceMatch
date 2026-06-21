## InputAction
##
## Instructions:
## 1. Ensure all values from project.godot [input] section are represented in this file.
## 2. Ensure the `name_for_action` value is correct.
class_name InputAction

#region General

const PAUSE := &"pause"
const TOGGLE_DEBUG_MENU := &"toggle_debug_menu"

#endregion

#region Interaction

const INTERACT := &"interact"

#endregion

#region Outfitting

const ROTATE_ITEM := &"rotate_item"
const QUICKBAR_SLOTS: Array[StringName] = [
	&"quickbar_slot_1", &"quickbar_slot_2", &"quickbar_slot_3", &"quickbar_slot_4",
	&"quickbar_slot_5", &"quickbar_slot_6", &"quickbar_slot_7", &"quickbar_slot_8",
	&"quickbar_slot_9", &"quickbar_slot_10",
]

#endregion

#region Cartography

const TOGGLE_MAP := &"toggle_map"

#endregion

#region Movement

const MOVE_FORWARD := &"move_forward"
const MOVE_BACKWARD := &"move_backward"
const STRAFE_LEFT := &"strafe_left"
const STRAFE_RIGHT := &"strafe_right"
const JUMP := &"jump"
const SPRINT := &"sprint"
const DEPLOY_BOARD := &"deploy_board"

#endregion

#region Camera

const CAMERA_PAN := &"camera_pan"
const ROTATE_LEFT := &"rotate_left"
const ROTATE_RIGHT := &"rotate_right"
const TILT_UP := &"tilt_up"
const TILT_DOWN := &"tilt_down"

#endregion

#region Time Scale

const TIME_SCALE_DECREASE := &"time_scale_decrease"
const TIME_SCALE_INCREASE := &"time_scale_increase"
const TIME_SCALE_MAX := &"time_scale_max"
const TIME_SCALE_RESET := &"time_scale_reset"

#endregion

#region Controls

class InputControl:
	var key: StringName
	var title: String
	var visibility: bool

	func _init(_key: StringName, _title: String, _visibility: bool) -> void:
		key = _key
		title = _title
		visibility = _visibility

#endregion

#region Utilities

static func name_for_action(action: StringName) -> String:
	var quickbar_slot := QUICKBAR_SLOTS.find(action)
	if quickbar_slot != -1:
		return "Quickbar Slot %d" % (quickbar_slot + 1)
	match action:
		PAUSE:
			return "Pause"
		TOGGLE_DEBUG_MENU:
			return "Toggle Debug Menu"
		ROTATE_ITEM:
			return "Rotate Item"
		TOGGLE_MAP:
			return "Toggle Map"
		MOVE_FORWARD:
			return "Move Forward"
		MOVE_BACKWARD:
			return "Move Backward"
		STRAFE_LEFT:
			return "Strafe Left"
		STRAFE_RIGHT:
			return "Strafe Right"
		JUMP:
			return "Jump"
		SPRINT:
			return "Sprint"
		DEPLOY_BOARD:
			return "Deploy Board"
		INTERACT:
			return "Interact"
		CAMERA_PAN:
			return "Camera Pan"
		ROTATE_LEFT:
			return "Rotate Left"
		ROTATE_RIGHT:
			return "Rotate Right"
		TILT_UP:
			return "Tilt Up"
		TILT_DOWN:
			return "Tilt Down"
		TIME_SCALE_DECREASE:
			return "Time Scale Decrease"
		TIME_SCALE_INCREASE:
			return "Time Scale Increase"
		TIME_SCALE_MAX:
			return "Time Scale Max"
		TIME_SCALE_RESET:
			return "Time Scale Reset"
		_:
			return action

static func visibility_for_action(action: StringName) -> bool:
	if action in QUICKBAR_SLOTS:
		return false
	match action:
		TIME_SCALE_DECREASE:
			return false
		TIME_SCALE_INCREASE:
			return false
		TIME_SCALE_MAX:
			return false
		TIME_SCALE_RESET:
			return false
		_:
			return true

static func get_custom_actions() -> Array[StringName]:
	var all_actions: Array[StringName] = InputMap.get_actions()
	var custom_actions: Array[StringName] = all_actions.filter(
		func(action: StringName) -> bool: return not action.begins_with("ui_")
	)
	return custom_actions

static func get_custom_controls() -> Array[InputControl]:
	var custom_actions: Array[StringName] = get_custom_actions()
	var controls: Array[InputControl] = []
	for action: StringName in custom_actions:
		var control := InputControl.new(
			action,
			InputAction.name_for_action(action),
			InputAction.visibility_for_action(action)
		)
		controls.append(control)
	return controls

#endregion
