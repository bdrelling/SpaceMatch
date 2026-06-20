class_name StageScreen
extends ArcadeScreen
## A placeholder production-stage page: a [member title] and a readout of the shared stock, refreshing
## as the economy changes. Stands in until a stage gets its real minigame — and proves each page
## reflects the one session every other page shares. [member title] is inherited from [ArcadeScreen].

var _inventory: Inventory
var _stock_label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	_stock_label = Label.new()
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stock_label)
	_refresh()

func bind(_session: GameSession, inventory: Inventory) -> void:
	if _inventory == inventory:
		return
	if _inventory != null and _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
	_inventory = inventory
	if _inventory != null and not _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.connect(_on_inventory_changed)
	_refresh()

## The stock readout text, for tests and hosts.
func summary() -> String:
	return _stock_label.text if _stock_label != null else ""

func _on_inventory_changed(_inventory: Inventory) -> void:
	_refresh()

func _refresh() -> void:
	if _stock_label == null or _inventory == null:
		return
	var lines: PackedStringArray = []
	for stack: ItemStack in _inventory.get_stacks():
		lines.append("%s × %d" % [stack.display_name, stack.quantity])
	_stock_label.text = "\n".join(lines) if not lines.is_empty() else "Empty"
