* Settings
  * Time Scale
  * Verbose Logging
  * Skip Intro
  * Quick Match
  * Starship
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
      * Minimum
      * Maximum
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
      * Type
        * Buff
        * Debuff
      * Maximum Stacks
      * Stacking
        * Stack
        * Replace
        * Keep Highest
      * Decay
        * Timing
        * Threshold
        * Trigger
    * Modifiers
      * Adjustment
      * Amount
    * Effects
    * Transforms
* Building Blocks
  * Adjustments
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Stat
      * Applies To
        * Current Value
      * Operation
        * Add
        * Multiply
  * Effects
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Target
      * Action
    * Conditions
      * Kind
        * Stat Threshold
          * Target
          * Stat
          * Comparison
            * Less Than
            * Equal To
            * Greater Than
          * Value
        * Compare Stats
          * Target
          * Other
          * Stat
          * Comparison
            * Less Than
            * Equal To
            * Greater Than
        * Has Status
          * Target
          * Status
        * Chance
          * Chance
        * And
          * Conditions
        * Or
          * Conditions
        * Not
          * Condition
    * Targets
      * Kind
        * Self
        * Opponent
        * Instigator
        * Chosen
        * Chosen Ally
        * All Entities
        * All Allies
        * All Opponents
        * Random Ally
        * Random Opponent
        * Highest Stat
          * From
          * Stat
        * Lowest Stat
          * From
          * Stat
        * Sides
          * Radius
    * Actions
      * Add Button? YES
      * Fields
        * ID
        * Filename
        * Name
        * Description
      * Kind
        * Attack
          * Amount
        * Shield
          * Amount
        * Dodge
        * Drain
          * Amount
        * Damage Buff
          * Amount
        * Disable
          * Turns
        * Apply Status
          * Status
          * Count
        * Remove Status
          * Status
        * Remove By Type
          * Type
            * Buff
            * Debuff
        * Modify Stat
          * Stat
          * Amount
          * Tag
          * Subtracts
          * Minimum
        * Set Stat
          * Stat
          * Amount
        * Drain Resource
          * Resources
          * Amount
  * Amount
    * Kind
      * Constant
        * Value
      * Current Stat
        * Stat
      * Maximum Stat
        * Stat
      * Missing Stat
        * Stat
      * Random
        * Minimum
        * Maximum
      * Math
        * Left
        * Operation
          * Add
          * Subtract
          * Multiply
        * Right
      * Modification
      * Status Count
        * Status
      * Currency
        * Currency
  * Transforms
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Kind
        * Absorb
        * Clamp
        * Flat Mitigation
        * Multiplier
* Content
  * Abilities
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Icon
    * Costs
      * Resource
      * Amount
    * Effects
  * Modules
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Texture
      * Section
        * Weapons
        * Defense
        * Propulsion
        * Systems
    * Modifiers
      * Adjustment
      * Amount
  * Loadouts
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Shape
    * Modules
  * Starships
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Texture
      * Loadout
      * Ruleset
* Config
  * Rules
    * Add Button? NO
    * Templates
      * Scoring
        * Score
      * Offset Scoring
        * Offset
      * Action Budget
        * Actions
        * Ability Turn Cost
      * Resource Capacity
        * Maximum
      * Extra Turn
        * Minimum
      * Tile Spawn
        * Tile
        * Weight
      * Tile Match
        * Tile
        * Reward
      * Damage
        * Tile
        * Damage
      * Alloy Grant
        * Tile
        * Amount
      * Warp
        * Tile
        * Charge
      * Board Fill
        * Direction
          * Top
          * Bottom
      * Reload Split
      * Territory
        * Player Color
        * Opponent Color
      * Selection
        * Mode
          * Swap
          * Slide
          * Trace
          * Teleport
        * Allow Diagonal
        * Minimum Run
        * Match Required
        * Teleport Range
  * Rulesets
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
    * Rules
    * Rulesets
  * Match Configs
    * Add Button? YES
    * Fields
      * ID
      * Filename
      * Name
      * Description
      * Ruleset
      * Columns
      * Rows
