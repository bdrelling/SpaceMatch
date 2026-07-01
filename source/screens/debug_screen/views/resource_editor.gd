class_name ResourceEditor
extends DebugView
## A generic, introspection-driven editor for any [Resource]: it reads the resource's script properties via
## [method Object.get_property_list] and builds a [DebugRow] for each — text for strings, a slider for ints and
## floats, a toggle for bools, a dropdown for enums, a picker for colours — editing the resource in place.
## Composite fields (nested resources and arrays) are shown dimmed and read-only for now; editing those is the
## next step. One editor for every data type means a new type gets a form for free, instead of a hand-written
## detail view.
##
## The host tunes it per instance, since introspection can't supply everything: [method with_range] gives a
## numeric field its slider bounds (the resources rarely use @export_range, and "id" means a different range on
## every type), and [method with_custom_field] drops a bespoke control in for one field — the escape hatch that
## lets a hand-built widget (a shape grid, a nested sub-editor) live inside the generic form.

# Fallback slider range for a numeric field the host didn't give a range.
const _DEFAULT_RANGE: Array = [0, 100]

var _resource: Resource
var _title: String = ""
# Per-property slider ranges [min, max], set by the host via with_range.
var _ranges: Dictionary = {}
# Per-property custom control providers: property -> Callable(resource) -> Control.
var _custom_fields: Dictionary = {}


## Builds an editor for [param resource]; [param title_text] is the page header (e.g. the catalog entry title).
static func create(resource: Resource, title_text: String = "") -> ResourceEditor:
	var editor := ResourceEditor.new()
	editor._resource = resource
	editor._title = title_text
	return editor


## Sets the slider range for numeric [param property]. Returns self for chaining.
func with_range(property: String, minimum: float, maximum: float) -> ResourceEditor:
	_ranges[property] = [minimum, maximum]
	return self


## Renders [param property] with a host-supplied control instead of a generic row. [param provider] receives
## the edited resource and returns the [Control] to use (e.g. a shape editor). Returns self for chaining.
func with_custom_field(property: String, provider: Callable) -> ResourceEditor:
	_custom_fields[property] = provider
	return self


func title() -> String:
	if not _title.is_empty():
		return _title
	return _resource.get_class() if _resource != null else "Editor"


func _build() -> void:
	if _resource == null:
		return
	for prop: Dictionary in _resource.get_property_list():
		var usage: int = prop.usage
		# Only the resource's own authored fields: a script variable that is actually stored. This skips the
		# Resource base's bookkeeping and any getter/setter-only pseudo-properties (no STORAGE).
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		add_child(_row_for(prop))


# The editing control for one property: a host override wins, then a scalar gets an editable row and anything
# composite a dimmed read-only summary (editing nested resources and arrays is the next milestone).
func _row_for(prop: Dictionary) -> Control:
	var resource := _resource
	var p: String = prop.name

	if _custom_fields.has(p):
		var provider: Callable = _custom_fields[p]
		var custom: Control = provider.call(resource)
		return custom

	var label := p.capitalize()
	var prop_type: int = prop.type
	var hint: int = prop.hint

	if prop_type == TYPE_INT and hint == PROPERTY_HINT_ENUM:
		var hint_string: String = prop.hint_string
		return _enum_row(label, p, hint_string)

	var row: Control
	match prop_type:
		TYPE_STRING, TYPE_STRING_NAME:
			var current_string := str(resource.get(p))
			row = DebugRow.text(label, current_string, func(value: String) -> void: _set_text(p, prop_type, value))
		TYPE_INT:
			var current_int: int = resource.get(p)
			var span := _range_for(p)
			var minimum: float = span[0]
			var maximum: float = span[1]
			row = DebugRow.slider(label, Color.WHITE, minimum, maximum, current_int, func(value: float) -> void: resource.set(p, int(value)))
		TYPE_FLOAT:
			var current_float: float = resource.get(p)
			var fspan := _range_for(p)
			var fmin: float = fspan[0]
			var fmax: float = fspan[1]
			row = DebugRow.slider(label, Color.WHITE, fmin, fmax, current_float, func(value: float) -> void: resource.set(p, value))
		TYPE_BOOL:
			var current_bool: bool = resource.get(p)
			row = DebugRow.toggle(label, current_bool, func(value: bool) -> void: resource.set(p, value))
		TYPE_COLOR:
			var current_color: Color = resource.get(p)
			row = DebugRow.color(label, current_color, func(value: Color) -> void: resource.set(p, value))
		_:
			row = _readonly_row(label, p, prop_type)
	return row


# A dropdown over an enum field. Enum hint tokens are "Name" or "Name:Value"; the option index is stored
# directly, which matches the sequential enums these resources use (e.g. Status.sign).
func _enum_row(label: String, p: String, hint_string: String) -> Control:
	var resource := _resource
	var options: Array = []
	for token: String in hint_string.split(",", false):
		options.append(token.get_slice(":", 0).capitalize())
	var current: int = resource.get(p)
	return DebugRow.option(label, options, current, func(index: int) -> void: resource.set(p, index))


# Writes a string field back, preserving StringName fields as StringName.
func _set_text(p: String, prop_type: int, value: String) -> void:
	if prop_type == TYPE_STRING_NAME:
		_resource.set(p, StringName(value))
	else:
		_resource.set(p, value)


# [min, max] for property [param p] — its host-set range, else the default.
func _range_for(p: String) -> Array:
	return _ranges[p] if _ranges.has(p) else _DEFAULT_RANGE


# A dimmed, read-only summary for a field this editor can't edit yet (nested resource, array, etc.).
func _readonly_row(label: String, p: String, prop_type: int) -> Control:
	var node := Label.new()
	node.text = "%s: %s" % [label, _readonly_text(p, prop_type)]
	node.add_theme_font_size_override("font_size", DebugRow.ROW_FONT)
	node.modulate = Color(1.0, 1.0, 1.0, 0.6)
	return node


func _readonly_text(p: String, prop_type: int) -> String:
	var raw: Variant = _resource.get(p)
	match prop_type:
		TYPE_ARRAY:
			var entries: Array = raw
			return "%d item(s)" % entries.size()
		TYPE_OBJECT:
			if raw == null:
				return "none"
			if raw is Resource:
				var nested: Resource = raw
				return nested.resource_name if not nested.resource_name.is_empty() else nested.get_class()
			return str(raw)
	return type_string(prop_type)
