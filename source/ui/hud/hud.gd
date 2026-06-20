class_name HUD
extends CanvasLayer

@export var _player: Player

@onready var _minimap: Minimap = %Minimap
@onready var _stamina_bar: StaminaBar = %StaminaBar

func _ready() -> void:
	if _player:
		bind_player(_player)

func bind_player(player: Player) -> void:
	_stamina_bar.bind_player(player)
	_minimap.bind_player(player)
