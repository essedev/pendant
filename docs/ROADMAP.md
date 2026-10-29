# Roadmap

## Stato corrente

Omi in uso. Il trasporto dell'audio verso un endpoint nostro è verificato col prototipo
(28/10/2026), la PR della vibrazione è aperta e l'ingest in Nexus è progettato (repo `nexus`,
`docs/features/audio-stream.md`, DECISIONS #97). Prossimo: il codice dell'extension in Nexus.

## Prossime milestone

- [x] M0 Prototipo del trasporto: 7 verifiche, esito in `ARCHITECTURE.md #Esito del prototipo`.
- [x] M1 PR vibrazione: [BasedHardware/omi#23912](https://github.com/BasedHardware/omi/pull/23912)
  (28/10/2026), conferma ogni azione del doppio tocco. In attesa di revisione; si sovrappone
  alla #18765 (tasti personalizzabili, approvata) e va riallineata se quella entra prima.
- [ ] M2 Confronto provider: 2-3 registrazioni vere su Mistral, Speechmatics Melia 1 ed
  Enhanced. Spesa stimata sotto 1 $, da approvare prima del lancio.
- [ ] M3 Ingest in Nexus, progettato il 28/10 (`nexus/docs/features/audio-stream.md`):
  extension con token dedicato, sessione per connessione, audio scritto a pezzi e recuperato
  dopo un riavvio, AAC alla chiusura, creazione della `transcription`, `wss://` dietro
  Cloudflare e Caddy in produzione. Stima 1-2 giorni.
- [ ] M4 Uso reale: misurare quanto spesso capitano audio offline e pause dimenticate.

## Domande aperte

- Audio offline verso Nexus: per ora condivisione manuale del WAV. Chiesto a Omi di
  includerlo nella issue [#20174](https://github.com/BasedHardware/omi/issues/20174)
  (29/10/2026: una connessione per registrazione, ora di registrazione nell'URL); un
  contributore si è offerto di scrivere la PR.
- Pausa che vale anche da scollegato: chiesta come opzione sulla PR firmware
  [#23735](https://github.com/BasedHardware/omi/pull/23735) (29/10/2026). Finché manca,
  per non registrare si spegne il ciondolo.
- Autenticazione in produzione: token nella query o header dal JSON avanzato dell'app.
- Segmentazione con LLM e filtro sulla mia voce: solo se M4 mostra pause dimenticate frequenti.
