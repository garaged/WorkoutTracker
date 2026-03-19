#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

CATALOG = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("workouttracker/Resources/Localizable.xcstrings")

PLACEHOLDER_RE = re.compile(r'%(?:\d+\$)?[@dDuUxXfFeEgGcCsSpaA]|%%')

def placeholders(s):
    if not s:
        return []
    return PLACEHOLDER_RE.findall(s)

with CATALOG.open("r", encoding="utf-8") as f:
    data = json.load(f)

strings = data.get("strings", {})
mismatches = []

for key, entry in strings.items():
    localizations = entry.get("localizations", {})

    en = localizations.get("en", {}).get("stringUnit", {}).get("value")
    es = localizations.get("es-MX", {}).get("stringUnit", {}).get("value")

    if en and es:
        en_ph = placeholders(en)
        es_ph = placeholders(es)
        if sorted(en_ph) != sorted(es_ph):
            mismatches.append((key, en, es, en_ph, es_ph))

for key, en, es, en_ph, es_ph in mismatches:
    print(f"\nKEY: {key}")
    print(f"EN : {en}")
    print(f"ES : {es}")
    print(f"EN placeholders: {en_ph}")
    print(f"ES placeholders: {es_ph}")

print(f"\nTotal placeholder mismatches: {len(mismatches)}")
