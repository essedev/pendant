# Convenzioni

## Generali

- Identificatori e commenti di codice in inglese, documentazione in italiano.
- Unità sempre esplicite: mA, mAh, kHz, KB/s, $/h.
- Dati di terzi (prezzi, comportamenti dell'app Omi, misure) con fonte e data di rilevazione.

## App iOS

- Swift e SwiftUI, solo iPhone. Il progetto Xcode lo crea Xcode; la logica sta in un pacchetto
  Swift locale dentro `app/`, così il file di progetto cambia di rado e la logica si testa con
  `swift test` senza iPhone.
- Nessun valore di comportamento nel codice: ogni tempo, soglia o mappa entra nello schema della
  configurazione con default e limiti.
- Il protocollo del ciondolo in un solo modulo, con i riferimenti al codice del firmware
  (`file:riga` al tag della versione).
- Il codice preso dall'app Omi (licenza MIT) cita file e commit d'origine.

## Prototipi

- Script Python autonomi con dipendenze inline (`# /// script`), lanciati con `uv run`.
- Le registrazioni contengono voci vere: si scrivono solo in `prototype/recordings/`, ignorata
  da git.
