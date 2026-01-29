#!/usr/bin/env bash
# tools/profile_build.sh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[36m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red()   { printf "\033[31m%s\033[0m\n" "$*"; }
die() { red "✖ $*"; exit 1; }

usage() {
  cat <<'USAGE'
profile_build.sh — SkSL capture & build helper

USAGE:
  # 1) Run app in profile and capture SkSL via DevTools
  tools/profile_build.sh run [-d DEVICE_ID]

  # 2) Build release APK with your exported SkSL JSON
  tools/profile_build.sh build --sksl path/to/flutter_sksl.json [-d DEVICE_ID] [--target android-arm64|android-arm]

EXAMPLES:
  tools/profile_build.sh run -d RFCW4070EXF
  tools/profile_build.sh build --sksl flutter_sksl.json --target android-arm64

NOTES:
- In RUN mode, the script launches:  flutter run --profile -d <device>
  Watch the console output for the DevTools link, open it → Performance tab,
  click "Capture/Record SkSL", exercise the app, then click "Export".
- In BUILD mode, the script builds the release APK with --bundle-sksl-path.

USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing '$1' on PATH"
}

run_mode() {
  local device="${1:-}"
  need flutter
  bold "▶ Launching in PROFILE mode…"
  if [[ -n "$device" ]]; then
    cyan "Device: $device"
    (cd "$PROJECT_ROOT" && flutter run --profile -d "$device")
  else
    (cd "$PROJECT_ROOT" && flutter run --profile)
  fi
  # When flutter run exits, user probably pressed 'q'.
}

build_mode() {
  local sksl="" device="" target="android-arm64"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sksl) sksl="$2"; shift 2;;
      -d|--device) device="$2"; shift 2;;
      --target) target="$2"; shift 2;;
      *) die "Unknown flag: $1";;
    esac
  done
  [[ -f "$sksl" ]] || die "SkSL JSON not found: $sksl"
  need flutter

  bold "▶ Building RELEASE APK with SkSL"
  cyan "SkSL: $sksl"
  cyan "Target platform: $target"
  if [[ -n "$device" ]]; then cyan "Device: $device"; fi

  (cd "$PROJECT_ROOT" && \
    flutter build apk --release \
      --target-platform="$target" \
      --bundle-sksl-path "$sksl")

  green "✓ Built: $(ls "$PROJECT_ROOT"/build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true)"
}

main() {
  [[ $# -lt 1 ]] && { usage; exit 1; }
  case "$1" in
    run)
      shift
      local device=""
      if [[ "${1:-}" == "-d" || "${1:-}" == "--device" ]]; then
        device="${2:-}"; shift 2 || true
      fi
      cat <<'TIP'
────────────────────────────────────────────────────────────────
INSTRUCTIONS (RUN MODE)
1) A Flutter DevTools URL will appear in the terminal once the app is running.
2) Open DevTools → Performance → "Capture/Record SkSL".
3) Exercise the app: Prayer, Announcements, Directory, More; scroll.
4) Export SkSL to a file, e.g., flutter_sksl.json.
5) When done, return here and press 'q' in the flutter run terminal to quit.
────────────────────────────────────────────────────────────────
TIP
      run_mode "$device"
      ;;
    build)
      shift
      build_mode "$@"
      ;;
    *)
      usage; exit 1;;
  esac
}

main "$@"