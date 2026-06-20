class_name PauseCommand
extends ConsoleCommand

func _init() -> void:
	key = "pause"
	description = "toggle pause"
	allow_hint = true

func execute(args: PackedStringArray) -> void:
	PauseMonitor.toggle()
	super.execute(args)
