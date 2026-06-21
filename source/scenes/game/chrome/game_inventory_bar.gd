class_name GameInventoryBar
extends Control
## The context strip above the tab bar. It reads the active stage's [method Minigame.inventory_chips]
## into an always-visible row, and — when the stage offers a [method Minigame.inventory_detail] — a tap
## expands it into a drawer with the richer view (recycling's full breakdown, outfitting's module grid).
## A stage whose inventory IS its interface ([method Minigame.inventory_pinned]) shows the drawer pinned
## open with no toggle; a stage with nothing to show hides the strip entirely. Like the other bars its
## [member Background] bleeds to the screen sides while the content insets to the safe area.

## Collapsed strip height in the portrait design space.
const _STRIP_HEIGHT: float = 100.0
## Gap between the strip and the expanded drawer.
const _DRAWER_GAP: float = 12.0
## Clear space kept between content and the safe-area side edges.
const _EDGE_PADDING: float = 24.0
const _CARET_EXPANDED: String = "  ⌄"
const _CARET_COLLAPSED: String = "  ⌃"

@onready var _content: VBoxContainer = $Content
@onready var _strip: Button = %Strip
@onready var _chip_row: HBoxContainer = %ChipRow
@onready var _drawer: MarginContainer = %Drawer

var _minigame: Minigame
var _detail: Control
# Where the detail lives when not in the drawer — its owning stage. The detail is always parented to one
# or the other (never orphaned), so it's freed with its stage.
var _detail_home: Node
var _pinned: bool = false
var _expanded: bool = false
var _insets := SafeArea.Insets.empty()

func _ready() -> void:
	_strip.pressed.connect(_on_strip_pressed)
	_drawer.visible = false
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

## Points the strip at [param minigame]; reads its chips and detail and lays the bar out. Pass null to
## clear (e.g. when the active page isn't a stage).
func bind(minigame: Minigame) -> void:
	_release_detail()
	_minigame = minigame
	if _minigame == null:
		_relayout()
		return
	_detail = _minigame.inventory_detail()
	_detail_home = _detail.get_parent() if _detail != null else null
	_pinned = _minigame.inventory_pinned()
	_expanded = _pinned
	refresh()

## Rebuilds the chip row from the active stage's current holdings — wired to
## [signal Minigame.inventory_changed].
func refresh() -> void:
	if _minigame == null:
		return
	_rebuild_chips(_minigame.inventory_chips())
	_sync_drawer()
	_relayout()

func _on_strip_pressed() -> void:
	if _detail == null or _pinned:
		return
	_expanded = not _expanded
	_sync_drawer()
	_relayout()

# Moves the stage's detail between the drawer and its home (the stage) to match the expanded state.
# The detail is always parented to one or the other, so it's never orphaned and frees with its stage.
func _sync_drawer() -> void:
	var show_detail: bool = _detail != null and _expanded
	if show_detail:
		if _detail.get_parent() != _drawer:
			_reparent_detail(_drawer)
		_detail.visible = true
	elif _detail != null and _detail.get_parent() == _drawer:
		_reparent_detail(_detail_home)
		_detail.visible = false
	_drawer.visible = show_detail

func _reparent_detail(target: Node) -> void:
	var parent: Node = _detail.get_parent()
	if parent != null:
		parent.remove_child(_detail)
	if target != null and is_instance_valid(target):
		target.add_child(_detail)

func _rebuild_chips(chips: Array[InventoryChip]) -> void:
	for child: Node in _chip_row.get_children():
		child.queue_free()
	for chip: InventoryChip in chips:
		_chip_row.add_child(_build_chip(chip))
	if _detail != null and not _pinned:
		var caret := Label.new()
		caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caret.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caret.text = _CARET_EXPANDED if _expanded else _CARET_COLLAPSED
		_chip_row.add_child(caret)

func _build_chip(chip: InventoryChip) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	if chip.color.a > 0.0:
		var swatch := ColorRect.new()
		swatch.color = chip.color
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "%s  %d" % [chip.label, chip.quantity]
	row.add_child(label)
	return row

# Returns the stage's detail to its home so the stage keeps owning it across page switches.
func _release_detail() -> void:
	if _detail != null and _detail.get_parent() == _drawer:
		_reparent_detail(_detail_home)
		_detail.visible = false
	_detail = null
	_detail_home = null
	_pinned = false
	_expanded = false

# Sizes the bar to its current content, hides the strip row when there are no chips, and hides the
# whole bar when the stage has nothing to show.
func _relayout() -> void:
	var has_chips: bool = _chip_row.get_child_count() > 0
	var has_detail: bool = _detail != null
	_strip.visible = has_chips
	visible = has_chips or has_detail
	if not visible:
		custom_minimum_size.y = 0.0
		return
	var height: float = _EDGE_PADDING * 2.0
	if has_chips:
		height += _STRIP_HEIGHT
	if _detail != null and _expanded:
		if has_chips:
			height += _DRAWER_GAP
		height += maxf(_detail.get_combined_minimum_size().y, _STRIP_HEIGHT)
	custom_minimum_size.y = height

func _apply_safe_area() -> void:
	_insets = DeviceUtils.get_safe_area(get_viewport()).insets
	_content.offset_left = _insets.leading + _EDGE_PADDING
	_content.offset_top = _EDGE_PADDING
	_content.offset_right = -(_insets.trailing + _EDGE_PADDING)
	_content.offset_bottom = -_EDGE_PADDING
