extends GdUnitTestSuite
## [ResourceEditor] introspects a resource and builds one editing row per authored field — proving a new data
## type gets a form for free — renders a field it can't edit yet (a nested resource) as a read-only label, and
## lets the host swap in a bespoke control for a field via [method ResourceEditor.with_custom_field].

# A stand-in resource with one field of each kind the editor handles, plus a nested-resource field it can't
# edit yet. Keeps the test independent of any real game type.
class _Stub extends Resource:
	enum Kind { ALPHA, BETA }
	@export var label: StringName = &""
	@export var amount: int = 0
	@export var ratio: float = 0.0
	@export var enabled: bool = false
	@export var kind: Kind = Kind.ALPHA
	@export var tint: Color = Color.WHITE
	@export var nested: Resource = null

func _editor(resource: Resource) -> ResourceEditor:
	var editor: ResourceEditor = auto_free(ResourceEditor.create(resource, "Stub"))
	add_child(editor)
	return editor

func test_builds_one_row_per_authored_field() -> void:
	var editor := _editor(_Stub.new())
	# label, amount, ratio, enabled, kind, tint, nested — seven authored fields, seven rows.
	assert_int(editor.get_child_count()).is_equal(7)

func test_uneditable_field_is_shown_read_only() -> void:
	var editor := _editor(_Stub.new())
	var read_only := 0
	for child: Node in editor.get_children():
		if child is Label:
			read_only += 1
	# Only the nested-resource field falls back to a read-only Label; the six scalars (incl. the colour) are
	# editable rows.
	assert_int(read_only).is_equal(1)

func test_custom_field_replaces_the_generic_row() -> void:
	var marker := Label.new()
	marker.name = "CustomMarker"
	var editor: ResourceEditor = auto_free(ResourceEditor.create(_Stub.new(), "Stub") \
		.with_custom_field("amount", func(_resource: Resource) -> Control: return marker))
	add_child(editor)
	# The "amount" field renders the host's control instead of a slider.
	assert_bool(editor.get_children().has(marker)).is_true()
