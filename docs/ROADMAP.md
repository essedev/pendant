# Roadmap

## Stato corrente

Architettura e BOM chiuse, ordine da fare. Nessun codice.

## Prossime milestone

- [ ] M0 Acquisti: carrello allineato a `BOM.md #Da ordinare`, ordine fatto.
- [ ] M1 Banco: XIAO Plus + 1 microfono + SD, registrazione WAV su SD, consumi misurati
  con INA219.
- [ ] M2 Firmware: tasto start/stop, LED di stato, buffer in PSRAM, rotazione
  dei file con timestamp, risparmio energetico.
- [ ] M3 Sync e pipeline: upload via WiFi a casa, trascrizione, destinazione dei dati.
- [ ] M4 Ciondolo: XIAO Plus, saldature, batteria, case e acustica.

## Domande aperte

- Framework firmware: ESP-IDF o Arduino (PlatformIO).
- Formato audio su SD: PCM, ADPCM o Opus.
- Trascrizione: Whisper locale o API. Destinazione: Nexus o archivio dedicato.
- Cifratura dei file su SD.
