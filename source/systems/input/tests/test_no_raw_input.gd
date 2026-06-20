extends GdUnitTestSuite
## Guards the [ManagedInput] invariant: no game script reads the [Input] singleton
## directly. All input flows through [ManagedInput] so focus / UI-capture gating can
## never be bypassed or forgotten at a new call site.
##
## Exempt: [ManagedInput] itself (it *is* the gated mirror), test suites that simulate
## presses via raw [Input], [JoypadLayout] (reads controller metadata, not input state),
## third-party [code]addons/[/code], throwaway [code]demos/[/code], and this scanner.
## A genuine bypass must edit [member _EXEMPT].

const _EXEMPT: Array[String] = [
	"res://systems/input/managed_input.gd",
	"res://systems/input/joypad_layout.gd",
	"res://systems/input/tests/test_no_raw_input.gd",
	"res://systems/input/tests/test_managed_input.gd",
	"res://entities/player/tests/test_player_collect.gd",
	"res://ui/overlay_panel/tests/test_overlay_panel.gd",
]

# Subtrees skipped entirely (third-party / throwaway).
const _SKIP_DIRS: Array[String] = [
	"res://addons",
	"res://systems/world/demos",
]

func test_no_direct_input_singleton_usage() -> void:
	var regex := RegEx.new()
	# \bInput\. matches the Input singleton only — not ManagedInput., InputMap.,
	# InputEvent, or InputAction. (those have no word boundary / no dot after "Input").
	regex.compile("\\bInput\\.")

	var offenders: Array[String] = []
	for path in _scan_gd_files("res://"):
		if path in _EXEMPT:
			continue
		var line_no := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			line_no += 1
			if line.strip_edges().begins_with("#"):
				continue
			if regex.search(line):
				offenders.append("%s:%d  %s" % [path, line_no, line.strip_edges()])

	assert_array(offenders).override_failure_message(
		"Direct Input singleton use found — route these through ManagedInput:\n%s"
		% "\n".join(PackedStringArray(offenders))
	).is_empty()

func _scan_gd_files(directory_path: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return found
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := directory_path.path_join(entry)
			if directory.current_is_dir():
				if not full in _SKIP_DIRS:
					found.append_array(_scan_gd_files(full))
			elif entry.ends_with(".gd"):
				found.append(full)
		entry = directory.get_next()
	return found
