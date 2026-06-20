extends Node

const MAXIMUM_RUNS: int = 9

var _playtests_directory: String
var _delay: float
var _duration: float
var _interval: float
var _output_directory: String
var _elapsed: float = 0.0
var _capture_elapsed: float = 0.0
var _time_since_last_capture: float = 0.0
var _capturing: bool = false

func _ready() -> void:
	if not CommandLine.has_launch_argument_key("screenshot-interval"):
		queue_free()
		return
	process_mode = PROCESS_MODE_ALWAYS
	_playtests_directory = CommandLine.get_launch_argument_value("screenshot-dir", Playtests.directory())
	_delay = float(CommandLine.get_launch_argument_value("screenshot-delay", "0"))
	_duration = float(CommandLine.get_launch_argument_value("screenshot-duration", "0"))
	_interval = float(CommandLine.get_launch_argument_value("screenshot-interval", "10"))
	# ISO 8601, with ":" swapped for "-" since colons are illegal in paths. Keeps the "T"
	# date/time separator so runs sort chronologically by name.
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var label: String = CommandLine.get_launch_argument_value("screenshot-label", "")
	var run_name: String = timestamp if label.is_empty() else "%s-%s" % [timestamp, label]
	_output_directory = _playtests_directory.path_join(run_name)
	DirAccess.make_dir_recursive_absolute(_output_directory)
	_cleanup_old_runs()

func _process(delta: float) -> void:
	_elapsed += delta
	if not _capturing:
		if _elapsed >= _delay:
			_capturing = true
		return
	_capture_elapsed += delta
	_time_since_last_capture += delta
	if _time_since_last_capture >= _interval:
		_time_since_last_capture -= _interval
		_capture_frame()
	if _duration > 0.0 and _capture_elapsed >= _duration:
		get_tree().quit()

func _capture_frame() -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var seconds: int = int(_elapsed)
	var filename: String = "%03ds.png" % seconds
	image.save_png(_output_directory + "/" + filename)

func _cleanup_old_runs() -> void:
	var directory := DirAccess.open(_playtests_directory)
	if not directory:
		return
	var runs: Array[String] = []
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		# Only prune our own timestamped run dirs; never touch unrelated folders that
		# happen to share the directory (so a stray dir can't evict a live capture).
		if directory.current_is_dir() and entry.begins_with("20") and entry.contains("T"):
			runs.append(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	runs.sort()
	while runs.size() > MAXIMUM_RUNS:
		var oldest: String = runs.pop_front()
		_remove_directory(_playtests_directory.path_join(oldest))

func _remove_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if not directory:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while entry != "":
		if not directory.current_is_dir():
			directory.remove(entry)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
