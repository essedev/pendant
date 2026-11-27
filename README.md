# pendant

Il ciondolo Omi collegato a Nexus: l'audio delle conversazioni va a Nexus, che lo conserva e lo
trascrive, invece che al cloud Omi.

Lo inoltra un'app iOS nostra, che sostituisce l'app Omi; in arrivo il recupero dell'audio
registrato offline e le note a tocchi sul pulsante.

Nato come ciondolo fai-da-te su ESP32-S3, poi sostituito da Omi: il progetto originale è in
`docs/archive/`.

## Stato

Inoltro dal vivo verso Nexus in uso con l'app iOS dal 26/11/2026; dal 27/11 l'app completa (M7),
in prova sul ciondolo. Prossimo: lo stato del ciondolo verso il server (M8).

## Avvio

Da `app/`: `make help` elenca i comandi, `make run` compila e installa l'app sull'iPhone
collegato, `make sim SCENE=<scena>` la apre nel simulatore. Il primo setup (XcodeGen, team di
firma, credenziali) è in `CLAUDE.md`.

## Documentazione

- [Architettura](docs/ARCHITECTURE.md)
- [Decisioni](docs/DECISIONS.md)
- [Convenzioni](docs/CONVENTIONS.md)
- [Roadmap](docs/ROADMAP.md)
- [Progetto fai-da-te archiviato](docs/archive/ARCHITECTURE-diy.md)
