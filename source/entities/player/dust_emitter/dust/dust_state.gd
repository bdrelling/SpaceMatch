class_name DustState
extends State

var dust_emitter: DustEmitter

func _ready() -> void:
	await owner.ready
	dust_emitter = get_parent().get_parent() as DustEmitter
	assert(dust_emitter != null)
