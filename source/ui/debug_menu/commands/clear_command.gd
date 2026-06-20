class_name ClearCommand
extends ConsoleCommand

func _init() -> void:
	key = "clear"
	description = "clear console"
	allow_hint = true

func execute(args: PackedStringArray) -> void:
	super.execute(args)
