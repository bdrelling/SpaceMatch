@tool
class_name Palette
extends Resource
## A semantic color palette resource. Every color used in the game lives here,
## grouped to mirror the Figma design-system structure.

@export_group("Board")
@export var board_cell_background: Color
@export var board_background: Color
@export var board_border: Color
@export var board_border_highlight: Color

@export_group("Background")
@export var background: Color
@export var background_border_primary: Color
@export var background_border_secondary: Color

@export_group("Sidebar")
@export var sidebar_card_background: Color
@export var sidebar_card_border: Color
@export var sidebar_debug_card_background: Color
@export var sidebar_debug_card_border: Color
@export var sidebar_debug_card_button_background: Color
@export var sidebar_slot_background: Color
@export var sidebar_slot_border: Color
@export var sidebar_text: Color
@export var sidebar_text_value: Color

@export_group("Status Bar")
@export var status_bar_border: Color
@export var status_bar_condition_empty: Color
@export var status_bar_condition_damaged: Color
@export var status_bar_condition_critical: Color
@export var status_bar_condition_full: Color
@export_subgroup("Text")
@export var status_bar_text_body: Color
@export var status_bar_text_heading_primary: Color
@export var status_bar_text_heading_secondary: Color
@export var status_bar_text_value: Color
@export var status_bar_text_value_highlighted: Color

@export_group("Notifications")
@export var notification_background: Color
@export var notification_border: Color
@export var notification_text: Color

@export_group("Palette")
@export var palette_board_object_text: Color
@export var palette_gunk_green: Color
@export var palette_scrap_yellow: Color
@export var palette_starship_part_blue: Color
@export var palette_starship_part_border_blue: Color
@export var palette_goo_pink: Color

@export_group("HUD")
@export var hud_text: Color
@export var hud_text_heading: Color
@export var hud_text_dimmed: Color
@export var hud_minimap_background: Color
@export var hud_minimap_border: Color
@export var hud_stamina_full: Color
@export var hud_stamina_low: Color
@export var hud_stamina_empty: Color
@export var hud_stamina_background: Color

@export_group("Unimplemented")
## Slots hoisted from hardcoded literals during the color-unification pass.
## No designer-approved values yet — current colors are the original placeholders.
@export_subgroup("Status Message")
@export var status_neutral_background: Color
@export var status_ok_background: Color
@export var status_error_background: Color
@export var status_win_background: Color
@export var status_neutral_foreground: Color
@export var status_ok_foreground: Color
@export var status_error_foreground: Color
@export var status_win_foreground: Color
@export_subgroup("Grid — Hose")
@export var hose: Color
@export var hose_dark: Color
@export_subgroup("Menu")
## Full-screen tint behind the pause menu / config panel modals.
@export var menu_backdrop: Color
@export var menu_card_background: Color
@export var menu_card_border: Color
@export var menu_label_dimmed: Color
@export var menu_label_very_dimmed: Color
@export_subgroup("Effects")
@export var cell_flash: Color
@export_subgroup("Match3 Playground")
@export var match3_square: Color
@export var match3_circle: Color
@export var match3_triangle: Color
@export var match3_star: Color
@export var match3_swap_highlight: Color
@export_subgroup("Minesweeper Playground")
@export var minesweeper_grid_background: Color
@export var minesweeper_cell_hidden: Color
@export var minesweeper_cell_hidden_border: Color
@export var minesweeper_cell_revealed: Color
@export var minesweeper_cell_revealed_border: Color
@export var minesweeper_mine: Color
@export var minesweeper_mine_trigger: Color
@export var minesweeper_mine_glyph: Color
@export var minesweeper_flag: Color
@export var minesweeper_flag_pole: Color
@export var minesweeper_count_1: Color
@export var minesweeper_count_2: Color
@export var minesweeper_count_3: Color
@export var minesweeper_count_4: Color
@export var minesweeper_count_5: Color
@export var minesweeper_count_6: Color
@export var minesweeper_count_7: Color
@export var minesweeper_count_8: Color
@export_subgroup("Pipes Playground")
@export var pipes_grid_background: Color
@export var pipes_cell_background: Color
@export var pipes_cell_border: Color
@export var pipes_segment: Color
@export var pipes_fluid: Color
@export var pipes_source_background: Color
@export var pipes_source_glyph: Color
@export var pipes_sink_background: Color
@export var pipes_sink_glyph: Color

## Shared panel surface used by the pause menu and config panel modals.
## Built from the menu_card_* palette entries so both modals stay in sync.
func build_menu_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = menu_card_background
	style.border_color = menu_card_border
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	style.anti_aliasing = false
	return style
