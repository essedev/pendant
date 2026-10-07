# Decisioni

## 2026-10-07 Costruire invece di comprare Omi

Omi costa 129 $ ed è open source, ma di default passa dal telefono e dal cloud e conserva
soprattutto trascrizioni. Lo costruiamo per spendere meno e avere un dispositivo custom:
registrazione offline su microSD, audio grezzo conservato, pipeline di trascrizione nostra.

## 2026-10-07 Due schede: Super Mini al banco, XIAO nel ciondolo

La Super Mini costa 3,90 € e ha più pin, ma la ricarica è incerta, ha LED che consumano sempre
e qualità variabile tra lotti. Il XIAO ha ricarica integrata, documentazione e qualità costante.
Super Mini per sviluppare il firmware, XIAO per l'indossabile.

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
