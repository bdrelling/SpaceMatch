@tool
class_name InteractableZone
extends Area3D
## A proximity trigger placed on an interactable object. Detects the [Player] entering its
## field and, when [member should_highlight] is set, outlines the object via
## [SilhouetteHighlighter] so the player can see what they're about to interact with.
## The owner connects to [signal player_entered] / [signal player_exited] to drive its own
## registration and interaction (see [Structure]).

signal player_entered(player: Player)
signal player_exited(player: Player)

## When true, the interactable is outlined while the player is in range.
@export var should_highlight: bool = true
## Subtree whose meshes get the outline. Defaults to this zone's parent when unset, which
## covers the common case of a zone sitting alongside the object's model.
@export var highlight_target: Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Detect the player only; never act as an obstacle.
	collision_layer = CollisionLayer.INTERACTION
	collision_mask = CollisionLayer.PLAYERS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	if should_highlight:
		# Route through the focus arbiter rather than highlighting directly, so a cluster of
		# interactables doesn't all light up at once. The arbiter decides what actually shows.
		InteractionFocus.enter(_target(), _source())
	player_entered.emit(player)

func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	if should_highlight:
		InteractionFocus.exit(_target())
	player_exited.emit(player)

func _target() -> Node3D:
	return highlight_target if highlight_target != null else get_parent() as Node3D

## The interactable this zone belongs to (the thing the Player acts on when this is focused) —
## the owning scene's root, e.g. the [Structure].
func _source() -> Object:
	return owner if owner != null else get_parent()

## Forces this zone's highlight off via the focus arbiter. For when the zone stops monitoring
## and so [signal Area3D.body_exited] won't fire — e.g. a scrap heap collapsing.
func clear_highlight() -> void:
	InteractionFocus.exit(_target())
