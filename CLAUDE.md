# pendant - Istruzioni per Claude

## Cos'è

Ciondolo registratore audio basato su ESP32-S3: registra su microSD, sincronizza via WiFi,
la trascrizione avviene a valle. Clone DIY di Omi. Progetto personale, trunk-based su main.

## Stato

Progettazione e acquisti. Ancora nessun `firmware/` né `server/`: quando nascono, aggiungere
qui comandi e Makefile.

## Dove sta cosa

- `docs/ARCHITECTURE.md`: componenti, budget dei pin, numeri di consumo e dati, rischi.
- `docs/BOM.md`: componenti, prezzi, stato degli acquisti. Fonte di verità per il carrello.
- `docs/DECISIONS.md`: scelte fatte e perché.
- `docs/ROADMAP.md`: milestone e domande aperte.

## Gotcha

- Il XIAO ESP32-S3 ha 11 GPIO: ogni periferica nuova va verificata contro il budget dei pin
  in `ARCHITECTURE.md` prima di proporla.
- Prezzi e specifiche AliExpress cambiano e sono spesso inaffidabili: ogni dato in BOM va
  riportato con fonte (link) e data di rilevazione.
- La ricerca prezzi su AliExpress richiede la sessione loggata di Simone (spedizione, dazi,
  pagina "My picks"): non fidarsi dei prezzi visti da sessione anonima.
