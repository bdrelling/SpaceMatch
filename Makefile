# =============================================================================
# ENVIRONMENT
# =============================================================================

# Load environment variables from .env files
-include .env
-include .env.local

# Pull in claudot's targets so `make claudot-up` etc. work from this root.
-include claudot/Makefile

# =============================================================================
# USAGE
# =============================================================================

.PHONY: help play play-tablet play-phone playtest test test-debug export-macos export-ios export-android export-linux export-web deploy-macos deploy-ios-store deploy-ios-sim deploy-iphone deploy-ipad deploy-android deploy-linux deploy-web release-macos release-ios release-android release-linux release-web clean

help: ## Show available commands
	@echo "MACOS:"
	@grep -E '^(export-macos|deploy-macos|release-macos):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "IOS:"
	@grep -E '^(export-ios|deploy-ios-store|deploy-ios-sim|deploy-iphone|deploy-ipad|release-ios):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "ANDROID:"
	@grep -E '^(export-android|deploy-android|release-android):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "LINUX:"
	@grep -E '^(export-linux|deploy-linux|release-linux):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "WEB:"
	@grep -E '^(export-web|deploy-web|release-web):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "DEV:"
	@grep -E '^(play[a-zA-Z-]*|playtest):.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "TESTING:"
	@grep -E '^test[a-zA-Z_-]*:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "CLAUDOT:"
	@grep -hE '^claudot-[a-zA-Z_-]*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "CLEANUP:"
	@grep -E '^clean:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# MACOS
# =============================================================================

export-macos: ## Export macOS build
	@./scripts/armory export macOS/Debug

deploy-macos: ## Deploy macOS build
	@./scripts/armory deploy macos

release-macos: export-macos deploy-macos ## Export and deploy macOS build

# =============================================================================
# IOS
# =============================================================================

export-ios: ## Export iOS build
	@./scripts/armory export iOS release

deploy-ios-store: ## Build and upload iOS to App Store Connect
	@./scripts/armory deploy ios appstore

deploy-ios-sim: ## Build and run iOS on the simulator
	@./scripts/armory deploy ios simulator

deploy-iphone: ## Build and run on a connected iPhone
	@./scripts/armory deploy ios iphone

deploy-ipad: ## Build and run on a connected iPad
	@./scripts/armory deploy ios ipad

release-ios: export-ios deploy-ios-store ## Export and deploy iOS build

# =============================================================================
# ANDROID
# =============================================================================

export-android: ## Export Android build
	@./scripts/armory export Android debug

deploy-android: ## Deploy Android build
	@./scripts/armory deploy android

release-android: export-android deploy-android ## Export and deploy Android build

# =============================================================================
# LINUX
# =============================================================================

export-linux: ## Export Linux build
	@./scripts/armory export Linux

deploy-linux: ## Deploy Linux build
	@./scripts/armory deploy linux

release-linux: export-linux deploy-linux ## Export and deploy Linux build

# =============================================================================
# WEB
# =============================================================================

export-web: ## Export web build
	@./scripts/armory export Web

deploy-web: ## Deploy web build to itch.io
	@./scripts/armory deploy web

release-web: export-web deploy-web ## Export and deploy web build

# =============================================================================
# DEV
# =============================================================================

# Desktop default is a tablet in portrait — the form factor we design against. Orientation still
# switches: append `-- --orientation=landscape` to override. --resolution sets the window size AND
# aspect; --orientation is read by main.gd.
# iPad Pro 11" ratio ≈ 0.698 (1117×1600); iPhone 15/16/17 ratio ≈ 0.461 (738×1600).
play: ## Launch the game as a tablet (portrait, desktop). Pass extra godot args after `--`.
	@./scripts/play.sh -w --resolution 1117x1600 -- --orientation=portrait

play-tablet: play ## Alias for `play` — tablet, portrait.

play-phone: ## Launch the game as a phone (portrait, desktop).
	@./scripts/play.sh -w --resolution 738x1600 -- --orientation=portrait

playtest: ## Run the game with screenshot capture. Pass extra args after `--`.
	@./scripts/playtest.sh $(ARGS)

# =============================================================================
# TESTING
# =============================================================================

test: ## Run all tests
	@./scripts/test.sh

test-debug: ## Run tests with debug output
	@DEBUG=true ./scripts/test.sh

# =============================================================================
# CLEANUP
# =============================================================================

clean: ## Clean build artifacts
	@rm -rf reports/

# =============================================================================
# CLAUDE CODE
# =============================================================================

claude-agents: ## Launch Claude Code agents view, keeping the Mac awake
	caffeinate -i claude agents
	
claude-rc: ## Launch Claude Code in remote-control mode, keeping the Mac awake
	caffeinate -i claude remote-control
