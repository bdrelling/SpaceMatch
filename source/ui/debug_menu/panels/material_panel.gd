class_name MaterialPanel
extends DebugPanel
## Material tab: pick + apply a material override to the linked node at runtime.

var _loaded: bool = false
var _material_index: Array[int] = [0]

func title() -> StringName:
	return &"Material"

func is_available() -> bool:
	return is_instance_valid(_menu.material_tester)

func draw() -> void:
	var tester: MaterialTester = _menu.material_tester
	if not _loaded:
		tester.scan()
		_loaded = true

	ImGui.Text("Target: " + tester.target_name())
	ImGui.TextDisabled("Overrides the linked node's meshes. Runtime only.")
	ImGui.Spacing()

	if tester.material_names.is_empty():
		ImGui.Text("No materials found in assets/materials/.")
		if ImGui.Button(&"Rescan"):
			tester.scan()
		return

	ImGui.SetNextItemWidth(220.0)
	ImGui.ComboChar(&"Material", _material_index, tester.material_names, tester.material_names.size())
	if ImGui.Button(&"Apply"):
		tester.apply(_material_index[0])
	ImGui.SameLine()
	if ImGui.Button(&"Clear"):
		tester.clear()
	ImGui.SameLine()
	if ImGui.Button(&"Rescan"):
		tester.scan()
