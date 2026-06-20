class_name RustboardPanel
extends DebugPanel
## Rustboard tab: load/edit/save RustboardBlueprints, applying edits to the player's
## live board. Mirrors [PlayerPanel]; targets [code]player.rustboard[/code].

const _BLUEPRINT_DIRECTORY: String = "res://systems/rustboarding/blueprints/"

var _loaded: bool = false
var _blueprint_paths: Array[String] = []
var _blueprint_names: Array[String] = []
var _blueprint_index: Array[int] = [0]
var _save_as_name: Array[String] = [""]
var _baseline_values: Array[float] = []
var _loaded_blueprint_index: int = 0
var _pending_blueprint_index: int = -1
var _working_blueprint: RustboardBlueprint = null

var _max_speed: Array[float] = [0.0]
var _nudge_acceleration: Array[float] = [0.0]
var _slope_acceleration_scale: Array[float] = [0.0]
var _kinetic_friction: Array[float] = [0.0]
var _static_friction: Array[float] = [0.0]
var _lateral_friction: Array[float] = [0.0]
var _stop_speed: Array[float] = [0.0]
var _rotation_speed: Array[float] = [0.0]
var _deploy_tilt_degrees: Array[float] = [0.0]
var _alignment_speed: Array[float] = [0.0]
var _straighten_speed: Array[float] = [0.0]
var _air_righting_speed: Array[float] = [0.0]
var _straighten_fade_speed: Array[float] = [0.0]
var _carve_grip: Array[float] = [0.0]
var _speed_turn_falloff: Array[float] = [0.0]
var _steer_ramp: Array[float] = [0.0]
var _lean_degrees: Array[float] = [0.0]
var _normal_smoothing: Array[float] = [0.0]

func title() -> StringName:
	return &"Rustboard"

func is_available() -> bool:
	return is_instance_valid(_menu.player) and is_instance_valid(_menu.player.rustboard)

func _rustboard() -> Rustboard:
	return _menu.player.rustboard

func draw() -> void:
	if not _loaded:
		_scan_blueprints()
		if not _blueprint_paths.is_empty():
			_load_blueprint_values(0)
		_loaded = true

	if not _blueprint_paths.is_empty():
		if ImGui.ComboChar(&"Blueprint", _blueprint_index, _blueprint_names, _blueprint_names.size()):
			if _is_modified():
				_pending_blueprint_index = _blueprint_index[0]
				_blueprint_index[0] = _loaded_blueprint_index
				ImGui.OpenPopup(&"Discard changes?##rb_discard")
			else:
				_select_blueprint(_blueprint_index[0])
		if _is_modified():
			ImGui.SameLine()
			ImGui.TextDisabled("(modified)")
	_draw_discard_popup()

	# Editing live-applies to the player's board so tweaks are felt immediately;
	# the saved blueprint on disk is untouched until Save.
	var changed: bool = false
	ImGui.SeparatorText(&"Speed")
	changed = _drag_float(&"Max Speed", _max_speed, Rustboard.MAX_SPEED_STEP, Rustboard.MAX_SPEED_MIN, Rustboard.MAX_SPEED_MAX, "%.1f") or changed
	changed = _drag_float(&"Nudge Acceleration", _nudge_acceleration, Rustboard.NUDGE_ACCELERATION_STEP, Rustboard.NUDGE_ACCELERATION_MIN, Rustboard.NUDGE_ACCELERATION_MAX, "%.2f") or changed
	changed = _drag_float(&"Slope Accel Scale", _slope_acceleration_scale, Rustboard.SLOPE_ACCELERATION_SCALE_STEP, Rustboard.SLOPE_ACCELERATION_SCALE_MIN, Rustboard.SLOPE_ACCELERATION_SCALE_MAX, "%.2f") or changed

	ImGui.SeparatorText(&"Friction")
	changed = _drag_float(&"Kinetic Friction", _kinetic_friction, Rustboard.KINETIC_FRICTION_STEP, Rustboard.KINETIC_FRICTION_MIN, Rustboard.KINETIC_FRICTION_MAX, "%.3f") or changed
	changed = _drag_float(&"Static Friction", _static_friction, Rustboard.STATIC_FRICTION_STEP, Rustboard.STATIC_FRICTION_MIN, Rustboard.STATIC_FRICTION_MAX, "%.3f") or changed
	changed = _drag_float(&"Lateral Friction", _lateral_friction, Rustboard.LATERAL_FRICTION_STEP, Rustboard.LATERAL_FRICTION_MIN, Rustboard.LATERAL_FRICTION_MAX, "%.2f") or changed
	changed = _drag_float(&"Stop Speed", _stop_speed, Rustboard.STOP_SPEED_STEP, Rustboard.STOP_SPEED_MIN, Rustboard.STOP_SPEED_MAX, "%.2f") or changed

	ImGui.SeparatorText(&"Handling")
	changed = _drag_float(&"Rotation Speed", _rotation_speed, Rustboard.ROTATION_SPEED_STEP, Rustboard.ROTATION_SPEED_MIN, Rustboard.ROTATION_SPEED_MAX, "%.2f") or changed
	changed = _drag_float(&"Deploy Tilt", _deploy_tilt_degrees, Rustboard.DEPLOY_TILT_DEGREES_STEP, Rustboard.DEPLOY_TILT_DEGREES_MIN, Rustboard.DEPLOY_TILT_DEGREES_MAX, "%.1f") or changed
	changed = _drag_float(&"Alignment Speed", _alignment_speed, Rustboard.ALIGNMENT_SPEED_STEP, Rustboard.ALIGNMENT_SPEED_MIN, Rustboard.ALIGNMENT_SPEED_MAX, "%.1f") or changed
	changed = _drag_float(&"Straighten Speed", _straighten_speed, Rustboard.STRAIGHTEN_SPEED_STEP, Rustboard.STRAIGHTEN_SPEED_MIN, Rustboard.STRAIGHTEN_SPEED_MAX, "%.2f") or changed
	changed = _drag_float(&"Air Righting Speed", _air_righting_speed, Rustboard.AIR_RIGHTING_SPEED_STEP, Rustboard.AIR_RIGHTING_SPEED_MIN, Rustboard.AIR_RIGHTING_SPEED_MAX, "%.1f") or changed
	changed = _drag_float(&"Straighten Fade Speed", _straighten_fade_speed, Rustboard.STRAIGHTEN_FADE_SPEED_STEP, Rustboard.STRAIGHTEN_FADE_SPEED_MIN, Rustboard.STRAIGHTEN_FADE_SPEED_MAX, "%.1f") or changed

	ImGui.SeparatorText(&"Carve")
	changed = _drag_float(&"Carve Grip", _carve_grip, Rustboard.CARVE_GRIP_STEP, Rustboard.CARVE_GRIP_MIN, Rustboard.CARVE_GRIP_MAX, "%.2f") or changed
	changed = _drag_float(&"Speed Turn Falloff", _speed_turn_falloff, Rustboard.SPEED_TURN_FALLOFF_STEP, Rustboard.SPEED_TURN_FALLOFF_MIN, Rustboard.SPEED_TURN_FALLOFF_MAX, "%.3f") or changed
	changed = _drag_float(&"Steer Ramp", _steer_ramp, Rustboard.STEER_RAMP_STEP, Rustboard.STEER_RAMP_MIN, Rustboard.STEER_RAMP_MAX, "%.1f") or changed
	changed = _drag_float(&"Lean Degrees", _lean_degrees, Rustboard.LEAN_DEGREES_STEP, Rustboard.LEAN_DEGREES_MIN, Rustboard.LEAN_DEGREES_MAX, "%.1f") or changed
	changed = _drag_float(&"Normal Smoothing", _normal_smoothing, Rustboard.NORMAL_SMOOTHING_STEP, Rustboard.NORMAL_SMOOTHING_MIN, Rustboard.NORMAL_SMOOTHING_MAX, "%.1f") or changed

	if changed:
		_apply_live_stats()

	ImGui.Spacing()
	ImGui.Spacing()
	if ImGui.Button(&"Save Blueprint"):
		_save_to_disk()

	ImGui.Spacing()
	ImGui.Text("Save as new blueprint:")
	ImGui.SetNextItemWidth(200.0)
	ImGui.InputText(&"##rb_save_as_name", _save_as_name, 128, 0)
	ImGui.SameLine()
	if ImGui.Button(&"Save As"):
		_save_as()

func _draw_discard_popup() -> void:
	var viewport_size: Vector2 = _menu.get_viewport().get_visible_rect().size
	ImGui.SetNextWindowPos(viewport_size * 0.5 - Vector2(150.0, 40.0), ImGui.Cond_Appearing)
	# Empty pass-by-ref array → the modal renders without a close (X) button.
	var no_close: Array[bool] = []
	if ImGui.BeginPopupModal(&"Discard changes?##rb_discard", no_close, 0):
		ImGui.Text("Discard unsaved changes to this blueprint?")
		ImGui.Spacing()
		if ImGui.Button(&"Discard"):
			_select_blueprint(_pending_blueprint_index)
			_pending_blueprint_index = -1
			ImGui.CloseCurrentPopup()
		ImGui.SameLine()
		if ImGui.Button(&"Cancel"):
			_pending_blueprint_index = -1
			ImGui.CloseCurrentPopup()
		ImGui.EndPopup()

func _select_blueprint(index: int) -> void:
	_blueprint_index[0] = index
	_load_blueprint_values(index)
	_apply_blueprint_to_board()

func _apply_live_stats() -> void:
	if not _working_blueprint:
		_working_blueprint = RustboardBlueprint.new()
	_write_values_to_blueprint(_working_blueprint)
	_rustboard().apply_stats(_working_blueprint)

func _load_blueprint_values(index: int) -> void:
	var blueprint: RustboardBlueprint = _load_blueprint(_blueprint_paths[index])
	if not blueprint:
		_log("[Rustboard] Failed to load: " + _blueprint_paths[index])
		return
	_max_speed[0] = blueprint.max_speed
	_nudge_acceleration[0] = blueprint.nudge_acceleration
	_slope_acceleration_scale[0] = blueprint.slope_acceleration_scale
	_kinetic_friction[0] = blueprint.kinetic_friction
	_static_friction[0] = blueprint.static_friction
	_lateral_friction[0] = blueprint.lateral_friction
	_stop_speed[0] = blueprint.stop_speed
	_rotation_speed[0] = blueprint.rotation_speed
	_deploy_tilt_degrees[0] = blueprint.deploy_tilt_degrees
	_alignment_speed[0] = blueprint.alignment_speed
	_straighten_speed[0] = blueprint.straighten_speed
	_air_righting_speed[0] = blueprint.air_righting_speed
	_straighten_fade_speed[0] = blueprint.straighten_fade_speed
	_carve_grip[0] = blueprint.carve_grip
	_speed_turn_falloff[0] = blueprint.speed_turn_falloff
	_steer_ramp[0] = blueprint.steer_ramp
	_lean_degrees[0] = blueprint.lean_degrees
	_normal_smoothing[0] = blueprint.normal_smoothing
	_baseline_values = _current_values()
	_loaded_blueprint_index = index

# Loads fresh from disk (ignoring the cache) so panel/baseline state reflects what
# is actually saved, not an instance a prior Apply mutated.
func _load_blueprint(path: String) -> RustboardBlueprint:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as RustboardBlueprint

func _scan_blueprints() -> void:
	_blueprint_paths.clear()
	_blueprint_names.clear()
	var directory: DirAccess = DirAccess.open(_BLUEPRINT_DIRECTORY)
	if not directory:
		_log("[Rustboard] Failed to open blueprint directory: " + _BLUEPRINT_DIRECTORY)
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			_blueprint_paths.append(_BLUEPRINT_DIRECTORY + file_name)
			_blueprint_names.append(file_name.get_basename())

func _current_values() -> Array[float]:
	return [
		_max_speed[0], _nudge_acceleration[0], _slope_acceleration_scale[0],
		_kinetic_friction[0], _static_friction[0], _lateral_friction[0],
		_stop_speed[0], _rotation_speed[0], _deploy_tilt_degrees[0],
		_alignment_speed[0], _straighten_speed[0], _air_righting_speed[0],
		_straighten_fade_speed[0], _carve_grip[0], _speed_turn_falloff[0],
		_steer_ramp[0], _lean_degrees[0], _normal_smoothing[0],
	]

func _is_modified() -> bool:
	# Tolerance compare: the ImGui DragFloat binding round-trips through 32-bit
	# floats each frame, so values drift from the pristine doubles by ~1e-7.
	var current: Array[float] = _current_values()
	if current.size() != _baseline_values.size():
		return true
	for i: int in current.size():
		if not is_equal_approx(current[i], _baseline_values[i]):
			return true
	return false

func _write_values_to_blueprint(blueprint: RustboardBlueprint) -> void:
	blueprint.max_speed = _max_speed[0]
	blueprint.nudge_acceleration = _nudge_acceleration[0]
	blueprint.slope_acceleration_scale = _slope_acceleration_scale[0]
	blueprint.kinetic_friction = _kinetic_friction[0]
	blueprint.static_friction = _static_friction[0]
	blueprint.lateral_friction = _lateral_friction[0]
	blueprint.stop_speed = _stop_speed[0]
	blueprint.rotation_speed = _rotation_speed[0]
	blueprint.deploy_tilt_degrees = _deploy_tilt_degrees[0]
	blueprint.alignment_speed = _alignment_speed[0]
	blueprint.straighten_speed = _straighten_speed[0]
	blueprint.air_righting_speed = _air_righting_speed[0]
	blueprint.straighten_fade_speed = _straighten_fade_speed[0]
	blueprint.carve_grip = _carve_grip[0]
	blueprint.speed_turn_falloff = _speed_turn_falloff[0]
	blueprint.steer_ramp = _steer_ramp[0]
	blueprint.lean_degrees = _lean_degrees[0]
	blueprint.normal_smoothing = _normal_smoothing[0]

func _apply_blueprint_to_board() -> void:
	var blueprint: RustboardBlueprint = _load_blueprint(_blueprint_paths[_blueprint_index[0]])
	if not blueprint:
		return
	_write_values_to_blueprint(blueprint)
	_rustboard().apply_blueprint(blueprint)
	_log("[Rustboard] Blueprint applied.")

func _save_to_disk() -> void:
	var path: String = _blueprint_paths[_blueprint_index[0]]
	var blueprint: RustboardBlueprint = _load_blueprint(path)
	if not blueprint:
		_log("[Rustboard] Save failed: could not load blueprint.")
		return
	_write_values_to_blueprint(blueprint)
	var error: Error = ResourceSaver.save(blueprint, path)
	if error == OK:
		_baseline_values = _current_values()
		_log("[Rustboard] Saved → " + path)
	else:
		_log("[Rustboard] Save failed (err " + str(error) + ")")

func _save_as() -> void:
	var file_name: String = _save_as_name[0].strip_edges()
	if file_name.is_empty():
		_log("[Rustboard] Save As: name is empty.")
		return
	if not file_name.ends_with(".tres"):
		file_name += ".tres"
	var path: String = _BLUEPRINT_DIRECTORY + file_name
	var source: RustboardBlueprint = _load_blueprint(_blueprint_paths[_blueprint_index[0]])
	if not source:
		_log("[Rustboard] Save As failed: could not load source blueprint.")
		return
	var copy: RustboardBlueprint = source.duplicate() as RustboardBlueprint
	_write_values_to_blueprint(copy)
	var error: Error = ResourceSaver.save(copy, path)
	if error != OK:
		_log("[Rustboard] Save As failed (err " + str(error) + ")")
		return
	_log("[Rustboard] Saved as → " + path)
	_save_as_name[0] = ""
	_scan_blueprints()
	var new_index: int = _blueprint_paths.find(path)
	_blueprint_index[0] = new_index if new_index >= 0 else 0
	_load_blueprint_values(_blueprint_index[0])
