# Build, install and launch the Pendant app from the command line, without opening Xcode.
# The device is the first paired iPhone unless DEVICE=<udid> is given.

BUNDLE_ID := dev.esse.pendant
DERIVED := .derived
APP := $(DERIVED)/Build/Products/Debug-iphoneos/Pendant.app
SOURCES := Pendant PendantKit/Sources PendantKit/Tests PendantKit/Package.swift
DEVICE ?= $(shell xcrun devicectl list devices --json-output /dev/stdout 2>/dev/null | \
	python3 -I -c "import json,sys; d=json.load(sys.stdin)['result']['devices']; \
	print(next((x['hardwareProperties']['udid'] for x in d if x['hardwareProperties'].get('reality')=='physical' \
	and x['connectionProperties'].get('pairingState')=='paired' and x['connectionProperties'].get('tunnelState')!='unavailable'),''))" 2>/dev/null)

.DEFAULT_GOAL := help
.PHONY: help project build install run test lint format check logs devices clean

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

logs: ## Copia dall'iPhone il log e i file della verifica in app/.logs
	@test -n "$(DEVICE)" || (echo "Nessun iPhone collegato" && exit 1)
	mkdir -p .logs
	xcrun devicectl device copy from --device $(DEVICE) --domain-type appDataContainer \
		--domain-identifier $(BUNDLE_ID) --source Documents --destination .logs

devices: ## Elenca i dispositivi visti da Xcode
	xcrun devicectl list devices

clean: ## Toglie build e progetto generato
	rm -rf $(DERIVED) Pendant.xcodeproj
