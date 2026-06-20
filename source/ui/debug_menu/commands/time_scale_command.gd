class_name TimeScaleCommand
extends ConsoleCommand

func _init() -> void:
	key = "time_scale"
	description = "set engine time scale"
	allow_hint = true

func execute(args: PackedStringArray) -> void:
	if args.size() > 0 and args[0].is_valid_float():
		Engine.time_scale = float(args[0])
		output_line("  time_scale → " + args[0])
		super.execute(args)
	else:
		output_line("  usage: /time_scale <number>")
