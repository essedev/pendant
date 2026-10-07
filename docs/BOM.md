# Distinta componenti (BOM)

Stato degli acquisti per banco e ciondolo. Prezzi AliExpress spedizione inclusa dove indicato,
rilevati prima della ricerca strutturata: vanno riverificati.

## Nel carrello o già scelti

| Componente | Scelta | Prezzo | Stato | Note |
|---|---|---|---|---|
| MCU ciondolo | Seeed XIAO ESP32-S3, store ufficiale Seeed | 8,55 € | da sostituire | Nel carrello "My picks" c'è una versione a 24,50 €: toglierla. Prenderne 2. Alternativa: Jessinie 9,69 € + 4,44 € sped. |
| MCU banco | ESP32-S3 Super Mini (Tenstar), ESP32-S3FH4R2 | 3,90 € | da aggiungere | 4 MB flash, 2 MB PSRAM. Verificare se ha un vero caricatore LiPo. LED sempre acceso da dissaldare. |
| Slot microSD | Clone Adafruit 4682, "3V only", pin SDIO esposti | 3,39 € | nel carrello | Si ordina solo da "My picks": verificare che spedizione gratuita e dazi restino validi dopo aver tolto l'ESP32 da 24,50 €. |
| Microfoni | Modulo MEMS I2S "mini" ×3 | 16,00 € (con 6,23 € sped.) | scelto | Più piccoli ed economici dei 3 "Choice" grandi (20,43 €). Modello esatto da confermare. |
| Batteria | LiPo 503450 1000 mAh, circa 5 × 34 × 50 mm | 4,69 € | scelto | La più sottile a parità di capacità. Deve avere PCM ("protection board"). Polarità JST da verificare. |
| Breadboard | 400 o 830 punti | circa 2 € | da aggiungere | La SYB-170 nel carrello è troppo piccola. |

## Mancanti

| Componente | Note |
|---|---|
| Kit tasti tattili assortiti | "tactile switch assortment kit", 1-2 €. 6×6 per il banco, 3×6 o 4×4 per il case. Pull-up interno, niente resistenze. |
| Kit resistenze | |
| LED | |
| Interruttore a slitta | Spegnimento fisico della batteria. |
| Modulo INA219 | Solo banco, misura consumi. |
| Filo sottile | Per i collegamenti nel ciondolo. |
| Nastro Kapton | Isolamento batteria e saldature. |
| Retina acustica | Davanti ai fori dei microfoni. |
| microSD High Endurance | Da Amazon, non AliExpress (falsi frequenti). |

## Da valutare

| Componente | Perché |
|---|---|
| Seeed XIAO ESP32-S3 Plus | 18 GPIO invece di 11, 16 MB flash, ricarica dichiarata 100 mA, circa 9-10 $. Elimina il vincolo sui pin, ma i GPIO extra sono piazzole da saldare sotto la scheda. |
| Seeed XIAO ESP32-S3 Sense | Microfono digitale e slot SD integrati sulla scheda aggiuntiva. Meno saldature, ma più spessa e deep sleep da 3 mA invece di 14 µA. |
| TP4056 | Solo se la Super Mini non ha caricatore o la ricarica del XIAO risulta troppo lenta. |
| Basetta con tasti 6×6 | Scartata: troppo ingombrante per il ciondolo e inutile sulla breadboard. |
