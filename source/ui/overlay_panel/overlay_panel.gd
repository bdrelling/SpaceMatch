class_name OverlayPanel
extends Control
## Base for toggleable in-game overlays (inventory, map, …).
##
## Listens for [member toggle_action] and presents [member content] with the chosen
## [member transition]. Subclasses fill in the content; they never re-implement
## open/close/toggle or the animation.
##
## The panel root stays full-rect and click-through; [member content] is the box that
## actually slides / grows / fades. Wire [member content] in the editor (defaults to the
## first [Control] child). The slide direction names the edge the box enters from.

signal opened
signal closed

enum InputPolicy {
	ALLOW_ALL, ## Game input flows normally while open (e.g. a map the player runs around with).
	BLOCK_ALL, ## Every game-bound read is suppressed while open (an exclusive menu).
	BLOCK_ACTIONS, ## Only [member blocked_actions] are suppressed while open.
}

enum Transition {
	FADE, ## Cross-fades [member content] in place.
	GROW_CENTER, ## Scales [member content] up from its center (1px → full size).
	SLIDE_FROM_LEFT,
	SLIDE_FROM_RIGHT,
	SLIDE_FROM_TOP,
	SLIDE_FROM_BOTTOM,
	## Grows [member content] out of [member grow_source]'s on-screen rect to its resting
	## place, and shrinks back into it on close. [member grow_source] is hidden while open
	## so the source widget appears to become the panel.
	GROW_FROM_SOURCE,
}

## Input action that toggles the panel. Leave empty to toggle only via code.
@export var toggle_action: StringName

## What game-bound input does while the panel is open. [code]ui_*[/code] actions are
## routed by the viewport, not [ManagedInput], so UI navigation always stays live.
## Note [constant InputPolicy.BLOCK_ALL] also blocks [member toggle_action] — pair it
## with a [code]ui_*[/code] close path (ui_cancel) instead.
@export var input_policy := InputPolicy.ALLOW_ALL

## The actions [constant InputPolicy.BLOCK_ACTIONS] suppresses.
@export var blocked_actions: Array[StringName] = []

## How [member content] animates on open and close.
@export var transition: Transition = Transition.FADE

## The widget [constant Transition.GROW_FROM_SOURCE] grows out of and shrinks back into.
@export var grow_source: Control

## Animation duration, in seconds.
@export var duration := 0.35

## The box to animate. Defaults to the first [Control] child when unset.
@export var content: Control

var is_open := false

var _rest_position: Vector2
var _rest_captured := false
var _tween: Tween

func _ready() -> void:
	if content == null:
		content = _first_control_child()
	if content == null:
		push_warning("OverlayPanel '%s' has no content to animate." % name)
		return
	_apply_closed()

func _unhandled_input(event: InputEvent) -> void:
	if not toggle_action.is_empty() and ManagedInput.event_is_action_pressed(event, toggle_action):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	_claim_input()
	if content:
		_capture_rest()
		content.visible = true
		_animate(true)
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_release_input()
	if content:
		_animate(false)
	closed.emit()

# A panel freed or removed while open must not leave its input block behind.
func _exit_tree() -> void:
	_release_input()

# Claims this panel's input block per [member input_policy].
func _claim_input() -> void:
	match input_policy:
		InputPolicy.BLOCK_ALL:
			ManagedInput.block_actions(self)
		InputPolicy.BLOCK_ACTIONS:
			if not blocked_actions.is_empty():
				ManagedInput.block_actions(self, blocked_actions)

func _release_input() -> void:
	ManagedInput.unblock_actions(self)

func _animate(opening: bool) -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel()

	match transition:
		Transition.FADE:
			_tween.tween_property(content, "modulate:a", 1.0 if opening else 0.0, duration)
		Transition.GROW_CENTER:
			content.pivot_offset = content.size / 2.0
			_tween.tween_property(content, "scale", Vector2.ONE if opening else Vector2.ZERO, duration)
		Transition.GROW_FROM_SOURCE:
			content.pivot_offset = content.size / 2.0
			var closed_scale := Vector2.ZERO
			var closed_position := _rest_position
			if grow_source and content.size.x > 0.0:
				var source_rectangle := grow_source.get_global_rect()
				var factor := minf(source_rectangle.size.x, source_rectangle.size.y) / content.size.x
				closed_scale = Vector2(factor, factor)
				var parent := content.get_parent() as Control
				var to_local := parent.get_global_transform().affine_inverse()
				closed_position = (to_local * source_rectangle.get_center()) - content.size / 2.0
			if opening:
				if grow_source:
					grow_source.visible = false
				content.scale = closed_scale
				content.position = closed_position
				_tween.tween_property(content, "scale", Vector2.ONE, duration)
				_tween.tween_property(content, "position", _rest_position, duration)
			else:
				_tween.tween_property(content, "scale", closed_scale, duration)
				_tween.tween_property(content, "position", closed_position, duration)
		_:
			var hidden_position := _rest_position + _slide_offset()
			_tween.tween_property(content, "position", _rest_position if opening else hidden_position, duration)

	if not opening:
		_tween.chain().tween_callback(_finish_close)

## Restores [member content] to hidden once a close finishes, and brings the
## [member grow_source] widget back so it can be grown from again.
func _finish_close() -> void:
	content.visible = false
	if transition == Transition.GROW_FROM_SOURCE and grow_source:
		grow_source.visible = true

## Snaps [member content] to its closed state without animating.
func _apply_closed() -> void:
	content.visible = false
	match transition:
		Transition.FADE:
			content.modulate.a = 0.0
		Transition.GROW_CENTER, Transition.GROW_FROM_SOURCE:
			content.scale = Vector2.ZERO
		_:
			pass ## Resting position is captured on first open; leave layout untouched.

## Records the laid-out resting position once, then offsets a slide panel off-screen so
## the first open animates in from the correct edge.
func _capture_rest() -> void:
	if _rest_captured:
		return
	_rest_captured = true
	_rest_position = content.position
	if _is_slide():
		content.position = _rest_position + _slide_offset()

func _is_slide() -> bool:
	return transition in [
		Transition.SLIDE_FROM_LEFT,
		Transition.SLIDE_FROM_RIGHT,
		Transition.SLIDE_FROM_TOP,
		Transition.SLIDE_FROM_BOTTOM,
	]

func _slide_offset() -> Vector2:
	match transition:
		Transition.SLIDE_FROM_LEFT:
			return Vector2(-content.size.x, 0.0)
		Transition.SLIDE_FROM_RIGHT:
			return Vector2(content.size.x, 0.0)
		Transition.SLIDE_FROM_TOP:
			return Vector2(0.0, -content.size.y)
		Transition.SLIDE_FROM_BOTTOM:
			return Vector2(0.0, content.size.y)
		_:
			return Vector2.ZERO

func _first_control_child() -> Control:
	for child in get_children():
		if child is Control:
			return child
	return null
