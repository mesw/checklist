#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# generate_index.sh
#
# Scans checklists/ for *.csv files and writes checklists/index.json.
# Run this locally before pushing whenever you add or remove CSV files.
#
# Usage:
#   ./generate_index.sh
#
# Output example:
#   checklists/index.json  →  ["bread_recipe", "morning_routine"]
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKLISTS_DIR="$SCRIPT_DIR/checklists"
OUTPUT="$CHECKLISTS_DIR/index.json"

if [ ! -d "$CHECKLISTS_DIR" ]; then
    echo "Error: checklists/ directory not found at $CHECKLISTS_DIR" >&2
    exit 1
fi

# Collect basenames (no path, no extension), sorted alphabetically
mapfile -t names < <(
    find "$CHECKLISTS_DIR" -maxdepth 1 -name "*.csv" -type f \
    | sort \
    | xargs -I{} basename {} .csv
)

if [ ${#names[@]} -eq 0 ]; then
    echo "[]" > "$OUTPUT"
    echo "No CSV files found — wrote empty index.json"
    exit 0
fi

# Build JSON array
printf '[\n' > "$OUTPUT"
for i in "${!names[@]}"; do
    if [ $i -lt $(( ${#names[@]} - 1 )) ]; then
        printf '  "%s",\n' "${names[$i]}" >> "$OUTPUT"
    else
        printf '  "%s"\n'  "${names[$i]}" >> "$OUTPUT"
    fi
done
printf ']\n' >> "$OUTPUT"

echo "Written $OUTPUT:"
cat "$OUTPUT"
