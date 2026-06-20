@tool
class_name Atmosphere
extends Node3D
## A drop-in, self-contained environment styler. Drives its own [WorldEnvironment] and key
## [DirectionalLight3D] — authored as children of [code]atmosphere.tscn[/code] in a fixed
## order and wired via [member world_environment] / [member sun] — reading every setting from
## an [AtmosphereConfig]: sky, ambient, tone mapping, fog, glow, adjustments, and the sun,
## live in the editor and at runtime.
##
## Instance [code]atmosphere.tscn[/code] (or build one with [method create]) into any scene;
## never attach this script to a bare node, or it has no nodes to drive. Assign a config
## and the whole look applies. Swap or edit the config and it re-applies instantly. Assign
## a [member cycle] instead and the look becomes a day/night blend steered by its sun dial
## (the cycle outranks the config while both are set). Clear both and the scene falls back
## to a bare Godot default (empty environment, no key light). Depth of field and vignette
## need the live game camera / a screen overlay, so they apply at runtime only — everything
## else previews in the editor.
##
## Touches no materials. Surface styling is the [MaterialTester]'s job.

const SCENE_PATH := "res://systems/atmosphere/atmosphere.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)
const STARFIELD_SHADER: Shader = preload("res://systems/atmosphere/shaders/starfield_sky.gdshader")

@export var config: AtmosphereConfig:
	set(value):
		if config and config.changed.is_connected(_on_config_changed):
			config.changed.disconnect(_on_config_changed)
		config = value
		if config:
			config.changed.connect(_on_config_changed)
		_apply()

## Optional day/night blend. When assigned (with both endpoints), it outranks
## [member config]: the applied look is the cycle's blend at its current sun angle,
## and the key light's rotation follows the dial instead of the config.
@export var cycle: AtmosphereCycle:
	set(value):
		if cycle and cycle.changed.is_connected(_on_config_changed):
			cycle.changed.disconnect(_on_config_changed)
		cycle = value
		if cycle:
			cycle.changed.connect(_on_config_changed)
		_apply()

@export_group("Nodes")
## The driven environment. Wired to the child WorldEnvironment in atmosphere.tscn.
@export var world_environment: WorldEnvironment
## The driven key light. Wired to the child DirectionalLight3D in atmosphere.tscn.
@export var sun: DirectionalLight3D

var _vignette: ColorRect
var _dof_applied: bool = false

#region Lifecycle

func _ready() -> void:
	_apply()

func _on_config_changed() -> void:
	_apply()

#endregion

#region Config

## Builds an [Atmosphere] from [param _config] using [constant SCENE] — the only
## construction path, so the authored node structure is always preserved.
static func create(_config: AtmosphereConfig) -> Atmosphere:
	if not _config:
		Log.error("Config required to create Atmosphere")
		return null
	var atmosphere: Atmosphere = SCENE.instantiate()
	atmosphere.apply_config(_config)
	return atmosphere

## Swaps the active config and re-applies.
func apply_config(_config: AtmosphereConfig) -> void:
	if not _config:
		Log.error("Unable to apply config; config not found")
		return
	config = _config

## Forces a re-apply of the current config — for callers that edit it in place
## (e.g. the debug menu) where the property setter wouldn't re-fire.
func reapply() -> void:
	_apply()

#endregion

#region Apply

func _apply() -> void:
	# The property setter fires during scene load, before the wired nodes resolve; bail then
	# and let _ready do the first apply.
	if not is_node_ready() or world_environment == null or sun == null:
		return
	var active := _active_config()
	if active == null:
		_reset_to_godot_defaults()
		return
	world_environment.environment = _build_environment(active)
	_apply_sun(active)
	if cycle and cycle.is_complete():
		sun.rotation_degrees = cycle.sun_rotation_degrees()
	# Camera- and overlay-bound effects only make sense with the live game running.
	if not Engine.is_editor_hint():
		_apply_dof(active)
		_apply_vignette(active)

## The look every apply reads: the cycle's blend when one is assigned, else the config.
func _active_config() -> AtmosphereConfig:
	if cycle and cycle.is_complete():
		return cycle.blended()
	return config

## With no config, hand the scene a bare engine default — a fresh blank [Environment] and
## the key light switched off — rather than codifying values that could drift between Godot
## versions. This is the "super empty" new-scene look.
func _reset_to_godot_defaults() -> void:
	world_environment.environment = Environment.new()
	sun.visible = false
	_clear_vignette()
	_clear_dof()

func _build_environment(active: AtmosphereConfig) -> Environment:
	var env := Environment.new()
	if active.sky_enabled:
		env.background_mode = Environment.BG_SKY
		env.sky = _build_sky(active)
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = active.clear_color

	env.ambient_light_source = active.ambient_source
	env.ambient_light_color = active.ambient_color
	env.ambient_light_energy = active.ambient_energy
	env.ambient_light_sky_contribution = active.ambient_sky_contribution

	env.tonemap_mode = active.tonemap_mode
	env.tonemap_exposure = active.tonemap_exposure
	env.tonemap_white = active.tonemap_white

	env.fog_enabled = active.fog_enabled
	env.fog_light_color = active.fog_color
	env.fog_density = active.fog_density
	env.volumetric_fog_enabled = active.volumetric_fog_enabled
	env.volumetric_fog_density = active.volumetric_fog_density
	env.volumetric_fog_albedo = active.volumetric_fog_albedo

	env.glow_enabled = active.glow_enabled
	if active.glow_enabled:
		env.glow_intensity = active.glow_intensity
		env.glow_strength = active.glow_strength
		env.glow_bloom = active.glow_bloom
		env.glow_hdr_threshold = active.glow_hdr_threshold

	env.ssao_enabled = active.ssao_enabled
	if active.ssao_enabled:
		env.ssao_radius = active.ssao_radius
		env.ssao_intensity = active.ssao_intensity
		env.ssao_power = active.ssao_power
		env.ssao_light_affect = active.ssao_light_affect

	env.adjustment_enabled = active.adjustments_enabled
	if active.adjustments_enabled:
		env.adjustment_brightness = active.adjustment_brightness
		env.adjustment_contrast = active.adjustment_contrast
		env.adjustment_saturation = active.adjustment_saturation
	return env

func _build_sky(active: AtmosphereConfig) -> Sky:
	var sky := Sky.new()
	match active.sky_mode:
		AtmosphereConfig.SkyMode.STARFIELD:
			sky.sky_material = _build_starfield_material(active)
		_:
			sky.sky_material = _build_gradient_material(active)
	return sky

func _build_gradient_material(active: AtmosphereConfig) -> ProceduralSkyMaterial:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = active.sky_top_color
	material.sky_horizon_color = active.sky_horizon_color
	material.sky_curve = active.sky_curve
	material.sky_energy_multiplier = active.sky_energy
	material.ground_bottom_color = active.ground_bottom_color
	material.ground_horizon_color = active.ground_horizon_color
	material.ground_curve = active.ground_curve
	return material

func _build_starfield_material(active: AtmosphereConfig) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STARFIELD_SHADER
	material.set_shader_parameter(&"sky_top_color", active.sky_top_color)
	material.set_shader_parameter(&"sky_horizon_color", active.sky_horizon_color)
	material.set_shader_parameter(&"sky_curve", maxf(active.sky_curve, 0.01))
	material.set_shader_parameter(&"ground_color", active.ground_bottom_color)
	material.set_shader_parameter(&"horizon_glow_color", active.horizon_glow_color)
	material.set_shader_parameter(&"horizon_glow_strength", active.horizon_glow_strength)
	material.set_shader_parameter(&"horizon_glow_height", active.horizon_glow_height)
	material.set_shader_parameter(&"horizon_glow_azimuth_degrees", active.horizon_glow_azimuth_degrees)
	material.set_shader_parameter(&"horizon_glow_focus", active.horizon_glow_focus)
	material.set_shader_parameter(&"star_density", active.star_density)
	material.set_shader_parameter(&"star_brightness", active.star_brightness)
	material.set_shader_parameter(&"star_twinkle_speed", active.star_twinkle_speed)
	material.set_shader_parameter(&"milky_way_intensity", active.milky_way_intensity)
	material.set_shader_parameter(&"milky_way_color", active.milky_way_color)
	material.set_shader_parameter(&"milky_way_width", active.milky_way_width)
	material.set_shader_parameter(&"milky_way_tilt_degrees", active.milky_way_tilt_degrees)
	material.set_shader_parameter(&"milky_way_rotation_degrees", active.milky_way_rotation_degrees)
	return material

func _apply_sun(active: AtmosphereConfig) -> void:
	sun.visible = active.sun_enabled
	if not active.sun_enabled:
		return
	sun.rotation_degrees = active.sun_rotation_degrees
	sun.light_color = active.sun_color
	sun.light_energy = active.sun_energy
	sun.shadow_enabled = active.shadow_enabled
	sun.shadow_blur = active.shadow_blur
	sun.shadow_opacity = active.shadow_opacity

func _apply_dof(active: AtmosphereConfig) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if not active.dof_enabled:
		_clear_dof()
		return
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_near_enabled = active.dof_near_enabled
	attributes.dof_blur_near_distance = maxf(0.0, active.dof_focus_distance - active.dof_near_transition)
	attributes.dof_blur_near_transition = active.dof_near_transition
	attributes.dof_blur_far_enabled = active.dof_far_enabled
	attributes.dof_blur_far_distance = active.dof_focus_distance + active.dof_far_transition
	attributes.dof_blur_far_transition = active.dof_far_transition
	attributes.dof_blur_amount = active.dof_blur_amount
	camera.attributes = attributes
	_dof_applied = true

# Only clears attributes we ourselves set, so a camera's authored ones survive.
func _clear_dof() -> void:
	if not _dof_applied or Engine.is_editor_hint():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		camera.attributes = null
	_dof_applied = false

#endregion

#region Vignette

func _apply_vignette(active: AtmosphereConfig) -> void:
	if not active.vignette_enabled:
		_clear_vignette()
		return
	if _vignette == null:
		_create_vignette()
	_vignette.visible = true
	var material: ShaderMaterial = _vignette.material as ShaderMaterial
	material.set_shader_parameter(&"vignette_color", active.vignette_color)
	material.set_shader_parameter(&"intensity", active.vignette_intensity)
	material.set_shader_parameter(&"softness", active.vignette_softness)

func _clear_vignette() -> void:
	if _vignette != null:
		_vignette.visible = false

func _create_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer, false, Node.INTERNAL_MODE_BACK)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = _VIGNETTE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_vignette.material = material
	layer.add_child(_vignette)

const _VIGNETTE_SHADER: String = """shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float intensity = 0.4;
uniform float softness = 0.5;
void fragment() {
	float d = length(UV - vec2(0.5)) * 1.41421356;
	float edge0 = clamp(1.0 - softness, 0.0, 0.999);
	float a = smoothstep(edge0, 1.0, d) * intensity;
	COLOR = vec4(vignette_color.rgb, a);
}
"""

#endregion
