#!/usr/bin/env bash
set -euo pipefail

PBX="ios/Runner.xcodeproj/project.pbxproj"
TS="$(date +%Y%m%d-%H%M%S)"
echo "[backup] $PBX -> $PBX.bak.$TS"
cp "$PBX" "$PBX.bak.$TS"

echo "[1/4] Force project format to 60 (avoids CocoaPods/xcodeproj issues)"
# If Xcode bumped it to 70, force back to 60.
sed -i '' 's/objectVersion = 70/objectVersion = 60/' "$PBX"

echo "[2/4] Rebuild the entire PBXCopyFilesBuildPhase section to a clean state"
# We keep ONLY the 'Embed Frameworks' phase and drop any stray/dangling watch-embed block.
# We detect the 'Embed Frameworks' block (ID exists already in your file: 9705A1C41CF9048500538489).
# Replace the whole section with a known-good section containing that block only.

# Extract the Embed Frameworks block body from your current file (in case Xcode reordered keys).
EMBED_BLOCK="$(awk '
  BEGIN{s=0}
  /\/\* Begin PBXCopyFilesBuildPhase section \*\//{s=1}
  s==1 && /\/\* Embed Frameworks \*\//{printline=1}
  printline==1{print}
  printline==1 && /^\t\};$/{exit}
' "$PBX")"

# If for any reason that extraction failed, fall back to a canonical block
if [ -z "$EMBED_BLOCK" ]; then
  EMBED_BLOCK=$'\t9705A1C41CF9048500538489 /* Embed Frameworks */ = {\n\t\tisa = PBXCopyFilesBuildPhase;\n\t\tdstPath = \"\";\n\t\tdstSubfolderSpec = 10;\n\t\tfiles = (\n\t\t);\n\t\tname = \"Embed Frameworks\";\n\t\trunOnlyForDeploymentPostprocessing = 0;\n\t};'
fi

# Replace the entire section with a clean section that contains only Embed Frameworks
awk -v block="$EMBED_BLOCK" '
  BEGIN{insec=0}
  /\/\* Begin PBXCopyFilesBuildPhase section \*\//{
    insec=1; print; print block; next
  }
  /\/\* End PBXCopyFilesBuildPhase section \*\//{
    insec=0; print; next
  }
  insec==1{ next }      # drop everything inside the section
  { print }             # keep everything else
' "$PBX" > "$PBX.tmp" && mv "$PBX.tmp" "$PBX"

echo "[3/4] Remove the watch PBXTargetDependency and its PBXContainerItemProxy blocks"
# Delete any PBXTargetDependency that references the watch target name
perl -0777 -pe 's/\n\t[A-F0-9]{24} \/\* PBXTargetDependency \*\/ = \{[^}]*PrayerTimesWatchApp Watch App[^}]*\};\n//sg' -i "$PBX"
# Delete any Proxy that names the watch target (remoteInfo)
perl -0777 -pe 's/\n\t[A-F0-9]{24} \/\* PBXContainerItemProxy \*\/ = \{[^}]*remoteInfo = "PrayerTimesWatchApp Watch App";[^}]*\};\n//sg' -i "$PBX"

echo "[4/4] Remove any reference to PBXTargetDependency inside the Runner target block"
# Constrain to just the Runner native target block, delete list entries referencing /* PBXTargetDependency */
# The Runner target header line is stable across your file: '97C146ED1CF9000F007C117D /* Runner */ = {'
awk '
  BEGIN{inrunner=0}
  /97C146ED1CF9000F007C117D \/\* Runner \*\/ = \{/ {inrunner=1; print; next}
  inrunner==1 {
    if ($0 ~ /\/\* PBXTargetDependency \*\//) next   # drop dependency list line
    print
    if ($0 ~ /^\t\};$/) { inrunner=0 }               # end of Runner block
    next
  }
  { print }
' "$PBX" > "$PBX.tmp" && mv "$PBX.tmp" "$PBX"

echo "---- VERIFY ----"
grep -n 'objectVersion' "$PBX" || true
grep -n '\$(CONTENTS_FOLDER_PATH)/Watch' "$PBX" || echo "OK: no CopyFiles dstPath=Watch in pbxproj"
grep -n 'Embed Watch Content' "$PBX" || echo "OK: no 'Embed Watch Content' text"
grep -n 'remoteInfo = "PrayerTimesWatchApp Watch App"' "$PBX" || echo "OK: no PBXContainerItemProxy for watch"
# List any remaining PBXTargetDependency lines; RunnerTests dependency is expected.
if grep -n "PBXTargetDependency" "$PBX"; then
  echo "(Above should list only RunnerTests dependency; watch dep should be gone)"
else
  echo "OK: no PBXTargetDependency blocks remain"
fi
BASH