class_name HelpCommand
extends ConsoleCommand

var _registry: Dictionary[String, ConsoleCommand]

func _init(registry: Dictionary[String, ConsoleCommand]) -> void:
	key = "help"
	description = "show commands"
	allow_hint = false
	_registry = registry

func execute(args: PackedStringArray) -> void:
	for command: ConsoleCommand in _registry.values():
		output_line("  /" + command.key + "  —  " + command.description)
	super.execute(args)
