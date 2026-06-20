extends DustState

func enter(_previous_state_name: StringName) -> void:
	dust_emitter.set_active_emitter(&"Walk")
