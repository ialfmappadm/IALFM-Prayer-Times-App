#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Config (override via env or CLI flags)
# ──────────────────────────────────────────────────────────────────────────────
FIREBASE_BUCKET="${FIREBASE_BUCKET:-}"           # e.g., "ialfm-prayer-times.firebasestorage.app"
FIREBASE_YEAR="${FIREBASE_YEAR:-$(date +%Y)}"    # default to current year
REMOTE_OBJECT_DEFAULT="prayer_times/${FIREBASE_YEAR}.json"   # <- remote canary path

# CLI flags (kept from your previous script; optional to use)
BUMP_BUILD=false
SET_VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump-build) BUMP_BUILD=true; shift ;;
    --set-version) SET_VERSION="${2:-}"; shift 2 ;;
    --year) FIREBASE_YEAR="${2:-}"; REMOTE_OBJECT_DEFAULT="prayer_times/${FIREBASE_YEAR}.json"; shift 2 ;;
    --bucket) FIREBASE_BUCKET="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2;;
  esac
done

GREEN="\033[92m"; YELLOW="\033[93m"; RED="\033[91m"; DIM="\033[2m"; RESET="\033[0m"
ok(){ echo -e "${GREEN}✔${RESET} $*"; }
warn(){ echo -e "${YELLOW}• WARN${RESET} $*"; }
fail(){ echo -e "${RED}✖ FAIL${RESET} $*" 1>&2; }
say(){ echo -e "${DIM}$*${RESET}"; }

# ──────────────────────────────────────────────────────────────────────────────
# Version helpers (same as before; no effect unless you pass flags)
# ──────────────────────────────────────────────────────────────────────────────
read_version(){ awk '/^version: /{print $2}' pubspec.yaml | head -n1; }
write_version(){ perl -0777 -pe "s/^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+/version: ${1}/m" -i pubspec.yaml; }
bump_build(){
  local v; v="$(read_version)"
  [[ -z "$v" ]] && { fail "version not found in pubspec.yaml"; exit 1; }
  if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
    local nb=$(( ${BASH_REMATCH[4]} + 1 ))
    local nv="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}+${nb}"
    write_version "$nv"; ok "Bumped build number: ${v} → ${nv}"
  else
    fail "Invalid version format '${v}' (expect 1.2.3+45)"; exit 1
  fi
}
set_version(){
  local nv="$1"
  [[ "$nv" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]] || { fail "Invalid --set-version '${nv}' (expect 1.2.3+45)"; exit 1; }
  write_version "$nv"; ok "Set version to ${nv}"
}

[[ -n "$SET_VERSION" ]] && set_version "$SET_VERSION"
[[ "$BUMP_BUILD" == "true" ]] && bump_build
say "Current version: $(read_version)"

# ──────────────────────────────────────────────────────────────────────────────
# 1) Clean ephemeral dirs
# ──────────────────────────────────────────────────────────────────────────────
say "Cleaning Flutter build dirs..."
flutter clean >/dev/null 2>&1 || true
rm -rf .dart_tool build

# ──────────────────────────────────────────────────────────────────────────────
# 2) Dependencies
# ──────────────────────────────────────────────────────────────────────────────
ok "flutter pub get"
flutter pub get

# ──────────────────────────────────────────────────────────────────────────────
# 3) Generate icons & splash
# ──────────────────────────────────────────────────────────────────────────────
ok "Generating launcher icons"
dart run flutter_launcher_icons
ok "Generating native splash"
dart run flutter_native_splash:create

# ──────────────────────────────────────────────────────────────────────────────
# 4) Validate LOCAL schedules (exactly two files you asked for)
# ──────────────────────────────────────────────────────────────────────────────
LOCAL_A="assets/data/prayer_times_2026.json"
LOCAL_B="assets/data/prayer_times_local.json"

echo "• Validating local schedule JSON (2 files)..."
MISSING=false
[[ -f "$LOCAL_A" ]] || { warn "Missing $LOCAL_A"; MISSING=true; }
[[ -f "$LOCAL_B" ]] || { warn "Missing $LOCAL_B"; MISSING=true; }

if [[ "$MISSING" == "true" ]]; then
  fail "One or more local schedule files are missing"; exit 1
fi

python3 tools/validate_json.py --local "$LOCAL_A" "$LOCAL_B"

# ──────────────────────────────────────────────────────────────────────────────
# 5) Fetch & validate Firebase Storage schedule (canary), then compare to local
#    Will look for: gs://$FIREBASE_BUCKET/prayer_times/$FIREBASE_YEAR.json
# ──────────────────────────────────────────────────────────────────────────────
TMP_DIR=".prebuild_tmp"
mkdir -p "$TMP_DIR"
REMOTE_FILE="$TMP_DIR/firebase_${FIREBASE_YEAR}.json"
REMOTE_OK=false

if [[ -n "${FIREBASE_BUCKET}" ]]; then
  say "Attempting remote fetch: gs://${FIREBASE_BUCKET}/${REMOTE_OBJECT_DEFAULT}"
  if command -v gsutil >/dev/null 2>&1; then
    gsutil cp "gs://${FIREBASE_BUCKET}/${REMOTE_OBJECT_DEFAULT}" "$REMOTE_FILE" >/dev/null 2>&1 && REMOTE_OK=true
  elif command -v firebase >/dev/null 2>&1; then
    firebase storage:download --bucket "$FIREBASE_BUCKET" "${REMOTE_OBJECT_DEFAULT}" "$REMOTE_FILE" >/dev/null 2>&1 && REMOTE_OK=true
  else
    warn "Neither gsutil nor firebase-tools found; skipping remote fetch"
  fi

  if $REMOTE_OK && [[ -s "$REMOTE_FILE" ]]; then
    ok "Downloaded remote: gs://${FIREBASE_BUCKET}/${REMOTE_OBJECT_DEFAULT}"
    # Validate the downloaded remote JSON with the same rules
    python3 tools/validate_json.py --local "$REMOTE_FILE"

    # Consistency check: remote vs local year file (sha256)
    if [[ -f "$LOCAL_A" ]]; then
      SHA_L=$(shasum -a 256 "$LOCAL_A" | awk '{print $1}')
      SHA_R=$(shasum -a 256 "$REMOTE_FILE" | awk '{print $1}')
      if [[ "$SHA_L" == "$SHA_R" ]]; then
        ok "Remote and local YEAR file match (sha256=$SHA_L)"
      else
        warn "Remote and local YEAR file differ!"
        echo -e "${DIM}  local : $LOCAL_A  sha256=$SHA_L${RESET}"
        echo -e "${DIM}  remote: $REMOTE_FILE sha256=$SHA_R${RESET}"
        # If you'd like to enforce equality before release, uncomment next line:
        # fail "SHA mismatch; aborting"; exit 1
      fi
    else
      warn "Local year file not found for compare: $LOCAL_A"
    fi
  else
    warn "Remote schedule not found or not downloaded (OK if canary is optional): gs://${FIREBASE_BUCKET}/${REMOTE_OBJECT_DEFAULT}"
  fi
else
  warn "FIREBASE_BUCKET not set; skipping remote schedule checks"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 6) Static analysis / format / l10n
# ──────────────────────────────────────────────────────────────────────────────
ok "flutter analyze"
flutter analyze

say "dart format (check only)"
dart format --set-exit-if-changed lib test || { fail "Source not formatted"; exit 1; }

ok "flutter gen-l10n"
flutter gen-l10n

# ──────────────────────────────────────────────────────────────────────────────
# 7) iOS pods / Android gradle sanity
# ──────────────────────────────────────────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  say "iOS pod install"
  pushd ios >/dev/null
  rm -rf Pods Podfile.lock
  pod install --repo-update
  popd >/dev/null
fi

say "Android gradle clean"
( cd android && ./gradlew clean )

ok "Pre-Build Completed"