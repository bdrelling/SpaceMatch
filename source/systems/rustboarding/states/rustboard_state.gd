class_name RustboardState
extends State

const STOWED := &"Stowed"
const DEPLOYED := &"Deployed"

var rustboard: Rustboard

func _ready() -> void:
	await owner.ready
	rustboard = get_parent().get_parent() as Rustboard
	assert(rustboard != null)
