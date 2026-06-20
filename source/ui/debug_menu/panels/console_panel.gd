class_name ConsolePanel
extends DebugPanel
## Console tab: command input + hints, and the shared log buffer other panels write to.

const _MAX_LINES: int = 500
const _HINT_ROW_HEIGHT: float = 20.0
const _HINT_MAX_VISIBLE: int = 5

var _log_lines: Array[String] = []
var _input: Array[String] = [""]
var _commands: Dictionary[String, ConsoleCommand] = {}
var _focus_input: bool = false

func title() -> StringName:
	return &"Console"

func push_line(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > _MAX_LINES:
		_log_lines.pop_front()

func register_command(command: ConsoleCommand) -> void:
	_commands[command.key] = command

func unregister_command(key: String) -> void:
	_commands.erase(key)

func register_builtin_commands(scene_tree: SceneTree) -> void:
	var help_command := HelpCommand.new(_commands)
	help_command.output.connect(push_line)
	register_command(help_command)

	var clear_command := ClearCommand.new()
	clear_command.executed.connect(func(_args: PackedStringArray) -> void: _log_lines.clear())
	register_command(clear_command)

	register_command(QuitCommand.new(scene_tree))
	register_command(PauseCommand.new())

	var time_scale_command := TimeScaleCommand.new()
	time_scale_command.output.connect(push_line)
	register_command(time_scale_command)

func draw() -> void:
	var available: Vector2 = ImGui.GetContentRegionAvail()
	var hints: Array[ConsoleCommand] = _active_hints()
	var hint_count: int = mini(hints.size(), _HINT_MAX_VISIBLE)
	var hint_height: float = float(hint_count) * _HINT_ROW_HEIGHT + 8.0 if hint_count > 0 else 0.0

	if ImGui.BeginChild(&"##console_log", Vector2(0.0, available.y - 34.0 - hint_height), ImGui.ChildFlags_Borders, 0):
		for line: String in _log_lines:
			ImGui.Text(line)
		if ImGui.GetScrollY() >= ImGui.GetScrollMaxY():
			ImGui.SetScrollHereY(1.0)
	ImGui.EndChild()

	if hint_count > 0:
		if ImGui.BeginChild(&"##cmd_hints", Vector2(0.0, hint_height), ImGui.ChildFlags_Borders, 0):
			for command: ConsoleCommand in hints:
				var label: String = "/" + command.key + "##hint_" + command.key
				if ImGui.Selectable(StringName(label)):
					_input[0] = "/" + command.key + " "
					_focus_input = true
				if not command.description.is_empty():
					ImGui.SameLine()
					ImGui.TextDisabled(command.description)
		ImGui.EndChild()

	if _focus_input:
		ImGui.SetKeyboardFocusHere()
		_focus_input = false
	ImGui.SetNextItemWidth(available.x - 60.0)
	if ImGui.InputText(&"##console_input", _input, 1024, ImGui.InputTextFlags_EnterReturnsTrue):
		_run(_input[0])
		_input[0] = ""
		_focus_input = true
	ImGui.SameLine()
	if ImGui.Button(&"Run"):
		_run(_input[0])
		_input[0] = ""

func _active_hints() -> Array[ConsoleCommand]:
	var input: String = _input[0]
	if not input.begins_with("/"):
		return []
	var after_slash: String = input.substr(1)
	if after_slash.contains(" "):
		return []
	var result: Array[ConsoleCommand] = []
	for command: ConsoleCommand in _commands.values():
		if command.allow_hint and command.key.begins_with(after_slash.to_lower()):
			result.append(command)
	return result

func _run(raw: String) -> void:
	var command: String = raw.strip_edges()
	if command.is_empty():
		return
	push_line("> " + command)
	if command.begins_with("/"):
		command = command.substr(1)
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return
	var key: String = parts[0].to_lower()
	if not _commands.has(key):
		push_line("  unknown: '" + parts[0] + "' (try 'help')")
		return
	var args: PackedStringArray = parts.slice(1)
	_commands[key].execute(args)
