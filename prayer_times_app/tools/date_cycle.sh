#!/usr/bin/env bash
#
# tools/date_cycle.sh
# Automates date/time cycling on macOS for iOS Simulator testing.
# - Only prompts for sudo if you actually change time or toggle Wi‑Fi.
# - Restores NTP and Wi‑Fi on exit.
# - Installs app if APP_BUNDLE_PATH is set, otherwise launches by bundle id.

set -Eeuo pipefail

### -------- optional --trace flag (debug) --------
if [[ "${1:-}" == "--trace" ]]; then
  set -x
fi

### -------- small logger helpers --------
log()   { printf "\033[0;36m[%s]\033[0m %s\n" "date_cycle" "$*"; }
ok()    { printf "\033[0;32m[ok]\033[0m %s\n" "$*"; }
warn()  { printf "\033[0;33m[warn]\033[0m %s\n" "$*"; }
err()   { printf "\033[0;31m[err]\033[0m %s\n" "$*" >&2; }

### -------- load config --------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/date_cycle_config.sh"

### -------- tooling checks --------
require_tool() { command -v "$1" >/dev/null 2>&1 || { err "Missing tool: $1"; exit 1; }; }
require_tool xcrun
require_tool awk
require_tool sed
require_tool date
command -v networksetup >/dev/null 2>&1 || true   # only if OFFLINE_MODE=wifi
command -v systemsetup  >/dev/null 2>&1 || true   # only if SKIP_TIME_OVERRIDE=false

### -------- echo config (debug) --------
if declare -p CHECKPOINTS >/dev/null 2>&1; then
  log "checkpoints.count=${#CHECKPOINTS[@]}"
  printf "[cfg] checkpoints.values=%s\n" "$(IFS=' | '; echo "${CHECKPOINTS[*]-}")"
else
  err "CHECKPOINTS is not defined as a bash array in tools/date_cycle_config.sh"
  exit 2
fi
log "bundle_id=${BUNDLE_ID}"
log "device=${DEVICE_NAME}"
log "skip_time_override=${SKIP_TIME_OVERRIDE}"
log "offline_mode=${OFFLINE_MODE}"
log "take_screenshot=${TAKE_SCREENSHOT}"

### -------- preflight sudo only if needed --------
NEED_SUDO="false"

# If systemsetup is unavailable, force skip
if [[ "${SKIP_TIME_OVERRIDE}" != "true" ]]; then
  if ! command -v systemsetup >/dev/null 2>&1; then
    warn "systemsetup not found; forcing SKIP_TIME_OVERRIDE=true"
    SKIP_TIME_OVERRIDE="true"
  fi
fi

# Decide if sudo is truly needed
if [[ "${SKIP_TIME_OVERRIDE}" != "true" ]]; then
  NEED_SUDO="true"
fi
if [[ "${OFFLINE_MODE}" == "wifi" ]]; then
  NEED_SUDO="true"
fi

if [[ "${NEED_SUDO}" == "true" ]]; then
  if ! sudo -v; then
    err "Admin privileges required (sudo) for time/network changes."
    exit 1
  fi
  # keep sudo alive during the run
  ( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "${SUDO_KEEPALIVE_PID}" >/dev/null 2>&1 || true' EXIT INT HUP
fi

### -------- Wi‑Fi helpers --------
get_wifi_device() {
  networksetup -listallhardwareports 2>/dev/null \
    | awk '/Wi-Fi|AirPort/{getline; print $2; exit}'
}
WIFI_DEVICE="$(get_wifi_device || true)"
WIFI_WAS_ON="unknown"

wifi_off() {
  [[ "${OFFLINE_MODE}" != "wifi" ]] && return 0
  if [[ -z "${WIFI_DEVICE}" ]]; then
    warn "Wi‑Fi interface not found; skipping Wi‑Fi toggle."
    return 0
  fi
  WIFI_WAS_ON="$(networksetup -getairportpower "${WIFI_DEVICE}" | awk '{print $NF}')"
  if [[ "${WIFI_WAS_ON}" == "On" ]]; then
    log "Turning Wi‑Fi OFF on ${WIFI_DEVICE}…"
    sudo networksetup -setairportpower "${WIFI_DEVICE}" off
  else
    log "Wi‑Fi already OFF."
  fi
}
wifi_restore() {
  [[ "${OFFLINE_MODE}" != "wifi" ]] && return 0
  if [[ "${WIFI_DEVICE}" != "" && "${WIFI_WAS_ON}" == "On" ]]; then
    log "Restoring Wi‑Fi ON on ${WIFI_DEVICE}…"
    sudo networksetup -setairportpower "${WIFI_DEVICE}" on
  fi
}

### -------- macOS NTP/time helpers --------
NTP_WAS_ON="unknown"
remember_ntp() {
  log "Preparing to change time: remembering current NTP state…"
  NTP_WAS_ON="$(sudo systemsetup -getusingnetworktime 2>/dev/null | awk '{print $NF}')"
  [[ -z "${NTP_WAS_ON}" ]] && NTP_WAS_ON="On"
}
ntp_off() {
  sudo systemsetup -setusingnetworktime off >/dev/null
}
ntp_restore() {
  if [[ "${NTP_WAS_ON}" == "On" ]]; then
    log "Restoring network time (NTP)…"
    sudo systemsetup -setusingnetworktime on >/dev/null
  fi
}
set_datetime() {
  local when="$1" # "YYYY-MM-DD HH:MM"
  local Y M D hh mm yy
  Y="$(awk -F'[ :-]' '{print $1}' <<<"$when")"
  M="$(awk -F'[ :-]' '{print $2}' <<<"$when")"
  D="$(awk -F'[ :-]' '{print $3}' <<<"$when")"
  hh="$(awk -F'[ :-]' '{print $4}' <<<"$when")"
  mm="$(awk -F'[ :-]' '{print $5}' <<<"$when")"
  yy="${Y:2:2}"
  log "Setting macOS time to ${Y}-${M}-${D} ${hh}:${mm} (local)"
  ntp_off
  sudo systemsetup -setdate "${M}:${D}:${yy}" >/dev/null
  sudo systemsetup -settime "${hh}:${mm}:00"  >/dev/null
}

### -------- sim helpers --------
resolve_udid() {
  local name_or_udid="$1"
  # If the input looks like a UDID, use it directly
  if [[ "${name_or_udid}" =~ ^[A-F0-9-]{36}$ ]]; then
    echo "${name_or_udid}"
    return
  fi
  # Match by name, prefer Booted/Shutdown (not unavailable)
  xcrun simctl list devices | awk -v pat="$name_or_udid" '
    $0 ~ pat && $0 !~ /unavailable/ && ($0 ~ /(Booted)|(Shutdown)/) {
      match($0, /\(([A-F0-9-]{36})\)/, m);
      if (m[1] != "") { print m[1]; exit }
    }'
}
boot_sim() {
  local UDID="$1"
  log "Booting Simulator ${UDID}…"
  xcrun simctl bootstatus "${UDID}" -b >/dev/null 2>&1 || xcrun simctl boot "${UDID}" >/dev/null
  open -a Simulator --args -CurrentDeviceUDID "${UDID}"
  xcrun simctl bootstatus "${UDID}" -b >/dev/null
}
launch_app() {
  local UDID="$1"
  local BUNDLE="$2"
  local ARGS="$3"

  if [[ -n "${APP_BUNDLE_PATH}" && -d "${APP_BUNDLE_PATH}" ]]; then
    log "Installing app: ${APP_BUNDLE_PATH}"
    if ! xcrun simctl install "${UDID}" "${APP_BUNDLE_PATH}"; then
      warn "Install failed (maybe already installed?)"
    fi
  fi

  log "Launching ${BUNDLE} ${ARGS}"
  xcrun simctl terminate "${UDID}" "${BUNDLE}" >/dev/null 2>&1 || true
  if ! xcrun simctl launch "${UDID}" "${BUNDLE}" ${ARGS}; then
    err "Launch failed. Is ${BUNDLE} installed? Either run once on this simulator OR set APP_BUNDLE_PATH in tools/date_cycle_config.sh."
  fi
}
screenshot_if_needed() {
  local UDID="$1"
  local label="$2" # e.g. 2026-02-14_10-00
  if [[ "${TAKE_SCREENSHOT}" == "true" ]]; then
    mkdir -p "${SCREENSHOT_DIR}"
    local out="${SCREENSHOT_DIR}/sim-${label}.png"
    log "Screenshot → ${out}"
    xcrun simctl io "${UDID}" screenshot "${out}" >/dev/null || warn "screenshot failed"
  fi
}
shutdown_sim() {
  local UDID="$1"
  xcrun simctl shutdown "${UDID}" >/dev/null 2>&1 || true
}

### -------- main --------
main() {
  if [[ ${#CHECKPOINTS[@]} -eq 0 ]]; then
    err "No checkpoints provided. Edit tools/date_cycle_config.sh → CHECKPOINTS=(\"YYYY-MM-DD HH:MM\" ...)"
    exit 3
  fi

  echo
  printf "\033[1m%s\033[0m\n" "== Date Cycling =="

  local UDID
  UDID="$(resolve_udid "${DEVICE_NAME}")"
  if [[ -z "${UDID}" ]]; then
    err "Could not resolve simulator for '${DEVICE_NAME}'. Use an exact device name or UDID."
    exit 4
  fi
  ok "Using simulator UDID: ${UDID}"

  # Only remember/restore NTP if we will change time
  if [[ "${SKIP_TIME_OVERRIDE}" != "true" ]]; then
    remember_ntp
  fi

  # Always restore on exit
  trap 'cleanup "'"${UDID}"'"' EXIT INT HUP

  for when in "${CHECKPOINTS[@]}"; do
    local label
    label="$(sed -E 's/[: ]/_/g' <<<"${when}")"

    echo
    printf "\033[1m%s\033[0m\n" "--> Visit ${when}"

    if [[ "${SKIP_TIME_OVERRIDE}" != "true" ]]; then
      set_datetime "${when}"
    else
      log "SKIP_TIME_OVERRIDE=true — not changing macOS date/time for ${when}"
    fi

    if [[ "${OFFLINE_MODE}" == "wifi" ]]; then
      wifi_off
    fi

    boot_sim "${UDID}"
    launch_app "${UDID}" "${BUNDLE_ID}" "${APP_ARGS}"

    sleep "${POST_LAUNCH_WAIT_SECS}"
    screenshot_if_needed "${UDID}" "${label}"

    if [[ "${COLD_START_BETWEEN_CHECKPOINTS}" == "true" ]]; then
      shutdown_sim "${UDID}"
    fi
  done

  ok "All checkpoints visited."
}

cleanup() {
  local UDID="$1"
  log "Cleaning up… restoring time/network (if needed)."
  if [[ "${SKIP_TIME_OVERRIDE}" != "true" ]]; then
    ntp_restore
  fi
  wifi_restore
  # Keep the simulator running; comment out if you prefer to shut down
  # shutdown_sim "${UDID}"
  ok "Restored."
}

main "$@"