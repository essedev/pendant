# Roadmap

## Stato corrente

Architettura e BOM chiuse, ordine da fare. Nessun codice.

## Prossime milestone

- [ ] M0 Acquisti: carrello allineato a `BOM.md #Da ordinare`, ordine fatto.
- [ ] M1 Banco: XIAO Plus + 1 microfono + SD + RTC, registrazione su SD a file da 5 minuti,
  consumi misurati con INA226, throughput WiFi, caduta sull'interruttore, pull-up della SD.
- [ ] M2 Firmware: tasto, LED di stato, ora da RTC, livello batteria, spegnimento controllato,
  risparmio energetico, compressione sì/no, pagina di configurazione.
- [ ] M3 Sync e pipeline: upload via WiFi a casa, trascrizione, destinazione dei dati.
- [ ] M4 Ciondolo: XIAO Plus, saldature, batteria, case e acustica.

## Domande aperte

- Formato audio su SD: PCM, ADPCM o Opus.
- Trascrizione: Whisper locale o API. Destinazione: Nexus o archivio dedicato.
- Cifratura dei file su SD e flash encryption: da decidere prima di M1 (non reversibile).
- Trigger del sync e alimentazione durante l'upload: da misurare al banco.
