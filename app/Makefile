# Build, install and launch the Pendant app from the command line, without opening Xcode.
# The device is the first paired iPhone unless DEVICE=<udid> is given.

BUNDLE_ID := dev.esse.pendant
DERIVED := .derived
APP := $(DERIVED)/Build/Products/Debug-iphoneos/Pendant.app
SOURCES := Pendant Shared PendantWidgets PendantKit/Sources PendantKit/Tests PendantKit/Package.swift
DEVICE ?= $(shell xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | \
	python3 -I -c "import json,sys; d=json.load(sys.stdin)['result']['devices']; \
	print(next((x['hardwareProperties']['udid'] for x in d if x['hardwareProperties'].get('reality')=='physical' \
	and x['connectionProperties'].get('pairingState')=='paired' and x['connectionProperties'].get('tunnelState')!='unavailable'),''))" 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help project build install run test lint format check credentials logs devices clean sim screens

help: ## Elenca i comandi
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

project: Local.xcconfig ## Genera Pendant.xcodeproj da project.yml
	xcodegen generate -q

Local.xcconfig:
	cp Local.xcconfig.example Local.xcconfig
	@echo "Imposta DEVELOPMENT_TEAM in app/Local.xcconfig e rilancia." && exit 1

build: project ## Compila e firma per l'iPhone collegato
	@test -n "$(DEVICE)" || (echo "Nessun iPhone collegato" && exit 1)
	xcodebuild -project Pendant.xcodeproj -scheme Pendant -destination 'id=$(DEVICE)' \
		-derivedDataPath $(DERIVED) -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
		-quiet build

install: build ## Installa sull'iPhone
	xcrun devicectl device install app --device $(DEVICE) $(APP)

run: install ## Installa e avvia sull'iPhone
	xcrun devicectl device process launch --device $(DEVICE) $(BUNDLE_ID)

test: ## Test del pacchetto PendantKit, senza iPhone
	cd PendantKit && swift test

lint: ## Controlla la formattazione
	swift format lint --strict -r $(SOURCES)

format: ## Formatta il codice Swift
	swift format -i -r $(SOURCES)

check: lint test build ## Giro completo: formattazione, test, build per l'iPhone

NEXUS_WS ?= wss://nexus.esse.dev/api/audio-stream/ws

credentials: ## Porta URL e token di Nexus nel portachiavi dell'app: TOKEN_FILE=<file col token>
	@test -n "$(DEVICE)" || (echo "Nessun iPhone collegato" && exit 1)
	@test -f "$(TOKEN_FILE)" || (echo "Serve TOKEN_FILE=<file col token>" && exit 1)
	@tmp=$$(mktemp -d) && trap 'rm -rf "$$tmp"' EXIT && \
		python3 -I -c "import json,sys; print(json.dumps({'url': sys.argv[1], 'token': open(sys.argv[2]).read().strip()}))" \
			"$(NEXUS_WS)" "$(TOKEN_FILE)" > "$$tmp/bootstrap.json" && \
		xcrun devicectl device copy to --device $(DEVICE) --domain-type appDataContainer \
			--domain-identifier $(BUNDLE_ID) --source "$$tmp/bootstrap.json" \
			--destination Documents/bootstrap.json >/dev/null && \
		echo "Credenziali copiate: l'app le sposta nel portachiavi al prossimo avvio."

logs: ## Copia dall'iPhone il log e i file della verifica in app/.logs
	@test -n "$(DEVICE)" || (echo "Nessun iPhone collegato" && exit 1)
	mkdir -p .logs
	xcrun devicectl device copy from --device $(DEVICE) --domain-type appDataContainer \
		--domain-identifier $(BUNDLE_ID) --source Documents --destination .logs

devices: ## Elenca i dispositivi visti da Xcode
	xcrun devicectl list devices

SIMULATOR ?= iPhone 18 Pro
SIM_ID = $(shell xcrun simctl list devices available -j | python3 -I -c "import json,sys; \
	d=[x for r in json.load(sys.stdin)['devices'].values() for x in r if x['name']=='$(SIMULATOR)']; \
	print(d[0]['udid'] if d else '')")
SIM_APP := $(DERIVED)/sim/Build/Products/Debug-iphonesimulator/Pendant.app
SCENES ?= $(shell sed -n 's/^  case [a-zA-Z]* = "\(.*\)"/\1/p; s/^  case \([a-z]*\)$$/\1/p' Pendant/Demo.swift)

sim: project ## Compila per il simulatore e lo avvia in una scena demo: SCENE=home.rec
	@test -n "$(SIM_ID)" || (echo "Nessun simulatore $(SIMULATOR)" && exit 1)
	xcodebuild -project Pendant.xcodeproj -scheme Pendant -destination 'id=$(SIM_ID)' \
		-derivedDataPath $(DERIVED)/sim -quiet build
	xcrun simctl boot $(SIM_ID) 2>/dev/null || true
	xcrun simctl bootstatus $(SIM_ID) -b >/dev/null
	xcrun simctl install $(SIM_ID) $(SIM_APP)
	xcrun simctl launch --terminate-running-process $(SIM_ID) $(BUNDLE_ID) -demo $(or $(SCENE),home.rec)

screens: sim ## Schermate di tutte le scene demo in app/.screens, chiaro e scuro
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
	@echo "Schermate in app/.screens"

clean: ## Toglie build e progetto generato
	rm -rf $(DERIVED) Pendant.xcodeproj
