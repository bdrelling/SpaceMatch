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

.PHONY: help setup play play-tablet play-phone playtest test test-debug export-macos export-ios export-android export-linux export-web deploy-macos deploy-ios-store deploy-ios-sim deploy-iphone deploy-ipad deploy-android deploy-linux deploy-web release-macos release-ios release-android release-linux release-web clean

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
	@echo "SETUP:"
	@grep -E '^setup:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
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

# Desktop preview window. `--resolution` opens it at a device-faithful size so the game boots straight
# into the right shape; `--device`/`--orientation` are read by main.gd, which sizes the window from
# armory's DeviceUtils (the source of truth). The px below DUPLICATE DeviceUtils.DEVICE_RESOLUTIONS ×
# the device's preview scale — when those change, update these to match.
#   iPhone 17 Pro 402×874 pt → 724×1573 (× 1.8)    iPad Pro 11" 834×1194 pt → 1112×1592 (× 4/3)
DEVICE_WINDOW_MODE        ?= tablet
DEVICE_WINDOW_ORIENTATION ?= portrait

PHONE_WINDOW_WIDTH   := 724
PHONE_WINDOW_HEIGHT  := 1573
TABLET_WINDOW_WIDTH  := 1112
TABLET_WINDOW_HEIGHT := 1592

ifeq ($(DEVICE_WINDOW_MODE),phone)
  _DEVICE_W := $(PHONE_WINDOW_WIDTH)
  _DEVICE_H := $(PHONE_WINDOW_HEIGHT)
else ifeq ($(DEVICE_WINDOW_MODE),tablet)
  _DEVICE_W := $(TABLET_WINDOW_WIDTH)
  _DEVICE_H := $(TABLET_WINDOW_HEIGHT)
else
  $(error DEVICE_WINDOW_MODE must be 'phone' or 'tablet' (got '$(DEVICE_WINDOW_MODE)'))
endif

ifeq ($(DEVICE_WINDOW_ORIENTATION),portrait)
  _WINDOW_W := $(_DEVICE_W)
  _WINDOW_H := $(_DEVICE_H)
else ifeq ($(DEVICE_WINDOW_ORIENTATION),landscape)
  _WINDOW_W := $(_DEVICE_H)
  _WINDOW_H := $(_DEVICE_W)
else
  $(error DEVICE_WINDOW_ORIENTATION must be 'portrait' or 'landscape' (got '$(DEVICE_WINDOW_ORIENTATION)'))
endif

play: ## Launch the game in a device window (DEVICE_WINDOW_MODE=phone|tablet, default tablet).
	@./scripts/play.sh -w --resolution $(_WINDOW_W)x$(_WINDOW_H) -- --device=$(DEVICE_WINDOW_MODE) --orientation=$(DEVICE_WINDOW_ORIENTATION)

play-tablet: ## Launch as a tablet (portrait).
	@$(MAKE) play DEVICE_WINDOW_MODE=tablet

play-phone: ## Launch as a phone (portrait).
	@$(MAKE) play DEVICE_WINDOW_MODE=phone

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

setup: ## Link docs/obsidian to $OBSIDIAN_VAULT
	@if [ -z "$$OBSIDIAN_VAULT" ]; then \
		echo "ERROR: OBSIDIAN_VAULT is not set. Set it in .env.local or your shell."; \
		exit 1; \
	fi
	@target=`echo "$$OBSIDIAN_VAULT" | sed "s|^ *~|$$HOME|; s|^ *||"`; \
		ln -sfn "$$target" docs/obsidian; \
		echo "Linked docs/obsidian -> $$target"

clean: ## Clean build artifacts
	@rm -rf reports/

# =============================================================================
# CLAUDE CODE
# =============================================================================

claude-agents: ## Launch Claude Code agents view, keeping the Mac awake
	caffeinate -i claude agents
	
claude-rc: ## Launch Claude Code in remote-control mode, keeping the Mac awake
	caffeinate -i claude remote-control
