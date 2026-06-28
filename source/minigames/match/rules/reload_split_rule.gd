class_name ReloadSplitRule
extends Rule
## Splits a dead board's tiles between both combatants as resources when the board reloads — each side banks
## floor(half) of every stat kind (the odd tile discarded), so a stalemate still pays out instead of vanishing.
## A composable rule: present + enabled = split on; drop it and a reload simply pours a fresh board. The rule
## owns the share computation ([method shares]); the host applies it (stat kinds to both tallies, scrap to the
## player's wallet) since which kind banks where is the host's economy.

func _init() -> void:
	rule_name = &"reload_split"

## Each combatant's share from [param board]: floor(count / 2) for every kind present (the odd tile discarded),
## as kind -> amount. Reads the generic `state["kind"]` so it needs no host tile type. The host decides what a
## kind means (stat tiles bank to both ships, scrap to the player; damage and warp aren't bankable).
func shares(board: GridState) -> Dictionary:
	var result: Dictionary = {}
	if board == null:
		return result
	for y: int in board.height:
		for x: int in board.width:
			var object: GridObjectState = board.get_object_at(0, x, y)
			var kind: int = object.state.get("kind", -1) if object != null else -1
			if kind >= 0:
				result[kind] = result.get(kind, 0) + 1
	for kind: int in result:
		result[kind] = result[kind] / 2  # floor; the odd leftover tile is discarded
	return result
