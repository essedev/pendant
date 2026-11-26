# Architettura

## Visione d'insieme

Omi registra l'audio delle conversazioni a cui partecipo, un'app iOS nostra lo riceve dal
ciondolo via Bluetooth e lo inoltra a Nexus, e Nexus lo conserva e lo trascrive. L'app Omi
resta installata solo per aggiornare il firmware: nessun audio, stato o testo passa dal cloud
Omi.

Fino al 26/11/2026 il trasporto lo faceva l'app Omi con lo "STT personalizzato" (sezione
[Trasporto precedente](#trasporto-precedente-app-omi-e-stt-personalizzato)). L'app nostra lo
sostituisce da quel giorno (DECISIONS), e serve anche a decidere se tenere Omi o passare al
reSpeaker Clip dopo due settimane d'uso.

Il ciondolo fai-da-te su ESP32-S3 progettato prima è superato: architettura, BOM e disegni
restano in `docs/archive/`.

## Flusso

```
Omi ──BLE, Opus 16 kHz──> app pendant (iPhone) ──wss──> Nexus audio_stream ──> transcription
     <── ora, vibrazione,         │                       (sessione = connessione)
         comandi della memoria    ├──> Nexus: stato del ciondolo, segnale periodico, note
                                  └──< Nexus: configurazione dell'app
```

- **Registrazione continua**: finché il ciondolo è collegato e non sono in pausa, l'app
  inoltra l'audio a `audio_stream`. Una connessione è una conversazione: si apre alla ripresa
  e si chiude alla pausa.
- **Offline**: da scollegato il ciondolo scrive in memoria. Alla connessione l'app la legge, la
  manda a Nexus e la libera solo dopo la conferma.
- **Note**: un gesto sul pulsante apre una nota, uno la chiude. L'app ritaglia quel pezzo dal
  flusso e lo manda a Nexus come nota, separata dalla registrazione continua.
- **Stato**: batteria, carica, connessione, memoria e un segnale periodico dell'app vanno a
  Nexus, che avvisa su Telegram quando qualcosa non va.

## Omi: hardware

Modello consumer CV1, dati da docs.omi.me e dal repo `BasedHardware/omi`, rilevati il
28/10/2026.

| Parte | Cosa |
|---|---|
| SoC | nRF5340 (BLE) più nRF7002 (WiFi 6, presente ma spento nel firmware) |
| Microfoni | 2 TDK T5838 PDM, con rilevamento d'attività acustica in hardware |
| Batteria | LiPo 150 mAh |
| Memoria | 512 MB SD NAND saldata, usata come buffer circolare per l'offline |
| Altro | IMU 6 assi (spenta nel firmware), tasto, motore di vibrazione |

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

Nell'uso reale si ricarica ogni sera: una recensione ha misurato 18-20 h, un utente circa
11 h con lo streaming attivo (ricerca del 26/11/2026). Dopo 10 s di silenzio il microfono si
addormenta e si risveglia al primo suono: la pausa decisa dall'app non fa risparmiare
batteria.

## Firmware: il protocollo

Letto nel codice del tag `Omi_CV1_v3.0.21` (il firmware sul mio ciondolo e l'ultimo
distribuito a tutti, verificato su `api.omi.me` il 26/11/2026). I riferimenti sono a
`omi/firmware/omi/src/`. La documentazione pubblica (`sdks/device/PROTOCOL.md`) è indietro:
dice codec 20 e frame da 960 campioni, il codice dice 21 e 320.

### Servizi

| Servizio | Caratteristica | Uso nell'app |
|---|---|---|
| Audio `19B10000-E8F2-537E-4F6C-D104768A1214` | `19B10001` notify | Flusso audio |
| | `19B10002` read | Codec: `21` = Opus |
| Settings `19B10010` | `19B10011` read/write | Luminosità LED, 0-100 |
| | `19B10012` read/write | Guadagno del microfono, 0-8, salvato |
| | `19B10013` read/notify | In carica: `1` |
| Features `19B10020` | `19B10021` read | Bitmask uint32 LE delle funzioni |
| Ora `19B10030` | `19B10031` write | Epoch in secondi, uint32 |
| Memoria `30295780-4301-EABD-2904-2849ADFEAE43` | `30295781` write/notify | Comandi e risposte della memoria |
| | `30295782` read | Byte usati, pacchetti non letti, byte liberi, RTC valido |
| Pulsante `23BA7924-0000-1000-7450-346EAC492E92` | `23BA7925` notify | Gesti, 8 byte |
| Vibrazione `CAB1AB95-2EA5-4F4D-BB56-874B72CFC984` | `CAB1AB96` write | `1` = 100 ms, `2` = 300 ms, `3` = 500 ms |
| Batteria `0x180F` | `0x2A19` read/notify | Percentuale |
| Device Information `0x180A` | `0x2A26` | Versione firmware, modello `Omi CV 1` |

- **Una sola connessione, ma per telefono** (`CONFIG_BT_MAX_CONN=1`): iOS condivide il
  collegamento fra le app. Con l'app Omi attiva, anche lei riceve audio e pulsante e reagisce
  agli stessi gesti (verificato il 26/11/2026: un doppio tocco ha messo in pausa noi e tolto la
  pausa a lei). L'app Omi va quindi scollegata dal ciondolo.
- **Nessun pairing richiesto**: gli attributi non chiedono cifratura (`transport.c`).
- **MTU**: il firmware chiede lo scambio fino a 498. Sotto 100 i frame audio vengono scartati.

### Audio

- Opus 16 kHz mono, 32 kbit/s VBR, frame da 20 ms (320 campioni), al massimo 160 byte
  (`config.h`, `codec.c`).
- Ogni notifica ha un'intestazione di 3 byte: contatore uint16 little-endian e indice del pezzo
  dentro il frame. Un frame si spezza su più notifiche solo se supera l'MTU. Un salto nel
  contatore è un pacchetto perso: non c'è ritrasmissione (`transport.c:1060-1099`).
- **Da collegato l'audio va solo via Bluetooth, non in memoria.** Da scollegato va solo in
  memoria. Connesso ma senza notifiche attive, il frame si perde (`transport.c:1215-1255`).
  Quindi la memoria contiene solo l'audio offline e non serve deduplicare.

### Pulsante

Costanti in `button.c`: tocco sotto 300 ms, doppio tocco entro 600 ms, pressione lunga a
3000 ms.

| Evento inviato | Valore | Quando |
|---|---|---|
| Tocco singolo | `1` | Circa 300 ms dopo un tocco senza secondo tocco |
| Doppio tocco | `2` | Al secondo tocco entro 600 ms |
| Rilascio | `5` | Una volta, quando il pulsante torna fermo dopo un gesto, e circa 300 ms dopo l'avvio |
| Pressione | `4` | **Mai inviato**: la funzione esiste ma nessuno la chiama |
| Pressione lunga | `3` | **Mai inviato**: a 3 s il ciondolo si spegne |

Il rilascio si manda solo se l'ultimo evento non era già un rilascio, e quel ricordo non si
azzera mai (`button.c:241-251`). Siccome ogni tocco è seguito da un rilascio, una pressione
tenuta fra 0,3 e 3 s non produce nessun evento.

Conseguenze per l'app: non sa quando inizia una pressione, e tenere premuto oltre 3 s spegne il
ciondolo. **Il "premi e parla" col firmware di serie non si può fare**, e i gesti utilizzabili
sono due: tocco singolo e doppio tocco.

### Memoria

Ring buffer sulla SD, a pacchetti da 444 byte: timestamp UTC di 4 byte più 440 byte di frame
Opus nella forma `[lunghezza][frame]`, senza terminatore (`sd_card.h`). Circa 100 ms d'audio
per pacchetto, quindi decine di ore di parlato prima di sovrascrivere.

| Comando | Byte | Cosa fa |
|---|---|---|
| Info | `0x10` | Risponde con `read_seq`, `write_seq`, capacità, pacchetti persi per sovrascrittura |
| Lettura | `0x11` + `start_seq` (u64) + `count` (u32, opzionale) | Inizio, dati a flusso, fine con `next_seq` |
| Avanza | `0x12` + `new_read_seq` (u64) | Sposta il puntatore di lettura: non cancella, rende sovrascrivibile |
| Svuota | `0x13` | Azzera il ring |
| Stop | `0x03` | Interrompe una lettura |

Tutti i numeri sono big-endian, le risposte arrivano su `30295781` (`storage.c`).

- **Il firmware avanza da solo** durante una lettura, ogni 2 s, in base a quello che lo stack
  Bluetooth ha spedito, non a quello che l'app ha salvato (`storage.c:380-434`). Poiché
  avanzare non cancella, l'app tiene l'intervallo di `seq` letto e, se il salvataggio fallisce,
  lo rilegge finché non è sovrascritto.
- **Senza ora valida l'offline si perde**: il firmware scarta le scritture se l'RTC non è
  impostato (`sd_card.c:680-687`). L'app scrive l'ora a ogni connessione.

### Cosa aggiunge il 3.0.24

Pubblicato il 9/11/2026 ma al 0% di rollout il 26/11/2026: non si installa dall'app Omi.

| Funzione | Effetto per l'app |
|---|---|
| Muto salvato (`19B10015`, bit 10) | Pausa che vale anche da scollegato e dopo un riavvio: niente audio né in streaming né in memoria |
| Spegnimento dall'app (bit 11) | L'app spegne un ciondolo acceso per sbaglio |
| `LIVE_MARK` e custodia | Collega l'audio dal vivo alla memoria |
| Safe mode | Un aggiornamento finito male si recupera senza J-Link |

## L'app

App iOS nativa in Swift, nella cartella `app/`. Solo iPhone. Il riferimento per il Bluetooth è
il codice Swift nativo dell'app Omi (`app/ios/Runner/Ble/OmiBleManager.swift`, licenza MIT),
che su iOS ha sostituito il plugin Flutter.

### Componenti

| Componente | Responsabilità |
|---|---|
| Collegamento | CoreBluetooth in background, ripristino dello stato dopo che iOS chiude l'app, riconnessione con backoff, lettura di versione e funzioni, scrittura dell'ora |
| Audio | Ricomposizione dei frame, conteggio dei pacchetti persi, decodifica Opus in PCM |
| Inoltro | WebSocket verso `audio_stream`, una connessione per conversazione, coda su disco quando la rete manca |
| Memoria | Lettura dell'offline alla connessione, invio a Nexus, avanzamento dopo la conferma |
| Gesti | Riconoscimento dei gesti dagli eventi del firmware, mappa gesto-azione dalla configurazione |
| Note | Ritaglio dell'audio fra apertura e chiusura, controllo che ci sia voce, invio a Nexus |
| Stato | Eventi del ciondolo e segnale periodico verso Nexus, notifiche locali |
| Configurazione | Scarica la configurazione da Nexus, la valida, tiene l'ultima buona |

### Ciclo di una connessione

1. Il ciondolo si collega. L'app scrive l'ora, legge versione, funzioni, codec e batteria, e
   si iscrive ad audio, pulsante, batteria e carica.
2. Se la versione non è fra quelle supportate dalla configurazione, l'app lo segnala e lavora
   solo sulle funzioni che il bitmask dichiara.
3. Se non sono in pausa, apre la sessione su `audio_stream` e inoltra.
4. Legge l'info della memoria. Se c'è audio offline, lo tratta secondo la politica configurata.
5. Alla disconnessione chiude la sessione senza `CloseStream`: Nexus la tiene `interrupted` per
   120 s e la riprende se il ciondolo torna.

### Custodia dell'audio

Ogni copia si cancella solo quando la successiva è confermata. Nessuna eccezione per comodità.

| Dove | Si libera quando |
|---|---|
| Memoria del ciondolo | Nexus ha confermato il pezzo offline: l'app manda l'avanzamento fino a quel `seq` |
| Coda su disco dell'app | Il frame è stato spedito sulla connessione a Nexus |
| Pezzo in memoria su Nexus | Ogni 30 s va in media (comportamento di `audio_stream`) |

L'inoltro dal vivo non ha una conferma per pezzo: un crash di Nexus perde al massimo gli ultimi
30 s, come oggi con l'app Omi. Una conferma vera richiede un'estensione del contratto.

### Gesti e azioni

Il firmware dà due gesti (sezione Pulsante). La mappa gesto-azione sta nella configurazione:

| Gesto | Azione di default |
|---|---|
| Doppio tocco | Pausa e ripresa della registrazione continua |
| Tocco singolo | Apre la nota, il successivo la chiude |

Sequenze di gesti (tocco seguito da doppio tocco entro un tempo dato) le può riconoscere l'app,
se due azioni non bastano: è una scelta della configurazione, non del firmware.

- **La vibrazione conferma ogni azione**: lunga quando accende, breve quando spegne.
- **In pausa le note funzionano**: il ciondolo trasmette comunque, l'app scarta il flusso e ne
  tiene solo le note.
- **Tocchi accidentali in tasca**: una nota senza voce rilevata si scarta, e dopo un tempo
  massimo configurabile si chiude da sola.
- **Accensioni accidentali**: da spento basta un tocco breve per riaccendere il ciondolo.
  Sul 3.0.21 l'app le vede (riconnessione dopo uno spegnimento) e le notifica, ma non può
  spegnerlo: serve il 3.0.24.

### Configurazione

Nessun valore di comportamento è scritto nel codice. Lo schema della configurazione (chiavi,
tipi, limiti, default) vive nell'app e i valori arrivano da Nexus, che è dove li modifico.
L'app tiene l'ultima configurazione valida e, se Nexus non risponde, lavora con quella.
Nell'app restano solo URL di Nexus e token, nel portachiavi di iOS.

| Gruppo | Esempi |
|---|---|
| Gesti | Mappa gesto-azione, durata della vibrazione per azione |
| Note | Durata massima, soglia di voce, pre-roll (secondi presi prima del gesto) |
| Memoria | Politica dell'offline: invia, svuota o lascia; dimensione delle letture |
| Stato | Intervallo del segnale periodico, soglia di batteria bassa, quali notifiche locali |
| Inoltro | Lingua, intervallo del ping, tempo di riconnessione |
| Firmware | Versioni supportate e funzioni da usare su ognuna |

Restano fissi solo i valori del firmware (tempi del pulsante, formato dei pacchetti): l'app li
legge dal protocollo, non li sceglie.

## Contratto con Nexus

Il primo passo non cambia Nexus: l'app parla a `audio_stream` come l'app Omi. Contratto
completo nel repo `nexus`, `docs/features/audio-stream.md`.

| Punto | Valore |
|---|---|
| Endpoint | `GET /api/audio-stream/ws`, `wss://` |
| Autenticazione | Token dedicato in `?token=` o `Authorization: Bearer` |
| Audio | Frame binari PCM s16le, mono, 16 kHz |
| Chiusura | `{"type":"CloseStream"}` chiude la conversazione |
| Interruzione | Senza `CloseStream` la sessione resta `interrupted` 120 s e si riprende |
| Ping | Ogni 20 s nel silenzio: Cloudflare chiude dopo circa 100 s senza traffico |
| Sessione vuota | Sotto 2 s d'audio non diventa una trascrizione |

Da aggiungere in Nexus, in proposta, uno alla volta quando la milestone li richiede:

| Aggiunta | Perché |
|---|---|
| Configurazione dell'app | Un documento con i valori della sezione Configurazione, modificabile in Nexus |
| Eventi del ciondolo e segnale periodico | Storico dello stato e avviso su Telegram se l'app tace |
| Audio offline | Pezzi con l'ora vera di registrazione, conferma per pezzo e idempotenza su `seq` |
| Note | Audio di una nota, trascritto e salvato separato dalle conversazioni |
| Opus invece di PCM | Da circa 115 a circa 7 MB l'ora di dati dal telefono, decodifica su Nexus |

## Distribuzione

- **Account Apple gratuito**: Xcode firma con il "Personal Team" e l'app scade dopo 7 giorni.
  Il cavo serve solo per il primo abbinamento, poi Xcode installa via Wi-Fi. SideStore rinnova
  da solo quando Mac e iPhone sono sulla stessa rete.
- **Limiti**: niente notifiche push (bastano le locali e Telegram per quelle da Nexus), al
  massimo 3 app firmate così. Il Bluetooth in background va verificato col primo build.
- **Se l'app passa la prova**: account sviluppatore a 99 $ l'anno, il certificato dura un anno.
- **App Omi**: resta installata, col ciondolo dimenticato e le azioni al tocco spente. Per un
  aggiornamento del firmware si ricollega, mettendo in pausa l'app nostra, e la si scollega
  di nuovo alla fine.
- **Credenziali**: `make credentials TOKEN_FILE=<file>` copia URL e token nei Documenti
  dell'app, che al primo avvio li sposta nel portachiavi e cancella il file. Il token viaggia
  verso Nexus nell'header `Authorization`, non nell'URL.

## Trasporto precedente: app Omi e STT personalizzato

In uso fino al 26/11/2026, resta il riferimento per il contratto di `audio_stream`. Verificato
col prototipo
`prototype/omi_stt_probe.py` il 28/10/2026, app Omi 1.0.577.

- L'app accetta solo `wss://`, aggiunge `?language=<lingua>` e autentica col token in query.
- Manda PCM a 16 bit, mono, 16 kHz (circa 115 MB l'ora), `{"type":"CloseStream"}` alla pausa,
  e messaggi JSON di stato suoi, da ignorare. Non si aspetta risposte.
- Senza trascrizioni di ritorno non crea conversazioni sul cloud Omi. Il canale con il backend
  Omi resta comunque aperto per lo stato dell'app.
- L'audio offline non arriva a Nexus: resta nell'app, che lo sa sincronizzare solo verso Omi.
- Ogni frame inviato in diretta resta anche come copia locale, che l'app rilascia solo quando
  il cloud Omi conferma una trascrizione. Con lo STT personalizzato non succede mai, quindi le
  copie si accumulano (21 h il 26/11/2026) e si cancellano a mano.

| Impostazione dell'app Omi | Valore | Perché |
|---|---|---|
| Fonte di trascrizione | Custom, in tempo reale | manda l'audio a Nexus |
| Invia l'audio grezzo a Omi | Off | altrimenti l'audio va anche al loro backend |
| Archivia audio nel cloud | Off | conserva sui loro server l'audio che li raggiunge |
| Sincronizzazione automatica | Off | manderebbe l'audio offline al loro backend |
| Pulsante "Sincronizza" | Non usare | trascrive l'offline sui server Omi |

## Trascrizione

La fa Nexus, a sessione chiusa, con la pipeline `transcription`: prima l'Executor remoto sul Mac
di casa, poi la riserva cloud (Voxtral, scelta col confronto del 28/10, DECISIONS #100 di
Nexus). Dettagli nel repo `nexus`, `docs/features/transcriptions.md`.

## Verifiche sul ciondolo

Fatte il 26/11/2026 con l'app di verifica (M5), firmware 3.0.21, iPhone 15 Pro. Il log si
scarica con `make logs`.

| Verifica | Esito |
|---|---|
| Collegamento e lettura | Modello `Omi CV 1`, firmware `3.0.21`, codec `21`, bitmask `0x1EC` come nel codice |
| Ora | Scritta a ogni connessione, la memoria la vede valida |
| Audio | Circa 46 notifiche al secondo da circa 85 B: un frame per notifica, nessuna spezzatura. Zero persi su 7.600 pacchetti. Nel silenzio il flusso si ferma, come previsto |
| Pulsante | Tocco: `singleTap` più `release`. Doppio tocco: `doubleTap` più `release`. Pressione di 1-2 s, provata due volte: nessun evento. Il premi e parla è escluso |
| Vibrazione | Le tre durate funzionano |
| Memoria | Info letta: 53 pacchetti in attesa, capacità 1.115.064 pacchetti da 444 B (circa 30 h di parlato, stima a 100 ms per pacchetto) |
| Batteria | Da 100% a 84% in 12 minuti: forse il primo valore era vecchio, da seguire |
| Inoltro a Nexus (M6) | Conversazione di prova: 287 s in 13 pezzi, chiusa col doppio tocco e `CloseStream`, trascritta. Pausa e ripresa aprono e chiudono una sessione sola |
| Ripristino dello stato | Al riavvio dell'app iOS ha restituito il ciondolo già collegato, e l'inoltro è ripartito da solo |
| Decodifica Opus | Con il codec di sistema (AudioToolbox): nessuna libreria, testata anche in `swift test` |

Ancora aperte:

- Il Bluetooth in background per ore con l'account gratuito, e il rilancio dell'app da parte
  di iOS dopo che l'ha chiusa. Si misura nell'uso reale.
- Il guadagno del microfono a `0`: dopo il cambio i pacchetti pesavano ancora circa 80 B, ma
  senza un confronto fra parlato e silenzio non si sa se è un muto o solo -20 dB.
- La lettura della memoria: formato dei blocchi da 440 byte e tempo per scaricare un'ora.
- Quanto spesso il ciondolo si accende da solo in tasca.

## Rischi

- **Bluetooth in background su iOS**: se iOS chiude l'app e il ripristino non scatta, la
  registrazione si ferma in silenzio. Il segnale periodico verso Nexus serve a saperlo.
- **Firmware che cambia**: ogni versione nuova può cambiare protocollo. L'app lavora solo sulle
  versioni dichiarate nella configurazione e sul bitmask delle funzioni.
- **Due app, un ciondolo**: se l'app Omi torna collegata, registra in parallelo verso Nexus e
  risponde agli stessi gesti, invertendo la pausa. Resta col ciondolo dimenticato.
- **Scadenza a 7 giorni**: un rinnovo saltato ferma l'app. Lo copre lo stesso segnale periodico.
- **Accensioni accidentali**: sul 3.0.21 il ciondolo acceso per sbaglio registra e consuma, e
  l'app non può spegnerlo.
- **Conversazioni altrui**: registrare conversazioni a cui non partecipo è un problema legale in
  Italia e di GDPR verso i colleghi. La regola d'uso è togliere la pausa solo quando partecipo.
