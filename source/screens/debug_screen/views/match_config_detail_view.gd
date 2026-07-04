class_name MatchConfigDetailView
extends DebugView
## The detail editor for one [MatchConfig] — the match settings that shape a match without touching its rules:
## a display name, board geometry (size, shortest run), team size, and the [Ruleset] it references. The ruleset
## is picked from the [RuleCatalog] and edited through the shared [MatchRulesView], so a config points at a
## reusable ruleset it never owns. "Play this mode" records this config and launches a fresh encounter with it.

var _config: MatchConfig


## Builds an editor for [param config] (an entry from the [MatchConfigCatalog]).
static func create(config: MatchConfig) -> MatchConfigDetailView:
	var view := MatchConfigDetailView.new()
	view._config = config
	return view


func title() -> String:
	return "Match Config"


func _build() -> void:
	if _config == null:
		return
	var config := _config
	add_child(DebugRow.text("Name", String(config.config_name), func(value: String) -> void: config.config_name = StringName(value)))
	add_child(DebugRow.slider("Width", Color.WHITE, 3, 12, config.board_width, func(value: float) -> void: config.board_width = int(value)))
	add_child(DebugRow.slider("Height", Color.WHITE, 3, 12, config.board_height, func(value: float) -> void: config.board_height = int(value)))
	add_child(DebugRow.slider("Min run", Color.WHITE, 3, 5, config.min_run, func(value: float) -> void: config.min_run = int(value)))
	add_child(DebugRow.slider("Team size", Color.WHITE, 1, 4, config.team_size, func(value: float) -> void: config.team_size = int(value)))
	# The ruleset is a reference into the RuleCatalog — drill in to pick one (and edit it via the rules editor).
	add_child(DebugRow.nav("Ruleset", _ruleset_title(config.ruleset), func() -> void: _push(_ruleset_picker())))
	add_child(DebugRow.nav("Play this mode", "", _play))


# Browse the RuleCatalog; tapping a ruleset makes it this config's ruleset and opens it in the shared rules
# editor (the rules-editor reuse). The picked ruleset is a shared reference — the config never copies it.
func _ruleset_picker() -> CatalogView:
	return CatalogView.create(
		Catalogs.rules,
		func(entry: Resource) -> DebugView:
			_config.ruleset = entry as Ruleset
			return MatchRulesView.create(entry as Ruleset)
	)


# A label for the currently-referenced ruleset: its display name, else its file name, else a placeholder.
func _ruleset_title(ruleset: Ruleset) -> String:
	if ruleset == null:
		return "None"
	if ruleset.ruleset_name != &"":
		return String(ruleset.ruleset_name).capitalize()
	if not ruleset.resource_path.is_empty():
		return ruleset.resource_path.get_file().get_basename().capitalize()
	return "Ruleset"


# Record this config as the board config the next board reads, then swap the whole root screen to a fresh
# encounter. Freeing the current screen tears down this debug UI (overlay or full-screen) with it; unpause in
# case we were launched from the in-match debug overlay, where the tree is paused.
func _play() -> void:
	DebugConfig.match_config = _config
	PauseMonitor.unpause()
	SceneLoader.transition_to(EncounterScreen.create())
