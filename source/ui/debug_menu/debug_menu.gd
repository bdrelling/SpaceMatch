class_name DebugMenu
extends Node
## Hosts the ImGui debug window: a tab bar over a list of [DebugPanel]s. Each panel
## owns its own state and draws its own tab; this node just routes the window, the
## toggle, and the shared console log. Add a subsystem = add one panel to [_panels].

@export var player: Player
## Drives the Environment tab. Wire to the scene's Atmosphere node; the tab hides when null.
@export var atmosphere: Atmosphere
## Drives the Material tab. Wire to the scene's MaterialTester node; the tab hides when null.
@export var material_tester: MaterialTester

var _is_open: bool = false
# ImGui pass-by-ref array for the window's close (X) button.
var _window_open_state: Array[bool] = [true]
# Empty array → tab items render without a per-tab close (X) button.
var _tab_close_disabled: Array[bool] = []

var _console: ConsolePanel
var _panels: Array[DebugPanel] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_console = ConsolePanel.new(self)
	_panels = [
		_console,
		PlayerPanel.new(self),
		RustboardPanel.new(self),
		EnvironmentPanel.new(self),
		MaterialPanel.new(self),
	]
	_console.register_builtin_commands(get_tree())
	log_line("Debug menu ready. Press ` to toggle. Type 'help' for commands.")

## Append a line to the console log. Panels reach this via [method DebugPanel._log].
func log_line(line: String) -> void:
	_console.push_line(line)

func _process(_delta: float) -> void:
	# The native imgui-godot GDExtension does not re-emit ImGuiRoot.imgui_layout;
	# the canonical GDScript pattern is to issue ImGui calls directly in _process.
	# ImGui's NewFrame runs at min process priority and Render at max, so this
	# node's default-priority _process lands safely between them.
	if ManagedInput.is_action_just_pressed(InputAction.TOGGLE_DEBUG_MENU):
		_is_open = not _is_open
	if not _is_open:
		return
	_draw_window()

func _draw_window() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var window_size: Vector2 = viewport_size * 0.5
	var window_position: Vector2 = (viewport_size - window_size) * 0.5
	ImGui.SetNextWindowPos(window_position, ImGui.Cond_Always)
	ImGui.SetNextWindowSize(window_size, ImGui.Cond_Always)

	_window_open_state[0] = true
	if ImGui.Begin(&"Debug##root", _window_open_state, ImGui.WindowFlags_NoResize | ImGui.WindowFlags_NoMove | ImGui.WindowFlags_NoCollapse):
		if ImGui.BeginTabBar(&"##tabs", 0):
			for panel: DebugPanel in _panels:
				if panel.is_available() and ImGui.BeginTabItem(panel.title(), _tab_close_disabled, 0):
					panel.draw()
					ImGui.EndTabItem()
			ImGui.EndTabBar()
	ImGui.End()

	if not _window_open_state[0]:
		_is_open = false
