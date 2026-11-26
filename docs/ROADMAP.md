# Roadmap

## Stato corrente

Omi in uso con l'app Omi e lo STT personalizzato: l'audio arriva a `audio_stream` di Nexus, in
produzione dal 28/10/2026, e la trascrizione la fa Nexus (Voxtral di riserva, confronto fatto il
28/10). Il 26/11/2026 si è deciso di scrivere un'app iOS nostra (DECISIONS): architettura in
`ARCHITECTURE.md #L'app`. Prossimo: la verifica sul ciondolo.

## Prossime milestone

- [ ] M5 Verifica sul ciondolo, mezza giornata: app Swift minima che si collega, legge versione,
  funzioni, batteria e info della memoria, riceve audio e pulsante, scrive l'ora. Chiude le
  voci di `ARCHITECTURE.md #Verifiche aperte`, compreso il background con l'account gratuito.
  Se il background non regge, ci si ferma e si rivaluta.
- [ ] M6 Inoltro dal vivo: l'app sostituisce l'app Omi verso `audio_stream` senza modifiche a
  Nexus (PCM, `CloseStream`, ping), con pausa al doppio tocco, vibrazione, notifiche locali e
  configurazione scaricata da Nexus (prima aggiunta lato Nexus).
- [ ] M7 Stato in Nexus: eventi del ciondolo e segnale periodico, avviso su Telegram se l'app
  tace o il ciondolo resta scollegato.
- [ ] M8 Offline dalla memoria: lettura alla connessione, invio a Nexus con l'ora vera,
  avanzamento solo dopo la conferma. Richiede l'aggiunta in Nexus.
- [ ] M9 Note a tocchi: apertura e chiusura, controllo della voce, invio a Nexus come nota.

Dopo M9 due settimane d'uso, poi la scelta: tenere Omi (e l'account Apple a 99 $) o passare al
reSpeaker Clip riscrivendo solo il collegamento.

## Domande aperte

- Pausa che vale anche da scollegato: arriva col firmware 3.0.24 (muto salvato), pubblicato il
  9/11 ma al 0% il 26/11. Sul 3.0.21 forse si ottiene col guadagno del microfono a 0, da
  misurare in M5.
- Accensioni accidentali in tasca: quante sono si misura in M5 e M6. Lo spegnimento dall'app
  arriva col 3.0.24.
- PR vibrazione [BasedHardware/omi#23912](https://github.com/BasedHardware/omi/pull/23912):
  aperta senza revisione, in conflitto con `main` dal 26/11. Con l'app nostra la vibrazione la
  comandiamo noi: si decide se chiuderla o tenerla per chi usa l'app Omi.
- Segmentazione con LLM e filtro sulla mia voce: solo se l'uso mostra pause dimenticate
  frequenti.
