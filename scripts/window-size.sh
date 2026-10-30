#!/usr/bin/env bash
#
# Diagnostic : plein écran et taille maximale de la fenêtre de Meld.
#
#   window-size.sh <Meld.app> <label> <dossier-de-sortie>
#
# Mesure, avec captures :
#   maximize   : double-clic sur la barre de titre (maximisation GTK) ;
#                cadre obtenu (CGWindowList, ombre comprise) et capture
#   f11        : plein écran de Meld (F11), tenu ou annulé au bout de 10 s ?
#                (le raccourci « Afficher le bureau » de macOS, sur F11, est
#                désactivé pour que la touche arrive à Meld)
#   native     : plein écran natif de macOS (AXFullScreen), idem
# N'échoue pas : c'est un banc de mesure, à lire dans window-size.txt.

set -uo pipefail

APP=$1
LABEL=$2
OUT=$3
HERE=$(cd "$(dirname "$0")/.." && pwd)
DOMAIN=org.gnome.Meld
mkdir -p "$OUT"
exec > >(tee -a "$OUT/window-size.txt") 2>&1

swiftc -O -o /tmp/winfo "$HERE/diag/winfo.swift" 2>&1 | grep -v warning || true
swiftc -O -o /tmp/click "$HERE/diag/click.swift" 2>&1 | grep -v warning || true

# F11 = « Afficher le bureau » (raccourcis 36 et 37) : à désactiver
for k in 36 37; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $k \
    "<dict><key>enabled</key><false/></dict>"
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
defaults delete $DOMAIN >/dev/null 2>&1 || true

"$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" &
PID=$!
sleep 15

se() { osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to $1" 2>&1; }
front() { se "set frontmost to true" >/dev/null; sleep 1; }
state() {
  echo "-- $1"
  /tmp/winfo $PID | sed 's/ -> .*//'
  echo "AX position/taille : $(se 'get {position, size} of window 1')"
  echo "AXFullScreen : $(se 'get value of attribute "AXFullScreen" of window 1')"
}

state initial

echo "---- maximize"
front
# double-clic sur la barre de titre : ~30 pt sous le haut du cadre, ombre
# comprise ou non
title() {
  read -r FX FY FW < <(/tmp/winfo $PID | sed -n 's/.*fenêtre "Meld" x=\(-*[0-9]*\) y=\(-*[0-9]*\) w=\([0-9]*\).*/\1 \2 \3/p' | head -1)
  /tmp/click $((FX + FW / 2)) $((FY + 30))
}
title
sleep 3; state "maximize"; screencapture -x "$OUT/$LABEL-maximize.png"
front; title
sleep 3; state "après démaximisation"

echo "---- f11"
front
osascript -e 'tell application "System Events" to key code 103'
sleep 2; state "f11 +2 s"; screencapture -x "$OUT/$LABEL-f11-2s.png"
sleep 8; state "f11 +10 s"; screencapture -x "$OUT/$LABEL-f11-10s.png"
front
osascript -e 'tell application "System Events" to key code 103'
sleep 5; state "après sortie (F11)"

echo "---- native"
se 'set value of attribute "AXFullScreen" of window 1 to true' >/dev/null
sleep 2; state "native +2 s"; screencapture -x "$OUT/$LABEL-native-2s.png"
sleep 8; state "native +10 s"; screencapture -x "$OUT/$LABEL-native-10s.png"
se 'set value of attribute "AXFullScreen" of window 1 to false' >/dev/null
sleep 5; state "après sortie (natif)"

kill $PID 2>/dev/null; wait $PID 2>/dev/null
defaults delete $DOMAIN >/dev/null 2>&1 || true
exit 0
