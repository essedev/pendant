# Architettura

## Visione d'insieme

Omi registra l'audio delle conversazioni a cui partecipo, l'app Omi sull'iPhone lo inoltra in
tempo reale a Nexus, e Nexus lo conserva e lo trascrive quando la conversazione si chiude.
Il cloud di Omi non riceve né audio né trascrizioni: l'app usa lo "STT personalizzato", cioè
manda l'audio a un endpoint nostro invece che al loro servizio di trascrizione.

Il ciondolo fai-da-te su ESP32-S3 progettato prima è superato (DECISIONS 2026-10-28): la sua
architettura, la BOM e i disegni restano in `docs/archive/`.

## Flusso

```
Omi ──BLE, Opus 32 kbps──> app Omi (iPhone) ──wss, PCM 16 kHz──> Nexus ──> transcription
                                   │                              (sessione = connessione)   (batch, diarizzazione)
                                   └──> backend Omi: solo lo stato dell'app, niente audio
```

Una conversazione è una connessione WebSocket: si apre quando tolgo la pausa dal ciondolo e si
chiude quando la rimetto. Nexus salva l'audio della sessione e alla chiusura crea una
`transcription`, che la pipeline esistente trascrive ed estrae.

## Omi: hardware

Modello consumer CV1, dati da docs.omi.me e dal repo `BasedHardware/omi`, rilevati il
28/10/2026.

| Parte | Cosa |
|---|---|
| SoC | nRF5340 (BLE) più nRF7002 (WiFi 6, presente ma spento nel firmware) |
| Microfoni | 2 TDK T5838 PDM, con rilevamento d'attività acustica in hardware |
| Batteria | LiPo 150 mAh |
| Memoria | 512 MB SD NAND saldata, usata come buffer circolare per l'offline |
| Audio | Opus 32 kbps verso il telefono |
| Altro | IMU 6 assi, tasto, motore di vibrazione |

## Consumi

Misure con Power Profiler Kit pubblicate nella PR firmware #6950 (unita il 23/04/2026), su
finestre di 20 s - 2 min. Il firmware è cambiato dopo: sono ordini di grandezza, non garanzie.

| Stato | Corrente media | Durata su 150 mAh |
|---|---|---|
| Spento (tasto premuto 3 s) | 0,031 mA | mesi |
| Silenzio, connesso | 3,10 mA | circa 48 h |
| Silenzio, offline | 3,26 mA | circa 46 h |
| Parlato, streaming al telefono | 4,44 mA | circa 34 h |
| Parlato, offline (scrive in memoria) | 7,03 mA | circa 21 h |
| Sync della memoria verso il telefono | 9,46 mA | circa 16 h |

Dopo 10 s di silenzio il microfono si addormenta (`CONFIG_OMI_VAD_HOLD_MS=10000`) e si
risveglia al primo suono: la pausa manuale non fa risparmiare batteria, serve solo a non
registrare.

## Uso del ciondolo

- **Doppio tocco**: pausa e ripresa, impostato nell'app ("Azione Doppio Tocco"). La pausa vive
  nell'app, non nel ciondolo: resta attiva anche dopo uno spegnimento.
- **Tasto premuto 3 s**: spegnimento. Per riaccendere si tiene premuto finché non vibra.
- **Nessun riscontro al doppio tocco**: il ciondolo non vibra. In pausa l'app mostra una Live
  Activity sull'iPhone. La vibrazione è oggetto di una PR verso Omi (ROADMAP).

## Trasporto: STT personalizzato live

Verificato con il prototipo `prototype/omi_stt_probe.py` il 28/10/2026, app 1.0.577.

- **URL**: l'app accetta solo `wss://`. Aggiunge `?language=<lingua>` alla query.
- **Autenticazione**: token nella query (`?token=...`) verificato. Gli header si possono
  impostare dal JSON della sezione avanzata, non ancora provati.
- **Audio**: frame binari di PCM a 16 bit little-endian, mono, 16 kHz (l'app decodifica l'Opus
  del ciondolo). Circa 115 MB per ora di traffico dati dal telefono.
- **Messaggi di testo**: alla chiusura l'app manda `{"type":"CloseStream"}` e chiude la
  connessione (codice 1005). Altri messaggi JSON di stato dell'app vanno scartati.
- **Risposta**: nessuna. L'app regge una connessione che non le rimanda trascrizioni, e senza
  trascrizioni non crea conversazioni sul cloud Omi.
- **Silenzio**: dentro una connessione aperta il flusso si interrompe per tutto il silenzio
  (microfono addormentato). Le interruzioni non sono confini di conversazione.

Impostazioni dell'app Omi, tutte in Trascrizione e in Sincronizzazione offline:

| Impostazione | Valore | Perché |
|---|---|---|
| Fonte di trascrizione | Custom, in tempo reale | manda l'audio a Nexus |
| Invia l'audio grezzo a Omi | Off | altrimenti l'audio va anche al loro backend |
| Archivia audio nel cloud | Off | conserva sui loro server l'audio che li raggiunge |
| Sincronizzazione automatica | Off | manderebbe l'audio offline al loro backend |
| Pulsante "Sincronizza" | Non usare | trascrive l'offline sui server Omi |

## Esito del prototipo

| Verifica | Esito |
|---|---|
| L'audio arriva | Sì, in tempo reale, livelli coerenti col parlato |
| Autenticazione | Sì, col token nella query |
| L'app regge senza risposte | Sì |
| Omi non riceve niente | Nessuna conversazione creata. Il canale verso il backend Omi resta aperto per lo stato dell'app |
| Pausa | Chiude la connessione con `CloseStream`: confine immediato |
| Ripresa | Primo audio 1,2 s dopo la riconnessione, le prime parole ci sono |
| Audio offline | **Non arriva a Nexus**: resta nel buffer dell'app, che sa sincronizzarlo solo verso Omi |

## Trascrizione

In Nexus, batch a sessione chiusa con diarizzazione, sulla capability `transcription` esistente.
Niente trascrizione live: costerebbe il doppio e diarizza peggio (DECISIONS 2026-10-28).

| Provider | Batch, $/h | Note |
|---|---|---|
| Mistral Voxtral Mini Transcribe V2 | 0,18 | diarizzazione nel batch |
| Speechmatics Melia 1 | 0,24 | stesso provider di oggi, host EU |
| Deepgram Nova-3 | 0,26-0,31 | azienda USA |
| Speechmatics Enhanced | 0,75 | quello che usa Nexus oggi |

Prezzi di listino rilevati il 28/10/2026. Da 1 a 6 ore registrate al giorno la spesa è
4-40 $ al mese a seconda del provider. Il provider lo sceglie un confronto su registrazioni
vere (ROADMAP).

## Rischi

- **App Omi che cambia sotto i piedi**: Omi unisce circa 75 PR al giorno e rilascia ogni pochi
  giorni. Il protocollo dello STT personalizzato può cambiare senza preavviso: il prototipo
  serve anche da test di regressione.
- **Canale verso il backend Omi sempre aperto**: anche con l'audio grezzo spento l'app tiene una
  connessione con Omi per il suo stato. Cosa registrino dal loro lato non è verificabile.
- **Audio offline perso per Nexus**: se il ciondolo registra senza telefono vicino, quell'audio
  resta nell'app. Si recupera a mano con "Condividi registrazione" (WAV) dal dettaglio della
  voce in Sincronizzazione offline.
- **Pausa dimenticata**: senza vibrazione il cambio di stato si vede solo sul telefono. Una
  pausa dimenticata attiva perde la conversazione; una dimenticata spenta registra altri.
- **Conversazioni altrui**: registrare conversazioni a cui non partecipo è un problema legale in
  Italia e di GDPR verso i colleghi. La regola d'uso è togliere la pausa solo quando partecipo.
