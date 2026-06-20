class_name InteractionFocus
## Arbitrates which interactable is highlighted, so a cluster of nearby objects doesn't light up
## all at once. Items ([Item]) and structures ([InteractableZone]) register here as they enter
## range; [SilhouetteHighlighter] does the actual outline.
##
## In [b]exclusive[/b] mode (the default) only ONE thing — the focus — is highlighted at a time,
## and the focus is [b]sticky[/b]: a newly-entered interactable never steals focus (e.g. an item
## ejected by the scrap heap you're standing at won't pull the highlight off the heap). Focus only
## moves on once the current focus leaves range, at which point the most-recently-entered candidate
## still in range takes over. In [b]shared[/b] mode every in-range interactable highlights (the
## original behaviour) — kept configurable for cases that want it.
##
## Stateful but global, mirroring [SilhouetteHighlighter]: a single player means a single focus.

## When true, only the focus is highlighted. Set via [method set_exclusive] so a live change
## re-evaluates immediately.
static var exclusive: bool = true

class _Candidate:
	var root: Node3D
	var source: Object
	func _init(p_root: Node3D, p_source: Object) -> void:
		root = p_root
		source = p_source

# In-range candidates, in entry order — the last is the most recently entered.
static var _candidates: Array[_Candidate] = []
static var _focus_root: Node3D = null

## Registers [param root] (the subtree to outline) as in range, owned by [param source] (the
## [Item] or [Structure] that [method focused_source] returns for interaction).
static func enter(root: Node3D, source: Object) -> void:
	if root == null:
		return
	for candidate: _Candidate in _candidates:
		if candidate.root == root:
			return
	_candidates.append(_Candidate.new(root, source))
	_reevaluate()

## Unregisters [param root]. Clears its outline and, if it was the focus, hands focus to the
## most-recently-entered candidate still in range.
static func exit(root: Node3D) -> void:
	for i: int in _candidates.size():
		if _candidates[i].root == root:
			_candidates.remove_at(i)
			break
	SilhouetteHighlighter.set_highlighted(root, false)
	_reevaluate()

## The [Item] or [Structure] currently focused, or null. The Player interacts with this in
## exclusive mode so "what's highlighted" is "what you interact with".
static func focused_source() -> Object:
	_prune()
	for candidate: _Candidate in _candidates:
		if candidate.root == _focus_root:
			return candidate.source
	return null

## Toggles exclusive vs shared and re-applies highlights so a live change takes effect at once.
static func set_exclusive(value: bool) -> void:
	exclusive = value
	_reevaluate()

## Drops all tracked candidates and clears their outlines. Call on teardown/scene change so a
## freed interactable can't linger as a stale focus.
static func clear() -> void:
	for candidate: _Candidate in _candidates:
		if is_instance_valid(candidate.root):
			SilhouetteHighlighter.set_highlighted(candidate.root, false)
	_candidates.clear()
	_focus_root = null

static func _prune() -> void:
	var kept: Array[_Candidate] = []
	for candidate: _Candidate in _candidates:
		if is_instance_valid(candidate.root):
			kept.append(candidate)
	_candidates = kept

static func _reevaluate() -> void:
	_prune()
	if not exclusive:
		# Shared: everything in range is highlighted.
		_focus_root = null
		for candidate: _Candidate in _candidates:
			SilhouetteHighlighter.set_highlighted(candidate.root, true)
		return

	# Exclusive: keep the current focus while it's still in range (sticky); otherwise take the
	# most-recently-entered candidate.
	var focus_in_range: bool = false
	for candidate: _Candidate in _candidates:
		if candidate.root == _focus_root:
			focus_in_range = true
			break
	if not focus_in_range:
		_focus_root = _candidates[-1].root if not _candidates.is_empty() else null

	for candidate: _Candidate in _candidates:
		SilhouetteHighlighter.set_highlighted(candidate.root, candidate.root == _focus_root)
