#!/usr/bin/env bash
#
# scripts/date_cycle.sh
# Automates date/time cycling on macOS for iOS Simulator testing.
# - Requires sudo for system time and (optionally) Wi‑Fi toggling.
# - Restores state (time + Wi‑Fi) on exit.

set -euo pipefail

# --- Preflight sudo (prompt once and keep alive) ---
if ! sudo -v; then
  echo "[date_cycle] Need admin privileges (sudo) to change time/network."
  exit 1
fi
( while true; do sleep 60; sudo -n true 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "${SUDO_KEEPALIVE_PID}" >/dev/null 2>&1 || true' EXIT INT HUP

# --- Load config ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/date_cycle_config.sh"

# --- Sanity checks ---
if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun not found; install Xcode command line tools." >&2
  exit 1
fi

if ! id -Gn | tr ' ' '\n' | grep -qi "^admin$"; then
  echo "You likely need admin privileges for time/Wi‑Fi changes." >&2
fi

# --- Helpers ---
red()   { printf "\033[0;31m%s\033[0m\n" "$*"; }
green() { printf "\033[0;32m%s\033[0m\n" "$*"; }
cyan()  { printf "\033[0;36m%s\033[0m\n" "$*"; }
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }

# Find Wi‑Fi device (usually en0)
get_wifi_device() {
  networksetup -listallhardwareports \
    | awk '/Wi-Fi|AirPort/{getline; print $2; exit}'
}

# Save & restore Wi‑Fi power state
WIFI_DEVICE="$(get_wifi_device || true)"
WIFI_WAS_ON="unknown"
wifi_off() {
  [[ "${OFFLINE_MODE}" != "wifi" ]] && return 0
  if [[ -z "${WIFI_DEVICE}" ]]; then
    red "Wi‑Fi device not found; skipping Wi‑Fi toggle."
    return 0
  fi
  WIFI_WAS_ON="$(networksetup -getairportpower "${WIFI_DEVICE}" | awk '{print $NF}')"
  if [[ "${WIFI_WAS_ON}" == "On" ]]; then
    cyan "Turning Wi‑Fi OFF on ${WIFI_DEVICE}…"
    sudo networksetup -setairportpower "${WIFI_DEVICE}" off
  else
    cyan "Wi‑Fi already OFF."
  fi
}
wifi_restore() {
  [[ "${OFFLINE_MODE}" != "wifi" ]] && return 0
  if [[ "${WIFI_DEVICE}" != "" && "${WIFI_WAS_ON}" == "On" ]]; then
    cyan "Restoring Wi‑Fi ON on ${WIFI_DEVICE}…"
    sudo networksetup -setairportpower "${WIFI_DEVICE}" on
  fi
}

# Time/Date control
NTP_WAS_ON="unknown"
remember_ntp() {
  NTP_WAS_ON="$(sudo systemsetup -getusingnetworktime 2>/dev/null | awk '{print $NF}')"
  [[ -z "${NTP_WAS_ON}" ]] && NTP_WAS_ON="On"
}
ntp_off() {
  sudo systemsetup -setusingnetworktime off >/dev/null
}
ntp_restore() {
  if [[ "${NTP_WAS_ON}" == "On" ]]; then
    cyan "Restoring network time (NTP)…"
    sudo systemsetup -setusingnetworktime on >/dev/null
  fi
}

set_datetime() {
  local when="$1" # "YYYY-MM-DD HH:MM"
  # Parse into components for `systemsetup`
  local Y M D hh mm
  Y="$(echo "$when" | awk '{print $1}' | awk -F- '{print $1}')"
  M="$(echo "$when" | awk '{print $1}' | awk -F- '{print $2}')"
  D="$(echo "$when" | awk '{print $1}' | awk -F- '{print $3}')"
  hh="$(echo "$when" | awk '{print $2}' | awk -F: '{print $1}')"
  mm="$(echo "$when" | awk '{print $2}' | awk -F: '{print $2}')"

  # systemsetup expects mm:dd:yy (two‑digit year) and HH:MM:SS
  local yy="${Y:2:2}"
  cyan "Setting macOS time to ${Y}-${M}-${D} ${hh}:${mm} (local)"
  sudo systemsetup -setusingnetworktime off   >/dev/null
  sudo systemsetup -setdate "${M}:${D}:${yy}" >/dev/null
  sudo systemsetup -settime "${hh}:${mm}:00"  >/dev/null
}

# Simulator device resolution
resolve_udid() {
  local name_or_udid="$1"
  # If already a UDID (has dashes), accept
  if [[ "${name_or_udid}" =~ ^[A-F0-9-]{36}$ ]]; then
    echo "${name_or_udid}"
    return
  fi
  # Try to resolve by name (first match)
  xcrun simctl list devices | awk -v pat="$name_or_udid" '
    $0 ~ pat && $0 !~ /unavailable/ && $0 ~ /\(Shutdown\)|\(Booted\)/ {
      match($0, /\(([A-F0-9-]{36})\)/, m);
      if (m[1] != "") { print m[1]; exit }
    }'
}

boot_sim() {
  local UDID="$1"
  cyan "Booting Simulator ${UDID}…"
  xcrun simctl bootstatus "${UDID}" -b >/dev/null 2>&1 || xcrun simctl boot "${UDID}" >/dev/null
  # Ensure the Simulator app is open on this UDID
  open -a Simulator --args -CurrentDeviceUDID "${UDID}"
  xcrun simctl bootstatus "${UDID}" -b >/dev/null
}

launch_app() {
  local UDID="$1"
  local BUNDLE="$2"
  local ARGS="$3"
  if [[ -n "${APP_BUNDLE_PATH}" && -d "${APP_BUNDLE_PATH}" ]]; then
    cyan "Installing app ${APP_BUNDLE_PATH}…"
    xcrun simctl install "${UDID}" "${APP_BUNDLE_PATH}" >/dev/null
  fi
  cyan "Launching ${BUNDLE} ${ARGS}"
  xcrun simctl terminate "${UDID}" "${BUNDLE}" >/dev/null 2>&1 || true
  xcrun simctl launch "${UDID}" "${BUNDLE}" ${ARGS} >/dev/null || true
}

screenshot_if_needed() {
  local UDID="$1"
  local label="$2" # e.g. 2026-02-14_10-00
  if [[ "${TAKE_SCREENSHOT}" == "true" ]]; then
    mkdir -p "${SCREENSHOT_DIR}"
    local out="${SCREENSHOT_DIR}/sim-${label}.png"
    cyan "Screenshot → ${out}"
    xcrun simctl io "${UDID}" screenshot "${out}" >/dev/null || true
  fi
}

shutdown_sim() {
  local UDID="$1"
  xcrun simctl shutdown "${UDID}" >/dev/null 2>&1 || true
}

# --- Main flow ---
main() {
  bold "== Date Cycling =="
  local UDID
  UDID="$(resolve_udid "${DEVICE_NAME}")"
  if [[ -z "${UDID}" ]]; then
    red "Could not resolve simulator for '${DEVICE_NAME}'. Use an exact device name or UDID in date_cycle_config.sh"
    exit 1
  fi
  green "Using simulator UDID: ${UDID}"

  remember_ntp
  trap 'cleanup "${UDID}"' EXIT INT HUP

  for when in "${CHECKPOINTS[@]}"; do
    local label
    label="$(echo "${when}" | sed -E 's/[: ]/_/g')"
    echo
    bold "--> Visit ${when}"

    set_datetime "${when}"

    if [[ "${OFFLINE_MODE}" == "wifi" ]]; then
      wifi_off
    fi

    boot_sim "${UDID}"
    launch_app "${UDID}" "${BUNDLE_ID}" "${APP_ARGS}"

    sleep "${POST_LAUNCH_WAIT_SECS}"
    screenshot_if_needed "${UDID}" "${label}"

    # Optional cold start between checkpoints (uncomment if desired)
    # shutdown_sim "${UDID}"
  done

  green "All checkpoints visited."
}

cleanup() {
  local UDID="$1"
  cyan "Cleaning up… restoring time and network."
  ntp_restore
  wifi_restore
  # Keep the simulator running (comment out if you prefer shutting it down)
  # shutdown_sim "${UDID}"
  green "Restored."
}

main "$@"