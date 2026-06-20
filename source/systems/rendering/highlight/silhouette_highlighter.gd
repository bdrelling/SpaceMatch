class_name SilhouetteHighlighter
## Toggles an L4D-style "you can interact with this" highlight on a node's meshes: one merged
## outer-silhouette outline plus a flat x-ray fill wherever the object is occluded. Built from
## three stencil/depth passes (see silhouette_stencil/outline/xray.gdshader) chained on a single
## material and applied as a [code]material_overlay[/code] — overlay, not next_pass/override, so
## the StyleApplicator (which rebuilds every mesh's material_override) never clobbers it.
## Drop-in sibling of [HullHighlighter] with the same [method set_highlighted] shape; use this
## for a clean merged silhouette and [HullHighlighter] for the per-mesh inverted-hull look.

const _STENCIL_SHADER: Shader = preload("res://systems/rendering/shaders/silhouette_stencil.gdshader")
const _STENCIL_VISIBLE_SHADER: Shader = preload("res://systems/rendering/shaders/silhouette_stencil_visible.gdshader")
const _XRAY_SHADER: Shader = preload("res://systems/rendering/shaders/silhouette_xray.gdshader")
const _EXCLUDE_SHADER: Shader = preload("res://systems/rendering/shaders/silhouette_exclude.gdshader")

# Shared, stateless materials — one lazily-built instance of each is enough for the whole game.
static var _material: ShaderMaterial
static var _exclude_material: ShaderMaterial

## Shows or hides the highlight on every [MeshInstance3D] in [param root]'s subtree
## ([param root] included). Safe to call with a single mesh as the root.
static func set_highlighted(root: Node3D, highlighted: bool) -> void:
	if root == null:
		return
	_apply(root, _shared_material() if highlighted else null)

## Marks [param root]'s meshes so that OTHER objects' highlights never draw their x-ray fill or
## outline over it — e.g. the player, which sits in front of highlighted structures. The mark is
## a stencil write that renders after the highlight's mask passes but before its readers, so the
## readers skip these pixels. Persistent; call once when the object's meshes exist.
static func set_excluded(root: Node3D, excluded: bool) -> void:
	if root == null:
		return
	_apply(root, _shared_exclude_material() if excluded else null)

static func _apply(node: Node, material: ShaderMaterial) -> void:
	var mesh: MeshInstance3D = node as MeshInstance3D
	if mesh != null:
		mesh.material_overlay = material
	for child: Node in node.get_children():
		_apply(child, material)

# Stencil-write chain, ordered by render_priority so that — across every mesh in a multi-part
# model — the writes land in sequence and merge the parts into one silhouette. The OUTLINE is no
# longer a material pass (inverted hull cracked on hard edges); it's drawn in screen space by
# [SilhouetteOutline]'s CompositorEffect, which tests stencil bit0. Stencil values:
#   bit0 = object silhouette, bit1 = visible. 1 = occluded, 3 = visible, 4 = excluded (player).
#   0 stencil (full silhouette → 1)  →  1 visible (→ 3)  →  [2 exclude → 4]  →  3 x-ray fill (==1)
static func _shared_material() -> ShaderMaterial:
	if _material == null:
		var xray := ShaderMaterial.new()
		xray.shader = _XRAY_SHADER
		xray.render_priority = 3

		var stencil_visible := ShaderMaterial.new()
		stencil_visible.shader = _STENCIL_VISIBLE_SHADER
		stencil_visible.render_priority = 1
		stencil_visible.next_pass = xray

		_material = ShaderMaterial.new()
		_material.shader = _STENCIL_SHADER
		_material.render_priority = 0
		_material.next_pass = stencil_visible
	return _material

static func _shared_exclude_material() -> ShaderMaterial:
	if _exclude_material == null:
		_exclude_material = ShaderMaterial.new()
		_exclude_material.shader = _EXCLUDE_SHADER
		_exclude_material.render_priority = 2
	return _exclude_material
