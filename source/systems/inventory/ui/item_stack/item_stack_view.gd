class_name ItemStackView
extends PanelContainer
## A single row in an [InventoryPanel]: the item's icon, name, and quantity, plus a drop
## button. The view never mutates the inventory itself — pressing drop emits
## [signal drop_requested] and the owning [InventoryPanel] performs the removal.

const SCENE_PATH := "res://systems/inventory/ui/item_stack/item_stack_view.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

const _PALETTE := preload("res://systems/design/rustyard.tres")
const _TRASH_ICON: Texture2D = preload("res://assets/icons/trash.svg")

## Emitted when the drop button is pressed. The panel drops one unit of [param stack].
signal drop_requested(stack: ItemStack)

## Plain white square shown when an item has no authored inventory_texture, so the blueprint's
## color still reads as a swatch.
static var _fallback_swatch: Texture2D = _make_fallback_swatch()

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _quantity: Label = %Quantity
@onready var _drop: Button = %Drop

var stack: ItemStack:
	set(value):
		stack = value
		if is_node_ready():
			_refresh()

func _ready() -> void:
	_apply_style()
	_drop.pressed.connect(_on_drop_pressed)
	_refresh()

func _refresh() -> void:
	if not stack or not stack.item_blueprint:
		_icon.texture = null
		_icon.modulate = Color.WHITE
		_name.text = ""
		_quantity.text = ""
		return

	var blueprint: ItemBlueprint = stack.item_blueprint
	var damaged: bool = stack.tags.has(Item.Tag.DAMAGED)
	_icon.texture = blueprint.inventory_texture if blueprint.inventory_texture != null else _fallback_swatch
	_icon.modulate = blueprint.color.darkened(0.45) if damaged else blueprint.color
	_name.text = stack.display_name
	if damaged:
		_name.add_theme_color_override("font_color", _PALETTE.status_bar_condition_damaged)
	else:
		_name.remove_theme_color_override("font_color")
	_quantity.text = str(stack.quantity)

func _on_drop_pressed() -> void:
	if stack:
		drop_requested.emit(stack)

func _apply_style() -> void:
	var row := StyleBoxFlat.new()
	row.bg_color = _PALETTE.sidebar_slot_background
	row.border_color = _PALETTE.sidebar_slot_border
	row.set_border_width_all(1)
	row.set_corner_radius_all(3)
	row.content_margin_left = 8
	row.content_margin_right = 8
	row.content_margin_top = 6
	row.content_margin_bottom = 6
	row.anti_aliasing = false
	add_theme_stylebox_override("panel", row)

	_drop.icon = _TRASH_ICON
	_drop.add_theme_color_override("icon_normal_color", Color.WHITE)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		_drop.add_theme_stylebox_override(state, _drop_style(state))

func _drop_style(state: StringName) -> StyleBoxFlat:
	var red: Color = _PALETTE.hud_stamina_empty
	var style := StyleBoxFlat.new()
	style.bg_color = red.lightened(0.12) if state == &"hover" else (red.darkened(0.2) if state == &"pressed" else red)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.anti_aliasing = false
	return style

static func _make_fallback_swatch() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

static func create(_stack: ItemStack) -> ItemStackView:
	var view: ItemStackView = SCENE.instantiate()
	view.stack = _stack
	return view
