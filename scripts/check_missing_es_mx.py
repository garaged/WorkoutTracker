#!/usr/bin/env python3
import json
import sys
from pathlib import Path

CATALOG = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("workouttracker/Resources/Localizable.xcstrings")

with CATALOG.open("r", encoding="utf-8") as f:
    data = json.load(f)

strings = data.get("strings", {})
missing = []
same_as_en = []
empty_es = []

for key, entry in strings.items():
    localizations = entry.get("localizations", {})

    en = localizations.get("en")
    es = localizations.get("es-MX")

    def extract_value(loc):
        if not loc:
            return None
        unit = loc.get("stringUnit")
        if unit and isinstance(unit, dict):
            return unit.get("value")
        return None

    en_value = extract_value(en)
    es_value = extract_value(es)

    # Missing es-MX block entirely
    if es is None:
        missing.append((key, en_value))
        continue

    # Present but empty
    if es_value is None or str(es_value).strip() == "":
        empty_es.append((key, en_value))
        continue

    # Suspicious: Spanish equals English exactly
    if en_value is not None and es_value == en_value:
        same_as_en.append((key, en_value))

print("=== Missing es-MX ===")
for key, value in missing:
    print(f"{key} :: {value}")

print(f"\nTotal missing es-MX: {len(missing)}")

print("\n=== Empty es-MX values ===")
for key, value in empty_es:
    print(f"{key} :: {value}")

print(f"\nTotal empty es-MX: {len(empty_es)}")

print("\n=== Suspicious same-as-English ===")
for key, value in same_as_en:
    print(f"{key} :: {value}")

print(f"\nTotal suspicious same-as-English: {len(same_as_en)}")
