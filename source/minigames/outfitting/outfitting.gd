class_name OutfittingMinigame
extends Minigame
## Outfitting: shows the starship's module grid. The module grid is the player's loadout; rearranging
## modules and buying new ones (from a shop) come later. For now this stage simply renders the grid.

const _CELL_SIZE: float = 96.0

@onready var _canvas: BoardCanvas = %BoardCanvas

var _grid_view: ModuleGridView

## Mounts the starship's module grid as the board. Called by [MinigameScreen] when the page mounts.
func bind_session(session: GameSession) -> void:
	if session == null or session.state == null:
		return
	var module_grid: ModuleGrid = session.state.starship.module_grid
	if module_grid == null:
		return
	_grid_view = ModuleGridView.new()
	_grid_view.configure(module_grid, _CELL_SIZE)
	_canvas.set_board(_grid_view, _grid_view.content_size())
