# Architettura

## Visione d'insieme

Ciondolo indossabile che registra l'audio della giornata, lo salva in locale su microSD e lo
scarica via WiFi quando torna a casa, dove una pipeline lo trascrive e lo indicizza. È un
clone DIY di [Omi](https://www.omi.me), costruito per spendere meno e avere il controllo
completo dei dati: audio grezzo compreso, trascrizione e destinazione scelte da noi.

## Riferimento: Omi

Cosa fa il prodotto da cui partiamo (verificato su omi.me, ottobre 2026):

- Dispositivo a 129 $, pagamento unico, piano gratuito senza abbonamento obbligatorio.
- Autonomia dichiarata 10-14 ore.
- Funziona anche offline e sincronizza dopo. Il dispositivo manda l'audio al telefono via BLE,
  l'app lo fa trascrivere nel cloud e conserva trascrizioni, riassunti e "memorie".
- Firmware, app e backend open source (GitHub `BasedHardware/omi`), backend self-hostable.
- Dichiara SOC 2 e HIPAA. Di default però la trascrizione passa da server terzi: il controllo
  completo si ottiene solo self-hostando.

Differenze volute rispetto a Omi:

- **Offline-first**: si registra su microSD, non in streaming BLE verso il telefono. Niente
  dipendenza dal telefono durante la giornata.
- **Audio grezzo conservato**: la trascrizione è un derivato rigenerabile, l'audio è la fonte.
- **Pipeline nostra**: modello di trascrizione e destinazione dei dati (es. Nexus) li
  scegliamo noi.

## Componenti

- **Dispositivo** (`hardware/`, `firmware/`, da creare): Seeed XIAO ESP32-S3 Plus, microfono
  MEMS I2S ICS-43434, microSD, LiPo, tasto, LED, interruttore. Registra, bufferizza in PSRAM,
  scrive su SD a blocchi.
- **Sync** (firmware + endpoint di casa): a casa il dispositivo si collega al WiFi e carica i
  file nuovi su un ricevitore locale (Mac o server). Da progettare.
- **Pipeline** (`server/`, da creare): trascrizione, diarizzazione, riassunti, archiviazione.
  Candidati: Whisper in locale o API, Nexus come destinazione. Da decidere.

## Due prototipi, stessa scheda

| | Banco (breadboard) | Ciondolo |
|---|---|---|
| Scheda | XIAO ESP32-S3 Plus con pin header | XIAO ESP32-S3 Plus, fili saldati |
| Scopo | firmware, misura consumi con INA219 | dispositivo indossabile |

Stessa scheda sui due prototipi: pin, PSRAM, caricatore e consumi misurati al banco valgono
anche per il ciondolo. Il perché della scelta è in `DECISIONS.md`.

## Budget dei pin (XIAO ESP32-S3 Plus, 11 GPIO sui lati)

| Funzione | Pin con SD a 4 bit | Pin con SD a 1 bit |
|---|---|---|
| microSD SDIO (CLK, CMD, D0..D3) | 6 | 3 |
| Microfono I2S (BCLK, WS, DATA; un secondo microfono condivide DATA come canale R) | 3 | 3 |
| Tasto | 1 | 1 |
| LED | 1 | 1 |
| INA219 (I2C), solo banco | 2 | 2 |
| **Totale** | **13, solo con i pin castellati** | **10, ci sta sui lati** |

La banda non giustifica l'SDIO a 4 bit: un canale a 16 kHz e 16 bit fa 32 KB/s, mentre
l'SDIO a 1 bit regge qualche MB/s. Il problema reale della SD sono i picchi di latenza in
scrittura (centinaia di ms), che si assorbono con gli 8 MB di PSRAM (oltre 4 minuti di audio
mono), non con più linee dati. Il Plus ha altri 9 GPIO su pin castellati a passo 1,27 mm,
da saldare, usabili se il budget sui lati non basta.

### Assegnazione proposta, da confermare al banco

| Pin | GPIO | Uso |
|---|---|---|
| D0 | 1 | Tasto verso GND, pull-up interno |
| D1, D2, D3 | 2, 3, 4 | Microfono I2S: BCLK, WS, DATA |
| D4, D5 | 5, 6 | I2C per l'INA219, solo banco |
| D6 | 43 | Libero |
| D7 | 44 | LED con resistenza da 1 kΩ |
| D8, D9, D10 | 7, 8, 9 | SD: CLK, DAT0, CMD |

Il LED sta su D7 e non su D6 perché D6 è il TX della UART0, dove il bootloader scrive
all'avvio. Il caricatore opzionale va sulla batteria prima dell'interruttore, così carica anche
a ciondolo spento. Schema e disegni in `docs/pendant.html`.

## Numeri di riferimento

- **Dati**: PCM mono 16 kHz 16 bit = 32 KB/s, circa 115 MB/ora, circa 1,8 GB per 16 ore.
  Con compressione (ADPCM, Opus) si scende di 4-10 volte. Una microSD da 32 GB tiene circa
  17 giorni di PCM.
- **Consumi dichiarati da Seeed** a 3,8 V ([wiki](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/)):
  modem-sleep (CPU attiva, radio spenta) 27 mA sul XIAO, 31,6 mA sul Plus, 44 mA sul Sense.
  Registrazione con microfono e scrittura su SD misurata sul Sense: 64,5 mA medi, 109,3 mA
  di picco.
- **Autonomia**: stima 45-55 mA medi sul Plus con WiFi spento, quindi 720-880 mAh in 16 ore.
  La 1000 mAh ci sta con circa il 10-30% di margine. È una congettura: va misurata con
  l'INA219 al banco.
- **Ricarica** (stessa fonte): 100 mA sul Plus, 50 mA su XIAO e Sense. Una giornata da 800
  mAh si ricarica in circa 8 ore sul Plus e in 16 sul XIAO.

## Rischi aperti

- **Autonomia sotto le 16 ore** se il consumo misurato supera i 60 mA: leve in ordine sono
  CPU a 80 MHz, buffer più grandi con scritture più rare, batteria più grande.
- **Polarità JST**: sulle LiPo AliExpress non è garantita. Verificare col multimetro prima di
  collegare.
- **Acustica**: microfono dentro un case, sotto i vestiti. Retina acustica e posizione dei fori
  vanno provate.
- **Privacy e legge**: registrare conversazioni a cui si partecipa è lecito in Italia, diffonderle
  no. Un ciondolo perso espone le registrazioni: valutare la cifratura su SD.

## Boundary

- Il dispositivo registra e trasferisce file. Non trascrive e non interpreta.
- La pipeline non dipende dal formato fisico della SD: riceve file audio con metadati
  (timestamp di inizio, durata, id dispositivo).
