#!/usr/bin/env python3
"""
Keeps the app's String Catalogs in step with the code and checks the Italian translation.

Usage:
  catalogs.py sync DERIVED_DATA   after a build: adds the strings the compiler found in the code
                                  to the catalogs and removes the ones the code no longer uses
  catalogs.py check               fails when a string has no Italian translation

English is the source language, written in the code; Italian is a translation in the catalogs
(docs/CONVENTIONS.md#language). Xcode keeps a catalog in step after every build, but the app
is built from the command line, so the Makefile calls `sync` after its builds and `check` to
verify the catalogs. A string meant to stay as it is (a value made at runtime, shown through
`.verbatim`) is marked `shouldTranslate: false` and skipped.

Standard library only; `sync` needs Xcode's `xcstringstool`.
"""

import json
import subprocess
import sys
from pathlib import Path

APP = Path(__file__).resolve().parent.parent / "app"

# Each catalog and the build directory whose .stringsdata feed it: the Xcode project's, which
# holds the app and the widget extension, and the package's. The app and the extension share
# one catalog: `Shared/` is compiled into both, and each bundle gets all of it.
SYNCED = {
    "Shared/Localizable.xcstrings": "Pendant.build",
    "PendantKit/Sources/PendantKit/Resources/Localizable.xcstrings": "PendantKit.build",
}
# Written by hand: the keys are those of Info.plist, which the compiler does not see.
MANUAL = ["Pendant/Resources/InfoPlist.xcstrings"]

TRANSLATION = "it"


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path, catalog):
    # The layout Xcode writes, so a later edit in Xcode leaves a small diff.
    text = json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "), sort_keys=True)
    path.write_text(text + "\n", encoding="utf-8")


def stringsdata(derived, project):
    """The .stringsdata files a build left for the targets of one project or package."""
    return sorted((Path(derived) / "Build" / "Intermediates.noindex" / project).rglob("*.stringsdata"))


def sync(derived):
    for rel, project in SYNCED.items():
        path = APP / rel
        files = stringsdata(derived, project)
        if not files:
            sys.exit(f"No .stringsdata for {rel} under {derived}: build first.")
        subprocess.run(
            ["xcrun", "xcstringstool", "sync", str(path), "--stringsdata", *map(str, files)],
            check=True,
        )
        # The code is the source of the keys: a string it no longer uses goes, git keeps it.
        catalog = load(path)
        strings = catalog["strings"]
        stale = [k for k, v in strings.items() if v.get("extractionState") == "stale"]
        for key in stale:
            del strings[key]
        save(path, catalog)
        print(f"{rel}: {len(strings)} strings, {len(stale)} removed")


def leaves(unit):
    """The string units of a localization, its plural or device variations included."""
    if "stringUnit" in unit:
        yield unit["stringUnit"]
    for variation in unit.get("variations", {}).values():
        for case in variation.values():
            yield from leaves(case)


def missing(catalog):
    for key, entry in sorted(catalog["strings"].items()):
        if entry.get("shouldTranslate") is False:
            continue
        unit = entry.get("localizations", {}).get(TRANSLATION)
        found = list(leaves(unit)) if unit else []
        if not found or any(u.get("state") != "translated" or not u.get("value") for u in found):
            yield key


def check():
    failed = False
    for rel in [*SYNCED, *MANUAL]:
        path = APP / rel
        catalog = load(path)
        gaps = list(missing(catalog))
        stale = [k for k, v in catalog["strings"].items() if v.get("extractionState") == "stale"]
        for key in gaps:
            print(f"{rel}: no Italian for {key!r}")
        for key in stale:
            print(f"{rel}: no longer in the code: {key!r}")
        failed = failed or bool(gaps or stale)
    if failed:
        print("Add the Italian in the catalog (docs/CONVENTIONS.md#language).")
    return 1 if failed else 0


def main(argv):
    if len(argv) == 3 and argv[1] == "sync":
        sync(argv[2])
        return 0
    if len(argv) == 2 and argv[1] == "check":
        return check()
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
