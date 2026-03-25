#!/usr/bin/env bash
# shellcheck shell=bash
#
# tools/date_cycle_config.sh
# Project-specific configuration for date cycling automation.

### REQUIRED: Your app’s bundle id (as installed on the simulator)
# Example: com.example.myapp
export BUNDLE_ID="org.ialfm.ialfmPrayerTimes"

### REQUIRED: Simulator device — exact name OR UDID
# Example names: "iPhone 15", "iPhone 15 Pro Max"
# Example UDID : "1B856CF2-D454-44DC-856C-8484A8AF9CC3"
export DEVICE_NAME="1B856CF2-D454-44DC-856C-8484A8AF9CC3"

### OPTIONAL: App launch arguments
export APP_ARGS=""

### OPTIONAL: Offline mode
# - "none" → leave network alone (recommended if you use Network Link Conditioner)
# - "wifi" → toggle Mac Wi‑Fi off during each checkpoint (requires sudo)
export OFFLINE_MODE="none"

### OPTIONAL: Skip changing macOS date/time (no sudo needed)
# If "true", the script WON’T touch macOS time. Set time manually via GUI/Simulator.
export SKIP_TIME_OVERRIDE="true"

### OPTIONAL: Take a screenshot per checkpoint
export TAKE_SCREENSHOT="true"
export SCREENSHOT_DIR="./screens"

### OPTIONAL: Wait (seconds) after launch before screenshot/next step
export POST_LAUNCH_WAIT_SECS=6

### OPTIONAL: Cold start the sim between checkpoints (true/false)
export COLD_START_BETWEEN_CHECKPOINTS="false"

### OPTIONAL: Path to built .app if not already installed on simulator
# After: flutter build ios --simulator
# Example: build/ios/iphonesimulator/Runner.app
export APP_BUNDLE_PATH=""

### REQUIRED: Test checkpoints (LOCAL time) — DO NOT export arrays
# SC2034: Used by date_cycle.sh after sourcing.
# shellcheck disable=SC2034
CHECKPOINTS=(
  "2026-02-14 10:00"  # T-2 heads-up
  "2026-02-15 19:30"  # T-1 (after Maghrib)
)