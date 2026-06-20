# AUTOLOAD: ManagedInput
extends Node
## A focus- and UI-aware mirror of the [Input] singleton. Game code reads input
## through [code]ManagedInput[/code] instead of [Input] directly, so every read is
## gated in one place: input is suppressed while the game window is unfocused, while
## an ImGui panel owns the pointer or keyboard (scrolling a menu, typing in a field),
## or while a claimant blocks actions via [method block_actions] (e.g. an exclusive
## overlay panel). Method names and signatures mirror [Input] 1:1 — migrating a call
## site is a literal [code]Input.[/code] → [code]ManagedInput.[/code] swap.
##
## Add a method here the first time a call site needs it; keep the signature identical
## to [Input]'s. If a read genuinely must bypass the gate, call [Input] directly — but
## [code]test/systems/input/test_no_raw_input.gd[/code] fails the build on any direct
## [Input] use outside this file, so that bypass has to be deliberate.
##
## Focus tracking here is intentionally independent of [FocusGuard], which suppresses
## game-bound *events* on the same focus signal. Two small self-contained pieces under
## [code]systems/input/[/code]; neither imports the other.

var _focused := true

# Claimant instance id -> the actions it blocks; an empty array blocks every action.
var _blocked_actions := {}

# Actions still physically held when their block lifted. The press that dismissed a
# claimant (e.g. ui_cancel closing a panel) can share a button with a game action, so
# edge reads of these stay suppressed per action until it is physically released.
var _held_through_unblock := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Drops unblock latches as their actions are physically released. Reads can't be
# relied on to land while an action is up (event-driven sites only read on presses),
# so the sweep is what guarantees a latch never outlives its hold.
func _process(_delta: float) -> void:
	if _held_through_unblock.is_empty():
		return
	for action: StringName in _held_through_unblock.keys():
		if not Input.is_action_pressed(action):
			_held_through_unblock.erase(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true

## Suppresses game-bound reads while [param claimant] holds the block: every action
## when [param actions] is empty, otherwise only the listed ones. A claimant holds at
## most one block — claiming again replaces it. [code]ui_*[/code] actions are routed
## by the viewport and never read here, so UI navigation stays live behind any block.
func block_actions(claimant: Object, actions: Array[StringName] = []) -> void:
	_blocked_actions[claimant.get_instance_id()] = actions

## Lifts [param claimant]'s block; a no-op when it holds none. Actions still held at
## this moment stay suppressed for [method is_action_just_pressed] until released, so
## the press that dismissed the claimant can't double as a fresh game press. Held
## continuous reads ([method is_action_pressed], [method get_axis]) resume
## immediately — releasing a held stick to re-enter movement would feel broken.
func unblock_actions(claimant: Object) -> void:
	var id: int = claimant.get_instance_id()
	if not _blocked_actions.has(id):
		return
	var actions: Array[StringName] = _blocked_actions[id]
	_blocked_actions.erase(id)
	if actions.is_empty():
		for action: StringName in InputMap.get_actions():
			if not action.begins_with("ui_"):
				actions.append(action)
	for action: StringName in actions:
		if Input.is_action_pressed(action):
			_held_through_unblock[action] = true

## True while game input should be ignored: the window is unfocused, or an ImGui
## panel is capturing the mouse or keyboard.
func _is_blocked() -> bool:
	var io: ImGuiIOPtr = ImGui.GetIO()
	return not _focused or io.WantCaptureMouse or io.WantCaptureKeyboard or io.WantTextInput

# True while [param action] has stayed held since its block lifted; [method _process]
# drops the latch once the action is physically released.
func _is_held_through_unblock(action: StringName) -> bool:
	return _held_through_unblock.has(action)

## True while reads of [param action] specifically should be ignored: the whole gate
## is down (see [method _is_blocked]) or a live claimant blocks this action.
func _is_action_blocked(action: StringName) -> bool:
	if _is_blocked():
		return true
	for id: int in _blocked_actions:
		if not is_instance_id_valid(id):
			continue
		var actions: Array[StringName] = _blocked_actions[id]
		if actions.is_empty() or action in actions:
			return true
	return false

#region Input mirror

func is_action_pressed(action: StringName) -> bool:
	return not _is_action_blocked(action) and Input.is_action_pressed(action)

func is_action_just_pressed(action: StringName) -> bool:
	return not _is_action_blocked(action) and not _is_held_through_unblock(action) \
		and Input.is_action_just_pressed(action)

## Gated mirror of [method InputEvent.is_action_pressed] — the read for press handling
## inside [code]_unhandled_input[/code]. Never poll [method is_action_just_pressed]
## there: the poll is true for the whole frame, so every other event dispatched that
## frame (a gamepad press rarely arrives without same-frame stick motion) re-triggers
## the handler. Matching against [param event] fires exactly once, on the press itself.
func event_is_action_pressed(event: InputEvent, action: StringName) -> bool:
	return not _is_action_blocked(action) and not _is_held_through_unblock(action) \
		and event.is_action_pressed(action)

func get_axis(negative_action: StringName, positive_action: StringName) -> float:
	if _is_action_blocked(negative_action) or _is_action_blocked(positive_action):
		return 0.0
	return Input.get_axis(negative_action, positive_action)

#endregion
