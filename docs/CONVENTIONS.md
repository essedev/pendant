# Conventions

## Language

Public repository: code, comments, docs and commits in English; README.md is mirrored in
README.it.md in the same commit.

| Level | Language |
|---|---|
| Identifiers, file names, branches | English |
| Comments, doc comments, test names | English |
| `README.md` | English, canonical |
| `README.it.md` | Italian, a translation of the canonical one |
| `docs/*`, `CLAUDE.md`, `.claude/rules/*` | English |
| Commit messages | English, Conventional Commits |
| App UI (string literals in the views, notifications, Live Activity) | Italian |
| `docs/concepts/` (mockups of the UI) | Italian, the language of the UI they show |
| `docs/archive/` (the superseded DIY pendant) | stays as written, in Italian |

`scripts/check-prose.py` runs in `make lint` and fails on Italian outside these places;
`.prose-allow` lists any further exception, each with its reason.

## Glossary

Italian terms of the project and the English used for them in code and docs. A term that is
also a label of the Italian UI stays as it is when the docs name that label.

| Italian | English | Notes |
|---|---|---|
| ciondolo | pendant | |
| conversazione | conversation | one connection to the server |
| segnalibro, segnare un momento | bookmark, mark a moment | |
| pausa, ripresa | pause, resume | |
| grazia | grace period | how long the server keeps an interrupted session |
| spia | LED | |
| coda senza rete | offline queue | `FrameSpool` in the code |
| audio offline | offline audio | recorded by the pendant without the phone |
| avviso del ciondolo acceso a vuoto | idle warning | the pendant on and connected, not recording |
| attività in tempo reale | Live Activity | |
| tasto Azione, Centro di Controllo | Action button, Control Center | |
| Adesso, Oggi, Impostazioni, Fuori dall'app | stay as they are | UI labels: the tabs and a settings page |
| giro (di mock) | round | a round of feedback on a mockup |

## General

- Units always explicit: mA, mAh, kHz, KB/s, $/h.
- Third-party data (prices, behaviour of the Omi app, measurements) with source and date.

## iOS app

- Swift and SwiftUI, iPhone only, all from the command line: XcodeGen generates the Xcode project
  from `app/project.yml` (the `.xcodeproj` is not versioned), build and install go through
  `app/Makefile`. The signing team sits in `app/Local.xcconfig`, ignored by git.
- The logic lives in the local Swift package `app/PendantKit`, testable with `swift test`
  without an iPhone; the app target stays thin.
- Formatting with `swift format` (the toolchain's), checked by `make lint`.
- No behaviour values in the code: every time, threshold or map goes into the configuration
  schema with a default and limits.
- The pendant protocol lives in one module, with references to the firmware code (`file:line`
  at the version tag).
- Code taken from the Omi app (MIT license) cites its source file and commit.
- Version: the minor in `app/project.yml` goes up by hand when a milestone closes (M5 0.2, M6
  0.3, M7 0.4, then 0.5). The Makefile sets the build number to the commit count of the branch:
  each install has its own, and Informazioni shows `0.4.1 (60)`, which leads back to the commit.
- Spacing (`Theme.Gutter`, `Theme.pageTop`): three horizontal margins by role, never a number
  typed by hand. 16 points for anything with a fill (display, keys, cells, cards), 24 for page
  titles and free blocks (the day), 32 for text inside cells and for text that goes with a
  group (headers, notes, hints). Vertically 28 before a group with a header, 20 without one and
  at the top of a pushed page, 8 between a group and its note. The first launch keeps its
  content at 24 and widens surfaces to 16, as in the app.

## Prototypes

- Standalone Python scripts with inline dependencies (`# /// script`), run with `uv run`.
- Recordings hold real voices: they are written only to `prototype/recordings/`, ignored by
  git.
