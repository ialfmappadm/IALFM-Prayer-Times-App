#!/usr/bin/env bash
set -euo pipefail

# ===== Minimal, app-scoped Doze collector (3 files only) =====
# Files produced in doze_min_<timestamp>_<serial>/ :
#   1) alarm_prayertimes.txt     -> your app's lines from dumpsys alarm (4 snapshots appended)
#   2) deviceidle_state.txt      -> tiny Doze state summary only (no app lists)
#   3) log_prayertimes.txt       -> logcat filtered to your package + DOZE_MARK timeline
#
# Privacy notes:
# - No getprop, no full deviceidle dumps, no package whitelists, no browser/app history.
# - logcat is filtered to lines containing your package name or DOZE_MARK.

SERIAL="${1:-RFCW4070EXF}"
PKG="${2:-org.ialfm.prayertimes}"
TEST_MINUTES="${3:-5}"

ts() { date +"%Y%m%d_%H%M%S"; }
now() { date +"%F %T"; }
OUT_DIR="doze_min_$(ts)_${SERIAL}"
mkdir -p "$OUT_DIR"

ALARM_OUT="$OUT_DIR/alarm_prayertimes.txt"
IDLE_OUT="$OUT_DIR/deviceidle_state.txt"
LOG_OUT="$OUT_DIR/log_prayertimes.txt"

echo "[*] Output folder: $OUT_DIR"
adb -s "$SERIAL" get-state 1>/dev/null

# ---------- Logcat (filtered) ----------
# Only keep lines that contain either our PKG string or our DOZE_MARK tag.
# stdbuf ensures line-buffered piping so logs appear in real time.
# ---------- Logcat (filtered) ----------
adb -s "$SERIAL" logcat -c || true

# Choose tags to include; add more if your app uses custom tags
# We include common Flutter tags by default.
LOG_TAGS=("DOZE_MARK" "flutter" "flutter_local_notifications")

# Build `-s` arguments for logcat (only include our tags; silence others)
LOGCAT_FILTER=(-v time -s)
for t in "${LOG_TAGS[@]}"; do LOGCAT_FILTER+=("$t"); done

# Start logcat with tag filters only (no stdbuf), write directly to file
adb -s "$SERIAL" logcat "${LOGCAT_FILTER[@]}" > "$LOG_OUT" 2>&1 &
LOG_PID=$!

cleanup() {
  if kill -0 "$LOG_PID" 2>/dev/null; then
    kill "$LOG_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

mark() {
  local m="$1"
  adb -s "$SERIAL" shell log -t DOZE_MARK "$m" || true
}

# ---------- helpers ----------
snapshot_alarm() {
  local name="$1"
  {
    echo "===== [$name] $(now) ====="
    # Pull only lines that include your package (with a little context).
    # -B1: one line before; -A4: four lines after helps show type/when/window around each hit.
    adb -s "$SERIAL" shell dumpsys alarm \
      | grep -n -E "(${PKG//./\\.})" -B1 -A4 || true
    echo
  } >> "$ALARM_OUT"
}

snapshot_idle() {
  local name="$1"
  {
    echo "===== [$name] $(now) ====="
    # A very small subset of deviceidle state—no app lists or whitelists:
    adb -s "$SERIAL" shell dumpsys deviceidle \
      | grep -E "^(m(State|LightState|ForceIdle|ForceType|LightEnabled|DeepEnabled)|mNext(AlarmTime|Idle(PendingDelay|Delay)|LightIdleDelay)|mMaintenanceStartTime|mInactiveTimeout|mCurLightIdleBudget)" \
      || true
    echo
  } >> "$IDLE_OUT"
}

# ---------- Phase 1: Baseline ----------
mark "BEGIN_BASELINE"
snapshot_alarm "before_doze"
snapshot_idle  "before_doze"

# ---------- Phase 2: Enter Doze ----------
echo "[*] Forcing Doze (unplug battery sim + force-idle)"
adb -s "$SERIAL" shell dumpsys battery unplug || true
adb -s "$SERIAL" shell cmd deviceidle force-idle 2>/dev/null || adb -s "$SERIAL" shell dumpsys deviceidle force-idle

mark "ENTERED_DOZE"
snapshot_alarm "after_force_idle"
snapshot_idle  "after_force_idle"

# ---------- Phase 3: Step maintenance windows ----------
STEPS=$(( TEST_MINUTES * 2 ))   # ~ two steps per minute (30s each)
echo "[*] Stepping maintenance windows: $STEPS steps (~${TEST_MINUTES} min)"
for i in $(seq 1 "$STEPS"); do
  mark "MAINT_STEP_${i}_BEGIN"
  adb -s "$SERIAL" shell cmd deviceidle step 2>/dev/null || adb -s "$SERIAL" shell dumpsys deviceidle step
  sleep 30
  mark "MAINT_STEP_${i}_END"
done

snapshot_alarm "after_steps"
snapshot_idle  "after_steps"

# ---------- Phase 4: Exit Doze ----------
mark "EXITING_DOZE"
adb -s "$SERIAL" shell cmd deviceidle unforce 2>/dev/null || true
adb -s "$SERIAL" shell dumpsys battery reset || true
sleep 1

snapshot_alarm "final"
snapshot_idle  "final"

# ---------- Stop logcat ----------
cleanup
echo "[*] Done."
echo "    - $ALARM_OUT"
echo "    - $IDLE_OUT"
echo "    - $LOG_OUT"