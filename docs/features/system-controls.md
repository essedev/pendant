# Comandi di sistema: tasto Azione, Centro di Controllo, blocco schermo

**Stato: fatta** (27/11/2026, M7): intent in `app/Shared/PendantIntents.swift`, controlli e
attività in tempo reale nell'estensione `app/PendantWidgets/`. Firmata e installata; il
comportamento sull'iPhone resta da provare (sezione Da provare).

## Perché

L'app si apre per controllare, non per registrare: il comando principale è il doppio tocco sul
ciondolo. Dal telefono la pausa deve arrivare senza aprire l'app e senza guardare lo schermo.
In più il ciondolo ha solo due gesti (tocco e doppio tocco, `ARCHITECTURE.md #Pulsante`): un
terzo comando, "segna questo momento", può arrivare solo dal telefono.

## Cosa

Due controlli dell'app, che si mettono dove si vuole:

| Controllo | Tipo | Effetto | Conferma |
|---|---|---|---|
| Pausa e ripresa | Interruttore | Come il doppio tocco: chiude o apre la conversazione | Il ciondolo vibra (breve in pausa, media alla ripresa) e iOS mostra lo stato nella Dynamic Island |
| Segna questo momento | Pulsante | Un segnalibro nella conversazione in corso, con l'ora | Vibrazione breve del ciondolo |

- **Tasto Azione** (iPhone 15 Pro e successivi): Impostazioni > Tasto Azione > Controlli >
  Pendant. Si attiva tenendolo premuto, quindi non parte in tasca. Uno dei due controlli,
  quello che scegli; per default "Segna questo momento", perché la pausa c'è già col doppio
  tocco.
- **Centro di Controllo e blocco schermo**: tutti e due.
- **Attività in tempo reale** sul blocco schermo e nella Dynamic Island. Ogni stato mostra
  solo quello che gli serve: mentre registra il tempo che scorre, Pausa e Segna; in pausa l'ora
  in cui è iniziata ("dalle 11:42") e solo Riprendi, perché il segnalibro vuole una
  registrazione; col ciondolo lontano l'ora dell'ultimo contatto, senza tasti. Il tempo che
  scorre compare solo mentre registra: una pausa contata come `23:00` si legge come un orario.
  Con "Sempre visibile" resta anche in pausa e da scollegato. iOS la chiude dopo circa 8 ore;
  se iOS rifiuta di aprirla con l'app in background, l'app riprova quando torna in primo piano.

Nell'app stanno in Impostazioni, Fuori dall'app: in cima l'attività in tempo reale in piccolo,
con le stesse viste dell'estensione (`app/Shared/ActivityViews.swift`) e i suoi due
interruttori; sotto una riga per posto, con i passaggi per metterci i controlli. Se le attività
sono spente nelle impostazioni di iOS la pagina lo dice e apre le impostazioni.

## Come

| Pezzo | Scelta | Fonte |
|---|---|---|
| Controlli | Estensione WidgetKit con `ControlWidgetToggle` (pausa, stato da `SetValueIntent`) e `ControlWidgetButton` (segnalibro). Testo per il tasto Azione che inizia con "Hold to", in italiano "Tieni premuto per" | [Creating controls](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system), [WWDC24 10157](https://developer.apple.com/videos/play/wwdc2024/10157/) |
| Dove gira l'intent | Di default nel processo dell'estensione, che non ha il Bluetooth né il WebSocket. Gli intent adottano `LiveActivityIntent`, così il sistema li esegue nel processo dell'app senza aprirla; il file dell'intent sta in entrambi i target | [Adding interactivity](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities), [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent) |
| Stato condiviso | App Group fra app ed estensione per lo stato da mostrare nel controllo (registra o in pausa) | [Configuring app groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) |
| Attività in tempo reale | ActivityKit con aggiornamenti locali, senza push. Il tempo con `Text(timerInterval:)`, che avanza da solo senza aggiornamenti: iOS limita quelli frequenti | [Forum 758469](https://developer.apple.com/forums/thread/758469) |
| Segnalibro | Un frame di testo sul WebSocket della conversazione: `{"type":"Mark","at":"<ISO 8601>"}`. `audio_stream` oggi ignora i messaggi di testo che non sono `CloseStream` (`router.py`, `_is_close_stream`), quindi si può mandare subito; il server lo userà quando lo saprà leggere | codice di `nexus` |

Scartato `AudioRecordingIntent`: serve alle app che registrano col microfono del telefono, chiede
un'attività in tempo reale per tutta la registrazione e di partire dall'app in primo piano
([AudioRecordingIntent](https://developer.apple.com/documentation/appintents/audiorecordingintent),
[forum 815725](https://developer.apple.com/forums/thread/815725)). Qui registra il ciondolo e
l'app è già attiva in background per il Bluetooth.

## Da provare sull'iPhone

- **App Group con l'account gratuito: verificato il 27/11/2026.** Xcode firma app ed estensione
  col Personal Team e il gruppo `group.dev.esse.pendant` è negli entitlement di tutte e due.
  Resta da vedere sull'iPhone che il controllo legga lo stato.
- **`perform` che non parte.** Più sviluppatori segnalano controlli e attività in tempo reale il
  cui intent non viene eseguito su iOS 18, risolto adottando `LiveActivityIntent` e mettendo
  l'intent in entrambi i target ([forum 789371](https://developer.apple.com/forums/thread/789371),
  [forum 760342](https://developer.apple.com/forums/thread/760342)). Va provato con l'app attiva
  in background e con l'app chiusa da iOS.

Fonti consultate il 26/11/2026.
