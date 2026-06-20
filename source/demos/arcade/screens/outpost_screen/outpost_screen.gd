class_name OutpostScreen
extends ArcadeScreen
## The outpost hub: its landing pads (each occupied by a ship or empty) and the contents of its
## salvage yard. Read-only for now — it reflects the [OutpostState] the rest of the game mutates.

var _outpost: OutpostState

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)

func bind(session: GameSession, _inventory: Inventory) -> void:
	_outpost = session.state.outpost if session != null and session.state != null else null
	_rebuild()

# The salvage yard is mutated elsewhere (outfitting draws from it); refresh whenever this page is
# shown rather than holding a live binding.
func _on_visibility_changed() -> void:
	if visible:
		_rebuild()

func _rebuild() -> void:
	var pad_list := get_node_or_null("%PadList") as Container
	var yard_list := get_node_or_null("%YardList") as VBoxContainer
	if pad_list != null:
		_rebuild_pads(pad_list)
	if yard_list != null:
		_rebuild_yard(yard_list)

# One [LandingPadBox] per pad — a low-res sample of its docked ship — followed by a dashed ghost box
# for the next pad the player could buy (display only).
func _rebuild_pads(pad_list: Container) -> void:
	for child: Node in pad_list.get_children():
		child.queue_free()
	if _outpost == null:
		return
	for index: int in _outpost.landing_pads.size():
		var box := LandingPadBox.new()
		box.index = index
		box.pad = _outpost.landing_pads[index]
		pad_list.add_child(box)
	var next_pad := LandingPadBox.new()
	next_pad.index = _outpost.landing_pads.size()
	next_pad.ghost = true
	pad_list.add_child(next_pad)

# Size of a scrap / component swatch in the count rows.
const _SWATCH_SIZE := Vector2(56, 56)
# Size of a module's footprint picture in the flow row.
const _MODULE_ICON_SIZE := Vector2(72, 72)
const _SECTION_FONT_SIZE := 22

# Scrap and components read as rows of colour-coded count squares; modules — the things you actually
# build with — get the richer footprint-and-name cards, the same picture the outfitting strip shows.
func _rebuild_yard(yard_list: VBoxContainer) -> void:
	for child: Node in yard_list.get_children():
		child.queue_free()
	yard_list.add_theme_constant_override("separation", 12)
	if _outpost == null or _outpost.salvage_yard == null:
		return
	var scrap: Array[ItemStack] = []
	var components: Array[ItemStack] = []
	var modules: Array[ItemStack] = []
	for stack: ItemStack in _outpost.salvage_yard.stacks:
		if stack == null or stack.item_blueprint == null or stack.quantity <= 0:
			continue
		match stack.item_blueprint.category:
			Item.Category.MODULE:
				modules.append(stack)
			Item.Category.COMPONENT:
				components.append(stack)
			_:
				scrap.append(stack)
	yard_list.add_child(_build_squares_section("Scrap", scrap))
	yard_list.add_child(_build_squares_section("Components", components))
	yard_list.add_child(_build_modules_section("Modules", modules))

# A labelled row of count squares — one per stack, tinted by the item's colour.
func _build_squares_section(title: String, stacks: Array[ItemStack]) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(_section_label(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for stack: ItemStack in stacks:
		row.add_child(_build_item_square(stack))
	section.add_child(row)
	return section

func _build_modules_section(title: String, stacks: Array[ItemStack]) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	section.add_child(_section_label(title))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	for stack: ItemStack in stacks:
		flow.add_child(_build_module_card(stack))
	section.add_child(flow)
	return section

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", _SECTION_FONT_SIZE)
	return label

# A scrap/component count square: the item's colour with its quantity beneath.
func _build_item_square(stack: ItemStack) -> Control:
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_theme_constant_override("separation", 4)
	cell.tooltip_text = stack.display_name
	var swatch := ColorRect.new()
	swatch.color = stack.item_blueprint.color
	swatch.custom_minimum_size = _SWATCH_SIZE
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(swatch)
	var count := Label.new()
	count.text = "×%d" % stack.quantity
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(count)
	return cell

# A module card: its footprint picture, name, and quantity — the outfitting strip's presentation.
func _build_module_card(stack: ItemStack) -> Control:
	var card := VBoxContainer.new()
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 4)
	var icon := ItemFootprintIcon.new()
	icon.blueprint = stack.item_blueprint
	icon.custom_minimum_size = _MODULE_ICON_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(icon)
	var name_label := Label.new()
	name_label.text = stack.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name_label)
	var count := Label.new()
	count.text = "×%d" % stack.quantity
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(count)
	return card
