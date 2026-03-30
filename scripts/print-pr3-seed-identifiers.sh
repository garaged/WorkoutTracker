#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="garaged.org.workouttracker"
SIMULATOR="booted"
LIMIT=15
SHOW_TABLES=0

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Best-effort inspector for the installed WorkoutTracker simulator store.
It finds the app data container, locates the SQLite/SwiftData store, and prints
likely routine/session rows with UUID-ish identifiers when possible.

Options:
  --bundle-id <id>       App bundle identifier (default: ${BUNDLE_ID})
  --simulator <name>     Simulator device name or UDID, or 'booted' (default: ${SIMULATOR})
  --limit <n>            Max sample rows per candidate table (default: ${LIMIT})
  --show-tables          Also print all table names discovered in the store
  -h, --help             Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bundle-id)
      BUNDLE_ID="$2"
      shift 2
      ;;
    --simulator)
      SIMULATOR="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --show-tables)
      SHOW_TABLES=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun is required." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

DATA_PATH=$(xcrun simctl get_app_container "$SIMULATOR" "$BUNDLE_ID" data 2>/dev/null || true)
if [[ -z "${DATA_PATH}" ]]; then
  echo "Could not find app data container for bundle id '${BUNDLE_ID}' on simulator '${SIMULATOR}'." >&2
  echo "Make sure the app is installed on that simulator first." >&2
  exit 1
fi

STORE_PATH=$(find "$DATA_PATH" -type f \( -name "default.store" -o -name "*.store" -o -name "*.sqlite" -o -name "*.db" \) | head -n 1)
if [[ -z "${STORE_PATH}" ]]; then
  echo "No obvious store file found under: $DATA_PATH" >&2
  exit 1
fi

echo "Bundle ID : $BUNDLE_ID"
echo "Simulator : $SIMULATOR"
echo "Data path : $DATA_PATH"
echo "Store path: $STORE_PATH"
echo

python3 - "$STORE_PATH" "$LIMIT" "$SHOW_TABLES" <<'PY'
import sqlite3
import sys
import uuid
from pathlib import Path

store_path = sys.argv[1]
limit = int(sys.argv[2])
show_tables = sys.argv[3] == "1"

uri = f"file:{Path(store_path).as_posix()}?mode=ro"
conn = sqlite3.connect(uri, uri=True)
conn.row_factory = sqlite3.Row


def decode_value(value):
    if value is None:
        return None
    if isinstance(value, bytes):
        if len(value) == 16:
            try:
                return str(uuid.UUID(bytes=value))
            except Exception:
                pass
        try:
            return value.decode("utf-8")
        except Exception:
            return value.hex()
    return value


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def fetch_table_names():
    rows = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
    ).fetchall()
    return [r[0] for r in rows]


def table_columns(table):
    rows = conn.execute(f"PRAGMA table_info({quote_ident(table)})").fetchall()
    return [
        {
            "name": r[1],
            "type": (r[2] or "").upper(),
        }
        for r in rows
    ]


def classify_table(table, cols):
    hay = f"{table} " + " ".join(c["name"] for c in cols)
    lowered = hay.lower()
    score_routine = 0
    score_session = 0
    for token in ("routine", "workoutroutine"):
        if token in lowered:
            score_routine += 3
    for token in ("session", "workoutsession"):
        if token in lowered:
            score_session += 3
    for token in ("name", "title", "sourceroutinename", "routinename"):
        if token in lowered:
            score_routine += 1
    for token in ("status", "ended", "started", "current", "exercise"):
        if token in lowered:
            score_session += 1
    if score_routine == 0 and score_session == 0:
        return None
    if score_routine >= score_session:
        return "routine"
    return "session"


def choose_columns(kind, cols):
    names = [c["name"] for c in cols]
    lowered = {c["name"]: c["name"].lower() for c in cols}

    def find_first(*candidates):
        for cand in candidates:
            for original, low in lowered.items():
                if cand == low:
                    return original
        return None

    def find_contains(*candidates):
        for cand in candidates:
            for original, low in lowered.items():
                if cand in low:
                    return original
        return None

    id_col = find_first("id", "zid") or find_contains("uuid", "identifier", " id", "_id") or find_contains("zid")
    pk_col = find_first("z_pk") or find_contains("pk")

    if kind == "routine":
        label_col = (
            find_first("name", "zname")
            or find_contains("name")
            or find_contains("title")
        )
        extra_cols = [
            c for c in [find_contains("notes"), find_contains("created"), find_contains("updated")] if c
        ]
    else:
        label_col = (
            find_contains("sourceroutinename")
            or find_contains("routinename")
            or find_first("name", "title", "zname")
        )
        extra_cols = [
            c for c in [find_contains("status"), find_contains("started"), find_contains("ended")] if c
        ]

    selected = []
    for c in [id_col, pk_col, label_col, *extra_cols]:
        if c and c not in selected:
            selected.append(c)

    if not selected:
        selected = names[: min(4, len(names))]

    return selected


def sample_rows(table, selected, limit):
    query = f"SELECT {', '.join(quote_ident(c) for c in selected)} FROM {quote_ident(table)} LIMIT {limit}"
    rows = conn.execute(query).fetchall()
    decoded = []
    for row in rows:
        item = {}
        for key in row.keys():
            item[key] = decode_value(row[key])
        decoded.append(item)
    return decoded


tables = fetch_table_names()
if show_tables:
    print("All tables:")
    for t in tables:
        print(f"  - {t}")
    print()

candidates = []
for table in tables:
    cols = table_columns(table)
    kind = classify_table(table, cols)
    if kind:
        candidates.append((kind, table, cols))

if not candidates:
    print("No obvious routine/session tables found.")
    print("Run again with --show-tables to inspect all table names.")
    sys.exit(0)

for kind in ("routine", "session"):
    kind_tables = [c for c in candidates if c[0] == kind]
    if not kind_tables:
        continue

    print(f"Likely {kind} tables:")
    for _, table, cols in kind_tables:
        selected = choose_columns(kind, cols)
        print(f"\n[{table}]")
        print("Columns:", ", ".join(c["name"] for c in cols))
        print("Sample fields:", ", ".join(selected))
        try:
            rows = sample_rows(table, selected, limit)
        except Exception as exc:
            print(f"  Could not sample rows: {exc}")
            continue
        if not rows:
            print("  (no rows)")
            continue
        for idx, row in enumerate(rows, start=1):
            pretty = ", ".join(f"{k}={row[k]!r}" for k in row)
            print(f"  {idx}. {pretty}")
    print()

print("Notes:")
print("- UUID-looking values decoded from 16-byte blobs are printed as standard UUID strings when possible.")
print("- SwiftData/Core Data stores may use internal table/column names, so this is best-effort rather than schema-perfect.")
PY
