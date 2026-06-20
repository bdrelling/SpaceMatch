@tool
class_name SilhouetteOutline
extends Node
## Drop this under a [Camera3D] to give it the screen-space silhouette outline (see
## [SilhouetteOutlineEffect]). On ready it installs the CompositorEffect onto the parent
## camera's Compositor; on exit it removes it again. Fully decoupled — it adds no camera and
## works on any [Camera3D]; objects opt into being outlined independently via
## [SilhouetteHighlighter.set_highlighted].

## Outline colour. HDR (energy > 1) so it blooms once glow is enabled.
@export var outline_color := Color(0.6, 0.85, 1.0) * 2.0
## Outline thickness in pixels.
@export_range(1, 16) var thickness: int = 2

## Per-game highlight behaviour (see [InteractionFocus]). When true, only the single focused
## interactable is highlighted at a time and the focus is sticky — a newly-arrived interactable
## never steals it. When false, every in-range interactable highlights at once. Configured here,
## on the highlight node dropped into the scene, rather than per-player.
@export var exclusive_highlight: bool = true:
	set(value):
		exclusive_highlight = value
		if is_node_ready() and not Engine.is_editor_hint():
			InteractionFocus.set_exclusive(value)

var _effect: SilhouetteOutlineEffect
var _owns_compositor: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	InteractionFocus.set_exclusive(exclusive_highlight)
	var camera := get_parent() as Camera3D
	if camera == null:
		push_warning("SilhouetteOutline must be a child of a Camera3D")
		return
	_effect = SilhouetteOutlineEffect.new()
	_effect.outline_color = outline_color
	_effect.thickness = thickness
	var compositor := camera.compositor
	if compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
		_owns_compositor = true
	compositor.compositor_effects = compositor.compositor_effects + [_effect]

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var camera := get_parent() as Camera3D
	if camera == null or _effect == null:
		return
	var compositor := camera.compositor
	if compositor != null:
		var effects := compositor.compositor_effects.duplicate()
		effects.erase(_effect)
		compositor.compositor_effects = effects
		if _owns_compositor and effects.is_empty():
			camera.compositor = null
	_effect = null
