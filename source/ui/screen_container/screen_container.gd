class_name ScreenContainer
extends Control
## A full-window presentation container: the app's themed [Background] behind a [SafeAreaContainer] that
## insets its content to the device safe area. Wrap any standalone screen in one so it presents the same
## way every time — same background, same safe-area insets, the project theme. The reusable answer to
## "this screen has no background / runs into the notch": present it with
## [code]SceneLoader.transition_to(ScreenContainer.create(content))[/code].
##
## Its only job is the background and the safe area. It deliberately adds no bars (no navigation bar);
## a screen that needs those uses [ScreenFrame] instead, or owns them itself.

#region Constants

## Loaded on demand in [method create] rather than `preload`-ed, mirroring the other screens:
## referencing [ScreenContainer] never pulls the scene into memory — only [method create] does.
const SCENE_PATH := "res://ui/screen_container/screen_container.tscn"

#endregion

#region Methods

## Mounts [param content] inside the safe area, replacing anything already there. Returns self so a
## freshly built container can be transitioned to inline.
func set_content(content: Control) -> ScreenContainer:
	var safe_area := _safe_area()
	for child: Node in safe_area.get_children():
		safe_area.remove_child(child)
		child.queue_free()
	if content != null:
		safe_area.add_child(content)
	return self

# The safe-area-inset region content mounts into — authored as a child in the scene.
func _safe_area() -> SafeAreaContainer:
	return $SafeArea as SafeAreaContainer

## Builds a ScreenContainer presenting [param content] — the standard way to show a standalone screen:
## [code]SceneLoader.transition_to(ScreenContainer.create(content))[/code].
static func create(content: Control = null) -> ScreenContainer:
	var scene: PackedScene = load(SCENE_PATH)
	var container: ScreenContainer = scene.instantiate()
	container.set_content(content)
	return container

#endregion
