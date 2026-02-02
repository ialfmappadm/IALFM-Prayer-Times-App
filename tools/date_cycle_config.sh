#!/usr/bin/env bash

# Bundle ID and device (UDID or exact device name)
export BUNDLE_ID="org.ialfm.ialfmPrayerTimes"
export DEVICE_NAME="1B856CF2-D454-44DC-856C-8484A8AF9CC3"

# Optional launch args
export APP_ARGS=""

# Start with no Wi‑Fi toggle; you can switch to "wifi" after verifying
export OFFLINE_MODE="none"

# Screenshots
export TAKE_SCREENSHOT="true"
export SCREENSHOT_DIR="./screens"
export POST_LAUNCH_WAIT_SECS=6

# DO NOT export arrays
CHECKPOINTS=(
  "2026-02-14 10:00"  # T-2
  "2026-02-15 19:30"  # T-1 (after Maghrib)
)

# If the app is not already installed on that simulator, point to the .app
export APP_BUNDLE_PATH=""  # or "build/ios/iphonesimulator/Runner.app"