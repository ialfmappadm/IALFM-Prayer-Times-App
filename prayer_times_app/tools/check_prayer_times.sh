#!/usr/bin/env bash
set -euo pipefail

ANDROID_PKG="${ANDROID_PKG:-org.ialfm.prayertimes}"
IOS_BUNDLE="${IOS_BUNDLE:-org.ialfm.prayertimes}"
META_NAME="prayer_times_meta.json"
DATA_NAME="prayer_times_local.json"

usage() {
  cat <<EOF
Usage:
  $0 --android [--package <pkg>]          Check on Android device/emulator via ADB (debuggable builds)
  $0 --ios-sim [--bundle <bundle-id>]     Check on iOS simulator (booted)

Examples:
  $0 --android --package org.ialfm.prayertimes
  $0 --ios-sim --bundle org.ialfm.prayertimes
EOF
  exit 1
}

MODE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --android) MODE="android"; shift ;;
    --ios-sim) MODE="ios-sim"; shift ;;
    --package) ANDROID_PKG="$2"; shift 2 ;;
    --bundle)  IOS_BUNDLE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

[[ -z "$MODE" ]] && usage

# ---------- Shared pretty-print (pure stdlib Python) ----------
pp_meta() {
  local meta_json="$1"
  local data_path="$2"
  local data_size="$3"
  python3 - "$meta_json" "$data_path" "$data_size" <<'PY'
import sys, json, datetime

def parse_iso_utc(s: str):
    # Accept "…Z" or offset form
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.datetime.fromisoformat(s)  # aware if +00:00
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=datetime.timezone.utc)
        return dt.astimezone(datetime.timezone.utc)
    except Exception:
        return None

def friendly_delta(then_local: datetime.datetime, now_local: datetime.datetime) -> str:
    delta = now_local - then_local
    sec = int(delta.total_seconds())
    future = sec < 0
    sec = abs(sec)
    if sec < 60:
        n, unit = sec, "second"
    elif sec < 3600:
        n, unit = sec//60, "minute"
    elif sec < 86400:
        n, unit = sec//3600, "hour"
    else:
        n, unit = sec//86400, "day"
    s = f"{n} {unit}" + ("" if n == 1 else "s")
    return ("in " + s) if future else (s + " ago")

if __name__ == "__main__":
    raw_meta = sys.argv[1]
    data_path = sys.argv[2]
    data_size = sys.argv[3]

    try:
        meta = json.loads(raw_meta)
    except Exception:
        print("❌ Meta JSON is invalid.")
        sys.exit(4)

    year = meta.get("year")
    last_updated = meta.get("lastUpdated")
    if not last_updated:
        print("❌ Meta missing 'lastUpdated'.")
        sys.exit(5)

    utc_dt = parse_iso_utc(last_updated)
    if not utc_dt:
        print(f"❌ Could not parse UTC ISO time: {last_updated}")
        sys.exit(6)

    local_dt = utc_dt.astimezone()              # system local tz
    now_local = datetime.datetime.now().astimezone()

    print("✅ Meta parsed")
    print(f"   year: {year}")
    print(f"   lastUpdated (UTC):   {utc_dt.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"   lastUpdated (Local): {local_dt.strftime('%Y-%m-%d %H:%M:%S %Z')}")
    print(f"   → File was updated {friendly_delta(local_dt, now_local)}")

    # Data file info
    try:
        size_int = int(data_size)
        size_str = f"{size_int:,} bytes"
    except Exception:
        size_str = f"{data_size} bytes"

    print("\n📄 Local data file")
    print(f"   path: {data_path}")
    print(f"   size: {size_str}")
    print("   note: fully overwritten atomically on each successful cloud download.")
PY
}

# ---------- Android branch ----------
if [[ "$MODE" == "android" ]]; then
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb not found. Install Android platform-tools."; exit 1
  fi
  if ! adb get-state >/dev/null 2>&1; then
    echo "No Android device/emulator detected by adb."; exit 1
  fi

  APP_DIR="/data/user/0/${ANDROID_PKG}/app_flutter"
  META_PATH="${APP_DIR}/${META_NAME}"
  DATA_PATH="${APP_DIR}/${DATA_NAME}"

  # Must be a debuggable build for run-as to work.
  if ! adb shell "run-as ${ANDROID_PKG} id" >/dev/null 2>&1; then
    cat <<EOF
❌ 'run-as ${ANDROID_PKG}' failed.
   • Ensure a **debuggable** build is installed (e.g., 'flutter run' or Android Studio "Run").
   • Verify package name: ${ANDROID_PKG}
   • You can probe with: adb shell "run-as ${ANDROID_PKG} id"
EOF
    exit 2
  fi

  # Ensure meta exists
  if ! adb shell "run-as ${ANDROID_PKG} sh -c 'ls -l \"${META_PATH}\"'" >/dev/null 2>&1; then
    echo "❌ Meta not found: ${META_PATH}"
    echo "   Open the app and let it download from cloud once to create the meta."
    exit 3
  fi

  META_JSON="$(adb exec-out run-as "${ANDROID_PKG}" sh -c "cat '${META_PATH}'" | tr -d '\r')"
  LOCAL_SIZE="$(adb exec-out run-as "${ANDROID_PKG}" sh -c "stat -c %s '${DATA_PATH}' 2>/dev/null || wc -c < '${DATA_PATH}' 2>/dev/null || echo 0" | tr -d '\r')"

  pp_meta "${META_JSON}" "${DATA_PATH}" "${LOCAL_SIZE}"
  exit 0
fi

# ---------- iOS Simulator branch ----------
if [[ "$MODE" == "ios-sim" ]]; then
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun not found. Install Xcode command line tools."; exit 1
  fi

  # Require a booted simulator
  BOOTED_ID="$(xcrun simctl list devices | awk '/Booted/{print $NF}' | tr -d '()' || true)"
  if [[ -z "${BOOTED_ID}" ]]; then
    echo "❌ No booted iOS simulator found. Boot one in Simulator.app or via:"
    echo "   xcrun simctl boot <device-id>"
    exit 3
  fi

  # Find the app's data container (Documents)
  CONTAINER="$(xcrun simctl get_app_container booted "${IOS_BUNDLE}" data 2>/dev/null || true)"
  if [[ -z "${CONTAINER}" ]]; then
    echo "❌ Could not find data container for bundle: ${IOS_BUNDLE}"
    echo "   Make sure the app is installed and has been launched at least once on the booted simulator."
    exit 4
  fi

  APP_DIR="${CONTAINER}/Documents"
  META_PATH="${APP_DIR}/${META_NAME}"
  DATA_PATH="${APP_DIR}/${DATA_NAME}"

  if [[ ! -f "${META_PATH}" ]]; then
    echo "❌ Meta file not found in simulator: ${META_PATH}"
    echo "   Launch the app in the simulator and let it download once."
    exit 5
  fi

  META_JSON="$(cat "${META_PATH}")"
  if [[ -f "${DATA_PATH}" ]]; then
    LOCAL_SIZE="$(stat -f%z "${DATA_PATH}")"
  else
    LOCAL_SIZE="0"
  fi

  pp_meta "${META_JSON}" "${DATA_PATH}" "${LOCAL_SIZE}"
  exit 0
fi

usage