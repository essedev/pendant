# pendant - Istruzioni per Claude

## Cos'è

Integrazione del ciondolo Omi con Nexus: l'app Omi manda l'audio a un endpoint nostro invece
che al cloud Omi, e Nexus lo trascrive. Il ciondolo fai-da-te su ESP32-S3 progettato prima è
superato e vive in `docs/archive/`. Progetto personale, trunk-based su main.

## Dove sta cosa

- `docs/ARCHITECTURE.md`: flusso, hardware e consumi di Omi, protocollo dello STT
  personalizzato, impostazioni dell'app, esito del prototipo, rischi.
- `docs/DECISIONS.md`: scelte fatte e perché.
- `docs/ROADMAP.md`: milestone e domande aperte.
- `prototype/omi_stt_probe.py`: server WebSocket di prova che registra quello che manda l'app.
- `docs/archive/`: architettura, BOM e disegni del ciondolo fai-da-te. Si legge, non si aggiorna.
- Clone di Omi per le PR: `~/Development/Projects/omi`, remote `upstream` (BasedHardware) e
  `origin` (fork `essedev/omi`). Flutter 3.44.5 in `~/Development/tools/flutter-3.44.5`.

## Comandi

- Prototipo: `PROBE_TOKEN=<token> uv run prototype/omi_stt_probe.py` (ascolta su
  127.0.0.1:8765, scrive WAV ed `events.jsonl` in `prototype/recordings/`).
- Esposizione per l'iPhone: `cloudflared tunnel --url http://localhost:8765`, poi nell'app
  `wss://<nome>.trycloudflare.com/stream?token=<token>`. Il tunnel lo autorizza Simone.

## Gotcha

- L'app Omi accetta solo URL `wss://`. Tailscale con il nome MagicDNS non ha funzionato
  dall'iPhone (risoluzione del nome fallita nell'app): usare il tunnel Cloudflare.
- Con lo STT personalizzato l'app tiene comunque aperta una connessione col backend Omi: le
  impostazioni che tengono l'audio fuori dal cloud sono in `ARCHITECTURE.md #Trasporto`.
- `prototype/recordings/` contiene voci vere: è in `.gitignore` e non va mai committata.
- Il repo Omi ha regole di contribuzione proprie (`AGENTS.md`, `make preflight`,
  `scripts/pr-preflight`): leggerle prima di toccarlo. Push e PR col solo account `essedev`,
  mai pubblicare senza il via di Simone.
- Il codice dell'app Omi cambia ogni giorno: prima di affermare come si comporta, leggere il
  clone aggiornato (`git -C ~/Development/Projects/omi fetch upstream main`).
