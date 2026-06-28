class_name DebugView
extends VBoxContainer
## Base for one screen in the [DebugNavigator] stack — an editor page. A view reports its [method title]
## and builds its body in [method _build] (collapsible [DebugSection]s, [DebugRow] controls, or a list of
## nav rows into deeper views). To drill into another view, call [method _push]; the navigator owns the
## stack, header, and back button. A view is a vertical column the navigator scrolls.

## Asks the navigator to push [param view] onto the stack (a drill-in). Emitted by [method _push].
signal push_requested(view: DebugView)

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	_build()

## The page title shown in the navigator header. Override per page.
func title() -> String:
	return "Debug"

## An optional header action for this page (e.g. a "+" to add a rule), placed top-right by the navigator.
## Override to provide one; null means no action. A fresh button is built each time the page is shown.
func action() -> Button:
	return null

## Override to populate the page. Runs once when the view is mounted.
func _build() -> void:
	pass

## Drills into [param view] — the navigator pushes it and shows a back button.
func _push(view: DebugView) -> void:
	push_requested.emit(view)

## Clears and re-runs [method _build] in place — for after the underlying data changed (e.g. an add).
func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_build()
