# Roadmap

## Stato corrente

Dal 26/11/2026 l'audio del ciondolo arriva a `audio_stream` di Nexus con l'app iOS nostra
(M5 e M6); l'app Omi resta solo per il firmware, col ciondolo dimenticato. La trascrizione la
fa Nexus. Architettura in `ARCHITECTURE.md #L'app`. L'app vera (M7) è scritta e installata il
27/11: manca la prova sul ciondolo.

## Prossime milestone

- [x] M5 Verifica sul ciondolo (26/11/2026): app di verifica in `app/`, esiti in
  `ARCHITECTURE.md #Verifiche sul ciondolo`. Il premi e parla è escluso; il background resta da
  misurare nell'uso di M6.
- [x] M6 Inoltro dal vivo (26/11/2026): l'app sostituisce l'app Omi verso `audio_stream` senza
  modifiche a Nexus, con pausa al doppio tocco, vibrazione e notifiche locali. Prova da capo a
  fondo riuscita (`ARCHITECTURE.md #Verifiche sul ciondolo`). Resta da misurare il background
  per ore nell'uso reale.
- [ ] M7 L'app vera: fatta il 27/11 dal mock completo (`docs/concepts/concept-b-app.html`):
  primo avvio, Adesso, Oggi, Impostazioni con server configurabile e prova della connessione,
  LED che segue la registrazione, segnalibri, comandi di sistema e attività in tempo reale,
  iOS 26. Verificata nel simulatore su ogni scena (`make screens`); resta la prova sul
  ciondolo: spia, segnalibro al tocco, controlli, attività in tempo reale, partenza in pausa
  e avviso del ciondolo acceso senza registrare.
- [ ] M8 Stato verso il server: eventi del ciondolo e segnale periodico, avviso su Telegram se
  l'app tace o il ciondolo resta scollegato. Aggiunta lato Nexus.
- [ ] M9 Offline dalla memoria: lettura alla connessione, invio al server con l'ora vera,
  avanzamento solo dopo la conferma. Richiede l'aggiunta lato Nexus.
- [ ] M10 Note a tocchi: apertura e chiusura, controllo della voce, invio al server come nota.

Dopo M10 due settimane d'uso, poi la scelta: tenere Omi (e l'account Apple a 99 $) o passare al
reSpeaker Clip riscrivendo solo il collegamento.

## Domande aperte

- Pausa che vale anche da scollegato: arriva col firmware 3.0.24 (muto salvato), pubblicato il
  9/11 ma al 0% il 26/11. Sul 3.0.21 forse si ottiene col guadagno del microfono a 0, da
  misurare in M5.
- Accensioni accidentali in tasca: quante sono si misura nell'uso. Lo spegnimento dall'app
  arriva col 3.0.24: allora l'avviso del ciondolo acceso senza registrare diventa uno
  spegnimento.
- PR vibrazione [BasedHardware/omi#23912](https://github.com/BasedHardware/omi/pull/23912):
  aperta senza revisione, in conflitto con `main` dal 26/11. Con l'app nostra la vibrazione la
  comandiamo noi: si decide se chiuderla o tenerla per chi usa l'app Omi.
- Segmentazione con LLM e filtro sulla mia voce: solo se l'uso mostra pause dimenticate
  frequenti.
