#!/usr/bin/env bash
# Usage: ./studio/new-feature.sh <slug> ["Title"]
# Creates studio/features/F-XXX-<slug>.md from the template with the next free ID
# and adds a row to STATUS.md.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEAT="$DIR/features"
TEMPLATE="$FEAT/_TEMPLATE.md"
STATUS="$DIR/STATUS.md"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <slug> [\"Title\"]" >&2
  exit 1
fi

SLUG="$(echo "$1" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9-')"
TITLE="${2:-$1}"
TODAY="$(date +%F)"

# Next ID = highest existing F-NNN + 1 (F-000 counts)
LAST=$(ls "$FEAT" 2>/dev/null | grep -oE '^F-[0-9]{3}' | sed 's/F-//' | sort -n | tail -1 || true)
if [[ -z "${LAST:-}" ]]; then NEXT=0; else NEXT=$((10#$LAST + 1)); fi
ID=$(printf "F-%03d" "$NEXT")

OUT="$FEAT/$ID-$SLUG.md"
if [[ -e "$OUT" ]]; then echo "Exists: $OUT" >&2; exit 1; fi

sed -e "s/F-XXX/$ID/g" \
    -e "s/<short name>/$TITLE/" \
    -e "s/<title>/$TITLE/" \
    -e "s/YYYY-MM-DD/$TODAY/g" \
    -e "s/<slug>/$SLUG/g" \
    "$TEMPLATE" > "$OUT"

# Append row to the board table (after the last table row in the first table)
ROW="| $ID | $TITLE | DRAFT | Planner | — |"
awk -v row="$ROW" '
  BEGIN{in_table=0; done=0}
  /^\| ID \|/ {in_table=1}
  in_table && !/^\|/ && !done {print row; done=1; in_table=0}
  {print}
  END{if(in_table && !done) print row}
' "$STATUS" > "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"
sed -i.bak "s/^\*\*Last updated:\*\*.*/**Last updated:** $TODAY/" "$STATUS" && rm -f "$STATUS.bak"

echo "Created $OUT"
