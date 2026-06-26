class_name MinigameScreen
extends GameScreen
## An game page that hosts a self-contained minigame. The minigame is authored as the page's child
## in the scene (so it's visible in the editor, not mounted blind at runtime); the page owns its own
## view and input, and this screen only pauses it while the page is off-screen so the five stages
## don't all tick at once. A minigame that reads the economy exposes a [code]bind_session[/code]
## method; this screen forwards the session to it on mount.

var _minigame: Node

func _ready() -> void:
	# The minigame is the page's authored child (see game.tscn) — nothing to instantiate here.
	_minigame = get_child(0) if get_child_count() > 0 else null
	if _minigame == null:
		return
	visibility_changed.connect(_sync_running)
	_sync_running()

## The hosted stage as its view-model, for the shell to read title/status/actions/inventory from. Null
## if the authored child isn't a [Minigame].
func minigame() -> Minigame:
	return _minigame as Minigame

# Mounts a minigame that opts in via bind_session (it reads the running game from the GameSession autoload);
# inert for those that don't.
func bind() -> void:
	if _minigame != null and _minigame.has_method("bind_session"):
		# Dynamic call: _minigame is typed Node and bind_session lives on the concrete minigame,
		# so a direct call trips the unsafe-method-call warning (treated as an error here).
		_minigame.call("bind_session")

# Only the visible page runs; hidden pages stop processing and input so off-screen minigames don't
# advance (a falling-piece stage would otherwise top out unseen).
func _sync_running() -> void:
	if _minigame == null:
		return
	_minigame.process_mode = PROCESS_MODE_INHERIT if is_visible_in_tree() else PROCESS_MODE_DISABLED
