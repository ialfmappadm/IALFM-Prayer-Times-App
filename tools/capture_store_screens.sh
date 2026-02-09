#!/usr/bin/env bash
set -euo pipefail

# ========== PROJECT ROOT / OUTPUT ==========
PROJECT_ROOT_DEFAULT="/Users/syed/AndroidStudioProjects/prayer_times_app"

OUT_DIR="${OUT_DIR-}"
if [[ -z "${OUT_DIR}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  probe="$SCRIPT_DIR"; FOUND_ROOT=""
  while [[ "$probe" != "/" ]]; do
    if [[ -f "$probe/pubspec.yaml" || -d "$probe/.git" ]]; then FOUND_ROOT="$probe"; break; fi
    probe="$(dirname "$probe")"
  done
  [[ -z "$FOUND_ROOT" ]] && FOUND_ROOT="$PROJECT_ROOT_DEFAULT"
  OUT_DIR="$FOUND_ROOT/tools/screenshots"
fi

# ========== DEVICE / SIM ==========
ANDROID_SERIAL="${ANDROID_SERIAL- RFCW4070EXF}"
IOS_UDID="${IOS_UDID- 1B856CF2-D454-44DC-856C-8484A8AF9CC3}"

# ========== ANDROID MODES ==========
# Use System‑UI saved file first (like manual capture). Recommended.
ANDROID_USE_SYSUI="${ANDROID_USE_SYSUI-true}"

# Only if System‑UI path fails AND you set this to true, we try screencap fallbacks:
ANDROID_ALLOW_SCREENCAP_FALLBACK="${ANDROID_ALLOW_SCREENCAP_FALLBACK-false}"
# (Z Fold long displayId example: 4630946474867211650)
ANDROID_DISPLAY_ID="${ANDROID_DISPLAY_ID-}"

# Where System‑UI saves files on Samsung/OneUI:
ANDROID_SYSUI_SS_DIR="${ANDROID_SYSUI_SS_DIR-/storage/emulated/0/DCIM/Screenshots}"
# Wait for a *new* screenshot (seconds) and grace after to quiet UI (seconds)
ANDROID_SYSUI_WAIT="${ANDROID_SYSUI_WAIT-12}"
ANDROID_SYSUI_GRACE="${ANDROID_SYSUI_GRACE-6}"

# Keep screen awake for the whole session + wake before each shot
KEEP_AWAKE="${KEEP_AWAKE-true}"
WAKE_BEFORE_CAPTURE="${WAKE_BEFORE_CAPTURE-true}"

# Output format / size
# Force PNG even if device saved JPG (no resampling)
ANDROID_FORCE_PNG="${ANDROID_FORCE_PNG-true}"
# Optional resize to standard canvas (off by default)
ANDROID_RESIZE="${ANDROID_RESIZE-false}"
ANDROID_TARGET_W="${ANDROID_TARGET_W-1080}"
ANDROID_TARGET_H="${ANDROID_TARGET_H-1920}"

# Keep *_raw.<ext> alongside final output?
KEEP_RAW="${KEEP_RAW-true}"

# ========== iOS ==========
IOS_FORCE_W="${IOS_FORCE_W-}"
IOS_FORCE_H="${IOS_FORCE_H-}"
IOS_STATUSBAR_OPTS=(--time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100)

# ========== HELPERS ==========
require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1"; exit 1; }; }
hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }
confirm() { read -r -p "$1 [Enter to continue / Ctrl+C to abort]"; }

ensure_output_roots() {
  mkdir -p "${OUT_DIR}/android" "${OUT_DIR}/ios"
  for d in "${OUT_DIR}/android" "${OUT_DIR}/ios"; do
    [[ -f "${d}/.gitkeep" ]] || : > "${d}/.gitkeep"
  done
}

# Keep-awake utilities (best effort; does not require root)
start_keep_awake() {
  adb -s "$ANDROID_SERIAL" shell settings put global stay_on_while_plugged_in 7 >/dev/null 2>&1 || true
  adb -s "$ANDROID_SERIAL" shell svc power stayon true >/dev/null 2>&1 || true
}
stop_keep_awake() {
  adb -s "$ANDROID_SERIAL" shell svc power stayon false >/dev/null 2>&1 || true
  adb -s "$ANDROID_SERIAL" shell settings put global stay_on_while_plugged_in 0 >/dev/null 2>&1 || true
}
wake_and_dismiss_keyguard() {
  # Wake (KEYCODE_WAKEUP 224) → does NOT toggle like POWER
  adb -s "$ANDROID_SERIAL" shell input keyevent 224 >/dev/null 2>&1 || true
  # Try dismissing keyguard (may be ignored on secure locks)
  adb -s "$ANDROID_SERIAL" shell wm dismiss-keyguard >/dev/null 2>&1 || true
  adb -s "$ANDROID_SERIAL" shell input keyevent 82 >/dev/null 2>&1 || true  # MENU
}

# --- Image validation / detection (PNG or JPG by magic) ---
is_image_signature_ok() {
  local f="$1"
  [[ -s "$f" ]] || return 1
  local sig8; sig8="$(head -c 8 "$f" | od -An -t x1 | tr -d ' \n')"
  local sig3="${sig8:0:6}"
  [[ "$sig8" == "89504e470d0a1a0a" ]] && return 0   # PNG
  [[ "$sig3" == "ffd8ff" ]] && return 0             # JPG
  return 1
}
detect_image_ext() {
  local f="$1"
  local sig8; sig8="$(head -c 8 "$f" | od -An -t x1 | tr -d ' \n')"
  local sig3="${sig8:0:6}"
  if [[ "$sig8" == "89504e470d0a1a0a" ]]; then echo "png"; return 0; fi
  if [[ "$sig3" == "ffd8ff" ]]; then echo "jpg"; return 0; fi
  echo "png"
}

# Finalize Android image to desired output
finalize_android_image() {
  # $1=infile; $2=final_path (extension should be .png if forcing PNG/resize)
  local in="$1" out="$2"
  if [[ "$ANDROID_RESIZE" == "true" ]]; then
    require sips
    sips -s format png -z "$ANDROID_TARGET_H" "$ANDROID_TARGET_W" "$in" --out "$out" >/dev/null
  elif [[ "$ANDROID_FORCE_PNG" == "true" ]]; then
    require sips
    sips -s format png "$in" --out "$out" >/dev/null
  else
    cp "$in" "$out"
  fi
}

# ========== ANDROID: System‑UI path ==========
android_newest_in_dir() {
  local dir="$1"
  adb -s "$ANDROID_SERIAL" shell "if [ -d '$dir' ]; then ls -1t '$dir' 2>/dev/null | head -n1; fi" | tr -d '\r'
}

android_capture_via_sysui_pull() {
  # $1 = remote path; $2 = raw_base (without ext)
  local remote="$1" raw_base="$2"
  local tmp_local="${raw_base}.tmp"
  adb -s "$ANDROID_SERIAL" pull "$remote" "$tmp_local" >/dev/null 2>&1 || return 1
  is_image_signature_ok "$tmp_local" || return 1
  local ext; ext="$(detect_image_ext "$tmp_local")"
  local raw_with_ext="${raw_base}.${ext}"
  mv -f "$tmp_local" "$raw_with_ext"
  echo "$raw_with_ext"
}

android_capture_via_sysui() {
  # $1 = raw_base (without extension). Echo local raw path on success.
  local raw_base="$1"
  local dirs=(
    "$ANDROID_SYSUI_SS_DIR"
    "/sdcard/DCIM/Screenshots"
    "/storage/emulated/0/Pictures/Screenshots"
    "/sdcard/Pictures/Screenshots"
  )
  local before0 before1 before2 before3
  before0="$(android_newest_in_dir "${dirs[0]}")"
  before1="$(android_newest_in_dir "${dirs[1]}")"
  before2="$(android_newest_in_dir "${dirs[2]}")"
  before3="$(android_newest_in_dir "${dirs[3]}")"

  echo "   • Triggering System‑UI screenshot..."
  if [[ "$WAKE_BEFORE_CAPTURE" == "true" ]]; then
    wake_and_dismiss_keyguard
    sleep 0.2
  fi
  # PRESS ONLY SYSRQ (120). DO NOT PRESS POWER (26).
  adb -s "$ANDROID_SERIAL" shell input keyevent 120 >/dev/null 2>&1 || true
  # If 120 is ignored on your build, press Power+Vol‑Down manually at the prompt.

  # Wait for a *new* file
  local newest="" chosen_dir="" i=0
  while [[ $i -lt $ANDROID_SYSUI_WAIT ]]; do
    local now0 now1 now2 now3
    now0="$(android_newest_in_dir "${dirs[0]}")"
    now1="$(android_newest_in_dir "${dirs[1]}")"
    now2="$(android_newest_in_dir "${dirs[2]}")"
    now3="$(android_newest_in_dir "${dirs[3]}")"
    if [[ -n "$now0" && "$now0" != "$before0" ]]; then newest="$now0"; chosen_dir="${dirs[0]}"; break; fi
    if [[ -n "$now1" && "$now1" != "$before1" ]]; then newest="$now1"; chosen_dir="${dirs[1]}"; break; fi
    if [[ -n "$now2" && "$now2" != "$before2" ]]; then newest="$now2"; chosen_dir="${dirs[2]}"; break; fi
    if [[ -n "$now3" && "$now3" != "$before3" ]]; then newest="$now3"; chosen_dir="${dirs[3]}"; break; fi
    sleep 1; i=$((i+1))
  done

  # If no "new", pragmatically pull current newest (covers manual hardware press)
  if [[ -z "$newest" ]]; then
    echo "   • No 'new' file detected in ${ANDROID_SYSUI_WAIT}s; pulling current newest pragmatically."
    if   [[ -n "$before0" ]]; then newest="$before0"; chosen_dir="${dirs[0]}";
    elif [[ -n "$before1" ]]; then newest="$before1"; chosen_dir="${dirs[1]}";
    elif [[ -n "$before2" ]]; then newest="$before2"; chosen_dir="${dirs[2]}";
    elif [[ -n "$before3" ]]; then newest="$before3"; chosen_dir="${dirs[3]}";
    else return 1; fi
  fi

  local remote="${chosen_dir}/${newest}"
  echo "   • Pulling: ${remote}"
  sleep "$ANDROID_SYSUI_GRACE"
  android_capture_via_sysui_pull "$remote" "$raw_base"
}

# ========== ANDROID: screencap fallbacks (opt-in only) ==========
android_capture_via_sdcard() {
  local raw_base="$1" id="${2-}"
  local tmp="/sdcard/__tmp_screen.png"
  adb -s "$ANDROID_SERIAL" shell rm -f "$tmp" >/dev/null 2>&1 || true
  if [[ -n "$id" ]]; then
    adb -s "$ANDROID_SERIAL" shell screencap -d "$id" -p "$tmp" >/dev/null 2>&1 || return 1
  else
    adb -s "$ANDROID_SERIAL" shell screencap -p "$tmp" >/dev/null 2>&1 || return 1
  fi
  local raw_with_ext="${raw_base}.png"
  adb -s "$ANDROID_SERIAL" pull "$tmp" "$raw_with_ext" >/dev/null 2>&1 || return 1
  adb -s "$ANDROID_SERIAL" shell rm -f "$tmp" >/dev/null 2>&1 || true
  is_image_signature_ok "$raw_with_ext" || return 1
  echo "$raw_with_ext"
}
android_capture_via_execout() {
  local raw_base="$1" id="${2-}"
  local raw_with_ext="${raw_base}.png"
  if [[ -n "$id" ]]; then
    adb -s "$ANDROID_SERIAL" exec-out screencap -d "$id" -p 2>/dev/null | tr -d '\r' > "$raw_with_ext" || return 1
  else
    adb -s "$ANDROID_SERIAL" exec-out screencap -p 2>/dev/null | tr -d '\r' > "$raw_with_ext" || return 1
  fi
  is_image_signature_ok "$raw_with_ext" || return 1
  echo "$raw_with_ext"
}

android_capture_raw() {
  local raw_base="$1" p=""
  if [[ "$ANDROID_USE_SYSUI" == "true" ]]; then
    if p="$(android_capture_via_sysui "$raw_base")"; then echo "$p"; return 0; fi
    echo "   ⤷ System‑UI path didn’t produce a pullable file."
  fi

  if [[ "$ANDROID_ALLOW_SCREENCAP_FALLBACK" == "true" ]]; then
    echo "   • Trying screencap fallback…"
    if [[ -n "$ANDROID_DISPLAY_ID" ]]; then
      if p="$(android_capture_via_sdcard "$raw_base" "$ANDROID_DISPLAY_ID")"; then echo "$p"; return 0; fi
      if p="$(android_capture_via_execout "$raw_base" "$ANDROID_DISPLAY_ID")"; then echo "$p"; return 0; fi
    fi
    if p="$(android_capture_via_sdcard "$raw_base" "")"; then echo "$p"; return 0; fi
    if p="$(android_capture_via_execout "$raw_base" "")"; then echo "$p"; return 0; fi
  fi

  return 1
}

capture_android() {
  local set_name="$1"; shift
  local screens=("$@")
  local out_dir="${OUT_DIR}/android/${set_name}"
  mkdir -p "$out_dir"

  echo "🔌 ANDROID serial    : $ANDROID_SERIAL"
  echo "📁 ANDROID out dir   : $out_dir"
  echo "🖼  System‑UI first  : $ANDROID_USE_SYSUI (dir: $ANDROID_SYSUI_SS_DIR, wait=${ANDROID_SYSUI_WAIT}s, grace=${ANDROID_SYSUI_GRACE}s)"
  echo "   Screencap fallback: $ANDROID_ALLOW_SCREENCAP_FALLBACK  (displayId: ${ANDROID_DISPLAY_ID:-<none>})"
  echo "   Keep awake        : $KEEP_AWAKE  | Wake before capture: $WAKE_BEFORE_CAPTURE"
  echo "   Force PNG         : $ANDROID_FORCE_PNG  | Resize: $ANDROID_RESIZE (${ANDROID_TARGET_W}x${ANDROID_TARGET_H})"

  # Keep screen awake for the whole run
  if [[ "$KEEP_AWAKE" == "true" ]]; then
    start_keep_awake
    trap 'stop_keep_awake' EXIT
  fi

  local i=1
  for scr in "${screens[@]}"; do
    echo "📱 Prepare: $scr"
    confirm "Open the view on the device, then press Enter to capture"

    local raw_base="${out_dir}/A_${i}_${scr}_raw"
    local final_base="${out_dir}/A_${i}_${scr}"

    local raw_path
    if ! raw_path="$(android_capture_raw "$raw_base")"; then
      echo "❌ All Android capture methods failed."
      exit 1
    fi

    # Decide final path
    local final_path
    if [[ "$ANDROID_RESIZE" == "true" || "$ANDROID_FORCE_PNG" == "true" ]]; then
      final_path="${final_base}.png"
    else
      local ext; ext="$(detect_image_ext "$raw_path")"
      final_path="${final_base}.${ext}"
    fi

    finalize_android_image "$raw_path" "$final_path"
    [[ "$KEEP_RAW" == "true" ]] || rm -f "$raw_path"
    echo "   ✔ Saved: $final_path"
    ((i++))
  done
  echo "✅ Android capture complete."
}

# ========== iOS ==========
boot_sim_if_needed() { xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null || xcrun simctl boot "$IOS_UDID"; xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null; }
set_clean_statusbar() { xcrun simctl status_bar "$IOS_UDID" override "${IOS_STATUSBAR_OPTS[@]}" || true; }
capture_ios() {
  local set_name="$1"; shift
  local screens=("$@")
  local out_dir="${OUT_DIR}/ios/${set_name}"
  mkdir -p "$out_dir"
  echo "🧪 iOS UDID       : $IOS_UDID"
  echo "📁 iOS out dir    : $out_dir"
  boot_sim_if_needed; set_clean_statusbar
  local i=1
  for scr in "${screens[@]}"; do
    echo "📱 iOS prepare: $scr"
    confirm "Arrange the Simulator view, then press Enter to capture"
    # Force PNG from Simulator, and verify it really exists before continuing
    local raw="${out_dir}/I_${i}_${scr}_raw.png"
    local final="${out_dir}/I_${i}_${scr}.png"

    # Ensure the sim is booted (idempotent)
    xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$IOS_UDID"
    xcrun simctl bootstatus "$IOS_UDID" -b >/dev/null 2>&1

    # Take the screenshot (force PNG)
    if ! xcrun simctl io "$IOS_UDID" screenshot --type=png "$raw"; then
      # Fallback: try 'booted' target
      xcrun simctl io booted screenshot --type=png "$raw" || {
        echo "❌ iOS: simctl screenshot failed (UDID=$IOS_UDID)."; exit 1;
      }
    fi

    # Verify the file actually exists and has data
    if [[ ! -s "$raw" ]]; then
      echo "❌ iOS: screenshot file not created at: $raw"
      ls -la "$out_dir"
      exit 1
    fi

    # Optionally scale; otherwise keep native pixels (App Store-friendly)
    if [[ -n "${IOS_FORCE_W}" && -n "${IOS_FORCE_H}" ]]; then
      require sips
      sips -s format png -z "$IOS_FORCE_H" "$IOS_FORCE_W" "$raw" --out "$final" >/dev/null
      [[ "$KEEP_RAW" == "true" ]] || rm -f "$raw"
    else
      # Keep raw (if requested) and write final as a copy
      cp "$raw" "$final"
      [[ "$KEEP_RAW" == "true" ]] || rm -f "$raw"
    fi
    echo "   ✔ Saved: $final"
    ((i++))
  done
  echo "✅ iOS capture complete."
}

usage() {
  cat <<EOF
Usage:
  $0 android  "<set_name>" "01_home" "02_directory" ...
  $0 ios      "<set_name>" "01_home" "02_directory" ...
  $0 both     "<set_name>" "01_home" "02_directory" ...

Env overrides:
  OUT_DIR=$OUT_DIR
  ANDROID_SERIAL=$ANDROID_SERIAL
  ANDROID_USE_SYSUI=$ANDROID_USE_SYSUI
  ANDROID_ALLOW_SCREENCAP_FALLBACK=$ANDROID_ALLOW_SCREENCAP_FALLBACK
  ANDROID_SYSUI_SS_DIR=$ANDROID_SYSUI_SS_DIR
  ANDROID_SYSUI_WAIT=$ANDROID_SYSUI_WAIT
  ANDROID_SYSUI_GRACE=$ANDROID_SYSUI_GRACE
  ANDROID_DISPLAY_ID=${ANDROID_DISPLAY_ID:-}
  KEEP_AWAKE=$KEEP_AWAKE
  WAKE_BEFORE_CAPTURE=$WAKE_BEFORE_CAPTURE
  ANDROID_FORCE_PNG=$ANDROID_FORCE_PNG
  ANDROID_RESIZE=$ANDROID_RESIZE
  ANDROID_TARGET_W=$ANDROID_TARGET_W
  ANDROID_TARGET_H=$ANDROID_TARGET_H
  IOS_UDID=$IOS_UDID
  IOS_FORCE_W=${IOS_FORCE_W:-}
  IOS_FORCE_H=${IOS_FORCE_H:-}
  KEEP_RAW=$KEEP_RAW
EOF
}

main() {
  require adb; require xcrun
  local need_sips=false
  if [[ "$ANDROID_RESIZE" == "true" || "$ANDROID_FORCE_PNG" == "true" ]]; then need_sips=true; fi
  if [[ -n "${IOS_FORCE_W}" && -n "${IOS_FORCE_H}" ]]; then need_sips=true; fi
  if $need_sips; then require sips; fi

  if [[ $# -lt 3 ]]; then usage; exit 1; fi
  ensure_output_roots

  local target="$1"; shift
  local set_name="$1"; shift
  local screens=("$@")

  hr
  echo "Output root      : $OUT_DIR"
  echo "Android SYSUI dir: $ANDROID_SYSUI_SS_DIR"
  echo "Use System UI    : $ANDROID_USE_SYSUI"
  echo "Allow screencap  : $ANDROID_ALLOW_SCREENCAP_FALLBACK"
  echo "Keep awake       : $KEEP_AWAKE  | Wake before capture: $WAKE_BEFORE_CAPTURE"
  echo "Force PNG        : $ANDROID_FORCE_PNG  | Resize: $ANDROID_RESIZE (${ANDROID_TARGET_W}x${ANDROID_TARGET_H})"
  echo "iOS UDID         : $IOS_UDID"
  hr

  case "$target" in
    android) capture_android "$set_name" "${screens[@]}";;
    ios)     capture_ios     "$set_name" "${screens[@]}";;
    both)    capture_android "$set_name" "${screens[@]}"; capture_ios "$set_name" "${screens[@]}";;
    *) usage; exit 1;;
  esac
  echo; echo "🎉 Done."
}
main "$@"