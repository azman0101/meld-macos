#!/usr/bin/env bash
#
# Installe un DMG de Meld, lance un diagnostic et prend des captures d'écran.
#
#   repro.sh <url-ou-chemin-du-dmg> <label> <dossier-de-sortie>
#
# Prévu pour un runner GitHub Actions macOS (session graphique disponible).

set -euo pipefail

DMG=$1
LABEL=$2
OUT=$3
HERE=$(cd "$(dirname "$0")/.." && pwd)

mkdir -p "$OUT"
exec > >(tee "$OUT/log.txt") 2>&1

echo "== système"
sw_vers
uname -m
system_profiler SPDisplaysDataType | grep -E "Resolution|Retina|UI Looks|Display Type" || true

echo "== installation de $DMG"
"$HERE/scripts/install.sh" "$DMG"
APP=/Applications/Meld.app

echo "== diagnostic gdk_quartz_osx_version"
# même SDK déclaré que Meld (11.3) pour reproduire la vue de GTK
clang -fobjc-arc -framework AppKit -framework CoreServices \
  -mmacosx-version-min=11.3 -Wl,-platform_version,macos,11.3,11.3 \
  -o /tmp/gdkver_sdk11 "$HERE/diag/gdkver.m"
# et avec le SDK courant, pour comparaison
clang -fobjc-arc -framework AppKit -framework CoreServices \
  -o /tmp/gdkver_sdkcur "$HERE/diag/gdkver.m"
echo "-- lié SDK 11.3"
GDKLIB=$(find "$APP/Contents" -name 'libgdk-3.0.dylib' | head -1)
echo "libgdk : $GDKLIB"
/tmp/gdkver_sdk11 "$GDKLIB" || true
echo "-- lié SDK courant"
/tmp/gdkver_sdkcur "$GDKLIB" || true

echo "== capture interne (MELD_SCREENSHOT_AND_EXIT, Meld >= 3.24)"
MELD_SCREENSHOT_AND_EXIT="$OUT/$LABEL-internal.png" MELD_SCREENSHOT_TIMEOUT_MS=8000 \
  perl -e 'alarm 60; exec @ARGV' "$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" \
  || echo "capture interne indisponible (code $?)"

echo "== capture écran (screencapture)"
"$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" &
PID=$!
sleep 20
screencapture -x "$OUT/$LABEL-screen.png" || echo "screencapture a échoué"
# fenêtre au premier plan, puis redimensionnement : force un nouveau rendu
osascript -e 'tell application "System Events" to set frontmost of (first process whose unix id is '"$PID"') to true' || true
sleep 3
screencapture -x "$OUT/$LABEL-screen-front.png" || true
osascript -e 'tell application "System Events" to tell (first process whose unix id is '"$PID"') to set size of window 1 to {1100, 700}' || true
sleep 3
screencapture -x "$OUT/$LABEL-screen-resized.png" || true
osascript -e 'tell application "System Events" to tell (first process whose unix id is '"$PID"') to get {position, size} of every window' || true
kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
ls -la "$OUT"
