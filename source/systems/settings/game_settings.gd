class_name GameSettings
extends RefCounted
## Typed accessor for the [code]game[/code] settings group.
##
## Reads resolve to the player's explicit override when one exists, otherwise to
## the shipped default from [member DEFAULTS]. Assigning a property records
## an override and persists it; [method clear] drops an override so the setting
## falls back to the default again. Only overridden keys are written to
## [member SAVE_PATH], so changing a default later still reaches players who
## never touched that setting.

signal changed

## The shipped default for each setting, keyed by name. Reads fall back here when
## the player has no override. Empty for now — the 3D camera/player options
## (camera_mode, invert_y_axis, sprint_mode) were removed with the overworld; add
## 2D game settings here as they arrive.
const DEFAULTS: Dictionary = {}
const SAVE_PATH: String = "user://game_settings.cfg"
const SECTION: String = "game"

var _overrides: Dictionary

func _init() -> void:
	_load_overrides()

## Returns [code]true[/code] when [param key] has no override and resolves to the default.
func is_default(key: StringName) -> bool:
	return not _overrides.has(key)

## Returns the shipped default value for [param key], ignoring any override.
func get_default(key: StringName) -> Variant:
	return DEFAULTS.get(key)

## Drops all overrides so every setting falls back to its shipped default.
func clear_all() -> void:
	if _overrides.is_empty():
		return
	_overrides.clear()
	_save()
	changed.emit()

## Drops the override for [param key] so it falls back to the shipped default.
func clear(key: StringName) -> void:
	if not _overrides.has(key):
		return
	_overrides.erase(key)
	_save()
	changed.emit()

func _set_override(key: StringName, value: Variant) -> void:
	if _overrides.has(key) and _overrides[key] == value:
		return
	_overrides[key] = value
	_save()
	changed.emit()

func _load_overrides() -> void:
	_overrides = {}
	var config: ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section(SECTION):
		return
	for key: String in config.get_section_keys(SECTION):
		_overrides[StringName(key)] = config.get_value(SECTION, key)

func _save() -> void:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in _overrides:
		config.set_value(SECTION, String(key), _overrides[key])
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		Log.warning("GameSettings: failed to save overrides to %s (error %d)." % [SAVE_PATH, error])
