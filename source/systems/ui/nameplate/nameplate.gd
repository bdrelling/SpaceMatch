@tool
class_name Nameplate
extends Label3D
## A text label that floats in the 3D world above an entity — a name tag for structures and other
## objects. Drop the [code]nameplate.tscn[/code] scene in as a child, set [member text], and pick how
## it [member orientation]s: [b]FIXED[/b] keeps the rotation it's authored with in the scene;
## [b]CAMERA_FOLLOW[/b] pivots around Y to face the camera while staying upright (a billboard, handled
## entirely by the renderer — no camera reference needed). Styling matches the HUD: Inconsolata,
## pale-blue text on a dark outline.

## How the nameplate orients itself relative to the viewer.
enum Orientation {
	FIXED,          ## Keeps the rotation it's authored with in the scene — good for facing a fixed direction.
	CAMERA_FOLLOW,  ## Pivots around Y to face the camera, staying upright (Y-locked billboard).
}

@export var orientation := Orientation.CAMERA_FOLLOW:
	set(value):
		orientation = value
		_apply_orientation()

func _ready() -> void:
	_apply_orientation()

# Maps our two intent-revealing options onto Label3D's billboard modes. Runs in the editor too
# (@tool) so the inspector choice previews live.
func _apply_orientation() -> void:
	match orientation:
		Orientation.FIXED:
			billboard = BaseMaterial3D.BILLBOARD_DISABLED
		Orientation.CAMERA_FOLLOW:
			billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
