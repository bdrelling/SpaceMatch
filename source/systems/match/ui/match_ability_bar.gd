class_name MatchAbilityBar
extends RefCounted
## The ability buttons under the board: builds one button per player ability (its cost tiles over its name),
## repaints them as affordability and the turn change, plays out the presentation events an ability's effects
## emit, and carries the cost/AI math the coordinator and the opponent solver read. The instance half paints the
## bar through the shared [MatchContext]; the cost math is static — pure functions the coordinator's flow methods
## and the AI pick call with the values they hold.

#region Constants

const _DAMAGE_KIND: int = 6

#endregion

#region Properties

var _ctx: MatchContext

# The scene's ability buttons, left to right, index-aligned with [member _player_abilities].
var _ability_buttons: Array[Button] = []
# The player starship's abilities the buttons map to, captured when the bar is wired. Abilities are the
# starship's, not the match's.
var _player_abilities: Array[Ability] = []

#endregion

#region Methods


func _init(ctx: MatchContext) -> void:
	_ctx = ctx


# Wires the scene's buttons to [param abilities], left to right, binding each press to [param on_pressed].
# Extra buttons (more than there are abilities) hide; the caller runs the affordability pass after.
func setup_abilities(abilities: Array[Ability], on_pressed: Callable) -> void:
	_ability_buttons.clear()
	_player_abilities = abilities
	var buttons: Array[Node] = _ctx.actions.get_children()
	for i: int in buttons.size():
		var button := buttons[i] as Button
		if button == null:
			continue
		if i < _player_abilities.size():
			configure_ability_button(button, _player_abilities[i])
			button.pressed.connect(on_pressed.bind(_player_abilities[i]))
			_ability_buttons.append(button)
		else:
			button.visible = false


# Lays out one ability button: the cost tile and its count over the ability's name. Built in code so the
# button stays data-driven off the rules. The content ignores the mouse so the whole button stays clickable.
func configure_ability_button(button: Button, ability: Ability) -> void:
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.clip_contents = true
	button.tooltip_text = ("%s — %s (%s)" % [str(ability.name), ability.describe(), cost_text(ability)])

	# A full-width padded column, so a long ability name can wrap to the button width rather than clip.
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 6)
	pad.add_theme_constant_override("margin_right", 6)
	button.add_child(pad)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	pad.add_child(column)

	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 6)
	column.add_child(cost_row)

	if ability.costs.is_empty():
		# A free ability still gets a label so the button isn't blank above its name.
		var free_label := Label.new()
		free_label.text = "Free"
		free_label.add_theme_font_size_override("font_size", 26)
		cost_row.add_child(free_label)
	else:
		# One tile + count per cost, joined with a "+" so a multi-tile price reads at a glance.
		for i: int in ability.costs.size():
			var cost: ResourceCost = ability.costs[i]
			if i > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.add_theme_font_size_override("font_size", 22)
				cost_row.add_child(plus)
			var icon := MatchTileIcon.new()
			var cost_kind: int = tile_kind_of(cost.resource)
			icon.kind = cost_kind if cost_kind >= 0 else 0
			icon.custom_minimum_size = Vector2(30, 30)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_row.add_child(icon)
			var cost_label := Label.new()
			cost_label.text = str(cost.amount)
			cost_label.add_theme_font_size_override("font_size", 26)
			cost_row.add_child(cost_label)

	var name_label := Label.new()
	name_label.text = str(ability.name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.70, 0.75, 0.88))
	column.add_child(name_label)


# Plays the presentation events an ability's effects emitted (see [member MatchResolutionContext.visuals]) — the
# portrait popups, health refresh and attack glyphs. They're read as data so the actions stay host-agnostic; a
# new visual kind adds a branch here.
func play_visuals(context: MatchResolutionContext) -> void:
	if context == null:
		return
	for event: Dictionary in context.visuals:
		var target: Combatant = event.get("target")
		var kind: StringName = event.get("kind", &"")
		var amount: int = event.get("amount", 0)
		match kind:
			&"shield":
				_ctx.readouts.refresh_health()
				_ctx.popups.spawn_portrait_popup(_ctx.popups.portrait_for(target), "+%d shield" % amount, MatchTile.color_of(3))
			&"dodge":
				_ctx.popups.spawn_portrait_popup(_ctx.popups.portrait_for(target), "Evading", MatchTile.color_of(1))
			&"drain":
				_ctx.popups.spawn_portrait_popup(_ctx.popups.portrait_for(target), "Drained", MatchTile.color_of(2))
			&"damage_buff":
				_ctx.popups.spawn_portrait_popup(_ctx.popups.portrait_for(target), "Damage +%d" % amount, MatchTile.color_of(0))
			&"disable":
				_ctx.popups.spawn_portrait_popup(_ctx.popups.portrait_for(target), "Disabled", MatchTile.color_of(2))
			&"attack":
				var result: int = event.get("result", 0)
				var source: Combatant = event.get("source")
				_ctx.readouts.refresh_health()
				_ctx.popups.fly_attack_glyphs(source, target, clampi(amount, 1, 5))
				_ctx.popups.spawn_portrait_popup_delayed(
					_ctx.popups.portrait_for(target), damage_text(result, amount), MatchTile.color_of(_DAMAGE_KIND), _ctx.popups.fly_duration()
				)


# Repaints each ability button from the player's tiles and whose turn it is: usable ones (affordable, on the
# player's turn) light up in the tile color and stay pressable; the rest are disabled and dimmed. Abilities
# end the turn, so they're only usable on the player's own turn. A no-op until the buttons are wired.
func refresh_abilities(can_act: bool) -> void:
	for i: int in _ability_buttons.size():
		var ability: Ability = _player_abilities[i]
		var usable: bool = can_act and affordable(_ctx.encounter, _ctx.encounter.player if _ctx.encounter != null else null, ability)
		var button: Button = _ability_buttons[i]
		button.disabled = not usable
		var primary: EntityResource = primary_cost_resource(ability)
		var tile_kind: int = tile_kind_of(primary)
		style_ability_button(button, tile_kind, usable)


# Swaps the button's box for the affordable look (a bright border in the tile color) or the idle look
# (dim, faint border). Disabled buttons show the idle box; affordable ones show the lit box.
func style_ability_button(button: Button, tile_kind: int, is_affordable: bool) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	if is_affordable:
		# A free ability (no cost kind) lights up neutral white rather than a tile color.
		var tile_color: Color = MatchTile.color_of(tile_kind) if tile_kind >= 0 else Color.WHITE
		style.bg_color = Color(tile_color.r, tile_color.g, tile_color.b, 0.22)
		style.set_border_width_all(3)
		style.border_color = tile_color
	else:
		style.bg_color = Color(0.12, 0.13, 0.21, 0.6)
		style.set_border_width_all(1)
		style.border_color = Color(1, 1, 1, 0.08)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, style)


# Whether [param combatant] holds enough matched tiles to pay every one of [param ability]'s costs — checked
# through the engine's ResourceEngine. A cost-less (free) ability is always affordable.
static func affordable(encounter: EncounterState, combatant: Combatant, ability: Ability) -> bool:
	if encounter == null:
		return false
	if combatant == null:
		return false
	return ResourceEngine.can_afford(combatant, ability.costs)


# The most expensive affordable ability for [param combatant] among [param abilities] (summed cost as an impact
# proxy), or null if none is affordable — the AI opponent's ability pick. A dodge already armed is skipped, so
# the opponent spends its turn attacking (or arming something else) instead of refreshing a permanent dodge.
static func best_affordable_ability(encounter: EncounterState, abilities: Array[Ability], combatant: Combatant) -> Ability:
	var best: Ability = null
	var best_cost: int = -1
	for ability: Ability in abilities:
		if arms_dodge(ability) and encounter != null and encounter.dodge_of(combatant):
			continue
		if not affordable(encounter, combatant, ability):
			continue
		var total: int = total_cost(ability)
		if best == null or total > best_cost:
			best = ability
			best_cost = total
	return best


# Whether [param ability] arms a dodge — keeps the AI from re-casting a dodge it already has.
static func arms_dodge(ability: Ability) -> bool:
	for effect: Effect in ability.effects:
		if effect != null and effect.action is DodgeAction:
			return true
	return false


# The summed tile cost of [param ability] — the AI's crude impact proxy when picking what to play.
static func total_cost(ability: Ability) -> int:
	var total: int = 0
	for cost: ResourceCost in ability.costs:
		if cost != null:
			total += cost.amount
	return total


# The resource of [param ability]'s first cost (for the button's accent color), or null when the ability is free.
static func primary_cost_resource(ability: Ability) -> EntityResource:
	return ability.costs[0].resource if not ability.costs.is_empty() else null


# The board tile kind whose glyph represents [param resource] — matched by the shared name (the combat tile and
# the combat resource share a name), so a cost draws its tile icon. -1 when the resource maps to no tile.
static func tile_kind_of(resource: EntityResource) -> int:
	if resource == null:
		return -1
	var tile: Tile = Catalogs.tiles.for_name(resource.name)
	return tile.kind if tile != null else -1


# A one-line price for the tooltip — "10 combat + 12 science", or "Free" when the ability has no costs.
static func cost_text(ability: Ability) -> String:
	if ability.costs.is_empty():
		return "Free"
	var parts: Array[String] = []
	for cost: ResourceCost in ability.costs:
		parts.append("%d %s" % [cost.amount, cost_name(cost)])
	return " + ".join(parts)


# The display name of a cost's resource (the tile name), or "" when the cost names no resource.
static func cost_name(cost: ResourceCost) -> String:
	if cost == null or cost.resource == null:
		return ""
	return MatchTile.name_of(tile_kind_of(cost.resource))


# The popup text for an attack: "Dodged!" when the target evaded it (result < 0), else the damage dealt.
static func damage_text(result: int, dealt: int) -> String:
	return "Dodged!" if result < 0 else "%d damage" % dealt

#endregion
