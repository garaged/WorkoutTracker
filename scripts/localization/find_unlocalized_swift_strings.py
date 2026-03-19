#!/usr/bin/env python3
"""
Find likely hardcoded user-visible SwiftUI strings that should be localized.

What it catches well:
- Text("...")
- Button("...")
- Label("...", systemImage: ...)
- navigationTitle("...")
- alert("...")
- TextField("...")
- SecureField("...")

What it tries to filter out:
- localization keys like "progress.dashboard.title"
- numeric / punctuation-only strings
- obvious UI test strings
- strings with only interpolation

Usage:
    python3 workouttracker/scripts/localization/find_unlocalized_swift_strings.py
    python3 workouttracker/scripts/localization/find_unlocalized_swift_strings.py --root workouttracker
    python3 workouttracker/scripts/localization/find_unlocalized_swift_strings.py --json
"""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

SWIFT_EXTENSIONS = {".swift"}

DEFAULT_EXCLUDE_DIRS = {
    "Pods",
    ".build",
    "DerivedData",
    ".git",
    "build",
}

DEFAULT_EXCLUDE_PATH_PARTS = {
    "/Pods/",
    "/.build/",
    "/DerivedData/",
    "/.git/",
    "/build/",
}

# Matches the most common SwiftUI literal patterns.
PATTERNS = [
    ("Text", re.compile(r'\bText\(\s*"((?:[^"\\]|\\.)*)"\s*\)')),
    ("Button", re.compile(r'\bButton\(\s*"((?:[^"\\]|\\.)*)"\s*\)')),
    ("Label", re.compile(r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*systemImage:')),
    ("navigationTitle", re.compile(r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"\s*\)')),
    ("alert", re.compile(r'\.alert\(\s*"((?:[^"\\]|\\.)*)"\s*\)')),
    ("TextField", re.compile(r'\bTextField\(\s*"((?:[^"\\]|\\.)*)"\s*,')),
    ("SecureField", re.compile(r'\bSecureField\(\s*"((?:[^"\\]|\\.)*)"\s*,')),
]

# Heuristics
INTERPOLATION_ONLY_RE = re.compile(r'^\s*(?:\\?\([^)]+\)\s*)+$')
LOCALIZATION_KEY_RE = re.compile(r"^[a-z0-9]+(?:[._-][a-z0-9]+)+$", re.IGNORECASE)
HAS_LETTER_RE = re.compile(r"[A-Za-z]")
MOSTLY_SYMBOLS_RE = re.compile(r"^[\s\d+\-–—•.:/()%@#&*_=<>|]+$")
SHORT_TOKEN_RE = re.compile(r"^[A-Za-z]{1,3}$")
PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?[@dDuUxXfFeEgGcCsSpaA]")
UI_TEST_HINT_RE = re.compile(r"\bUITest\b|\bUI Test\b", re.IGNORECASE)

# Common words that often indicate real user-facing English.
ENGLISH_HINT_WORDS = {
    "today", "history", "close", "save", "cancel", "delete", "start", "finish",
    "resume", "open", "edit", "summary", "import", "export", "support", "settings",
    "routine", "routines", "workout", "workouts", "exercise", "exercises", "progress",
    "reflection", "reflections", "backup", "restore", "compare", "new", "done",
    "skip", "previous", "active", "session", "sessions", "schedule", "templates",
    "equipment", "program", "programs", "mappings", "database", "catalog",
}

@dataclass
class Finding:
    file: str
    line: int
    api: str
    text: str
    classification: str
    reason: str


def iter_swift_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.suffix not in SWIFT_EXTENSIONS:
            continue
        if any(part in DEFAULT_EXCLUDE_DIRS for part in path.parts):
            continue
        path_str = path.as_posix()
        if any(part in path_str for part in DEFAULT_EXCLUDE_PATH_PARTS):
            continue
        yield path


def classify_string(text: str, file_path: Path) -> tuple[str, str]:
    stripped = text.strip()

    if not stripped:
        return "ignore", "empty"

    if UI_TEST_HINT_RE.search(stripped):
        return "ignore", "ui-test-specific"

    if file_path.as_posix().endswith("UITests.swift") or "UITests" in file_path.parts:
        return "ignore", "ui-test-file"

    if INTERPOLATION_ONLY_RE.fullmatch(stripped):
        return "ignore", "interpolation-only"

    if MOSTLY_SYMBOLS_RE.fullmatch(stripped):
        return "ignore", "symbols-or-numbers-only"

    if LOCALIZATION_KEY_RE.fullmatch(stripped):
        return "key", "looks-like-localization-key"

    if not HAS_LETTER_RE.search(stripped):
        return "ignore", "no-letters"

    # Single short tokens are often okay but still worth a low-priority look.
    if SHORT_TOKEN_RE.fullmatch(stripped):
        return "low", "short-token"

    lower = stripped.lower()

    if " " in stripped:
        return "high", "contains-spaces"

    if PLACEHOLDER_RE.search(stripped):
        return "medium", "contains-format-placeholder"

    if any(word in lower for word in ENGLISH_HINT_WORDS):
        return "medium", "matches-common-ui-word"

    return "medium", "single-word-literal"


def find_line_number(content: str, match_start: int) -> int:
    return content.count("\n", 0, match_start) + 1


def scan_file(path: Path) -> list[Finding]:
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        content = path.read_text(encoding="utf-8", errors="replace")

    findings: list[Finding] = []

    for api_name, pattern in PATTERNS:
        for match in pattern.finditer(content):
            text = match.group(1)
            classification, reason = classify_string(text, path)
            if classification == "ignore":
                continue

            findings.append(
                Finding(
                    file=path.as_posix(),
                    line=find_line_number(content, match.start()),
                    api=api_name,
                    text=text,
                    classification=classification,
                    reason=reason,
                )
            )

    return findings


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--root",
        default="workouttracker",
        help="Root folder to scan (default: workouttracker)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print results as JSON",
    )
    args = parser.parse_args()

    root = Path(args.root)
    if not root.exists():
        raise SystemExit(f"Root path does not exist: {root}")

    findings: list[Finding] = []
    for swift_file in iter_swift_files(root):
        findings.extend(scan_file(swift_file))

    findings.sort(key=lambda f: (f.classification, f.file, f.line))

    if args.json:
        print(json.dumps([asdict(f) for f in findings], indent=2, ensure_ascii=False))
        return 0

    buckets = {"high": [], "medium": [], "low": [], "key": []}
    for f in findings:
        buckets.setdefault(f.classification, []).append(f)

    for level in ("high", "medium", "low", "key"):
        bucket = buckets.get(level, [])
        print(f"\n=== {level.upper()} ({len(bucket)}) ===")
        for f in bucket:
            print(f"{f.file}:{f.line} [{f.api}] {f.text!r}  ({f.reason})")

    print("\nSummary:")
    for level in ("high", "medium", "low", "key"):
        print(f"  {level}: {len(buckets.get(level, []))}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
