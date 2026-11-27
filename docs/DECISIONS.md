# Decisioni

Le decisioni in vigore. Quelle superate, compreso il ciondolo fai-da-te, sono in
[decisions-archive.md](decisions-archive.md).

## 2026-10-28 Comprare Omi invece di costruire

Omi fa già quello che serviva al ciondolo: registra tutto il giorno, ha 512 MB di memoria per
l'offline e un'app con firmware open source. Il controllo dei dati, motivo del fai-da-te, si
ottiene lo stesso dirottando l'audio verso Nexus: prima con l'app Omi, dal 2026-11-26 con l'app
nostra. Il ciondolo su ESP32-S3 resta in `docs/archive/`. Supera la decisione del 2026-10-07
(archivio).

## 2026-10-28 La pausa apre e chiude la conversazione

Il doppio tocco mette in pausa; in pausa l'app chiude la connessione con `CloseStream`, e
quella chiusura è il confine della conversazione in Nexus. Scartati: il timeout di silenzio
(in ufficio qualcuno parla sempre, quindi non scatta mai), la segmentazione con un LLM e il
filtro sulla mia voce (rimandati: servono solo se le pause dimenticate diventano frequenti).

## 2026-10-28 Trascrizione batch a conversazione chiusa, niente live

Un solo passaggio batch con diarizzazione sull'audio intero della conversazione, nella
capability `transcription` di Nexus. Scartati: il live (circa il doppio del costo e
diarizzazione peggiore) e il batch a blocchi da 8 s (ogni blocco diarizza da solo, le
etichette dei parlanti non tornano). Il provider lo decide un confronto su registrazioni vere.

## 2026-10-28 Vibrazione al doppio tocco: PR a Omi, senza interruttore

Il ciondolo non dà riscontro alle azioni del doppio tocco. Si propone a Omi (PR #23912) di
confermarle tutte con la vibrazione già comandabile via Bluetooth: lunga (300 ms) quando
l'azione accende qualcosa (ripresa, preferito), breve (100 ms) quando spegne o completa (pausa,
preferito tolto, termina ed elabora). Scartata la versione limitata alla pausa: la regola
"la vibrazione conferma l'azione" vale per ogni azione assegnata al tasto.
Niente interruttore nelle impostazioni: il tocco singolo vibra già senza opzione, e un
interruttore vorrebbe traduzioni in tutte le lingue dell'app e la verifica dell'interfaccia.
In parte superata dalla decisione del 2026-11-26 sull'app nostra: la vibrazione ora la
comanda l'app nostra; la PR resta aperta per chi usa l'app Omi (ROADMAP, domande aperte).

## 2026-11-26 App iOS nostra al posto dell'app Omi

Un'app iOS nostra riceve l'audio dal ciondolo via Bluetooth e lo manda a Nexus; l'app Omi
resta solo per aggiornare il firmware. Supera la decisione del 2026-10-29 e, con l'app in uso
dal 26/11, il trasporto con lo STT personalizzato del 2026-10-28 (tutte e due in archivio). Riaperta perché l'app Omi
accumula copie locali che non rilascia mai (21 h il 26/11), non espone stato, batteria né
pulsante, e i maintainer accettano poche PR. Il protocollo non va più ricostruito: il codice del
firmware 3.0.21 e quello Swift nativo dell'app Omi (MIT) lo danno intero. Serve anche a
decidere se tenere Omi o passare al reSpeaker Clip dopo due settimane d'uso. Scartati: restare
sull'app Omi con PR (troppo lente), il fork dell'app Omi (enorme, legata al loro backend),
comprare subito il Clip (in prevendita, e l'app serve comunque).

## 2026-11-26 Swift nativo, solo iPhone

L'app è in Swift con CoreBluetooth. Il Bluetooth in background e il ripristino dello stato
dopo che iOS chiude l'app si gestiscono direttamente, e il riferimento è già Swift
(`OmiBleManager.swift` dell'app Omi). Scartato Flutter: avrebbe permesso di copiare il Dart
dell'app Omi, ma su iOS anche loro sono passati al Bluetooth nativo, e il livello in più
complica background e debug. Android non serve.

## 2026-11-26 App indipendente, server configurabile, impostazioni sul telefono

L'app non è legata a Nexus: parla un protocollo (oggi quello di `audio_stream`) verso un server
che si imposta nell'app con indirizzo e token, e nell'interfaccia il server si chiama solo
Server. Ogni valore di comportamento sta nello schema della configurazione, con default e
limiti, e si cambia dalle impostazioni dell'app, che restano sul telefono. Riscrive la scelta
della mattina, che voleva i valori scaricati da Nexus: avrebbe legato l'app a un server solo e
richiesto un'aggiunta a Nexus prima di poter cambiare un'impostazione. Scartato anche tenere le
impostazioni sia nell'app sia sul server: due posti da tenere allineati senza un bisogno.

## 2026-11-26 Note col pulsante a tocchi, niente premi e parla

Col firmware 3.0.21 le note si aprono e chiudono con dei tocchi, non tenendo premuto. Il
firmware non manda l'inizio di una pressione, non manda il rilascio di una pressione tenuta, e
a 3 s si spegne (`button.c`). Il premi e parla richiede un firmware modificato: si rivaluta col
Clip o se Omi aggiunge gli eventi di pressione (issue #25872). Scartato ricavare la pressione
dal flusso audio: non ha un inizio affidabile.

## 2026-11-26 Firmware di serie, 3.0.24 solo dal rollout

L'app lavora sul firmware distribuito, oggi il 3.0.21, e usa muto e spegnimento dall'app quando
il 3.0.24 arriva a tutti. Scartato installarlo a mano adesso: Omi lo tiene al 0% di proposito,
e un aggiornamento fallito si recupera solo con un J-Link. Si rivaluta se l'app regge e le
accensioni accidentali restano il problema principale.

## 2026-11-26 Account Apple gratuito per la prova

La prova di due settimane usa il "Personal Team" di Xcode: l'app scade ogni 7 giorni e si
rinnova via Wi-Fi o con SideStore. I 99 $ l'anno si spendono solo se l'app viene tenuta.
Bastano le notifiche locali: quelle che nascono da Nexus vanno su Telegram.

## 2026-11-26 Opus decodificato sul telefono col codec di sistema

Il primo inoltro parla a `audio_stream` come l'app Omi, quindi il telefono decodifica l'Opus del
ciondolo in PCM con il codec Opus di AudioToolbox, senza librerie. In coda resta l'Opus
compresso (circa 4 KB/s), decodificato solo all'invio: mezz'ora senza rete sta in memoria.
Scartati: una libreria libopus (dipendenza in più per una cosa che il sistema fa), e mandare
subito l'Opus a Nexus (circa 7 invece di 115 MB l'ora, ma richiede di cambiare `audio_stream`:
si fa dopo, insieme alle altre aggiunte lato Nexus). Il token va nell'header `Authorization`,
non nell'URL, che proxy e Cloudflare scrivono nei log.

## 2026-11-26 Interfaccia: il display di un registratore, grafite e rosso

L'app ha la forma della variante L del mock (`docs/concepts/concept-a-app-fable.html`,
`ARCHITECTURE.md #Interfaccia`): la home è il display di un registratore, il rosso vuol dire
solo registrare, un solo tasto incassato (grafite "Pausa", rosso "Riprendi"). Grafite e rosso
è il tema di default: display e accento si scelgono (da Temi, 2026-11-27). Scartati, dopo
dodici giri: la schermata tecnica di oggi, il telecomando col pulsante enorme, il diario come
home, la lista nativa di iOS, il ciondolo fotografato o disegnato al centro, la linea a tre
fermate (`concept-a-app.html`, varianti A-I, J e K), altre undici coppie di colori, e per la
pausa la slitta, i tasti a scatto, la spia toccabile, il tasto nel display, il tasto di vetro e
il tieni premuto. Il tieni premuto per registrare un pezzo è scartato anche nel merito: l'app
si apre per controllare, non per registrare. In parte superata dalla decisione Temi del
2026-11-27.

## 2026-11-26 Comandi di sistema per la pausa e i segnalibri

Pausa e ripresa e "segna questo momento" sono controlli di sistema (tasto Azione, Centro di
Controllo, blocco schermo) più un'attività in tempo reale, così dal telefono non serve aprire
l'app; il segnalibro è un terzo gesto che il ciondolo non può dare. Gli intent adottano
`LiveActivityIntent` per girare nel processo dell'app, dove ci sono Bluetooth e WebSocket; lo
stato per il Centro di Controllo passa dall'App Group. Fatti in M7 il 27/11.
Dettagli e verifiche in `docs/features/system-controls.md`. Scartato `AudioRecordingIntent`:
serve a chi registra col microfono del telefono e chiede di partire dall'app in primo piano.

## 2026-11-27 Il tocco singolo segna il momento finché non ci sono le note

Il tocco singolo, che nel progetto doveva aprire e chiudere una nota, fino alle note (M10) mette
un segnalibro nella conversazione in corso, con una vibrazione breve. Scartato lasciarlo senza
azione: è il gesto più comodo e il segnalibro serve già. "Apri e chiudi nota" non compare fra
le scelte finché non esiste; quando arriva si decide se diventa il default.

## 2026-11-27 La prova della connessione non chiude conversazioni

"Prova la connessione" apre il WebSocket col token e lo chiude senza `CloseStream`, e mentre una
conversazione è aperta non apre una seconda connessione: risponde con quella in corso. Su
`audio_stream` aprire riprende la sessione interrotta da meno della grazia e toglie la sessione
alla connessione che la tiene. Scartato chiudere con `CloseStream`: chiuderebbe proprio quella
conversazione. La sessione vuota della prova il server la scarta da solo (sotto 2 s d'audio).

## 2026-11-27 Si registra solo su richiesta, e il ciondolo acceso a vuoto avvisa

Ogni collegamento del ciondolo parte in pausa: si registra solo col doppio tocco, il tasto o un
controllo di sistema. Riprende da sola solo una registrazione tagliata da una disconnessione e
tornata entro la grazia di `audio_stream` (120 s), così un Bluetooth che cade un attimo non
spezza la conversazione. Riscrive la registrazione continua di M6, in cui ogni collegamento
fuori pausa registrava: un'accensione in tasca diventava una registrazione. Se il ciondolo
resta collegato senza registrare, fuori dal caricatore, l'app avvisa e ripete l'avviso finché
non registri o lo spegni (tempi e vibrazione in ARCHITECTURE, Ciclo di una connessione); spegnerlo
dall'app richiede il 3.0.24 (DECISIONS 2026-11-26, firmware di serie). Scartato
partire in pausa anche dopo un taglio breve: ogni caduta del Bluetooth avrebbe chiesto un
doppio tocco.

## 2026-11-27 Icona: il ciondolo visto dall'alto

L'icona dell'app è il ciondolo visto dall'alto, come nel render di Omi: disco grigio in un
anello chiaro, col LED rosso al centro, su fondo chiaro, con le rese scura e tinta (`docs/concepts/concept-c-icona.html`,
variante C). Scartate la spia col livello (A), che da piccola diventa un puntino e una riga, e
le barre della Dynamic Island (B), più leggibili ma comuni fra le app che registrano. Il
limite accettato: sotto i 40 pt nel tema scuro il LED si vede poco. Le PNG nascono dagli SVG
in `app/Icon/` con `make icon`; Icon Composer (file `.icon` a livelli) resta un passo dopo.

## 2026-11-27 Temi: display e accento a scelta, rosso e ambra fissi

L'app ha un selettore di temi (Impostazioni, Tema): dieci temi pronti, dai giri del mock
(Grafite e rosso, Casio, G-Shock, Carta, Calcolatrice, Blu e arancio, Petrolio e menta, Bosco,
Salvia, Notte e menta), più la combinazione libera di un display e un accento. Il display ha una
resa chiara e una scura; l'accento colora interruttori, scheda attiva, tasti, tacche registrate,
"In pausa" e "in linea". Restano fissi il rosso della registrazione e l'ambra degli avvisi, e
fra gli accenti non ci sono rosso, giallo né ambra. Ogni combinazione è nel catalogo con un test
di contrasto (4,5:1); sul display un accento che non regge torna all'inchiostro secondario.
Scartati il colore libero col selettore di sistema (contrasto non garantito) e un rosso che
cambia col tema (il segnale "registra" deve valere ovunque). Il default resta Grafite e rosso.
