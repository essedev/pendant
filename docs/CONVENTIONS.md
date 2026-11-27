# Convenzioni

## Generali

- Identificatori e commenti di codice in inglese, documentazione in italiano.
- Unità sempre esplicite: mA, mAh, kHz, KB/s, $/h.
- Dati di terzi (prezzi, comportamenti dell'app Omi, misure) con fonte e data di rilevazione.

## App iOS

- Swift e SwiftUI, solo iPhone, tutto da riga di comando: il progetto Xcode lo genera XcodeGen
  da `app/project.yml` (il `.xcodeproj` non è versionato), build e installazione passano da
  `app/Makefile`. Il team di firma sta in `app/Local.xcconfig`, ignorato da git.
- La logica sta nel pacchetto Swift locale `app/PendantKit`, testabile con `swift test` senza
  iPhone; il target dell'app resta sottile.
- Formattazione con `swift format` (quello della toolchain), controllata da `make lint`.
- Nessun valore di comportamento nel codice: ogni tempo, soglia o mappa entra nello schema della
  configurazione con default e limiti.
- Il protocollo del ciondolo in un solo modulo, con i riferimenti al codice del firmware
  (`file:riga` al tag della versione).
- Il codice preso dall'app Omi (licenza MIT) cita file e commit d'origine.
- Versione in `app/project.yml`: la minore sale a ogni milestone (M5 0.2, M6 0.3, M7 0.4), la
  patch a ogni giro di correzioni installato sul telefono dentro la stessa milestone; il numero
  di build sale con la versione.
- Spazi (`Theme.Gutter`, `Theme.pageTop`): tre margini laterali per ruolo, mai un numero a mano.
  16 punti per ciò che ha un fondo (display, tasti, celle, card), 24 per i titoli di pagina e i
  blocchi liberi (la giornata), 32 per il testo dentro le celle e per quello che accompagna un
  gruppo (intestazioni, note, suggerimenti). In verticale 28 prima di un gruppo con intestazione,
  20 senza e all'inizio di una pagina interna, 8 fra un gruppo e la sua nota. Il primo avvio
  tiene il contenuto a 24 e allarga le superfici a 16, come nell'app.

## Prototipi

- Script Python autonomi con dipendenze inline (`# /// script`), lanciati con `uv run`.
- Le registrazioni contengono voci vere: si scrivono solo in `prototype/recordings/`, ignorata
  da git.
