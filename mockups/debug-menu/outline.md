# Debug Editor — Schema Outline

Word-map-ready outline of the debug editor hierarchy. Schema only — no instance data. Enums list their values; `→` marks a reference picked from another catalog; `(list)` marks a repeatable owned section.

* Debug
  * Settings
    * Time Scale
    * Verbose Logging
    * Skip Intro
    * Quick Match → Match Config
    * Starship → Starship
  * Primitives
    * Resources
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Color
        * Special
    * Tiles
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Color
        * Texture
        * Special
    * Stats
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Hidden
        * Minimum (number, or None)
        * Maximum (number, or None)
        * Default
    * Statuses
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Symbol
        * Color
        * Type (enum: Buff, Debuff)
        * Maximum Stacks
        * Stacking (enum: Stack, Replace, Keep Highest)
        * Decay (enum: Timing, Threshold, Trigger)
      * Modifiers (list)
        * Adjustment → Adjustment
        * Amount (see Amount)
      * Effects (list) → Effect
      * Transforms (list) → Transform
  * Building Blocks
    * Adjustments
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Stat → Stat
        * Applies To (enum: Current Value, … TBD)
        * Operation (enum: Add, Multiply)
    * Effects
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Target (see Target)
        * Action → Action
      * Conditions (list — see Condition)
      * Target (kind vocabulary — view-only catalog)
        * Kind (enum: Self, Opponent, Instigator, Chosen, Chosen Ally, All Entities, All Allies, All Opponents, Random Ally, Random Opponent, Highest Stat, Lowest Stat, Sides)
        * Highest Stat / Lowest Stat parameters
          * From (Target)
          * Stat → Stat
        * Sides parameters
          * Radius
      * Actions
        * Add Button? YES
        * Fields
          * ID
          * Filename
          * Name
          * Description
          * Kind (enum: Attack, Shield, Dodge, Drain, Damage Buff, Disable, Apply Status, Remove Status, Remove By Type, Modify Stat, Set Stat, Drain Resource)
          * Stat → Stat (stat kinds only)
          * Status → Status (status kinds only)
          * Amount (see Amount)
      * Conditions (kind vocabulary — view-only catalog; instances owned by effects)
        * Kind (enum: Stat Threshold, Compare Stats, Has Status, Chance, And, Or, Not)
        * Stat Threshold parameters
          * Target (Target)
          * Stat → Stat
          * Comparison (enum: Less Than, Equal To, Greater Than)
          * Value (Amount)
        * Compare Stats parameters
          * Target (Target)
          * Other (Target)
          * Stat → Stat
          * Comparison (enum: Less Than, Equal To, Greater Than)
        * Has Status parameters
          * Target (Target)
          * Status → Status
        * Chance parameters
          * Chance (percent)
        * And / Or parameters
          * Conditions (list, nested)
        * Not parameters
          * Condition (nested)
    * Amount (shared numeric building block — owned inline wherever used)
      * Kind (enum: Constant, Current Stat, Maximum Stat, Missing Stat, Random, Math, Modification, Status Count, Currency)
      * Constant parameters
        * Value
      * Current Stat / Maximum Stat / Missing Stat parameters
        * Stat → Stat
      * Random parameters
        * Minimum
        * Maximum
      * Math parameters
        * Left (Amount, nested)
        * Operation (enum: Add, Subtract, Multiply)
        * Right (Amount, nested)
      * Status Count parameters
        * Status → Status
      * Currency parameters
        * Currency → Resource
    * Transforms
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Kind (enum: Absorb, Clamp, Flat Mitigation, Multiplier)
  * Content
    * Abilities
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Icon
      * Costs (list)
        * Resource → Resource
        * Amount
      * Effects (list) → Effect
    * Modules
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Texture
        * Section (enum: Weapons, Defense, Propulsion, Systems — temporary grouping)
      * Modifiers (list)
        * Adjustment → Adjustment
        * Amount (see Amount)
    * Loadouts
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Shape (grid of sockets, not necessarily rectangular)
      * Modules (list) → Module
    * Starships
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Texture
        * Loadout → Loadout
        * Ruleset → Ruleset
  * Config
    * Rules (templates — code-defined, view-only)
      * Add Button? NO (instances are created inside rulesets)
      * Template page fields
        * Name
        * Description (raw, with {parameter} tokens)
        * Example (description with values substituted)
        * Parameters (per template, below)
      * Scoring parameters
        * Score (Amount)
      * Offset Scoring parameters
        * Offset (Amount)
      * Action Budget parameters
        * Actions (Amount)
        * Ability Turn Cost (Amount)
      * Resource Capacity parameters
        * Maximum (Amount)
      * Extra Turn parameters
        * Minimum (Amount)
      * Tile Spawn parameters
        * Tile → Tile
        * Weight (Amount)
      * Tile Match parameters
        * Tile → Tile
        * Reward → Resource
      * Damage parameters
        * Tile → Tile
        * Damage (Amount)
      * Alloy Grant parameters
        * Tile → Tile
        * Amount (Amount)
      * Warp parameters
        * Tile → Tile
        * Charge (Amount)
      * Board Fill parameters
        * Direction (enum: Top, Bottom)
      * Reload Split parameters
        * (none)
      * Territory parameters
        * Player Color
        * Opponent Color
      * Selection parameters
        * Mode (enum: Swap, Slide, Trace, Teleport)
        * Allow Diagonal
        * Minimum Run
        * Match Required
        * Teleport Range
    * Rulesets
      * Add Button? YES
      * Catalog sections (derived from usage: Match Configs, Starships, Nested, Unused)
      * Fields
        * ID
        * Filename
        * Name
        * Description
      * Rules (list — rule instances: a template with parameter values filled in)
      * Rulesets (list, nested) → Ruleset
    * Match Configs
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
        * Ruleset → Ruleset
        * Columns
        * Rows
