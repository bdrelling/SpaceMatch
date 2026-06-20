class_name RustboardBlueprint
extends Resource
## Authored tuning data for a [Rustboard] — speed, friction, handling.
## Copied onto the [Rustboard] at apply time; never read at runtime.

@export_group("Speed")
@export var max_speed: float = Rustboard.MAX_SPEED_DEFAULT
@export var nudge_acceleration: float = Rustboard.NUDGE_ACCELERATION_DEFAULT
## Multiplier on gravity's pull along a slope. Applied symmetrically (downhill
## accelerates, uphill decelerates), so the board stops near the crest and rolls
## back down. Also scales the slope that [member static_friction] can hold:
## the grip angle is atan([member static_friction] / slope_acceleration_scale).
@export var slope_acceleration_scale: float = Rustboard.SLOPE_ACCELERATION_SCALE_DEFAULT

@export_group("Friction")
## Kinetic (sliding) friction as a fraction of normal force — a constant
## deceleration that brings the board to a *full* stop instead of creeping
## forever. Low = slick, glides far. This is the "frictionless fun" knob.
@export var kinetic_friction: float = Rustboard.KINETIC_FRICTION_DEFAULT
## Static (grip) friction. The board stays put at rest until the slope is steep
## enough to break grip — grip angle = atan(static_friction / slope_acceleration_scale).
## Raise it if the board creeps on flat ground; lower it if gentle slopes feel sticky.
@export var static_friction: float = Rustboard.STATIC_FRICTION_DEFAULT
## Sideways grip — how hard the board resists slipping off its forward axis (carving).
@export var lateral_friction: float = Rustboard.LATERAL_FRICTION_DEFAULT
## Below this horizontal speed, with no input on a grippable slope, the board
## snaps to rest (prevents endless sub-pixel creep).
@export var stop_speed: float = Rustboard.STOP_SPEED_DEFAULT

@export_group("Handling")
@export var rotation_speed: float = Rustboard.ROTATION_SPEED_DEFAULT
@export var deploy_tilt_degrees: float = Rustboard.DEPLOY_TILT_DEGREES_DEFAULT
## How quickly board and rider lean to match the floor while riding — the
## per-second blend toward the surface normal. Higher snaps, lower floats.
@export var alignment_speed: float = Rustboard.ALIGNMENT_SPEED_DEFAULT
## With no steer input, how fast the board yaws toward its direction of travel
## (radians/second) — what swings it straight after sliding back down a wall.
@export var straighten_speed: float = Rustboard.STRAIGHTEN_SPEED_DEFAULT
## How quickly board and rider ease back upright while airborne. Kept well
## below [member alignment_speed] so launching off a lip carries the lean into
## the air instead of popping straight.
@export var air_righting_speed: float = Rustboard.AIR_RIGHTING_SPEED_DEFAULT
## Speed at which [member straighten_speed] has fully faded out. Straightening
## is stall recovery; left on at riding speed it wrenches every line toward the
## fall line whenever steering eases off.
@export var straighten_fade_speed: float = Rustboard.STRAIGHTEN_FADE_SPEED_DEFAULT

@export_group("Carve")
## How fast the velocity direction swings to follow the board's heading
## (radians/second), preserving speed — the rails-not-drift turn. 0 leaves
## turning entirely to [member lateral_friction] damping, which bleeds speed.
@export var carve_grip: float = Rustboard.CARVE_GRIP_DEFAULT
## How much steering tightness falls off with speed: effective turn rate is
## rotation_speed / (1 + speed * falloff). 0 keeps the turn rate constant.
@export var speed_turn_falloff: float = Rustboard.SPEED_TURN_FALLOFF_DEFAULT
## How fast steer input ramps toward the stick's position (full-lock units per
## second) — softens turn-in so carves start progressively. 0 is instant.
@export var steer_ramp: float = Rustboard.STEER_RAMP_DEFAULT
## Visual bank into the turn at full steer and speed, in degrees. 0 disables.
@export var lean_degrees: float = Rustboard.LEAN_DEGREES_DEFAULT
## Per-second blend smoothing the floor normal that slope acceleration reads,
## so faceted terrain pulls evenly instead of ticking seam to seam. 0 uses the
## raw contact normal.
@export var normal_smoothing: float = Rustboard.NORMAL_SMOOTHING_DEFAULT
