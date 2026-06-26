class_name Wallet
extends Node
## The player's currency entity — the [Node] that represents a [WalletState] in the game hierarchy (a child
## of [Game]). Holds the state the HUD reads and abilities spend. Not blueprinted (currency has no authored
## template), so [method create] is a plain constructor wrapping a fresh or supplied [WalletState].

const SCENE_PATH := "res://entities/wallet/wallet.tscn"
const SCENE: PackedScene = preload(SCENE_PATH)

@export var state: WalletState

## A wallet node wrapping [param wallet_state] (a fresh empty [WalletState] when null).
static func create(wallet_state: WalletState = null) -> Wallet:
	var wallet: Wallet = SCENE.instantiate()
	wallet.state = wallet_state if wallet_state != null else WalletState.new()
	return wallet
