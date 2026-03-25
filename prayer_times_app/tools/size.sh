#!/usr/bin/env bash
# tools/size.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${PROJECT_ROOT}/build/app/outputs/bundle/release"
AAB="${OUT_DIR}/app-release.aab"
APKS="${PROJECT_ROOT}/app.apks"
REPORT="${PROJECT_ROOT}/tools/size_report.txt"

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

die() { red "✖ $*"; exit 1; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing '$1' on PATH"
}

bytes_to_human() {
  # $1 = bytes
  awk -v b="$1" 'BEGIN {
    mib = b/1048576.0; mb = b/1000000.0;
    printf("%.2f MiB (%.2f MB)", mib, mb);
  }'
}

extract_minmax_line() {
  # reads CSV (MIN,MAX header followed by one line)
  # prints: "<min_bytes> <max_bytes>"
  tail -n +2 | head -n 1 | awk -F',' '{print $1" "$2}'
}

ensure_device_json() {
  local json="$1"
  # If device is connected, capture its spec. If not, create a generic arm64 spec.
  if bundletool get-device-spec --output="$json" >/dev/null 2>&1; then
    return 0
  fi
  cat > "$json" <<'JSON'
{
  "supportedAbis": ["arm64-v8a"],
  "supportedLocales": ["en","ar"],
  "deviceFeatures": [],
  "glExtensions": []
}
JSON
}

main() {
  need flutter
  need bundletool

  bold "▶ Building AAB (release)…"
  (cd "$PROJECT_ROOT" && flutter build appbundle --release >/dev/null)
  [ -f "$AAB" ] || die "AAB not found at $AAB"
  green "✓ AAB: $AAB"

  bold "▶ Building APKS from AAB (local, unsigned OK)…"
  bundletool build-apks \
    --bundle="$AAB" \
    --output="$APKS" \
    --mode=DEFAULT \
    --overwrite >/dev/null
  green "✓ APKS: $APKS"

  DEVICE_JSON="${PROJECT_ROOT}/device.json"
  ARM64_JSON="${PROJECT_ROOT}/arm64.json"
  ARMV7_JSON="${PROJECT_ROOT}/armv7.json"

  bold "▶ Preparing device specs…"
  ensure_device_json "$DEVICE_JSON"
  cat > "$ARM64_JSON" <<'JSON'
{
  "supportedAbis": ["arm64-v8a"],
  "supportedLocales": ["en","ar"],
  "deviceFeatures": [],
  "glExtensions": []
}
JSON
  cat > "$ARMV7_JSON" <<'JSON'
{
  "supportedAbis": ["armeabi-v7a"],
  "supportedLocales": ["en","ar"],
  "deviceFeatures": [],
  "glExtensions": []
}
JSON
  green "✓ Specs: $DEVICE_JSON, $ARM64_JSON, $ARMV7_JSON"

  bold "▶ Computing sizes (download)…"

  # 1) Your device
  DEV_LINE="$(bundletool get-size total --apks="$APKS" --device-spec="$DEVICE_JSON" | extract_minmax_line || true)"
  DEV_MIN="$(echo "$DEV_LINE" | awk '{print $1}')"
  DEV_MAX="$(echo "$DEV_LINE" | awk '{print $2}')"

  # 2) ARM64 generic
  ARM64_LINE="$(bundletool get-size total --apks="$APKS" --device-spec="$ARM64_JSON" | extract_minmax_line || true)"
  ARM64_MIN="$(echo "$ARM64_LINE" | awk '{print $1}')"
  ARM64_MAX="$(echo "$ARM64_LINE" | awk '{print $2}')"

  # 3) ARMv7 generic
  ARMV7_LINE="$(bundletool get-size total --apks="$APKS" --device-spec="$ARMV7_JSON" | extract_minmax_line || true)"
  ARMV7_MIN="$(echo "$ARMV7_LINE" | awk '{print $1}')"
  ARMV7_MAX="$(echo "$ARMV7_LINE" | awk '{print $2}')"

  # 4) Per‑ABI ranges
  ABI_CSV="$(bundletool get-size total --apks="$APKS" --dimensions=ABI || true)"

  # Print
  {
    echo "==== IALFM Android Size Report ===="
    echo "AAB (full bundle): $(du -h "$AAB" | awk '{print $1}') at $AAB"
    echo
    echo "Device (connected or generic arm64):"
    if [[ -n "${DEV_MIN:-}" && -n "${DEV_MAX:-}" ]]; then
      echo "  Download: min $(bytes_to_human "$DEV_MIN"), max $(bytes_to_human "$DEV_MAX")"
    else
      echo "  (No device; fell back to generic arm64)"
    fi
    echo
    echo "ARM64 generic:"
    [[ -n "${ARM64_MIN:-}" && -n "${ARM64_MAX:-}" ]] && \
      echo "  Download: min $(bytes_to_human "$ARM64_MIN"), max $(bytes_to_human "$ARM64_MAX")"
    echo
    echo "ARMv7 generic:"
    [[ -n "${ARMV7_MIN:-}" && -n "${ARMV7_MAX:-}" ]] && \
      echo "  Download: min $(bytes_to_human "$ARMV7_MIN"), max $(bytes_to_human "$ARMV7_MAX")"
    echo
    echo "Per‑ABI ranges (bytes, from bundletool):"
    echo "$ABI_CSV"
    echo
    echo "Generated: $(date)"
  } | tee "$REPORT"

  cyan "Report saved to $REPORT"
  green "Done."
}

main "$@"