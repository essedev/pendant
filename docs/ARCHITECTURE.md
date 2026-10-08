# Architettura

## Visione d'insieme

Ciondolo indossabile che registra l'audio della giornata, lo salva in locale su microSD e lo
scarica via WiFi quando torna a casa, dove una pipeline lo trascrive e lo indicizza. È un
clone DIY di [Omi](https://www.omi.me), costruito per avere il controllo completo dei dati:
registrazione senza telefono, audio grezzo conservato, trascrizione e destinazione scelte da
noi. Costa anche meno di Omi, ma il risparmio sul primo pezzo è piccolo e non è la ragione.

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
  MEMS I2S ICS-43434, microSD, RTC DS3231, LiPo, tasto, LED, interruttore. Firmware in
  ESP-IDF. Registra, bufferizza 1-2 s in RAM interna, scrive su SD a blocchi grandi.
- **Sync** (firmware + endpoint di casa): a casa il dispositivo si collega al WiFi e carica i
  file nuovi su un ricevitore locale (Mac o server). Vedi `#Sync e configurazione`.
- **Pipeline** (`server/`, da creare): trascrizione, diarizzazione, riassunti, archiviazione.
  Candidati: Whisper in locale o API, Nexus come destinazione. Da decidere.

## Due prototipi, stessa scheda

| | Banco (breadboard) | Ciondolo |
|---|---|---|
| Scheda | XIAO ESP32-S3 Plus con pin header | XIAO ESP32-S3 Plus, fili saldati |
| Scopo | firmware, misura consumi con INA226 | dispositivo indossabile |

Stessa scheda sui due prototipi: pin, PSRAM, caricatore e consumi misurati al banco valgono
anche per il ciondolo. Il perché della scelta è in `DECISIONS.md`.

## Budget dei pin (XIAO ESP32-S3 Plus, 11 GPIO sui lati)

| Funzione | Pin con SD a 4 bit | Pin con SD a 1 bit |
|---|---|---|
| microSD SDIO (CLK, CMD, D0..D3) | 6 | 3 |
| Microfono I2S (BCLK, WS, DATA; un secondo microfono condivide DATA come canale R) | 3 | 3 |
| Tasto | 1 | 1 |
| LED | 1 | 1 |
| I2C: RTC DS3231 (0x68) e, solo al banco, INA226 (0x40) | 2 | 2 |
| **Totale** | **13, solo con i pin castellati** | **10, ci sta sui lati** |

La banda non giustifica l'SDIO a 4 bit: un canale a 16 kHz e 16 bit fa 32 KB/s, mentre
l'SDIO a 1 bit regge qualche MB/s. Il problema reale della SD sono i picchi di latenza in
scrittura (centinaia di ms), che si assorbono con un buffer di 1-2 s (64-128 KB) in RAM
interna, non con più linee dati. Un buffer più lungo non serve e si perde se la batteria cede.
Il Plus ha altri 9 GPIO su pin castellati a passo 1,27 mm, da saldare, usabili se il budget
sui lati non basta. Uno di questi, D16 (GPIO10), è collegato alla batteria come `ADC_BAT`
([wiki Seeed](https://wiki.seeedstudio.com/xiao_esp32s3_getting_started/)): il livello
batteria si legge senza componenti, il rapporto del partitore va misurato.

### Assegnazione proposta, da confermare al banco

| Pin | GPIO | Uso |
|---|---|---|
| D0 | 1 | Tasto verso GND, pull-up interno |
| D1, D2, D3 | 2, 3, 4 | Microfono I2S: BCLK, WS, DATA |
| D4, D5 | 5, 6 | I2C: RTC DS3231, più INA226 al banco |
| D6 | 43 | Libero |
| D7 | 44 | LED con resistenza da 1 kΩ |
| D8, D9, D10 | 7, 8, 9 | SD: CLK, DAT0, CMD |
| D16 (castellato) | 10 | Lettura tensione batteria (`ADC_BAT`) |

Il LED sta su D7 e non su D6 perché D6 è il TX della UART0, dove il bootloader scrive
all'avvio. La SD sull'S3 accetta qualsiasi GPIO tramite la matrice
([ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-reference/peripherals/sdmmc_host.html)),
ma vuole pull-up da 10 kΩ su CMD e DAT0-3: il modulo Adafruit li dichiara, sul clone vanno
misurati. Il caricatore opzionale va sulla batteria prima dell'interruttore, così carica anche
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
  l'INA226 al banco.
- **Ricarica** (stessa fonte): 100 mA sul Plus, 50 mA su XIAO e Sense. Una giornata da 800
  mAh si ricarica in circa 8 ore sul Plus e in 16 sul XIAO.
- **Microfono a 16 kHz**: l'ICS-43434 lavora in modalità low power (6,25-18,75 kHz), SNR
  64 dBA invece di 65, 230 µA invece di 490 ([datasheet](https://www.cdiweb.com/datasheets/invensense/ds-000069-ics-43434-v1.0-2.pdf)).
- **Sync**: throughput WiFi dell'S3 misurato in rete tra 4,5 e 9 Mbps
  ([esp32.com](https://esp32.com/viewtopic.php?p=101785)): 1,8 GB di PCM sono 25-55 minuti,
  con Opus a 16 kbps (circa 115 MB al giorno) pochi minuti. Va misurato in M1.

## Formato, ora e robustezza

- **File da 5 minuti** (circa 9,6 MB in PCM), chiusi e sincronizzati su SD a ogni rotazione:
  FatFS ha bassa resilienza agli spegnimenti
  ([ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/v5.4.4/esp32s3/api-guides/file-system-considerations.html)),
  un file lungo aperto per ore è il caso peggiore. FAT32 sulla scheda da 32 GB.
- **Header WAV riparabile**: dimensione scritta solo alla chiusura; se il file resta aperto,
  il server la ricostruisce dalla lunghezza.
- **Spegnimento controllato**: sotto circa 3,4 V letti da `ADC_BAT` il firmware chiude il file
  e smette di registrare.
- **Ora**: RTC DS3231 con batteria tampone sul bus I2C, rimesso via NTP a casa e dall'ora del
  browser quando si apre la pagina di configurazione. Senza RTC l'ora si perderebbe a ogni
  spegnimento con l'interruttore.
- **Compressione**: Opus o ADPCM da valutare in M2 misurando CPU e consumo. Riduce di 4-16
  volte dati, scritture e tempo di sync.
- **Cifratura**: per file, con l'acceleratore AES; la cifratura della flash va decisa prima di
  M1 perché non è reversibile.

## Sync e configurazione

- **Upload**: HTTP PUT per file con SHA-256, server idempotente che risponde con l'hash
  ricevuto. Il dispositivo cancella solo dopo la conferma e tiene comunque gli ultimi giorni
  finché la SD non si riempie. Server trovato via mDNS.
- **Quando**: sulla rete di casa e con l'USB del XIAO collegato. Se in quel caso il carico è
  alimentato dall'USB o dalla batteria va verificato al banco (schema non pubblicato).
- **Configurazione**: con una pressione lunga del tasto, o al primo avvio senza reti salvate,
  il ciondolo accende una propria rete WiFi protetta da password (diversa per ogni pezzo) e
  apre una pagina web via captive portal. La rete si spegne dopo qualche minuto senza utenti;
  la registrazione continua. Dalla pagina: reti WiFi salvate, indirizzo e token del server,
  stato (batteria, SD, ultimo sync), ora dal browser, aggiornamento del firmware, reset. La
  stessa pagina è raggiungibile su `pendant.local` quando il ciondolo è sulla rete di casa.

## Case (proposta per M4)

Sandwich di due lastre fumé da 2 mm (acrilico, o policarbonato se si temono cadute) con una
cornice laterale in TPU stampata in 3D, tenuto da 4 viti M2 su distanziali negli angoli,
fuori dalla batteria. Misure circa 62 × 46 × 15,5 mm con angoli da 5 mm di raggio: con 60 × 44
e angoli più tondi i distanziali Ø 3,5 mm toccherebbero la cella. Peso stimato 40-45 g. Dentro: 1 mm di
gioco e uno strato di schiuma per il rigonfiamento della LiPo, spazio per il connettore della
batteria. Porta acustica di circa 1,5 mm con guarnizione senza fughe, in un incavo della
faccia e lontana dal laccio; LED con foro o light pipe; sgancio di sicurezza sul laccio. Le
quote acustiche sono ipotesi da verificare sulle application note TDK e al banco.

## Rischi aperti

- **Autonomia sotto le 16 ore** se il consumo misurato supera i 60 mA: leve in ordine sono
  CPU a 80 MHz, buffer più grandi con scritture più rare, batteria più grande.
- **Polarità JST**: sulle LiPo AliExpress non è garantita. Verificare col multimetro prima di
  collegare.
- **LiPo indossata**: rigonfiamento e schiacciamento. Gioco e schiuma nel case, Kapton tra
  cella ed elettronica.
- **Due caricatori sulla stessa batteria** (con il TP4057): un solo cavo USB per volta, e la
  carica veloce a ciondolo spento, altrimenti la carica può non terminare e il modulo dissipa
  fino a circa 1 W vicino alla cella.
- **Interruttore SS12D00**: portata dei cloni tra 0,2 e 0,5 A contro picchi WiFi di centinaia
  di mA. Misurare la caduta al banco.
- **Acustica**: microfono dentro un case, sotto i vestiti. Retina acustica e posizione dei fori
  vanno provate.
- **Privacy e legge**: registrare conversazioni a cui si partecipa è lecito in Italia, diffonderle
  no. Un ciondolo perso espone le registrazioni: valutare la cifratura su SD.

## Boundary

- Il dispositivo registra e trasferisce file. Non trascrive e non interpreta.
- La pipeline non dipende dal formato fisico della SD: riceve file audio con metadati
  (timestamp di inizio, durata, id dispositivo).
