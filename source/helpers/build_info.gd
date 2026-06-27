class_name BuildInfo
## Build identity for the footnote watermark: "v1.0.0b1 (2026-06-26 14:32)". Version and build number live
## in project.godot ([code]application/config/version[/code] / [code]application/config/build[/code]); the
## timestamp is when this build was produced. Shown on the main menu, and on the encounter screen in debug
## builds only.

## "v<version>b<build> (<local build time>)".
static func stamp() -> String:
	var version: String = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var build: int = ProjectSettings.get_setting("application/config/build", 0)
	return "v%sb%d (%s)" % [version, build, _build_time()]

# When this build was produced, read off the running binary's timestamp. On an exported build (e.g. the
# phone) that's the actual build time; in the editor there's no build step, so we fall back to project.godot's
# mtime as the closest "last touched" proxy. Shown local, since it's a human-facing footnote.
static func _build_time() -> String:
	var path := OS.get_executable_path()
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://project.godot")
	var unix := FileAccess.get_modified_time(path)
	if unix == 0:
		return "unknown"
	var bias: int = Time.get_time_zone_from_system().bias
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return "%04d-%02d-%02d %02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute]
