# Roadmap

## Stato corrente

Architettura e componenti principali scelti. Carrello AliExpress da sistemare, ricerca dei
componenti mancanti da fare. Nessun codice.

## Prossime milestone

- [ ] M0 Acquisti: scelta del ciondolo (Sense o Plus + moduli), carrello allineato a
  `BOM.md`, ordine fatto.
- [ ] M1 Banco: Super Mini + 1 microfono + SD, registrazione WAV su SD, consumi misurati
  con INA219.
- [ ] M2 Firmware: 2 microfoni, tasto start/stop, LED di stato, buffer in PSRAM, rotazione
  dei file con timestamp, risparmio energetico.
- [ ] M3 Sync e pipeline: upload via WiFi a casa, trascrizione, destinazione dei dati.
- [ ] M4 Ciondolo: XIAO, saldature, batteria, case e acustica.

## Domande aperte

- Ciondolo: XIAO Sense (tutto integrato, mono) o XIAO Plus + 2 ICS-43434 + slot SD.
  Confronto prezzi in `BOM.md`.
- Framework firmware: ESP-IDF o Arduino (PlatformIO).
- Formato audio su SD: PCM, ADPCM o Opus. Mono o stereo.
- Trascrizione: Whisper locale o API. Destinazione: Nexus o archivio dedicato.
- Cifratura dei file su SD.
