# Roadmap

## Stato corrente

Omi in uso. Il trasporto dell'audio verso un endpoint nostro è verificato col prototipo
(28/10/2026). In preparazione la PR della vibrazione su Omi; l'ingest in Nexus non è iniziato.

## Prossime milestone

- [x] M0 Prototipo del trasporto: 7 verifiche, esito in `ARCHITECTURE.md #Esito del prototipo`.
- [ ] M1 PR vibrazione su `BasedHardware/omi` dal fork `essedev/omi`: modifica, test,
  `make preflight`, testo approvato da Simone prima della pubblicazione.
- [ ] M2 Confronto provider: 2-3 registrazioni vere su Mistral, Speechmatics Melia 1 ed
  Enhanced. Spesa stimata sotto 1 $, da approvare prima del lancio.
- [ ] M3 Ingest in Nexus: capability con token dedicato, sessione per connessione, audio
  scritto a pezzi e recuperato dopo un riavvio, conversione in Opus, creazione della
  `transcription`, `wss://` dietro Caddy in produzione. Stima 1-2 giorni.
- [ ] M4 Uso reale: misurare quanto spesso capitano audio offline e pause dimenticate.

## Domande aperte

- Recupero dell'audio offline: basta la condivisione manuale del WAV (anche verso il bot
  Telegram di Nexus, se accetta audio) o serve una PR a Omi sulla sincronizzazione?
- Autenticazione in produzione: token nella query o header dal JSON avanzato dell'app.
- Segmentazione con LLM e filtro sulla mia voce: solo se M4 mostra pause dimenticate frequenti.
