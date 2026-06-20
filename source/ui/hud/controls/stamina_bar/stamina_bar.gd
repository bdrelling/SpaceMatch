class_name StaminaBar
extends VBoxContainer

const _PALETTE := preload("res://systems/design/rustyard.tres")

## Stamina fraction below which the bar reads yellow (mid). Below the player's
## red threshold the bar reads red; above this it reads green.
const _YELLOW_THRESHOLD: float = 0.4

@onready var _progress_bar: ProgressBar = %ProgressBar

@export var _player: Player

var _fill_style: StyleBoxFlat

func _ready() -> void:
	_apply_styles()

func bind_player(player: Player) -> void:
	if player == _player:
		return
	
	if _player:
		_player.stamina_changed.disconnect(_on_stamina_changed)
		
	_player = player
	
	player.stamina_changed.connect(_on_stamina_changed)
	_progress_bar.max_value = player.max_stamina
	_progress_bar.value = player.stamina

func _on_stamina_changed(current: float, maximum: float) -> void:
	_progress_bar.max_value = maximum
	_progress_bar.value = current
	_update_fill_color(current / maximum)

func _apply_styles() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = _PALETTE.hud_stamina_background
	background.anti_aliasing = false
	_progress_bar.add_theme_stylebox_override("background", background)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = _PALETTE.hud_stamina_full
	_fill_style.anti_aliasing = false
	_progress_bar.add_theme_stylebox_override("fill", _fill_style)

func _update_fill_color(ratio: float) -> void:
	if _fill_style == null:
		return
	if ratio > _YELLOW_THRESHOLD:
		_fill_style.bg_color = _PALETTE.hud_stamina_full
	elif ratio > Player.STAMINA_RED_THRESHOLD:
		_fill_style.bg_color = _PALETTE.hud_stamina_low
	else:
		_fill_style.bg_color = _PALETTE.hud_stamina_empty
