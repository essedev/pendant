# pendant - Istruzioni per Claude

## Cos'è

Il ciondolo Omi collegato a Nexus. Un'app iOS nostra in Swift (`app/`) riceve l'audio via
Bluetooth e lo manda a `audio_stream` di Nexus; l'app Omi resta solo per gli aggiornamenti del
firmware. Il ciondolo fai-da-te su ESP32-S3 è
superato e vive in `docs/archive/`. Progetto personale, trunk-based su main.

## Dove sta cosa

- `docs/ARCHITECTURE.md`: flusso, protocollo Bluetooth del firmware, componenti dell'app,
  custodia dell'audio, configurazione, contratto con Nexus, verifiche sul ciondolo, rischi.
- `docs/DECISIONS.md`: scelte fatte e perché. `docs/ROADMAP.md`: milestone e domande aperte.
- `docs/CONVENTIONS.md`: regole di codice e di prosa.
- `docs/features/`: una feature per file (comandi di sistema). `docs/concepts/`: i mock HTML
  dell'interfaccia; `docs/concepts/inspo/` è ispirazione scaricata, non versionata.
- `app/`: l'app iOS. `project.yml` (XcodeGen), `Pendant/` il target dell'app, `PendantKit/`
  il pacchetto con la logica, `PendantWidgets/` l'estensione (controlli e attività in tempo
  reale), `Shared/` il codice di entrambi (tema, intent, viste dell'attività), `Icon/` gli SVG
  dell'icona (`make icon`).
- `prototype/omi_stt_probe.py`: server WebSocket di prova che registra quello che manda l'app
  Omi.
- `docs/archive/`: il ciondolo fai-da-te. Si legge, non si aggiorna.
- Lato Nexus: repo `~/Development/Projects/nexus`, `docs/features/audio-stream.md` (contratto
  del WebSocket) e `backend/src/extensions/audio_stream/`.
- Clone di Omi: `~/Development/Projects/omi`, remote `origin` (BasedHardware) e `fork`
  (`essedev/omi`). Una PR = un worktree accanto al clone. Flutter 3.44.5 in
  `~/Development/tools/flutter-3.44.5`.

## Comandi

- App, da `app/`: `make run` (genera il progetto, compila, installa e avvia sull'iPhone
  collegato), `make test`, `make check` prima di ogni commit che tocca l'app, `make help` per
  il resto. Primo setup: `brew install xcodegen`, Apple ID in Xcode, `DEVELOPMENT_TEAM` in
  `app/Local.xcconfig` (il Team ID è l'OU del certificato "Apple Development" nel portachiavi),
  poi `make credentials TOKEN_FILE=<file col token di audio_stream>` (oppure si scrivono nel
  primo avvio). `make logs` scarica il log dell'app in `app/.logs/`.
- Simulatore, da `app/`: `make sim SCENE=<scena>` avvia l'app in una scena demo (elenco in
  `Pendant/Demo.swift`, argomento `-demo`), `make screens` fotografa tutte le scene in chiaro e
  scuro in `app/.screens/`. Per guardare una UI si confronta col mock `concept-b-app.html`.
- Prototipo: `PROBE_TOKEN=<token> uv run prototype/omi_stt_probe.py` (ascolta su
  127.0.0.1:8765, scrive WAV ed `events.jsonl` in `prototype/recordings/`).
- Esposizione per l'iPhone: `cloudflared tunnel --url http://localhost:8765`, poi nell'app
  `wss://<nome>.trycloudflare.com/stream?token=<token>`. Il tunnel lo autorizza Simone.
- Firmware distribuito per il CV1: `curl -s "https://api.omi.me/v2/firmware/stable?device_model=Omi%20CV%201"`.

## Gotcha

- **Il protocollo si legge al tag del firmware in uso**, non su `main`:
  `git -C ~/Development/Projects/omi show Omi_CV1_v3.0.21:omi/firmware/omi/src/<file>`. `main`
  ha funzioni (muto, spegnimento, `LIVE_MARK`) che il ciondolo non ha. `sdks/device/PROTOCOL.md`
  è indietro rispetto al codice.
- **Il riferimento per il Bluetooth su iOS è Swift**: `app/ios/Runner/Ble/OmiBleManager.swift`
  nel clone Omi, non il Dart.
- **iOS condivide il ciondolo fra le app**: con l'app Omi collegata, anche lei riceve audio e
  gesti e manda a Nexus una seconda registrazione. Va tenuta col ciondolo dimenticato.
- **Nessun valore di comportamento nel codice dell'app**: va nello schema della configurazione
  (`ARCHITECTURE.md #Configurazione`).
- **L'iPhone vero serve per il ciondolo**: il simulatore non ha Bluetooth, le schermate si
  provano con le scene demo. L'app firmata col Personal Team
  scade dopo 7 giorni.
- L'app Omi accetta solo URL `wss://`. Tailscale con il nome MagicDNS non ha funzionato
  dall'iPhone: usare il tunnel Cloudflare.
- `prototype/recordings/` contiene voci vere: è in `.gitignore` e non va mai committata.
- Il repo Omi ha regole di contribuzione proprie (`AGENTS.md`, template della PR,
  `make preflight`, `scripts/pr-preflight`): leggerle prima di toccarlo. `make preflight` va
  lanciato con `OMI_PR_BODY_FILE=<bozza>` o fallisce su `ui-evidence`. Push e PR col solo
  account `essedev` (`GH_TOKEN=$(gh auth token --user essedev)`) ed email `hello@esse.dev`,
  mai pubblicare senza il via di Simone.
- Il codice dell'app Omi cambia ogni giorno: prima di affermare come si comporta, aggiornare il
  clone (`git -C ~/Development/Projects/omi fetch origin main --tags`).
