class_name BootConfig
extends RefCounted
## Decides which experience boots and how the screen is oriented.
##
## [member mode] selects the Arcade or Game entry scene; [member orientation] is
## the portrait/landscape lock to apply before that scene loads. Each resolves
## through [method CommandLine.get_launch_option]: a `--mode=` / `--orientation=`
## launch argument when present, otherwise a platform-derived default.

enum Mode { ARCADE, GAME }

## Maps a launch-argument value to a [enum Mode].
const MODE_NAMES := {
	"arcade": Mode.ARCADE,
	"game": Mode.GAME,
}

var mode: Mode
var orientation: DeviceUtils.Orientation

## Resolves the boot mode and orientation from the launch arguments and platform.
static func resolve() -> BootConfig:
	var config: BootConfig = BootConfig.new()
	config.mode = CommandLine.get_launch_option("mode", MODE_NAMES, default_mode())
	config.orientation = CommandLine.get_launch_option(
		"orientation", DeviceUtils.ORIENTATION_NAMES, DeviceUtils.get_default_orientation()
	)
	return config

## Mobile and web default to the Arcade; desktop and consoles default to the Game.
static func default_mode() -> Mode:
	if OS.has_feature(FeatureTag.MOBILE) or OS.has_feature(FeatureTag.WEB):
		return Mode.ARCADE
	return Mode.GAME
