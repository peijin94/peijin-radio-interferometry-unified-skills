#!/usr/bin/env bash
# Resumable batch template: one unit at a time, niced, trap-safe.
# Adapt: STAMPS list, per-unit work, success check, collect, cleanup.
set -uo pipefail
cd /path/to/work || exit 1
source /path/to/env.sh
OUTROOT=./out; WORKROOT=./work; LOG=./run.log; MANIFEST=./manifest.tsv
mkdir -p "$WORKROOT" "$OUTROOT"
[ -f "$MANIFEST" ] || printf "unit\tstatus\telapsed_s\n" > "$MANIFEST"
trap 'echo "=== interrupted ===" >> "$LOG"; exit 130' INT TERM
ulimit -n 65536 || true
for UNIT in "$@"; do  # or: mapfile -t UNITS < <(generate list)
    OUT="$OUTROOT/$UNIT"
    if [ -f "$OUT/.done" ]; then continue; fi
    start=$(date +%s)
    WD="$WORKROOT/$UNIT"; rm -rf "$WD"; mkdir -p "$WD"
    if nice -n 19 ionice -c3 python process_unit.py --unit "$UNIT" --work-dir "$WD" \
        --out-dir "$OUT" >> "$LOG" 2>&1; then
        echo "$(date +%s)" > "$OUT/.done"
        printf "%s\tok\t%d\n" "$UNIT" "$(( $(date +%s) - start ))" >> "$MANIFEST"
        rm -rf "$WD"
    else
        printf "%s\tfailed\t%d\n" "$UNIT" "$(( $(date +%s) - start ))" >> "$MANIFEST"
        echo "FAILED $UNIT (work kept at $WD)" >> "$LOG"
    fi
done
echo "=== done ===" >> "$LOG"
