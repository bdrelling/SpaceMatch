# AUTOLOAD: JoypadLayout
extends Node
## Swaps the A/B joypad events of [code]ui_accept[/code]/[code]ui_cancel[/code] while a
## Nintendo controller is connected, so the right-hand face button (labeled A on
## Nintendo pads) confirms and the bottom one (labeled B) cancels, per the Nintendo
## convention. Godot reports face buttons by physical position (SDL convention), so
## without the swap a Nintendo pad confirms on its B label. Gameplay actions stay
## positional and are not touched.
##
## Detection uses the USB vendor id rather than the controller name, which varies by
## OS. Under Steam Input the pad surfaces as a virtual Xbox controller, so no swap
## happens — Steam already applies the player's button-layout preference.

const _NINTENDO_VENDOR_ID := 0x057E

## Actions whose A/B events follow button labels instead of positions.
const _SWAPPED_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]

const _SWAPS: Dictionary[JoyButton, JoyButton] = {
	JOY_BUTTON_A: JOY_BUTTON_B,
	JOY_BUTTON_B: JOY_BUTTON_A,
}

var _swapped := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh()

func _refresh() -> void:
	set_swapped(_is_nintendo_pad_connected())

func _is_nintendo_pad_connected() -> bool:
	for device: int in Input.get_connected_joypads():
		# vendor_id is a decimal string (e.g. Nintendo 0x057E arrives as "1406").
		var vendor_id: String = str(Input.get_joy_info(device).get("vendor_id", ""))
		if vendor_id.to_int() == _NINTENDO_VENDOR_ID:
			return true
	return false

## Idempotent: swaps the A/B events of [member _SWAPPED_ACTIONS] when enabling, swaps
## them back when disabling. [method InputMap.action_get_events] returns the stored
## events themselves, so mutating [member InputEventJoypadButton.button_index] in
## place retargets matching immediately.
func set_swapped(enabled: bool) -> void:
	if enabled == _swapped:
		return
	_swapped = enabled
	for action: StringName in _SWAPPED_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			var button := event as InputEventJoypadButton
			if button != null and _SWAPS.has(button.button_index):
				button.button_index = _SWAPS[button.button_index]
