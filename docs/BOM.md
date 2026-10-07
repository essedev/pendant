# Distinta componenti (BOM)

Stato degli acquisti per banco e ciondolo. Prezzi letti dalla sessione AliExpress loggata
(spedizione verso Varese, IVA inclusa, dazi calcolati al checkout). "Sped." è la tariffa
standard del singolo store: articoli dello stesso store possono condividerla, il totale vero
lo dà il checkout.

## Ciondolo: due configurazioni a confronto

Rilevati il 2026-10-07. La scelta è aperta (vedi `ROADMAP.md`).

| Configurazione | Componenti | Totale per 1 pezzo |
|---|---|---|
| **Plus + moduli** | XIAO ESP32-S3 Plus 9,04 € + 5,05 € sped. ([Seeed](https://www.aliexpress.com/item/1005008329745247.html)); 2 microfoni ICS-43434 7,18 € + 4,69 € sped.; slot SD 3,40 € | circa 29,40 € più la spedizione della SD |
| **Sense** | XIAO ESP32-S3 Sense con fotocamera OV3660, 15,60 € + 6,70 € sped. ([Seeed](https://www.aliexpress.com/item/1005006988111963.html)). Alternativa: 17,09 € + 5,06 € ([Your Cee](https://www.aliexpress.com/item/1005005386944262.html), variante "ESP32S3 Sense Module") | circa 22,30 € |

Il XIAO standard costa 8,55 € + 5,05 € sped. ([Seeed](https://www.aliexpress.com/item/1005007341749305.html)):
il Plus costa solo 0,49 € in più, quindi il XIAO standard non ha più motivo di essere scelto.

## Componenti verificati

| Componente | Scelta | Prezzo (2026-10-07) | Stato | Note |
|---|---|---|---|---|
| Microfoni | [Modulo mini ICS-43434](https://www.aliexpress.com/item/1005012141271976.html), Yeteng Global Technology Store | 3,59 €/pz + 4,69 € sped. | nel carrello (1 pz) | Chip ICS-43434 confermato dalle foto, pin LR per la coppia stereo. Store con 21 vendite e 2 recensioni. Nel carrello c'è anche un [ICS-43434 WCMCU](https://www.aliexpress.com/item/1005008740947486.html) a 6,81 €, doppione da togliere. |
| Slot microSD | [Clone Adafruit 4682](https://www.aliexpress.com/item/1005010386227173.html), "3V only", pin SDIO esposti | 3,40 € | da aggiungere | Spedito con la logistica AliExpress, spedizione gratuita da 10 €. Non è più nel carrello. Serve solo con la configurazione Plus. |
| Batteria | [LiPo 503450 1000 mAh](https://www.aliexpress.com/item/1005004375261361.html), YouTu Four Battery Store | 4,69 € + 3,63 € sped. | nel carrello | Il listing dichiara PCM con protezione da sovraccarica, scarica e corto. Connettore JST PH 2,0 mm. Polarità da misurare all'arrivo. |
| MCU banco | [ESP32-S3 Super Mini](https://www.aliexpress.com/item/1005005757810089.html), variante "ESP32 S3 Supermini" | 4,79 € | da decidere | Logistica AliExpress, spedizione gratuita da 10 €. La foto ha le piazzole B+/B- e la serigrafia BAT, ma il chip del caricatore non è verificabile. Al banco non conta: si alimenta da USB. |
| XIAO nel carrello | [Jessinie](https://www.aliexpress.com/item/1005005556287360.html) 9,69 € + 4,44 € sped. | | da togliere | Lo store Seeed costa meno ed è ufficiale. La versione da 24,50 € citata in passato non è più nel carrello. |
| Breadboard | 400 o 830 punti | circa 2 € | da aggiungere | La SYB-170 è troppo piccola. |

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
| microSD High Endurance | Da Amazon, non AliExpress (falsi frequenti). Con il Sense, Seeed dichiara un massimo di 32 GB FAT32. |

## Scartati o condizionati

| Componente | Perché |
|---|---|
| XIAO ESP32-S3 standard | Il Plus costa 0,49 € in più e toglie il vincolo sui pin. |
| TP4056 | Solo se la ricarica del XIAO misurata risulta sotto i 100 mA. |
| Basetta con tasti 6×6 | Troppo ingombrante per il ciondolo e inutile sulla breadboard. |
