class_name AbilityResource
extends EntityResource
## A spendable resource an ability costs — the game's "mana" ([EntityResource]) pools: energy, ammo, a tile
## economy. Its own subtype so ability costs and the resources a match banks read as abilities' currency, distinct
## from a wallet's currency or an inventory item. Adds nothing over [EntityResource] but the semantics.
