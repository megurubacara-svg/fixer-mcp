SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
DASHBOARD_APP_DIR := $(ROOT_DIR)/fixer_mcp/dashboard_app
STUDIO_APP_PATH ?= /Applications/Fixer Studio.app
STUDIO_BUILD_APP ?= $(DASHBOARD_APP_DIR)/build/macos/Build/Products/Release/fixer_dashboard_app.app
STUDIO_LSREGISTER ?= /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build-studio-app

build-studio-app:
	@set -eu; \
	if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "build-studio-app requires macOS" >&2; \
		exit 1; \
	fi; \
	command -v flutter >/dev/null 2>&1 || { echo "Flutter is required to build Fixer Studio" >&2; exit 1; }; \
	test -d "$(DASHBOARD_APP_DIR)" || { echo "Dashboard app directory is missing: $(DASHBOARD_APP_DIR)" >&2; exit 1; }; \
	source_icon="$(DASHBOARD_APP_DIR)/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"; \
	test -f "$$source_icon" || { echo "Fixer Studio source icon is missing: $$source_icon" >&2; exit 1; }; \
	source_icon_hash="$$(shasum -a 256 "$$source_icon" | awk '{print $$1}')"; \
	test "$$source_icon_hash" != "6232e5815af17e25e0268b2fec7aea9e068cc92ec709e9605c2b31df4ff2a313" || { echo "Fixer Studio source icon regressed to the stock Flutter icon" >&2; exit 1; }; \
	cd "$(DASHBOARD_APP_DIR)"; \
	flutter clean; \
	flutter pub get; \
	flutter build macos --release \
		--dart-define=FIXER_STUDIO_MANAGE_BACKEND=true \
		--dart-define=FIXER_STUDIO_ROOT="$(ROOT_DIR)"; \
	test -d "$(STUDIO_BUILD_APP)" || { echo "Release app was not produced: $(STUDIO_BUILD_APP)" >&2; exit 1; }; \
	install_dir="$$(dirname "$(STUDIO_APP_PATH)")"; \
	test -d "$$install_dir" || mkdir -p "$$install_dir"; \
	if [ -e "$(STUDIO_APP_PATH)" ]; then rm -rf "$(STUDIO_APP_PATH)"; fi; \
	ditto "$(STUDIO_BUILD_APP)" "$(STUDIO_APP_PATH)"; \
	icon_path="$(STUDIO_APP_PATH)/Contents/Resources/AppIcon.icns"; \
	if [ ! -f "$$icon_path" ]; then \
		icon_source="$(DASHBOARD_APP_DIR)/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon.icns"; \
		test -f "$$icon_source" || { echo "Custom macOS icon was not packaged: $$icon_path" >&2; exit 1; }; \
		install -m 0644 "$$icon_source" "$$icon_path"; \
	fi; \
	bundle_icon="$$(/usr/bin/plutil -extract CFBundleIconFile raw -o - "$(STUDIO_APP_PATH)/Contents/Info.plist")"; \
	case "$$bundle_icon" in AppIcon|AppIcon.icns) ;; *) echo "Unexpected CFBundleIconFile: $$bundle_icon" >&2; exit 1;; esac; \
	test -s "$$icon_path"; \
	test -x "$(STUDIO_LSREGISTER)" || { echo "Launch Services registrar is missing: $(STUDIO_LSREGISTER)" >&2; exit 1; }; \
	"$(STUDIO_LSREGISTER)" -f "$(STUDIO_APP_PATH)"; \
	touch "$(STUDIO_APP_PATH)"; \
	killall Dock >/dev/null 2>&1 || true; \
	echo "Fixer Studio installed and registered: $(STUDIO_APP_PATH)"
