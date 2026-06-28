## InputAction
##
## Mirror of the custom actions in project.godot's [input] section — keep the two in sync.
## (Built-in ui_* actions are excluded; see [method get_custom_actions].)
class_name InputAction

#region General

const PAUSE := &"pause"
const TOGGLE_DEBUG_MENU := &"toggle_debug_menu"

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
	match action:
		PAUSE:
			return "Pause"
		TOGGLE_DEBUG_MENU:
			return "Toggle Debug Menu"
		_:
			return action

static func visibility_for_action(_action: StringName) -> bool:
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
