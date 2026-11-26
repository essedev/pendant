# Decisioni

## 2026-10-07 Costruire invece di comprare Omi

Omi costa 129 $ ed è open source, ma di default passa dal telefono e dal cloud e conserva
soprattutto trascrizioni. Lo costruiamo per spendere meno e avere un dispositivo custom:
registrazione offline su microSD, audio grezzo conservato, pipeline di trascrizione nostra.
Superata dalla decisione del 2026-10-28 di comprare Omi.

## 2026-10-07 Due schede: Super Mini al banco, XIAO nel ciondolo

La Super Mini costa 3,90 € e ha più pin, ma la ricarica è incerta, ha LED che consumano sempre
e qualità variabile tra lotti. Il XIAO ha ricarica integrata, documentazione e qualità costante.
Super Mini per sviluppare il firmware, XIAO per l'indossabile.
Superata dalla decisione del 2026-10-07 sul XIAO Plus.

## 2026-10-07 Batteria 503450 1000 mAh

A parità di capacità è la più sottile (circa 5 mm contro 6 della 603048 e 8 della 803040).
In un ciondolo lo spessore conta più dell'ingombro in pianta.

## 2026-10-07 microSD su modulo clone Adafruit 4682

Modulo a 3 V senza regolatore né traslatore di livello, con pin SDIO esposti: è quello che
serve per un ESP32-S3 a 3,3 V. Per il budget dei pin si userà probabilmente l'SDIO a 1 bit
(vedi `archive/ARCHITECTURE-diy.md #Budget dei pin`).

## 2026-10-07 Tasti sfusi da kit assortito

La basetta con tasti 6×6 occupa più del XIAO stesso. Un kit assortito copre sia la breadboard
(6×6) sia il case (3×6, 4×4).

## 2026-10-07 XIAO ESP32-S3 Plus sia al banco sia nel ciondolo

Il criterio decisivo è il ciclo giornaliero: 16 ore di registrazione consumano circa 800 mAh
e vanno ricaricate in una notte. Il Plus carica a 100 mA (circa 8 ore), XIAO e Sense a 50 mA
(circa 16). Scartati:

- **Sense**: microfono equivalente (SNR 64 contro 65 dB dell'ICS-43434), ma consuma 64,5 mA
  misurati da Seeed in registrazione, quindi le 16 ore non stanno in 1000 mAh, e carica a 50 mA.
- **XIAO standard**: costa solo 0,49 € in meno e ha la ricarica a 50 mA.
- **Super Mini al banco**: risparmia circa 4 €, ma ha meno PSRAM, un altro pinout e un
  caricatore non verificabile. Con la stessa scheda al banco, firmware e misure di consumo
  valgono anche per il ciondolo.
- **XIAO ESP32-C6**: modem-sleep a 30 mA, nessun vantaggio sul Plus, e niente PSRAM.
- **nRF52840/nRF5340** (Omi, Friend): niente WiFi, e 1,8 GB al giorno via BLE non si scaricano.

## 2026-10-07 Un solo microfono ICS-43434, mono

La trascrizione non usa la separazione spaziale e lo stereo raddoppia dati e consumo della SD.
Se ne comprano 3: banco, ciondolo e uno per provare la coppia stereo se serve. Il pin LR
permette di aggiungere il secondo senza pin in più.

## 2026-10-07 microSD di marca standard, non High Endurance

Con 1,8 GB al giorno una scheda da 32 GB fa circa 21 cicli di scrittura completi all'anno,
molto sotto la durata di una TLC di marca. La latenza di scrittura la assorbe la PSRAM. Le
High Endurance costano il doppio (circa 28 € contro 10 € su Amazon) senza un beneficio
misurabile qui.

## 2026-10-07 Retina acustica rimandata al case

Il formato dipende dal diametro e dalla posizione dei fori, che si decidono in M4. Si compra
con i materiali del case.

## 2026-10-07 Ricarica veloce come opzione: TP4057 a 500 mA

Il caricatore del Plus a 100 mA basta per una notte, ma non per i rabbocchi: un'ora in carica
vale circa 2 ore di registrazione. Un modulo TP4057 collegato direttamente alla batteria la
carica a 500 mA, cioè 0,5C come da carica standard dichiarata: 800 mAh in circa 1,6 ore di
fase a corrente costante. L'USB del XIAO resta per programmare, e i due caricatori non vanno
alimentati insieme. Si prova al banco; in M4 si decide se entra nel case. Scartati il TP4056
(ingombro paragonabile al XIAO e 1 A di fabbrica, cioè 1C) e il MCP73831 (su AliExpress solo
chip sfusi).

## 2026-10-08 Revisione con quattro revisori: correzioni alla BOM

INA226 al posto dell'INA219: 16 bit invece di 12, misura meglio la media e la carica integrata
su 16 ore. Aggiunti condensatori di bypass, connettori JST di ricambio e guaina, che
mancavano. Il livello batteria non richiede componenti: il Plus lo espone su GPIO10. Scartata
la preoccupazione sul microfono a 16 kHz: la modalità low power perde 1 dB di SNR e dimezza il
consumo.

## 2026-10-08 RTC DS3231 sul bus I2C

Per un registratore della giornata l'ora dei file è essenziale, e senza RTC si perde a ogni
spegnimento. Il DS3231 mini (13,4 mm per lato, batteria tampone a bordo, 5,59 €) usa i pin I2C
già previsti, liberi nel ciondolo. Scartati il RV-3028 (su AliExpress solo moduli da 14-28 €)
e la sola ricostruzione lato server (buchi tra uno spegnimento e il sync).

## 2026-10-08 Firmware: ESP-IDF, file da 5 minuti, buffer in RAM interna

ESP-IDF per avere controllo su risparmio energetico, SD, NVS cifrata, flash encryption e OTA;
Arduino è costruito sopra e toglie controllo. File da 5 minuti chiusi a ogni rotazione per
reggere gli spegnimenti; buffer di 1-2 s in RAM interna. Corregge l'idea precedente di un
buffer di minuti in PSRAM: non serve per la latenza della SD e si perde se la batteria cede.

## 2026-10-08 Configurazione da rete WiFi propria e pagina web

Il ciondolo accende una sua rete solo su richiesta (pressione lunga, o primo avvio) e la spegne
dopo qualche minuto: tenerla accesa ogni volta che non c'è connessione consumerebbe più della
registrazione. Rete protetta con password per pezzo, captive portal, stessa pagina su
`pendant.local` a casa. Scartate la configurazione via Bluetooth di Espressif (serve la loro
app) e Web Bluetooth (non va su iPhone).

## 2026-10-08 WiFi e SD, non streaming BLE verso il telefono

Confermata l'architettura: lo streaming BLE alla Omi darebbe un oggetto molto più piccolo
(un XIAO nRF52840 Sense con 300 mAh, circa 45-55 € a pezzo) e il riuso del loro software, ma
richiede il telefono vicino tutto il giorno e rinuncia all'audio grezzo, che sono le ragioni
del progetto.

## 2026-10-28 Comprare Omi invece di costruire

Omi fa già quello che serviva al ciondolo: registra tutto il giorno, ha 512 MB di memoria per
l'offline e un'app con firmware open source. Il controllo dei dati, motivo del fai-da-te, si
ottiene lo stesso dirottando l'audio verso Nexus (decisione successiva). Il ciondolo su
ESP32-S3 resta in `docs/archive/`. Supera la decisione del 2026-10-07.

## 2026-10-28 Audio verso Nexus con lo STT personalizzato live dell'app Omi

L'app manda l'audio in tempo reale a un WebSocket nostro, senza scrivere un'app e senza
passare dal cloud Omi (verificato col prototipo, `ARCHITECTURE.md #Esito del prototipo`).
Scartati: il webhook "Realtime audio bytes" (lo spedisce il backend Omi, quindi l'audio passa
da loro), un'app iOS propria via Bluetooth (giorni di lavoro e manutenzione, si rivaluta se
l'app Omi diventa inaffidabile), un ponte fisso Mac o Raspberry (niente live in mobilità), il
backend Omi in proprio (più costoso dell'app propria e non porta a Nexus).

## 2026-10-28 La pausa apre e chiude la conversazione

Il doppio tocco mette in pausa; in pausa l'app chiude la connessione con `CloseStream`, e
quella chiusura è il confine della conversazione in Nexus. Scartati: il timeout di silenzio
(in ufficio qualcuno parla sempre, quindi non scatta mai), la segmentazione con un LLM e il
filtro sulla mia voce (rimandati: servono solo se le pause dimenticate diventano frequenti).

## 2026-10-28 Trascrizione batch a conversazione chiusa, niente live

Un solo passaggio batch con diarizzazione sull'audio intero della conversazione, nella
capability `transcription` di Nexus. Scartati: il live (circa il doppio del costo e
diarizzazione peggiore) e il batch a blocchi da 8 s (ogni blocco diarizza da solo, le
etichette dei parlanti non tornano). Il provider lo decide un confronto su registrazioni vere.

## 2026-10-28 Impostazioni Omi per non passare dal cloud

Audio grezzo a Omi, archivio audio nel cloud e sincronizzazione automatica spenti, e niente
sincronizzazione manuale: sono le quattro strade da cui l'audio raggiungerebbe i server Omi
(`ARCHITECTURE.md #Trasporto: STT personalizzato live`).

## 2026-10-28 Audio offline: recupero manuale

L'audio registrato senza telefono vicino resta nel buffer dell'app, che lo sa sincronizzare
solo verso Omi. Per ora si recupera a mano con "Condividi registrazione". Scartata per ora una
PR a Omi che faccia usare alla sincronizzazione offline l'endpoint personalizzato: giorni di
lavoro su codice loro, da rivalutare se l'offline risulta frequente nell'uso reale.

## 2026-10-28 Vibrazione al doppio tocco: PR a Omi, senza interruttore

Il ciondolo non dà riscontro alle azioni del doppio tocco. Si propone a Omi (PR #23912) di
confermarle tutte con la vibrazione già comandabile via Bluetooth: lunga (300 ms) quando
l'azione accende qualcosa (ripresa, preferito), breve (100 ms) quando spegne o completa (pausa,
preferito tolto, termina ed elabora). Scartata la versione limitata alla pausa: la regola
"la vibrazione conferma l'azione" vale per ogni azione assegnata al tasto.
Niente interruttore nelle impostazioni: il tocco singolo vibra già senza opzione, e un
interruttore vorrebbe traduzioni in tutte le lingue dell'app e la verifica dell'interfaccia.

## 2026-10-29 Omi così com'è, con due limiti accettati

Niente fork dell'app né del firmware, niente app propria. Si accettano due limiti: da
scollegato la pausa non vale (il ciondolo registra nella sua memoria) e l'audio offline non
arriva da solo a Nexus. Si compensano spegnendo il ciondolo quando non si deve registrare e
condividendo a mano le registrazioni offline che servono. Scartati: un'app iOS propria
(Bluetooth in background, protocollo, manutenzione, account sviluppatore da 99 $ l'anno, e
non risolve la pausa, che decide il firmware); il fork dell'app (enorme, legata al backend
Omi, cambia di circa 75 PR al giorno); il fork del firmware (fattibile, la chiave di firma è
nel repo, ma un firmware che rompe il Bluetooth blocca il ciondolo). Le correzioni vere si
chiedono a Omi: issue #20174 e PR #23735.

## 2026-11-26 App iOS nostra al posto dell'app Omi

Un'app iOS nostra riceve l'audio dal ciondolo via Bluetooth e lo manda a Nexus; l'app Omi
resta solo per aggiornare il firmware. Supera la decisione del 2026-10-29 e, quando l'app
sarà in uso, il trasporto con lo STT personalizzato del 2026-10-28. Riaperta perché l'app Omi
accumula copie locali che non rilascia mai (21 h il 26/11), non espone stato, batteria né
pulsante, e i maintainer accettano poche PR. Il protocollo non va più ricostruito: il codice del
firmware 3.0.21 e quello Swift nativo dell'app Omi (MIT) lo danno intero. Serve anche a
decidere se tenere Omi o passare al reSpeaker Clip dopo due settimane d'uso. Scartati: restare
sull'app Omi con PR (troppo lente), il fork dell'app Omi (enorme, legata al loro backend),
comprare subito il Clip (in prevendita, e l'app serve comunque).

## 2026-11-26 Swift nativo, solo iPhone

L'app è in Swift con CoreBluetooth. Il Bluetooth in background e il ripristino dello stato
dopo che iOS chiude l'app si gestiscono direttamente, e il riferimento è già Swift
(`OmiBleManager.swift` dell'app Omi). Scartato Flutter: avrebbe permesso di copiare il Dart
dell'app Omi, ma su iOS anche loro sono passati al Bluetooth nativo, e il livello in più
complica background e debug. Android non serve.

## 2026-11-26 Configurazione da Nexus, niente valori nel codice

Ogni valore di comportamento dell'app (mappa dei gesti, tempi, politica dell'offline,
notifiche, versioni del firmware supportate) sta in una configurazione che l'app scarica da
Nexus. Lo schema con i default e i limiti vive nell'app, che tiene l'ultima configurazione
valida. Nell'app restano solo URL e token. Scartata una schermata di impostazioni nell'app:
due posti dove cambiare le cose, e ogni modifica di default richiederebbe un nuovo build, che
con l'account gratuito scade ogni 7 giorni.

## 2026-11-26 Note col pulsante a tocchi, niente premi e parla

Col firmware 3.0.21 le note si aprono e chiudono con dei tocchi, non tenendo premuto. Il
firmware non manda l'inizio di una pressione, non manda il rilascio di una pressione tenuta, e
a 3 s si spegne (`button.c`). Il premi e parla richiede un firmware modificato: si rivaluta col
Clip o se Omi aggiunge gli eventi di pressione (issue #25872). Scartato ricavare la pressione
dal flusso audio: non ha un inizio affidabile.

## 2026-11-26 Firmware di serie, 3.0.24 solo dal rollout

L'app lavora sul firmware distribuito, oggi il 3.0.21, e usa muto e spegnimento dall'app quando
il 3.0.24 arriva a tutti. Scartato installarlo a mano adesso: Omi lo tiene al 0% di proposito,
e un aggiornamento fallito si recupera solo con un J-Link. Si rivaluta se l'app regge e le
accensioni accidentali restano il problema principale.

## 2026-11-26 Account Apple gratuito per la prova

La prova di due settimane usa il "Personal Team" di Xcode: l'app scade ogni 7 giorni e si
rinnova via Wi-Fi o con SideStore. I 99 $ l'anno si spendono solo se l'app viene tenuta.
Bastano le notifiche locali: quelle che nascono da Nexus vanno su Telegram.
