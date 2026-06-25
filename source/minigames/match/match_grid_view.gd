class_name MatchGridView
extends GridView
## The match board's grid view, rendered in SpaceMatch (not the generic grid_system addon) so the
## encounter owns its backing's look. Extends [GridView] — which draws only the structural cell
## lattice — and fills a dark backing behind it. Drawn from the board's own origin, so the backing
## hugs the square grid at any fit scale the [BoardCanvas] frames it to.

const _BACKDROP := Color(0.16, 0.21, 0.34)
const _INSET := 4.0

func _draw() -> void:
	var size := content_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2(-_INSET, -_INSET), size + Vector2(_INSET * 2.0, _INSET * 2.0)), _BACKDROP)
	super._draw()
