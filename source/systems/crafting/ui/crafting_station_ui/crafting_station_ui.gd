class_name CraftingStationUI
extends Node
## Shows a [CraftingPanel] when the player interacts with a [CraftingStation] and hides it when they
## walk away. Lives in the level's overlay layer (above the HUD). Driven by the player's interaction
## signals — nothing is looked up by group or searched for in the tree (see
## armory/docs/godot/patterns/dependency-injection.md): the player is injected, and each station
## names the panel scene it wants via [member CraftingStation.panel_scene]. Panels are instanced
## once and reused, so stations sharing a scene share an instance.

## The player whose interactions drive the panels. Wire in the editor (a sibling in the level scene).
@export var player: Player

# Panel instances keyed by their source scene, so one scene maps to one reused panel.
var _panels: Dictionary[PackedScene, CraftingPanel] = {}
var _active: CraftingPanel

func _ready() -> void:
	if player == null:
		push_warning("CraftingStationUI has no player wired; crafting panels won't open.")
		return
	player.structure_interacted.connect(_on_structure_interacted)
	player.structure_exited.connect(_on_structure_exited)

func _on_structure_interacted(structure: Structure) -> void:
	var station := structure as CraftingStation
	if station == null or station.recipe_book == null or station.panel_scene == null:
		return
	var panel := _panel_for(station.panel_scene)
	if panel == null:
		return
	if _active != null and _active != panel:
		_active.close()
	_active = panel
	panel.open_for(station, player)

func _on_structure_exited(structure: Structure) -> void:
	var station := structure as CraftingStation
	if station == null or _active == null:
		return
	if _active.is_showing(station):
		_active.close()

# Lazily instances (and caches) the panel for a scene, parenting it here so it renders in the layer.
func _panel_for(scene: PackedScene) -> CraftingPanel:
	if not _panels.has(scene):
		var panel := scene.instantiate() as CraftingPanel
		if panel == null:
			push_warning("CraftingStation.panel_scene root is not a CraftingPanel; ignoring.")
			return null
		add_child(panel)
		_panels[scene] = panel
	return _panels[scene]
