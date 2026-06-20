class_name PlayerBlueprint
extends Resource

@export_range(Player.MOVE_SPEED_MIN, Player.MOVE_SPEED_MAX, Player.MOVE_SPEED_STEP)
var move_speed: float = Player.MOVE_SPEED_DEFAULT

@export_range(Player.JUMP_VELOCITY_MIN, Player.JUMP_VELOCITY_MAX, Player.JUMP_VELOCITY_STEP)
var jump_velocity: float = Player.JUMP_VELOCITY_DEFAULT

@export_range(Player.SPRINT_MULTIPLIER_MIN, Player.SPRINT_MULTIPLIER_MAX, Player.SPRINT_MULTIPLIER_STEP)
var sprint_multiplier: float = Player.SPRINT_MULTIPLIER_DEFAULT

@export_range(Player.GROUND_DECELERATION_MIN, Player.GROUND_DECELERATION_MAX, Player.GROUND_DECELERATION_STEP)
var ground_deceleration: float = Player.GROUND_DECELERATION_DEFAULT

@export_range(Player.PIVOT_SPEED_MIN, Player.PIVOT_SPEED_MAX, Player.PIVOT_SPEED_STEP)
var pivot_speed: float = Player.PIVOT_SPEED_DEFAULT

@export var model_scene: PackedScene

@export_group("Collision")

@export_range(Player.CAPSULE_RADIUS_MIN, Player.CAPSULE_RADIUS_MAX, Player.CAPSULE_RADIUS_STEP)
var capsule_radius: float = Player.CAPSULE_RADIUS_DEFAULT

@export_range(Player.CAPSULE_HEIGHT_MIN, Player.CAPSULE_HEIGHT_MAX, Player.CAPSULE_HEIGHT_STEP)
var capsule_height: float = Player.CAPSULE_HEIGHT_DEFAULT

@export_group("Stamina")

@export_range(Player.MAX_STAMINA_MIN, Player.MAX_STAMINA_MAX, Player.MAX_STAMINA_STEP)
var max_stamina: float = Player.MAX_STAMINA_DEFAULT

@export_range(Player.STAMINA_DRAIN_RATE_MIN, Player.STAMINA_DRAIN_RATE_MAX, Player.STAMINA_DRAIN_RATE_STEP)
var stamina_drain_rate: float = Player.STAMINA_DRAIN_RATE_DEFAULT

@export_range(Player.STAMINA_REGEN_RATE_MIN, Player.STAMINA_REGEN_RATE_MAX, Player.STAMINA_REGEN_RATE_STEP)
var stamina_regen_rate: float = Player.STAMINA_REGEN_RATE_DEFAULT
