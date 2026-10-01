#!/usr/bin/env bash
# calim2_calib_status.sh — summarize recent OVRO-LWA centralized calibration runs.
# Run ON calim2 (lwacalim02). Read-only: only reads logs/results/watch_state.
#
# Usage:  bash calim2_calib_status.sh [N_DAYS]     (default 3 most recent date dirs)
set -uo pipefail

N=${1:-3}
FAST=/fast/pipeline/calibration
LOGS=$FAST/logs
STATE=$FAST/watch_state
RES=/lustre/pipeline/calibration/results

echo "== watcher =="
if pgrep -af watch_calib_auto.sh >/dev/null 2>&1; then
    pgrep -af watch_calib_auto.sh
else
    echo "watch_calib_auto.sh NOT RUNNING (restart it in a tmux/nohup session if expected)"
fi
[ -f "$LOGS/watch_calib_auto.log" ] && { echo "-- last watcher lines:"; tail -n 3 "$LOGS/watch_calib_auto.log"; }

echo
echo "== results, last $N date dirs =="
for d in $(ls -1 "$RES" 2>/dev/null | tail -n "$N"); do
    printf '%s: ' "$d"
    for h in "$RES/$d"/*h; do
        [ -d "$h" ] || continue
        st="?"
        [ -d "$h/successful" ]   && st=successful
        [ -d "$h/unsuccessful" ] && st=unsuccessful
        printf '%s=%s  ' "$(basename "$h")" "$st"
    done
    echo
done

echo
echo "== newest hour-logs =="
for f in $(ls -t "$LOGS"/calib_*.log 2>/dev/null | head -2); do
    echo "--- $f"
    grep -E "=== (Start|End)|status: SUCCESS|status: FAILURE|std::bad_alloc|(WSClean .* failed)" "$f" 2>/dev/null | tail -8
done

echo
echo "== watch_state (last 6) =="
ls "$STATE" 2>/dev/null | tail -6
