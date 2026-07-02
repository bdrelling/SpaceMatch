class_name MatchPopups
extends RefCounted
## The match's floating-text and flying-glyph presentation: "+N combat" over a cleared match, a damage number
## over a struck portrait, and the damage glyphs that fly from the board (or an attacker) to their target. Reads
## everything it needs — the popup overlay, the board view, the portraits — through the shared [MatchContext],
## so it renders the events the rules emit without reaching the coordinator.

#region Constants

# Damage tiles fly from the match to the target portrait before the hit lands: glyph size, travel time, the
# impact pop at the end, and the head-start between successive tiles so they stream rather than stack.
const _DAMAGE_KIND: int = 6
const _FLY_TILE_PX: float = 54.0
const _FLY_DURATION: float = 0.5
const _FLY_POP: float = 0.13
const _FLY_STAGGER: float = 0.07

#endregion

#region Properties

var _ctx: MatchContext

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# How long a damage fly takes to reach its target — the delay before its number lands (see the coordinator's
# delayed portrait popup after a fly).
func fly_duration() -> float:
	return _FLY_DURATION


# The center of a board cell in the view's local pixel space (the grid is anchored at the origin).
func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * _ctx.cell_size


# A floating popup for a cleared kind: "+N <name>" for resources (damage is shown by flying tiles instead),
# colored by the tile.
func spawn_match_popup(kind: int, count: int, center_local: Vector2) -> void:
	if _ctx.popup_layer == null or _ctx.view == null:
		return
	var text: String = "%d damage" % count if kind == _DAMAGE_KIND else "+%d %s" % [count, kind_name(kind)]
	_emit_popup(_ctx.view.to_global(center_local), text, MatchTile.color_of(kind))


# A floating popup centered over a portrait — used for ability hits, which have no board cell.
func spawn_portrait_popup(portrait: Control, text: String, color: Color) -> void:
	if _ctx.popup_layer == null or not is_instance_valid(portrait):
		return
	_emit_popup(portrait.get_global_rect().get_center(), text, color)


# Same as [method spawn_portrait_popup] but after [param delay] seconds — so a damage number lands when the
# tiles that carry it reach the portrait. Bails if the board tears down before the delay elapses.
func spawn_portrait_popup_delayed(portrait: Control, text: String, color: Color, delay: float) -> void:
	if _ctx.popup_layer == null:
		return
	await _ctx.popup_layer.get_tree().create_timer(delay).timeout
	# The board can tear down during the delay, freeing the popup layer (and the portrait) — check the
	# instance is still valid before touching it, or is_inside_tree() crashes on a freed reference.
	if not is_instance_valid(_ctx.popup_layer) or not _ctx.popup_layer.is_inside_tree():
		return
	spawn_portrait_popup(portrait, text, color)


# Flings one damage-tile glyph per cleared damage cell at the struck portrait — the "the match throws its
# damage at them" beat. Purely cosmetic; the hit already landed.
func fly_damage_to_portrait(cells: Array[Vector2i], target_combatant: Combatant) -> void:
	var portrait: Control = portrait_for(target_combatant)
	if _ctx.view == null or portrait == null:
		return
	var target: Vector2 = portrait.get_global_rect().get_center()
	for i: int in cells.size():
		_fly_glyph(_ctx.view.to_global(cell_center(cells[i])), target, i * _FLY_STAGGER)


# Flings a few damage glyphs from the attacker portrait to the target — the version used when an ability
# deals the damage, since an ability has no board cells of its own.
func fly_attack_glyphs(from_combatant: Combatant, to_combatant: Combatant, count: int) -> void:
	var from_portrait: Control = portrait_for(from_combatant)
	var to_portrait: Control = portrait_for(to_combatant)
	if from_portrait == null or to_portrait == null:
		return
	var from: Vector2 = from_portrait.get_global_rect().get_center()
	var target: Vector2 = to_portrait.get_global_rect().get_center()
	for i: int in count:
		_fly_glyph(from, target, i * _FLY_STAGGER)


# The portrait belonging to a combatant (the player's on the left, the opponent's on the right).
func portrait_for(combatant: Combatant) -> PortraitPanel:
	return _ctx.opponent_portrait if _ctx.encounter != null and combatant == _ctx.encounter.opponent else _ctx.player_portrait


# A kind's display name, from the resource catalog.
func kind_name(kind: int) -> String:
	return MatchTile.name_of(kind)


func _emit_popup(global_pos: Vector2, text: String, color: Color) -> void:
	var popup := FloatingText.new()
	_ctx.popup_layer.add_child(popup)
	popup.global_position = global_pos
	popup.setup(text, color)


# Sends a single damage glyph from one screen point to another: it launches fast, holds full size across
# the trip, then pops (shrinks + fades) as it lands, and frees itself. The visible half of "dealing damage".
func _fly_glyph(from_global: Vector2, to_global: Vector2, delay: float) -> void:
	if _ctx.popup_layer == null:
		return
	var glyph := MatchTile.new()
	glyph.kind = _DAMAGE_KIND
	glyph.scale = Vector2(_FLY_TILE_PX, _FLY_TILE_PX)
	glyph.modulate.a = 0.0 if delay > 0.0 else 1.0  # staggered glyphs stay hidden until their turn
	_ctx.popup_layer.add_child(glyph)
	glyph.global_position = from_global
	var tween: Tween = glyph.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_property(glyph, "modulate:a", 1.0, 0.01)
	# Launch and travel — fast off the mark, easing in as it nears the portrait, growing a touch on the way.
	tween.tween_property(glyph, "global_position", to_global, _FLY_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glyph, "scale", Vector2(_FLY_TILE_PX, _FLY_TILE_PX) * 1.25, _FLY_DURATION).set_ease(Tween.EASE_IN)
	# Impact pop at the portrait.
	tween.tween_property(glyph, "scale", Vector2.ZERO, _FLY_POP).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(glyph, "modulate:a", 0.0, _FLY_POP)
	tween.tween_callback(glyph.queue_free)

#endregion
