class_name AtmosphereConfig
extends Resource
## Live config for an [Atmosphere] — every global environment lever in one resource:
## sky, ambient, tone mapping, fog, the key light (sun), and screen-space post.
##
## Pure [code]@export[/code] data, zero logic. Read live (not a blueprint — the [Atmosphere]
## node never copies these onto itself; it reads each field on every apply). Authored as
## [code].tres[/code] presets in [code]res://systems/atmosphere/configs/[/code]; an
## [Atmosphere] node reads one and pushes it onto its owned [WorldEnvironment] and
## [DirectionalLight3D]. Editing any field re-applies live (the node listens to
## [signal Resource.changed]).
##
## Every default below matches a bare Godot scene — a blank config reproduces the engine
## defaults (no sky, no ambient, no sun). The shipped [code]rustyard_*[/code] presets layer
## the game's looks on top. Holds nothing about surface materials — that is the
## [MaterialTester]'s concern.

@export_group("Metadata")
## Shown in the debug-menu profile picker.
@export var name: String = "Untitled"
@export_multiline var description: String = ""

## Which sky the [Atmosphere] builds when [member sky_enabled] is on.
enum SkyMode {
	## Daytime gradient via [ProceduralSkyMaterial].
	GRADIENT,
	## Night shader sky — stars, Milky Way, horizon glow (see [code]starfield_sky.gdshader[/code]).
	STARFIELD,
}

@export_group("Sky")
## When on, the background is a procedural gradient sky; when off, a flat [member clear_color].
@export var sky_enabled: bool = false
@export var sky_mode: SkyMode = SkyMode.GRADIENT
## Flat background color used when [member sky_enabled] is off (Godot's default clear gray).
@export var clear_color: Color = Color(0.3, 0.3, 0.3)
@export var sky_top_color: Color = Color(0.385, 0.454, 0.55)
## Pull this toward [member sky_top_color] to kill the pale "atmospheric" horizon band.
@export var sky_horizon_color: Color = Color(0.6463, 0.6558, 0.6708)
## Lower = harder, more graphic transition between top and horizon (less gradient).
@export_range(0.0, 1.0, 0.01) var sky_curve: float = 0.15
@export_range(0.0, 4.0, 0.01) var sky_energy: float = 1.0
@export var ground_bottom_color: Color = Color(0.2, 0.169, 0.1333)
@export var ground_horizon_color: Color = Color(0.6463, 0.6558, 0.6708)
@export_range(0.0, 1.0, 0.01) var ground_curve: float = 0.02

@export_group("Sky — Starfield")
## Residual sunset light hugging the horizon. Alpha is ignored; use the strength.
@export var horizon_glow_color: Color = Color(0.45, 0.32, 0.2)
@export_range(0.0, 4.0, 0.01) var horizon_glow_strength: float = 1.0
## How far the glow climbs above the horizon (fraction of the upper hemisphere).
@export_range(0.01, 1.0, 0.01) var horizon_glow_height: float = 0.18
## Compass direction the glow sits in. Pair with [member sun_rotation_degrees] for a set-sun feel.
@export var horizon_glow_azimuth_degrees: float = 150.0
## How tightly the glow hugs its azimuth; 0 wraps the whole horizon.
@export_range(0.0, 8.0, 0.01) var horizon_glow_focus: float = 2.0
@export_range(0.0, 1.0, 0.01) var star_density: float = 0.5
## >1 is intentional — keeps stars bright enough to bloom once glow is enabled.
@export_range(0.0, 8.0, 0.01) var star_brightness: float = 2.0
@export_range(0.0, 4.0, 0.01) var star_twinkle_speed: float = 0.6
@export_range(0.0, 4.0, 0.01) var milky_way_intensity: float = 1.0
@export var milky_way_color: Color = Color(0.5, 0.6, 0.8)
@export_range(0.05, 1.0, 0.01) var milky_way_width: float = 0.3
## Tilt and swing of the galactic band across the sky.
@export var milky_way_tilt_degrees: float = 60.0
@export var milky_way_rotation_degrees: float = 0.0

@export_group("Ambient")
## Color is the flat, stylized choice; Sky bleeds soft realistic GI from the gradient.
@export var ambient_source: Environment.AmbientSource = Environment.AMBIENT_SOURCE_BG
@export var ambient_color: Color = Color(0.0, 0.0, 0.0)
## Higher lifts the shadow side so nothing reads pure black.
@export_range(0.0, 4.0, 0.01) var ambient_energy: float = 1.0
@export_range(0.0, 1.0, 0.01) var ambient_sky_contribution: float = 1.0

@export_group("Tone Mapping")
## Linear keeps colors as authored (punchy/stylized); AgX/Filmic roll off to a filmic, realistic look.
@export var tonemap_mode: Environment.ToneMapper = Environment.TONE_MAPPER_LINEAR
@export_range(0.0, 4.0, 0.01) var tonemap_exposure: float = 1.0
@export_range(0.5, 4.0, 0.01) var tonemap_white: float = 1.0

@export_group("Fog")
@export var fog_enabled: bool = false
@export var fog_color: Color = Color(0.8, 0.85, 0.9)
@export_range(0.0, 0.1, 0.0005) var fog_density: float = 0.01
@export var volumetric_fog_enabled: bool = false
@export_range(0.0, 1.0, 0.001) var volumetric_fog_density: float = 0.05
@export var volumetric_fog_albedo: Color = Color(1.0, 1.0, 1.0)

@export_group("Sun")
@export var sun_enabled: bool = false
@export var sun_color: Color = Color(1.0, 1.0, 1.0)
@export_range(0.0, 8.0, 0.01) var sun_energy: float = 1.0
## Euler degrees of the key light. Y = compass direction, X = height above the horizon.
@export var sun_rotation_degrees: Vector3 = Vector3.ZERO
@export var shadow_enabled: bool = false
## Softens shadow edges; lower reads more graphic/toy-like.
@export_range(0.0, 8.0, 0.05) var shadow_blur: float = 1.0
## <1 lets ambient lift the shadows so nothing goes pure black.
@export_range(0.0, 1.0, 0.01) var shadow_opacity: float = 1.0

@export_group("Post — Bloom")
@export var glow_enabled: bool = false
@export_range(0.0, 4.0, 0.01) var glow_intensity: float = 0.6
@export_range(0.0, 4.0, 0.01) var glow_strength: float = 1.0
@export_range(0.0, 4.0, 0.01) var glow_bloom: float = 0.1
## Only pixels brighter than this bloom. >1 keeps bloom to highlights only.
@export_range(0.0, 4.0, 0.01) var glow_hdr_threshold: float = 1.0

@export_group("Post — Ambient Occlusion")
@export var ssao_enabled: bool = false
## Large radius reads as soft form shading across terrain; small radius as contact occlusion.
@export_range(0.01, 16.0, 0.01) var ssao_radius: float = 1.0
@export_range(0.0, 16.0, 0.01) var ssao_intensity: float = 2.0
@export_range(0.0, 16.0, 0.01) var ssao_power: float = 1.5
## >0 lets occlusion dim direct sunlight too, not just ambient — needed for AO to show on lit faces.
@export_range(0.0, 1.0, 0.01) var ssao_light_affect: float = 0.0

@export_group("Post — Adjustments")
@export var adjustments_enabled: bool = false
@export_range(0.0, 4.0, 0.01) var adjustment_brightness: float = 1.0
@export_range(0.0, 4.0, 0.01) var adjustment_contrast: float = 1.0
@export_range(0.0, 4.0, 0.01) var adjustment_saturation: float = 1.0

@export_group("Post — Depth of Field (runtime)")
## Tilt-shift blur on the active camera. Runtime only — needs the live game camera.
@export var dof_enabled: bool = false
@export var dof_near_enabled: bool = true
@export var dof_far_enabled: bool = true
@export_range(0.5, 200.0, 0.5) var dof_focus_distance: float = 14.0
@export_range(0.0, 100.0, 0.5) var dof_near_transition: float = 8.0
@export_range(0.0, 100.0, 0.5) var dof_far_transition: float = 12.0
@export_range(0.0, 1.0, 0.001) var dof_blur_amount: float = 0.08

@export_group("Post — Vignette (runtime)")
## Soft corner darkening via a screen overlay. Runtime only.
@export var vignette_enabled: bool = false
@export var vignette_color: Color = Color(0.0, 0.0, 0.0)
@export_range(0.0, 1.0, 0.01) var vignette_intensity: float = 0.4
@export_range(0.0, 1.0, 0.01) var vignette_softness: float = 0.5
