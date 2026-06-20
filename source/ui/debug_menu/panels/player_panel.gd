class_name PlayerPanel
extends DebugPanel
## Player tab: load/edit/save PlayerBlueprints, applying edits to the live player.

const _BLUEPRINT_DIRECTORY: String = "res://entities/player/blueprint/"

var _loaded: bool = false
var _blueprint_paths: Array[String] = []
var _blueprint_names: Array[String] = []
var _blueprint_index: Array[int] = [0]
var _save_as_name: Array[String] = [""]
var _baseline_values: Array[float] = []
# Index whose on-disk values are currently loaded (the baseline / combo selection).
var _loaded_blueprint_index: int = 0
# Target index awaiting discard confirmation; -1 when no prompt is pending.
var _pending_blueprint_index: int = -1
# Ephemeral blueprint that edited stats are pushed onto and applied live.
var _working_blueprint: PlayerBlueprint = null

var _move_speed: Array[float] = [0.0]
var _jump_velocity: Array[float] = [0.0]
var _sprint_multiplier: Array[float] = [0.0]
var _ground_deceleration: Array[float] = [0.0]
var _pivot_speed: Array[float] = [0.0]
var _capsule_radius: Array[float] = [0.0]
var _capsule_height: Array[float] = [0.0]
var _max_stamina: Array[float] = [0.0]
var _stamina_drain_rate: Array[float] = [0.0]
var _stamina_regen_rate: Array[float] = [0.0]

func title() -> StringName:
	return &"Player"

func is_available() -> bool:
	return is_instance_valid(_menu.player)

func draw() -> void:
	if not _loaded:
		_scan_blueprints()
		if not _blueprint_paths.is_empty():
			_load_blueprint_values(0)
		_loaded = true

	if not _blueprint_paths.is_empty():
		if ImGui.ComboChar(&"Blueprint", _blueprint_index, _blueprint_names, _blueprint_names.size()):
			if _is_modified():
				# Don't lose unsaved edits silently — confirm first, and keep the
				# combo showing the loaded blueprint until the user decides.
				_pending_blueprint_index = _blueprint_index[0]
				_blueprint_index[0] = _loaded_blueprint_index
				ImGui.OpenPopup(&"Discard changes?##bp_discard")
			else:
				_select_blueprint(_blueprint_index[0])
		if _is_modified():
			ImGui.SameLine()
			ImGui.TextDisabled("(modified)")
	_draw_discard_popup()

	# Editing any value live-applies the working blueprint to the player so tweaks
	# are felt immediately; the saved blueprint on disk is untouched until Save.
	var changed: bool = false
	ImGui.SeparatorText(&"Movement")
	changed = _drag_float(&"Move Speed", _move_speed, Player.MOVE_SPEED_STEP, Player.MOVE_SPEED_MIN, Player.MOVE_SPEED_MAX, "%.2f") or changed
	changed = _drag_float(&"Jump Velocity", _jump_velocity, Player.JUMP_VELOCITY_STEP, Player.JUMP_VELOCITY_MIN, Player.JUMP_VELOCITY_MAX, "%.2f") or changed
	changed = _drag_float(&"Sprint Multiplier", _sprint_multiplier, Player.SPRINT_MULTIPLIER_STEP, Player.SPRINT_MULTIPLIER_MIN, Player.SPRINT_MULTIPLIER_MAX, "%.2f") or changed
	changed = _drag_float(&"Ground Deceleration", _ground_deceleration, Player.GROUND_DECELERATION_STEP, Player.GROUND_DECELERATION_MIN, Player.GROUND_DECELERATION_MAX, "%.1f") or changed
	changed = _drag_float(&"Pivot Speed", _pivot_speed, Player.PIVOT_SPEED_STEP, Player.PIVOT_SPEED_MIN, Player.PIVOT_SPEED_MAX, "%.2f") or changed

	ImGui.SeparatorText(&"Collision")
	changed = _drag_float(&"Capsule Radius", _capsule_radius, Player.CAPSULE_RADIUS_STEP, Player.CAPSULE_RADIUS_MIN, Player.CAPSULE_RADIUS_MAX, "%.3f") or changed
	changed = _drag_float(&"Capsule Height", _capsule_height, Player.CAPSULE_HEIGHT_STEP, Player.CAPSULE_HEIGHT_MIN, Player.CAPSULE_HEIGHT_MAX, "%.3f") or changed

	ImGui.SeparatorText(&"Stamina")
	changed = _drag_float(&"Max Stamina", _max_stamina, Player.MAX_STAMINA_STEP, Player.MAX_STAMINA_MIN, Player.MAX_STAMINA_MAX, "%.1f") or changed
	changed = _drag_float(&"Drain Rate", _stamina_drain_rate, Player.STAMINA_DRAIN_RATE_STEP, Player.STAMINA_DRAIN_RATE_MIN, Player.STAMINA_DRAIN_RATE_MAX, "%.2f") or changed
	changed = _drag_float(&"Regen Rate", _stamina_regen_rate, Player.STAMINA_REGEN_RATE_STEP, Player.STAMINA_REGEN_RATE_MIN, Player.STAMINA_REGEN_RATE_MAX, "%.2f") or changed

	if changed:
		_apply_live_stats()

	ImGui.Spacing()
	ImGui.Spacing()
	if ImGui.Button(&"Save Blueprint"):
		_save_to_disk()

	ImGui.Spacing()
	ImGui.Text("Save as new blueprint:")
	ImGui.SetNextItemWidth(200.0)
	ImGui.InputText(&"##save_as_name", _save_as_name, 128, 0)
	ImGui.SameLine()
	if ImGui.Button(&"Save As"):
		_save_as()

func _draw_discard_popup() -> void:
	var viewport_size: Vector2 = _menu.get_viewport().get_visible_rect().size
	ImGui.SetNextWindowPos(viewport_size * 0.5 - Vector2(150.0, 40.0), ImGui.Cond_Appearing)
	# Empty pass-by-ref array → the modal renders without a close (X) button.
	var no_close: Array[bool] = []
	if ImGui.BeginPopupModal(&"Discard changes?##bp_discard", no_close, 0):
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
	_apply_blueprint_to_player()

func _apply_live_stats() -> void:
	if not _working_blueprint:
		_working_blueprint = PlayerBlueprint.new()
	_write_values_to_blueprint(_working_blueprint)
	_menu.player.apply_stats(_working_blueprint)

func _load_blueprint_values(index: int) -> void:
	var blueprint: PlayerBlueprint = _load_blueprint(_blueprint_paths[index])
	if not blueprint:
		_log("[Player] Failed to load: " + _blueprint_paths[index])
		return
	_move_speed[0] = blueprint.move_speed
	_jump_velocity[0] = blueprint.jump_velocity
	_sprint_multiplier[0] = blueprint.sprint_multiplier
	_ground_deceleration[0] = blueprint.ground_deceleration
	_pivot_speed[0] = blueprint.pivot_speed
	_capsule_radius[0] = blueprint.capsule_radius
	_capsule_height[0] = blueprint.capsule_height
	_max_stamina[0] = blueprint.max_stamina
	_stamina_drain_rate[0] = blueprint.stamina_drain_rate
	_stamina_regen_rate[0] = blueprint.stamina_regen_rate
	_baseline_values = _current_values()
	_loaded_blueprint_index = index

# Loads fresh from disk (ignoring the resource cache) so panel/baseline state
# always reflects what is actually saved, not an instance a prior Apply mutated.
func _load_blueprint(path: String) -> PlayerBlueprint:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PlayerBlueprint

func _scan_blueprints() -> void:
	_blueprint_paths.clear()
	_blueprint_names.clear()
	var directory: DirAccess = DirAccess.open(_BLUEPRINT_DIRECTORY)
	if not directory:
		_log("[Player] Failed to open blueprint directory: " + _BLUEPRINT_DIRECTORY)
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			_blueprint_paths.append(_BLUEPRINT_DIRECTORY + file_name)
			_blueprint_names.append(file_name.get_basename())

func _current_values() -> Array[float]:
	return [
		_move_speed[0], _jump_velocity[0], _sprint_multiplier[0],
		_ground_deceleration[0], _pivot_speed[0], _capsule_radius[0],
		_capsule_height[0], _max_stamina[0], _stamina_drain_rate[0],
		_stamina_regen_rate[0],
	]

func _is_modified() -> bool:
	# Compare with tolerance, not exact equality: the ImGui DragFloat binding
	# round-trips each value through a 32-bit float every frame, so the panel
	# values drift from the pristine doubles by ~1e-7 without any user edit.
	var current: Array[float] = _current_values()
	if current.size() != _baseline_values.size():
		return true
	for i: int in current.size():
		if not is_equal_approx(current[i], _baseline_values[i]):
			return true
	return false

func _write_values_to_blueprint(blueprint: PlayerBlueprint) -> void:
	blueprint.move_speed = _move_speed[0]
	blueprint.jump_velocity = _jump_velocity[0]
	blueprint.sprint_multiplier = _sprint_multiplier[0]
	blueprint.ground_deceleration = _ground_deceleration[0]
	blueprint.pivot_speed = _pivot_speed[0]
	blueprint.capsule_radius = _capsule_radius[0]
	blueprint.capsule_height = _capsule_height[0]
	blueprint.max_stamina = _max_stamina[0]
	blueprint.stamina_drain_rate = _stamina_drain_rate[0]
	blueprint.stamina_regen_rate = _stamina_regen_rate[0]

func _apply_blueprint_to_player() -> void:
	var blueprint: PlayerBlueprint = _load_blueprint(_blueprint_paths[_blueprint_index[0]])
	if not blueprint:
		return
	_write_values_to_blueprint(blueprint)
	_menu.player.apply_blueprint(blueprint)
	_log("[Player] Blueprint applied.")

func _save_to_disk() -> void:
	var path: String = _blueprint_paths[_blueprint_index[0]]
	var blueprint: PlayerBlueprint = _load_blueprint(path)
	if not blueprint:
		_log("[Player] Save failed: could not load blueprint.")
		return
	_write_values_to_blueprint(blueprint)
	var error: Error = ResourceSaver.save(blueprint, path)
	if error == OK:
		_baseline_values = _current_values()
		_log("[Player] Saved → " + path)
	else:
		_log("[Player] Save failed (err " + str(error) + ")")

func _save_as() -> void:
	var file_name: String = _save_as_name[0].strip_edges()
	if file_name.is_empty():
		_log("[Player] Save As: name is empty.")
		return
	if not file_name.ends_with(".tres"):
		file_name += ".tres"
	var path: String = _BLUEPRINT_DIRECTORY + file_name
	var source: PlayerBlueprint = _load_blueprint(_blueprint_paths[_blueprint_index[0]])
	if not source:
		_log("[Player] Save As failed: could not load source blueprint.")
		return
	var copy: PlayerBlueprint = source.duplicate() as PlayerBlueprint
	_write_values_to_blueprint(copy)
	var error: Error = ResourceSaver.save(copy, path)
	if error != OK:
		_log("[Player] Save As failed (err " + str(error) + ")")
		return
	_log("[Player] Saved as → " + path)
	_save_as_name[0] = ""
	_scan_blueprints()
	var new_index: int = _blueprint_paths.find(path)
	_blueprint_index[0] = new_index if new_index >= 0 else 0
	_load_blueprint_values(_blueprint_index[0])
