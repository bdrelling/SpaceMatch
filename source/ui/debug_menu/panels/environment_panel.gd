class_name EnvironmentPanel
extends DebugPanel
## Environment tab — every lever mirrors the active AtmosphereConfig and applies live.
## ImGui needs stable single-element arrays as in/out params; colors are [r, g, b].

const _CONFIG_DIRECTORY: String = "res://systems/atmosphere/configs/"
const _TONEMAP_NAMES: Array[String] = ["Linear", "Reinhard", "Filmic", "ACES", "AGX"]
# Indexed by Environment.AmbientSource (0=Background, 1=Disabled, 2=Color, 3=Sky).
const _AMBIENT_NAMES: Array[String] = ["Background", "Disabled", "Color", "Sky"]

var _loaded: bool = false
var _config_paths: Array[String] = []
var _config_names: Array[String] = []
var _config_index: Array[int] = [0]
var _save_as_name: Array[String] = [""]
# The live-edited config pushed onto the Atmosphere node.
var _working_config: AtmosphereConfig = null

# Sky
var _sky_enabled: Array[bool] = [true]
var _clear_color: Array[float] = [0.5, 0.6, 0.7]
var _sky_top_color: Array[float] = [0.37, 0.68, 0.87]
var _sky_horizon_color: Array[float] = [0.37, 0.68, 0.87]
var _sky_curve: Array[float] = [0.1]
var _sky_energy: Array[float] = [1.0]
var _ground_bottom_color: Array[float] = [0.89, 0.57, 0.41]
var _ground_horizon_color: Array[float] = [0.89, 0.57, 0.41]
var _ground_curve: Array[float] = [0.05]
# Ambient
var _ambient_source: Array[int] = [2]
var _ambient_color: Array[float] = [0.6, 0.52, 0.46]
var _ambient_energy: Array[float] = [0.5]
var _ambient_sky: Array[float] = [0.0]
# Tone mapping
var _tonemap_mode: Array[int] = [0]
var _tonemap_exposure: Array[float] = [1.0]
var _tonemap_white: Array[float] = [1.0]
# Fog
var _fog_enabled: Array[bool] = [false]
var _fog_color: Array[float] = [0.8, 0.85, 0.9]
var _fog_density: Array[float] = [0.01]
var _volumetric_fog_enabled: Array[bool] = [false]
var _volumetric_fog_density: Array[float] = [0.05]
var _volumetric_fog_albedo: Array[float] = [1.0, 1.0, 1.0]
# Sun
var _sun_enabled: Array[bool] = [true]
var _sun_color: Array[float] = [0.99, 0.92, 0.76]
var _sun_energy: Array[float] = [1.2]
var _sun_pitch: Array[float] = [-40.0]
var _sun_yaw: Array[float] = [150.0]
var _sun_roll: Array[float] = [0.0]
var _shadow_enabled: Array[bool] = [true]
var _shadow_blur: Array[float] = [0.75]
var _shadow_opacity: Array[float] = [0.75]
# Bloom
var _glow_enabled: Array[bool] = [false]
var _glow_intensity: Array[float] = [0.6]
var _glow_strength: Array[float] = [1.0]
var _glow_bloom: Array[float] = [0.1]
var _glow_hdr_threshold: Array[float] = [1.0]
# Adjustments
var _adjustments_enabled: Array[bool] = [false]
var _adjustment_brightness: Array[float] = [1.0]
var _adjustment_contrast: Array[float] = [1.0]
var _adjustment_saturation: Array[float] = [1.0]
# Camera DOF (runtime)
var _dof_enabled: Array[bool] = [false]
var _dof_near_enabled: Array[bool] = [true]
var _dof_far_enabled: Array[bool] = [true]
var _dof_focus_distance: Array[float] = [14.0]
var _dof_near_transition: Array[float] = [8.0]
var _dof_far_transition: Array[float] = [12.0]
var _dof_blur_amount: Array[float] = [0.08]
# Vignette (runtime)
var _vignette_enabled: Array[bool] = [false]
var _vignette_color: Array[float] = [0.0, 0.0, 0.0]
var _vignette_intensity: Array[float] = [0.4]
var _vignette_softness: Array[float] = [0.5]

func title() -> StringName:
	return &"Environment"

func is_available() -> bool:
	return is_instance_valid(_menu.atmosphere)

func draw() -> void:
	var atmosphere: Atmosphere = _menu.atmosphere
	if not _loaded:
		_scan_configs()
		var current_index: int = 0
		if atmosphere.config:
			var found: int = _config_paths.find(atmosphere.config.resource_path)
			if found >= 0:
				current_index = found
		if not _config_paths.is_empty():
			_select_config(current_index)
		_loaded = true

	if not _config_names.is_empty():
		if ImGui.ComboChar(&"Profile", _config_index, _config_names, _config_names.size()):
			_select_config(_config_index[0])

	if _working_config == null:
		ImGui.Text("No atmosphere configs found in configs/.")
		return
	if not _working_config.description.is_empty():
		ImGui.TextWrapped(_working_config.description)

	var changed: bool = false

	ImGui.SeparatorText(&"Sky")
	changed = ImGui.Checkbox(&"Procedural Sky", _sky_enabled) or changed
	if _sky_enabled[0]:
		changed = ImGui.ColorEdit3(&"Sky Top", _sky_top_color) or changed
		changed = ImGui.ColorEdit3(&"Sky Horizon", _sky_horizon_color) or changed
		changed = ImGui.SliderFloatEx(&"Sky Curve", _sky_curve, 0.0, 1.0, "%.2f", 0) or changed
		changed = ImGui.SliderFloatEx(&"Sky Energy", _sky_energy, 0.0, 4.0, "%.2f", 0) or changed
		changed = ImGui.ColorEdit3(&"Ground Bottom", _ground_bottom_color) or changed
		changed = ImGui.ColorEdit3(&"Ground Horizon", _ground_horizon_color) or changed
		changed = ImGui.SliderFloatEx(&"Ground Curve", _ground_curve, 0.0, 1.0, "%.2f", 0) or changed
	else:
		changed = ImGui.ColorEdit3(&"Clear Color", _clear_color) or changed

	ImGui.SeparatorText(&"Ambient")
	changed = ImGui.ComboChar(&"Source", _ambient_source, _AMBIENT_NAMES, _AMBIENT_NAMES.size()) or changed
	changed = ImGui.ColorEdit3(&"Ambient Color", _ambient_color) or changed
	changed = ImGui.SliderFloatEx(&"Ambient Energy", _ambient_energy, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Ambient Sky Contribution", _ambient_sky, 0.0, 1.0, "%.2f", 0) or changed

	ImGui.SeparatorText(&"Tone Mapping")
	changed = ImGui.ComboChar(&"Mode", _tonemap_mode, _TONEMAP_NAMES, _TONEMAP_NAMES.size()) or changed
	changed = ImGui.SliderFloatEx(&"Exposure", _tonemap_exposure, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"White", _tonemap_white, 0.5, 4.0, "%.2f", 0) or changed

	ImGui.SeparatorText(&"Fog")
	changed = ImGui.Checkbox(&"Fog", _fog_enabled) or changed
	changed = ImGui.ColorEdit3(&"Fog Color", _fog_color) or changed
	changed = ImGui.SliderFloatEx(&"Fog Density", _fog_density, 0.0, 0.1, "%.4f", 0) or changed
	changed = ImGui.Checkbox(&"Volumetric Fog", _volumetric_fog_enabled) or changed
	changed = ImGui.SliderFloatEx(&"Volumetric Density", _volumetric_fog_density, 0.0, 1.0, "%.3f", 0) or changed
	changed = ImGui.ColorEdit3(&"Volumetric Albedo", _volumetric_fog_albedo) or changed

	ImGui.SeparatorText(&"Sun")
	changed = ImGui.Checkbox(&"Sun", _sun_enabled) or changed
	changed = ImGui.ColorEdit3(&"Sun Color", _sun_color) or changed
	changed = ImGui.SliderFloatEx(&"Sun Energy", _sun_energy, 0.0, 8.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Sun Pitch", _sun_pitch, -180.0, 180.0, "%.1f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Sun Yaw", _sun_yaw, -180.0, 180.0, "%.1f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Sun Roll", _sun_roll, -180.0, 180.0, "%.1f", 0) or changed
	changed = ImGui.Checkbox(&"Shadows", _shadow_enabled) or changed
	changed = ImGui.SliderFloatEx(&"Shadow Blur", _shadow_blur, 0.0, 8.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Shadow Opacity", _shadow_opacity, 0.0, 1.0, "%.2f", 0) or changed

	ImGui.SeparatorText(&"Post — Bloom")
	changed = ImGui.Checkbox(&"Glow", _glow_enabled) or changed
	changed = ImGui.SliderFloatEx(&"Glow Intensity", _glow_intensity, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Glow Strength", _glow_strength, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Glow Bloom", _glow_bloom, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Glow HDR Threshold", _glow_hdr_threshold, 0.0, 4.0, "%.2f", 0) or changed

	ImGui.SeparatorText(&"Post — Adjustments")
	changed = ImGui.Checkbox(&"Adjustments", _adjustments_enabled) or changed
	changed = ImGui.SliderFloatEx(&"Brightness", _adjustment_brightness, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Contrast", _adjustment_contrast, 0.0, 4.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Saturation", _adjustment_saturation, 0.0, 4.0, "%.2f", 0) or changed

	ImGui.SeparatorText(&"Post — Depth of Field (runtime)")
	changed = ImGui.Checkbox(&"Depth of Field", _dof_enabled) or changed
	changed = ImGui.Checkbox(&"Near Blur", _dof_near_enabled) or changed
	ImGui.SameLine()
	changed = ImGui.Checkbox(&"Far Blur", _dof_far_enabled) or changed
	changed = ImGui.SliderFloatEx(&"Focus Distance", _dof_focus_distance, 0.5, 200.0, "%.1f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Near Transition", _dof_near_transition, 0.0, 100.0, "%.1f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Far Transition", _dof_far_transition, 0.0, 100.0, "%.1f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Blur Amount", _dof_blur_amount, 0.0, 1.0, "%.3f", 0) or changed

	ImGui.SeparatorText(&"Post — Vignette (runtime)")
	changed = ImGui.Checkbox(&"Vignette", _vignette_enabled) or changed
	changed = ImGui.ColorEdit3(&"Vignette Color", _vignette_color) or changed
	changed = ImGui.SliderFloatEx(&"Vignette Intensity", _vignette_intensity, 0.0, 1.0, "%.2f", 0) or changed
	changed = ImGui.SliderFloatEx(&"Vignette Softness", _vignette_softness, 0.0, 1.0, "%.2f", 0) or changed

	if changed:
		_write_to_config(_working_config)
		atmosphere.reapply()

	ImGui.Spacing()
	if ImGui.Button(&"Save Profile"):
		_save_active()
	ImGui.SameLine()
	ImGui.SetNextItemWidth(200.0)
	ImGui.InputText(&"##at_save_as", _save_as_name, 128, 0)
	ImGui.SameLine()
	if ImGui.Button(&"Save As New"):
		_save_as()

func _scan_configs() -> void:
	_config_paths.clear()
	_config_names.clear()
	var directory: DirAccess = DirAccess.open(_CONFIG_DIRECTORY)
	if not directory:
		_log("[Env] Failed to open config directory: " + _CONFIG_DIRECTORY)
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		if file_name.ends_with(".tres"):
			_config_paths.append(_CONFIG_DIRECTORY + file_name)
			_config_names.append(file_name.get_basename())

func _select_config(index: int) -> void:
	if index < 0 or index >= _config_paths.size():
		return
	var config: AtmosphereConfig = _load_config(_config_paths[index])
	if not config:
		_log("[Env] Failed to load: " + _config_paths[index])
		return
	_config_index[0] = index
	_working_config = config
	_load_values(config)
	_menu.atmosphere.apply_config(config)

# Loads fresh from disk (ignoring the cache) so the panel reflects what is saved.
func _load_config(path: String) -> AtmosphereConfig:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AtmosphereConfig

func _load_values(config: AtmosphereConfig) -> void:
	_sky_enabled[0] = config.sky_enabled
	_clear_color = _color_to_array(config.clear_color)
	_sky_top_color = _color_to_array(config.sky_top_color)
	_sky_horizon_color = _color_to_array(config.sky_horizon_color)
	_sky_curve[0] = config.sky_curve
	_sky_energy[0] = config.sky_energy
	_ground_bottom_color = _color_to_array(config.ground_bottom_color)
	_ground_horizon_color = _color_to_array(config.ground_horizon_color)
	_ground_curve[0] = config.ground_curve
	_ambient_source[0] = config.ambient_source
	_ambient_color = _color_to_array(config.ambient_color)
	_ambient_energy[0] = config.ambient_energy
	_ambient_sky[0] = config.ambient_sky_contribution
	_tonemap_mode[0] = config.tonemap_mode
	_tonemap_exposure[0] = config.tonemap_exposure
	_tonemap_white[0] = config.tonemap_white
	_fog_enabled[0] = config.fog_enabled
	_fog_color = _color_to_array(config.fog_color)
	_fog_density[0] = config.fog_density
	_volumetric_fog_enabled[0] = config.volumetric_fog_enabled
	_volumetric_fog_density[0] = config.volumetric_fog_density
	_volumetric_fog_albedo = _color_to_array(config.volumetric_fog_albedo)
	_sun_enabled[0] = config.sun_enabled
	_sun_color = _color_to_array(config.sun_color)
	_sun_energy[0] = config.sun_energy
	_sun_pitch[0] = config.sun_rotation_degrees.x
	_sun_yaw[0] = config.sun_rotation_degrees.y
	_sun_roll[0] = config.sun_rotation_degrees.z
	_shadow_enabled[0] = config.shadow_enabled
	_shadow_blur[0] = config.shadow_blur
	_shadow_opacity[0] = config.shadow_opacity
	_glow_enabled[0] = config.glow_enabled
	_glow_intensity[0] = config.glow_intensity
	_glow_strength[0] = config.glow_strength
	_glow_bloom[0] = config.glow_bloom
	_glow_hdr_threshold[0] = config.glow_hdr_threshold
	_adjustments_enabled[0] = config.adjustments_enabled
	_adjustment_brightness[0] = config.adjustment_brightness
	_adjustment_contrast[0] = config.adjustment_contrast
	_adjustment_saturation[0] = config.adjustment_saturation
	_dof_enabled[0] = config.dof_enabled
	_dof_near_enabled[0] = config.dof_near_enabled
	_dof_far_enabled[0] = config.dof_far_enabled
	_dof_focus_distance[0] = config.dof_focus_distance
	_dof_near_transition[0] = config.dof_near_transition
	_dof_far_transition[0] = config.dof_far_transition
	_dof_blur_amount[0] = config.dof_blur_amount
	_vignette_enabled[0] = config.vignette_enabled
	_vignette_color = _color_to_array(config.vignette_color)
	_vignette_intensity[0] = config.vignette_intensity
	_vignette_softness[0] = config.vignette_softness

func _write_to_config(config: AtmosphereConfig) -> void:
	config.sky_enabled = _sky_enabled[0]
	config.clear_color = _array_to_color(_clear_color)
	config.sky_top_color = _array_to_color(_sky_top_color)
	config.sky_horizon_color = _array_to_color(_sky_horizon_color)
	config.sky_curve = _sky_curve[0]
	config.sky_energy = _sky_energy[0]
	config.ground_bottom_color = _array_to_color(_ground_bottom_color)
	config.ground_horizon_color = _array_to_color(_ground_horizon_color)
	config.ground_curve = _ground_curve[0]
	config.ambient_source = _ambient_source[0] as Environment.AmbientSource
	config.ambient_color = _array_to_color(_ambient_color)
	config.ambient_energy = _ambient_energy[0]
	config.ambient_sky_contribution = _ambient_sky[0]
	config.tonemap_mode = _tonemap_mode[0] as Environment.ToneMapper
	config.tonemap_exposure = _tonemap_exposure[0]
	config.tonemap_white = _tonemap_white[0]
	config.fog_enabled = _fog_enabled[0]
	config.fog_color = _array_to_color(_fog_color)
	config.fog_density = _fog_density[0]
	config.volumetric_fog_enabled = _volumetric_fog_enabled[0]
	config.volumetric_fog_density = _volumetric_fog_density[0]
	config.volumetric_fog_albedo = _array_to_color(_volumetric_fog_albedo)
	config.sun_enabled = _sun_enabled[0]
	config.sun_color = _array_to_color(_sun_color)
	config.sun_energy = _sun_energy[0]
	config.sun_rotation_degrees = Vector3(_sun_pitch[0], _sun_yaw[0], _sun_roll[0])
	config.shadow_enabled = _shadow_enabled[0]
	config.shadow_blur = _shadow_blur[0]
	config.shadow_opacity = _shadow_opacity[0]
	config.glow_enabled = _glow_enabled[0]
	config.glow_intensity = _glow_intensity[0]
	config.glow_strength = _glow_strength[0]
	config.glow_bloom = _glow_bloom[0]
	config.glow_hdr_threshold = _glow_hdr_threshold[0]
	config.adjustments_enabled = _adjustments_enabled[0]
	config.adjustment_brightness = _adjustment_brightness[0]
	config.adjustment_contrast = _adjustment_contrast[0]
	config.adjustment_saturation = _adjustment_saturation[0]
	config.dof_enabled = _dof_enabled[0]
	config.dof_near_enabled = _dof_near_enabled[0]
	config.dof_far_enabled = _dof_far_enabled[0]
	config.dof_focus_distance = _dof_focus_distance[0]
	config.dof_near_transition = _dof_near_transition[0]
	config.dof_far_transition = _dof_far_transition[0]
	config.dof_blur_amount = _dof_blur_amount[0]
	config.vignette_enabled = _vignette_enabled[0]
	config.vignette_color = _array_to_color(_vignette_color)
	config.vignette_intensity = _vignette_intensity[0]
	config.vignette_softness = _vignette_softness[0]

func _save_active() -> void:
	if _working_config == null:
		return
	var path: String = _config_paths[_config_index[0]]
	_write_to_config(_working_config)
	var error: Error = ResourceSaver.save(_working_config, path)
	if error == OK:
		_log("[Env] Saved → " + path)
	else:
		_log("[Env] Save failed (err " + str(error) + ")")

func _save_as() -> void:
	if _working_config == null:
		return
	var file_name: String = _save_as_name[0].strip_edges()
	if file_name.is_empty():
		_log("[Env] Save As: name is empty.")
		return
	if not file_name.ends_with(".tres"):
		file_name += ".tres"
	var path: String = _CONFIG_DIRECTORY + file_name
	_write_to_config(_working_config)
	var copy: AtmosphereConfig = _working_config.duplicate() as AtmosphereConfig
	copy.name = file_name.get_basename().capitalize()
	var error: Error = ResourceSaver.save(copy, path)
	if error != OK:
		_log("[Env] Save As failed (err " + str(error) + ")")
		return
	_log("[Env] Saved as → " + path)
	_save_as_name[0] = ""
	_scan_configs()
	var new_index: int = _config_paths.find(path)
	_config_index[0] = new_index if new_index >= 0 else 0
	_select_config(_config_index[0])

func _color_to_array(color: Color) -> Array[float]:
	return [color.r, color.g, color.b]

func _array_to_color(array: Array[float]) -> Color:
	return Color(array[0], array[1], array[2])
