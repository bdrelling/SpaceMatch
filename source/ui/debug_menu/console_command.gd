class_name ConsoleCommand
extends RefCounted

var key: String
var description: String
var allow_hint: bool

signal executed(args: PackedStringArray)
signal output(line: String)

func execute(args: PackedStringArray) -> void:
	executed.emit(args)

## Subclasses call this to push a line of text to whoever connected to [signal output]
## (the [ConsolePanel]). The signal is owned and fired here in the base rather than
## emitted directly from each command.
func output_line(line: String) -> void:
	output.emit(line)
