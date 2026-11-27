# Build, install and launch the Pendant app from the command line, without opening Xcode.
# The device is the first paired iPhone unless DEVICE=<udid> is given.

BUNDLE_ID := dev.esse.pendant
DERIVED := .derived
APP := $(DERIVED)/Build/Products/Debug-iphoneos/Pendant.app
# Build number: the commits on the branch, so each install carries its own and points to a commit.
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
SOURCES := Pendant Shared PendantWidgets PendantKit/Sources PendantKit/Tests PendantKit/Package.swift
DEVICE ?= $(shell xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | \
	python3 -I -c "import json,sys; d=json.load(sys.stdin)['result']['devices']; \
	print(next((x['hardwareProperties']['udid'] for x in d if x['hardwareProperties'].get('reality')=='physical' \
	and x['connectionProperties'].get('pairingState')=='paired' and x['connectionProperties'].get('tunnelState')!='unavailable'),''))" 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help project build install run test lint format check strings credentials logs devices clean \
	sim screens icon

help: ## List the commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

project: Local.xcconfig ## Generate Pendant.xcodeproj from project.yml
	xcodegen generate -q

Local.xcconfig:
	cp Local.xcconfig.example Local.xcconfig
	@echo "Set DEVELOPMENT_TEAM in app/Local.xcconfig and run again." && exit 1

build: project ## Build and sign for the connected iPhone
	@test -n "$(DEVICE)" || (echo "No iPhone connected" && exit 1)
	xcodebuild -project Pendant.xcodeproj -scheme Pendant -destination 'id=$(DEVICE)' \
		-derivedDataPath $(DERIVED) -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
		CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) -quiet build
	python3 ../scripts/catalogs.py sync $(DERIVED)

install: build ## Install on the iPhone
	xcrun devicectl device install app --device $(DEVICE) $(APP)

run: install ## Install and launch on the iPhone
	xcrun devicectl device process launch --device $(DEVICE) $(BUNDLE_ID)

test: ## Test the PendantKit package, no iPhone needed
	cd PendantKit && swift test

lint: ## Check the formatting, the prose language and the Italian of the catalogs (docs/CONVENTIONS.md#language)
	swift format lint --strict -r $(SOURCES)
	cd .. && python3 scripts/check-prose.py
	python3 ../scripts/catalogs.py check

format: ## Format the Swift code
	swift format -i -r $(SOURCES)

check: lint test build ## Full round: formatting, tests, build for the iPhone

# Xcode updates the String Catalogs after every build; here `build` and `sim` do it, and this
# target does it without an iPhone.
strings: project ## Build without signing, bring the catalogs in step with the code, check the Italian
	xcodebuild -project Pendant.xcodeproj -scheme Pendant -destination 'generic/platform=iOS' \
		-derivedDataPath $(DERIVED) -quiet build CODE_SIGNING_ALLOWED=NO
	python3 ../scripts/catalogs.py sync $(DERIVED)
	python3 ../scripts/catalogs.py check

SERVER_WS ?=

credentials: ## Put the server URL and token in the app's keychain: SERVER_WS=<url> TOKEN_FILE=<token file>
	@test -n "$(DEVICE)" || (echo "No iPhone connected" && exit 1)
	@test -n "$(SERVER_WS)" || (echo "Needs SERVER_WS=wss://<server>/api/audio-stream/ws" && exit 1)
	@test -f "$(TOKEN_FILE)" || (echo "Needs TOKEN_FILE=<token file>" && exit 1)
	@tmp=$$(mktemp -d) && trap 'rm -rf "$$tmp"' EXIT && \
		python3 -I -c "import json,sys; print(json.dumps({'url': sys.argv[1], 'token': open(sys.argv[2]).read().strip()}))" \
			"$(SERVER_WS)" "$(TOKEN_FILE)" > "$$tmp/bootstrap.json" && \
		xcrun devicectl device copy to --device $(DEVICE) --domain-type appDataContainer \
			--domain-identifier $(BUNDLE_ID) --source "$$tmp/bootstrap.json" \
			--destination Documents/bootstrap.json >/dev/null && \
		echo "Credentials copied: the app moves them to the keychain at its next launch."

logs: ## Copy the app's log and probe files from the iPhone to app/.logs
	@test -n "$(DEVICE)" || (echo "No iPhone connected" && exit 1)
	mkdir -p .logs
	xcrun devicectl device copy from --device $(DEVICE) --domain-type appDataContainer \
		--domain-identifier $(BUNDLE_ID) --source Documents --destination .logs

devices: ## List the devices Xcode sees
	xcrun devicectl list devices

SIMULATOR ?= iPhone 18 Pro
SIM_ID = $(shell xcrun simctl list devices available -j | python3 -I -c "import json,sys; \
	d=[x for r in json.load(sys.stdin)['devices'].values() for x in r if x['name']=='$(SIMULATOR)']; \
	print(d[0]['udid'] if d else '')")
SIM_APP := $(DERIVED)/sim/Build/Products/Debug-iphonesimulator/Pendant.app
SCENES ?= $(shell sed -n 's/^  case [a-zA-Z]* = "\(.*\)"/\1/p; s/^  case \([a-z]*\)$$/\1/p' Pendant/Demo.swift)

sim: project ## Build for the simulator and launch a demo scene: SCENE=home.rec THEME=casio.orange
	@test -n "$(SIM_ID)" || (echo "No simulator $(SIMULATOR)" && exit 1)
	xcodebuild -project Pendant.xcodeproj -scheme Pendant -destination 'id=$(SIM_ID)' \
		-derivedDataPath $(DERIVED)/sim CURRENT_PROJECT_VERSION=$(BUILD_NUMBER) -quiet build
	python3 ../scripts/catalogs.py sync $(DERIVED)/sim
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	xcrun simctl bootstatus $(SIM_ID) -b >/dev/null
	xcrun simctl install $(SIM_ID) $(SIM_APP)
	xcrun simctl launch --terminate-running-process $(SIM_ID) $(BUNDLE_ID) -demo $(or $(SCENE),home.rec) \
		$(if $(THEME),-theme $(THEME))

screens: sim ## Screenshots of every demo scene in app/.screens, light and dark
	mkdir -p .screens
	xcrun simctl status_bar $(SIM_ID) override --time 17:42 --batteryState charged --batteryLevel 100
	@for mode in light dark; do \
		xcrun simctl ui $(SIM_ID) appearance $$mode; \
		for scene in $(SCENES); do \
			xcrun simctl launch --terminate-running-process $(SIM_ID) $(BUNDLE_ID) -demo $$scene >/dev/null; \
			sleep 2.5; \
			xcrun simctl io $(SIM_ID) screenshot .screens/$$scene.$$mode.png >/dev/null 2>&1; \
		done; \
	done
	xcrun simctl ui $(SIM_ID) appearance light
	@echo "Screenshots in app/.screens"

ICONSET := Pendant/Resources/Assets.xcassets/AppIcon.appiconset

icon: ## Regenerate the icon PNGs from the SVGs in Icon/ (needs rsvg-convert, brew install librsvg)
	rsvg-convert -w 1024 -h 1024 --background-color '#d6d7d3' Icon/pendant-light.svg -o $(ICONSET)/icon-light.png
	rsvg-convert -w 1024 -h 1024 --background-color '#0e0f12' Icon/pendant-dark.svg -o $(ICONSET)/icon-dark.png
	rsvg-convert -w 1024 -h 1024 Icon/pendant-tinted.svg -o $(ICONSET)/icon-tinted.png

clean: ## Remove the build and the generated project
	rm -rf $(DERIVED) Pendant.xcodeproj
