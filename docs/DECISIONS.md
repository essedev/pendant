# Decisioni

## 2026-10-07 Costruire invece di comprare Omi

Omi costa 129 $ ed è open source, ma di default passa dal telefono e dal cloud e conserva
soprattutto trascrizioni. Lo costruiamo per spendere meno e avere un dispositivo custom:
registrazione offline su microSD, audio grezzo conservato, pipeline di trascrizione nostra.

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
(vedi `ARCHITECTURE.md #Budget dei pin`).

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
