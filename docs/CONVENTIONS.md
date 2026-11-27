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
| App UI (views, notifications, Live Activity, controls, Info.plist) | English in the code, the source language; Italian in the String Catalogs |
| `docs/concepts/` (mockups of the UI) | Italian, the language of the UI they show |
| `docs/archive/` (the superseded DIY pendant) | stays as written, in Italian |

`scripts/check-prose.py` runs in `make lint` and fails on Italian outside these places;
`.prose-allow` lists any further exception, each with its reason.

The app follows the phone's language, or the one chosen for Pendant in iOS Settings, and falls
back to English. To add or change a UI string:

- Write it in English in the code: a literal in `Text`, `Button` and the like, a literal for a
  component's `LocalizedStringResource` parameter (`Row`, `CellGroup`, `.page(_:)`), or
  `String(localized:)` where a `String` is needed (notifications, the Live Activity's state;
  with `bundle: .module` in PendantKit). Text made at runtime that is already in the phone's
  language or is never translated (a time, a host, a duration) goes through `.verbatim(_:)`.
- A count is one string with its number (`"\(n) conversations"`); the catalog gives it the
  plural variations, in English too.
- Build (`make strings`, or `make build` and `make sim`): `scripts/catalogs.py sync` adds the
  new keys to the catalogs and removes the ones the code no longer uses, as Xcode does after
  a build. Then write the Italian in `app/Shared/Localizable.xcstrings` (the app and the
  widget extension) or `app/PendantKit/Sources/PendantKit/Resources/Localizable.xcstrings`;
  the Info.plist texts are in `app/Pendant/Resources/InfoPlist.xcstrings`.
- Two gotchas of the extraction. A ternary passed to an optional parameter loses its second
  branch: the compiler does not list it, so move the ternary into a property or function that
  returns `LocalizedStringResource`. The same English with two Italian renderings needs its
  own key: `String(localized: "tag.sinceDay", defaultValue: "since \(day)")`.

## Glossary

Italian terms of the project and the English used for them in code and docs, and in the
English UI. Older docs quote the labels of the Italian UI ("Riprendi", "Fuori dall'app"); new
text names the English label.

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
| attività in tempo reale | Live Activity | <!-- prose-allow --> |
| tasto Azione, Centro di Controllo | Action button, Control Center | |
| Adesso, Oggi, Impostazioni, Fuori dall'app | Now, Today, Settings, Outside the app | UI labels: the tabs and a settings page |
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
