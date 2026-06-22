class_name OutfittingMinigame
extends Minigame
## Outfitting: shows the starship's module grid. The module grid is the player's loadout; rearranging
## modules and buying new ones (from a shop) come later. For now this stage simply renders the grid.

const _CELL_SIZE: float = 96.0

@onready var _canvas: BoardCanvas = %BoardCanvas

var _grid_view: ModuleGridView

## Mounts the player's module grid as the board. Called by [MinigameScreen] when the page mounts; the
## shell re-points this at another combatant's ship via [method show_starship] when a portrait drills in.
func bind_session(session: GameSession) -> void:
	if session == null or session.state == null:
		return
	_show_grid(session.state.starship.module_grid)

## Re-points the board at [param starship]'s module grid — called by the shell when a portrait drills
## in, so this one stage shows the player's loadout or an opponent's. Rebuilds the board view.
func show_starship(starship: StarshipState) -> void:
	if starship == null:
		return
	_show_grid(starship.module_grid)

# Rebuilds the board for [param module_grid], freeing the prior view first ([BoardCanvas.set_board]
# detaches the old board but doesn't free it, so re-pointing would otherwise leak views).
func _show_grid(module_grid: ModuleGrid) -> void:
	if module_grid == null:
		return
	if _grid_view != null:
		_grid_view.queue_free()
	_grid_view = ModuleGridView.new()
	_grid_view.configure(module_grid, _CELL_SIZE)
	_canvas.set_board(_grid_view, _grid_view.content_size())
