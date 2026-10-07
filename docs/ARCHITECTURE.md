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

- **Dispositivo** (`hardware/`, `firmware/`, da creare): ESP32-S3, 2 microfoni MEMS I2S,
  microSD, LiPo, tasto, LED, interruttore. Registra, bufferizza in PSRAM, scrive su SD a blocchi.
- **Sync** (firmware + endpoint di casa): a casa il dispositivo si collega al WiFi e carica i
  file nuovi su un ricevitore locale (Mac o server). Da progettare.
- **Pipeline** (`server/`, da creare): trascrizione, diarizzazione, riassunti, archiviazione.
  Candidati: Whisper in locale o API, Nexus come destinazione. Da decidere.

## Due prototipi

| | Banco (breadboard) | Ciondolo |
|---|---|---|
| Scheda | ESP32-S3 Super Mini (clone Tenstar, 3,90 €) | Seeed XIAO ESP32-S3 |
| Scopo | firmware, misura consumi con INA219 | dispositivo indossabile |
| Ricarica | da verificare se integrata | integrata (vedi sotto) |
| Pin | più GPIO liberi | 11 GPIO, vincolo stretto |

## Budget dei pin (XIAO ESP32-S3, 11 GPIO)

| Funzione | Pin con SD a 4 bit | Pin con SD a 1 bit |
|---|---|---|
| microSD SDIO (CLK, CMD, D0..D3) | 6 | 3 |
| Microfoni I2S (BCLK, WS, DATA condiviso L/R) | 3 | 3 |
| Tasto | 1 | 1 |
| LED | 1 | 1 |
| INA219 (I2C) | 2 | 2 |
| **Totale** | **13, non ci sta** | **10, ci sta** |

La banda non giustifica l'SDIO a 4 bit: 2 canali a 16 kHz e 16 bit fanno 64 KB/s, mentre
l'SDIO a 1 bit regge qualche MB/s. Il problema reale della SD sono i picchi di latenza in
scrittura (centinaia di ms), che si assorbono con il buffer in PSRAM, non con più linee dati.
L'INA219 serve solo al banco per misurare i consumi: sul ciondolo non è necessario.

Con il XIAO Sense il conto cambia: lo slot SD della scheda aggiuntiva è in SPI su D8-D10
(GPIO7, 8, 9) più GPIO21, e il microfono PDM usa GPIO41 e 42, non esposti. Dei pin laterali
la SD ne occupa 3 e il microfono nessuno
([wiki Seeed](https://wiki.seeedstudio.com/xiao_esp32s3_sense_mic/)). Il XIAO Plus ha gli
stessi pin laterali più piazzole sotto la scheda.

## Numeri di riferimento

- **Dati**: PCM mono 16 kHz 16 bit = 32 KB/s, circa 115 MB/ora, circa 1,8 GB per 16 ore.
  In stereo il doppio. Con compressione (ADPCM, Opus) si scende di 4-10 volte.
- **Autonomia**: stima a 40-50 mA medi con WiFi spento, quindi circa 20 ore con 1000 mAh.
  È una congettura: va misurata con l'INA219 al banco.
- **Ricarica XIAO**: Seeed dichiara 50 mA nel datasheet e 100 mA nel wiki. Con 1000 mAh
  significa 10-20 ore di ricarica. Se è troppo lento serve un caricatore esterno (TP4056) o
  una batteria più piccola.

## Rischi aperti

- **Ricarica**: lenta sul XIAO, forse assente sulla Super Mini.
- **Polarità JST**: sulle LiPo AliExpress non è garantita. Verificare col multimetro prima di
  collegare.
- **Microfoni**: il modulo "mini" monta un ICS-43434 (confermato dal listing). Con il Sense
  il microfono è il PDM integrato MSM261D3526H1CPM, mono: qualità da confrontare al banco.
- **Acustica**: microfoni dentro un case, sotto i vestiti. Retina acustica e posizione dei fori
  vanno provate.
- **Privacy e legge**: registrare conversazioni a cui si partecipa è lecito in Italia, diffonderle
  no. Un ciondolo perso espone le registrazioni: valutare la cifratura su SD.

## Boundary

- Il dispositivo registra e trasferisce file. Non trascrive e non interpreta.
- La pipeline non dipende dal formato fisico della SD: riceve file audio con metadati
  (timestamp di inizio, durata, id dispositivo).
