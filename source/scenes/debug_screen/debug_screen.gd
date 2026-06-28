class_name DebugScreen
extends ScreenFrame
## The main-menu Debug landing — the [DebugNavigator] (opened on [DebugHomeView]) hosted in the standard
## [ScreenFrame] for the app background and safe-area insets. The navigator carries its own bar as it
## drills through pages, so the frame's own bar is hidden. Done returns to the [MainMenuScreen].

const SCENE_PATH := "res://scenes/debug_screen/debug_screen.tscn"

func _ready() -> void:
	super._ready()
	hide_bar()
	var navigator := DebugNavigator.create(DebugHomeView.new())
	navigator.closed.connect(_on_closed)
	set_content(navigator)

func _on_closed() -> void:
	SceneLoader.transition_to(MainMenuScreen.create())

static func create() -> DebugScreen:
	var scene: PackedScene = load(SCENE_PATH)
	return scene.instantiate()
