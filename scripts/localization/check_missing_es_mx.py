#!/usr/bin/env python3
"""
Audit Localizable.xcstrings for missing or suspicious es-MX translations.

Checks:
- missing es-MX localization block
- empty es-MX value
- es-MX value identical to English (filtered to likely-actionable cases)
- placeholder mismatch between English and es-MX (normalized semantically)

Usage:
    python3 workouttracker/scripts/localization/check_missing_es_mx.py
    python3 workouttracker/scripts/localization/check_missing_es_mx.py \
        --catalog workouttracker/Resources/Localizable.xcstrings
    python3 workouttracker/scripts/localization/check_missing_es_mx.py --json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

DEFAULT_CATALOG = "workouttracker/Resources/Localizable.xcstrings"
# Matches printf-style placeholders while ignoring %%.
PLACEHOLDER_RE = re.compile(
    r"%(?!%)(?:(?P<position>\d+)\$)?(?P<flags>[-+# 0]*)?(?P<width>\d+|\*)?(?:\.(?P<precision>\d+|\*))?(?P<length>hh|h|ll|l|L|z|j|t)?(?P<spec>[@dDuUxXoOfFeEgGaAcCsSp])"
)
ALLOWED_SAME_AS_ENGLISH_KEYS = {
    "common.ok",
    "progress.dashboard.strength.badge.pr",
    "progress.detail.performance.value.reps_weight",
    "session.pr.badge",
    "session.pr.sheet_title",
}
ALLOWED_SAME_AS_ENGLISH_VALUES = {
    "OK",
    "No",
    "PR",
    "A",
    "B",
    "Δ",
    "+%lld",
    "%lld min",
    "±0",
    "%1$@ %2$@",
    "%1$@: %2$@",
    "%1$@. %2$@",
    "A: %@",
    "App: %@",
    "B: %@",
    "%lld × %@",
}


@dataclass
class Finding:
    key: str
    issue: str
    en: str | None
    es_mx: str | None
    details: str | None = None


def load_catalog(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def extract_string_unit_value(localization: dict[str, Any] | None) -> str | None:
    if not localization:
        return None

    string_unit = localization.get("stringUnit")
    if isinstance(string_unit, dict):
        value = string_unit.get("value")
        if isinstance(value, str):
            return value

    return None


def extract_localizations(entry: dict[str, Any]) -> tuple[str | None, str | None]:
    localizations = entry.get("localizations", {})
    en_value = extract_string_unit_value(localizations.get("en"))
    es_mx_value = extract_string_unit_value(localizations.get("es-MX"))
    return en_value, es_mx_value


def normalize_placeholder_spec(spec: str) -> str:
    if spec == "@":
        return "object"
    if spec in {"d", "D", "u", "U", "x", "X", "o"}:
        return "integer"
    if spec in {"f", "F", "e", "E", "g", "G", "a", "A"}:
        return "float"
    if spec in {"c", "C"}:
        return "char"
    if spec in {"s", "S"}:
        return "string"
    if spec == "p":
        return "pointer"
    return spec


def placeholders(value: str | None) -> list[str]:
    if not value:
        return []
    return sorted(normalize_placeholder_spec(match.group("spec")) for match in PLACEHOLDER_RE.finditer(value))


def likely_actionable_same_as_english(key: str, value: str) -> bool:
    if key in ALLOWED_SAME_AS_ENGLISH_KEYS or value in ALLOWED_SAME_AS_ENGLISH_VALUES:
        return False
    # Skip placeholder-only or mostly symbolic strings.
    stripped = PLACEHOLDER_RE.sub("", value).strip()
    if not stripped:
        return False
    if not re.search(r"[A-Za-zÁÉÍÓÚáéíóúÑñ]", stripped):
        return False
    return True


def audit_catalog(data: dict[str, Any]) -> list[Finding]:
    findings: list[Finding] = []
    strings = data.get("strings", {})

    for key, entry in strings.items():
        if not isinstance(entry, dict):
            continue

        en_value, es_mx_value = extract_localizations(entry)
        localizations = entry.get("localizations", {})

        if "es-MX" not in localizations:
            findings.append(
                Finding(
                    key=key,
                    issue="missing_es_mx",
                    en=en_value,
                    es_mx=None,
                    details="No es-MX localization block",
                )
            )
            continue

        if es_mx_value is None or not es_mx_value.strip():
            findings.append(
                Finding(
                    key=key,
                    issue="empty_es_mx",
                    en=en_value,
                    es_mx=es_mx_value,
                    details="es-MX block exists but value is empty",
                )
            )
            continue

        if en_value is not None and es_mx_value == en_value and likely_actionable_same_as_english(key, es_mx_value):
            findings.append(
                Finding(
                    key=key,
                    issue="same_as_english",
                    en=en_value,
                    es_mx=es_mx_value,
                    details="es-MX matches English exactly",
                )
            )

        en_placeholders = placeholders(en_value)
        es_placeholders = placeholders(es_mx_value)
        if en_value and es_mx_value and en_placeholders != es_placeholders:
            findings.append(
                Finding(
                    key=key,
                    issue="placeholder_mismatch",
                    en=en_value,
                    es_mx=es_mx_value,
                    details=f"en={en_placeholders} es-MX={es_placeholders}",
                )
            )

    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--catalog",
        default=DEFAULT_CATALOG,
        help=f"Path to .xcstrings catalog (default: {DEFAULT_CATALOG})",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print results as JSON",
    )
    args = parser.parse_args()

    catalog_path = Path(args.catalog)
    if not catalog_path.exists():
        raise SystemExit(f"Catalog not found: {catalog_path}")

    data = load_catalog(catalog_path)
    findings = audit_catalog(data)

    if args.json:
        print(json.dumps([asdict(f) for f in findings], indent=2, ensure_ascii=False))
        return 0

    grouped: dict[str, list[Finding]] = {
        "missing_es_mx": [],
        "empty_es_mx": [],
        "same_as_english": [],
        "placeholder_mismatch": [],
    }

    for finding in findings:
        grouped.setdefault(finding.issue, []).append(finding)

    for issue in ("missing_es_mx", "empty_es_mx", "same_as_english", "placeholder_mismatch"):
        bucket = grouped.get(issue, [])
        print(f"\n=== {issue.upper()} ({len(bucket)}) ===")
        for item in bucket:
            print(repr(item.key))
            if item.en is not None:
                print(f"  en   : {item.en}")
            if item.es_mx is not None:
                print(f"  es-MX: {item.es_mx}")
            if item.details:
                print(f"  note : {item.details}")

    print("\nSummary:")
    for issue in ("missing_es_mx", "empty_es_mx", "same_as_english", "placeholder_mismatch"):
        print(f"  {issue}: {len(grouped.get(issue, []))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
