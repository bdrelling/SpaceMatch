class_name HullHighlighter
## Toggles an inverted-hull silhouette outline (see highlight.gdshader) on every mesh in a
## node's subtree. Each mesh gets its own hull, so a multi-part model shows every part's ridge
## — a deliberate look; for a single clean merged outer silhouette use [SilhouetteHighlighter]
## instead. Applied as a [code]material_overlay[/code] — overlay, not next_pass/override, so the
## StyleApplicator (which rebuilds every mesh's material_override) never clobbers it.

const _HIGHLIGHT_SHADER: Shader = preload("res://systems/rendering/shaders/highlight.gdshader")

# One material shared across every highlighted mesh in the game — it carries no per-instance
# state, so a single lazily-built instance is enough.
static var _material: ShaderMaterial

## Shows or hides the highlight on every [MeshInstance3D] in [param root]'s subtree
## ([param root] included). Safe to call with a single mesh as the root.
static func set_highlighted(root: Node3D, highlighted: bool) -> void:
	if root == null:
		return
	_apply(root, _shared_material() if highlighted else null)

static func _apply(node: Node, material: ShaderMaterial) -> void:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh != null:
		mesh.material_overlay = material
	for child: Node in node.get_children():
		_apply(child, material)

static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = _HIGHLIGHT_SHADER
	return _material
