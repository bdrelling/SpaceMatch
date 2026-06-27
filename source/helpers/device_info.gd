class_name DeviceInfo
## The device this run renders as, in [enum DeviceUtils.DeviceType] terms. On a real build that's the
## platform; on a desktop preview the `--device=` launch flag (`make play-phone`/`play-tablet`)
## overrides it so the window mirrors the phone/iPad it stands in for. The `--device` flag is a
## SpaceMatch dev affordance, not an armory concept — DeviceUtils only lends the shared vocabulary.

## The active [enum DeviceUtils.DeviceType]: the `--device` launch flag when present (desktop
## previews), else the platform default — MOBILE on a real handheld build, DESKTOP otherwise.
static func device_type() -> DeviceUtils.DeviceType:
	if CommandLine.has_launch_argument_key("device"):
		return CommandLine.get_launch_option(
			"device", DeviceUtils.DEVICE_TYPE_NAMES, DeviceUtils.DeviceType.DESKTOP
		)
	return DeviceUtils.DeviceType.MOBILE if OS.has_feature("mobile") else DeviceUtils.DeviceType.DESKTOP

## Whether the active device is a handheld (phone or tablet) — real or emulated by a preview window.
## The signal for handheld-only behavior, like OS-owned app exit (no in-app Quit button).
static func is_handheld() -> bool:
	return device_type() in [DeviceUtils.DeviceType.MOBILE, DeviceUtils.DeviceType.TABLET]

## The device a desktop preview should simulate a safe area for, or -1 for the live OS safe area.
## Real hardware reports its own notch, so it's never simulated; only the `--device` previews stand in
## for one. Feeds [member SafeAreaContainer.default_simulated_device] at boot.
static func simulated_device() -> int:
	if OS.has_feature("mobile"):
		return -1
	var device := device_type()
	return device if DeviceUtils.DEVICE_SAFE_INSETS.has(device) else -1
