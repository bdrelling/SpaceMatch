class_name MaterialTester
extends Node
## A runtime-only look-dev tool for trying materials on a single linked node (e.g. the
## player). Link [member target] in the editor; during gameplay the debug menu's Material
## tab shows the target's name and a dropdown of every material in [constant MATERIALS_DIRECTORY],
## and applies the chosen one as a [code]material_override[/code] on every mesh under the
## target.
##
## Deliberately isolated from [Atmosphere] and never touches the world — it overrides only
## the linked node, only at runtime, and restores the authored overrides when cleared.

const MATERIALS_DIRECTORY: String = "res://assets/materials/"

## The node whose meshes get the test material. Usually the player.
@export var target: Node3D

## Absolute paths of the scanned materials, parallel to [member material_names].
var material_paths: Array[String] = []
## Display names (file basenames) for the dropdown.
var material_names: Array[String] = []

# instance_id -> authored material_override (may be null), captured before the first apply.
var _original_overrides: Dictionary[int, Material] = {}
var _captured: bool = false

## The linked node's name, or a placeholder when nothing is linked.
func target_name() -> String:
	return String(target.name) if is_instance_valid(target) else "<no target linked>"

## Re-reads [constant MATERIALS_DIRECTORY] into [member material_paths] / [member material_names].
func scan() -> void:
	material_paths.clear()
	material_names.clear()
	var directory: DirAccess = DirAccess.open(MATERIALS_DIRECTORY)
	if directory == null:
		return
	var files: PackedStringArray = directory.get_files()
	files.sort()
	for file_name: String in files:
		var path: String = file_name.trim_suffix(".remap")
		if path.ends_with(".tres") or path.ends_with(".material") or path.ends_with(".res"):
			material_paths.append(MATERIALS_DIRECTORY + path)
			material_names.append(path.get_basename())

## Overrides every mesh under [member target] with the material at [param index].
func apply(index: int) -> bool:
	if not is_instance_valid(target):
		Log.warning("MaterialTester: no target linked.")
		return false
	if index < 0 or index >= material_paths.size():
		return false
	var material: Material = ResourceLoader.load(material_paths[index]) as Material
	if material == null:
		Log.warning("MaterialTester: failed to load %s" % material_paths[index])
		return false
	_capture_originals()
	for geometry: GeometryInstance3D in _meshes():
		geometry.material_override = material
	return true

## Restores the authored overrides captured before the first apply.
func clear() -> void:
	if not _captured:
		return
	for geometry: GeometryInstance3D in _meshes():
		var id: int = geometry.get_instance_id()
		if _original_overrides.has(id):
			geometry.material_override = _original_overrides[id]

func _capture_originals() -> void:
	if _captured:
		return
	for geometry: GeometryInstance3D in _meshes():
		_original_overrides[geometry.get_instance_id()] = geometry.material_override
	_captured = true

func _meshes() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if is_instance_valid(target):
		_collect(target, result)
	return result

func _collect(node: Node, result: Array[GeometryInstance3D]) -> void:
	var geometry: GeometryInstance3D = node as GeometryInstance3D
	if geometry != null:
		result.append(geometry)
	for child: Node in node.get_children():
		_collect(child, result)
