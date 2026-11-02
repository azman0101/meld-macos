#!/usr/bin/env bash
#
# Déplacement de la fenêtre de Meld vers un second écran.
#
#   display.sh <Meld.app> <label> <dossier-de-sortie>
#
# Crée un écran virtuel à droite de l'écran principal (diag/vdisplay.m), puis :
#   boutons    : sous-rôles des boutons de la fenêtre (AXCloseButton, ... si
#                la barre de titre est celle de macOS)
#   ax         : déplacement par l'accessibilité vers le second écran
#   souris     : glisser-déposer de la barre de titre vers le second écran
# Après chaque déplacement, la position est relevée 2 s puis 8 s plus tard :
# la fenêtre est-elle restée sur le second écran, ou revenue ?
# N'échoue pas : c'est un banc de mesure, à lire dans display.txt.

set -uo pipefail

APP=$1
LABEL=$2
OUT=$3
HERE=$(cd "$(dirname "$0")/.." && pwd)
DOMAIN=org.gnome.Meld
mkdir -p "$OUT"
exec > >(tee -a "$OUT/display.txt") 2>&1

swiftc -O -o /tmp/winfo "$HERE/diag/winfo.swift" 2>&1 | grep -v warning || true
swiftc -O -o /tmp/drag "$HERE/diag/drag.swift" 2>&1 | grep -v warning || true
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  -o /tmp/vdisplay "$HERE/diag/vdisplay.m" 2>&1 | grep -v warning || true

defaults delete $DOMAIN >/dev/null 2>&1 || true

echo "== écran virtuel"
/tmp/vdisplay 1280 800 600 > /tmp/vdisplay.log 2>&1 &
VD=$!
sleep 10
cat /tmp/vdisplay.log

"$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" &
PID=$!
sleep 15

se() { osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to $1" 2>&1; }
info() { /tmp/winfo $PID | grep -E "^display|fenêtre" | grep -v '^fenêtre ""'; }
frame() { /tmp/winfo $PID | sed -n 's/^fenêtre "Meld" x=\(-*[0-9]*\) y=\(-*[0-9]*\) w=\([0-9]*\) h=\([0-9]*\).*/\1 \2 \3 \4/p' | head -1; }

echo "== écrans et fenêtre au départ"
info
read -r D2X D2Y D2W D2H < <(/tmp/winfo $PID | sed -n 's/^display 2 frame x=\(-*[0-9]*\) y=\(-*[0-9]*\) w=\([0-9]*\) h=\([0-9]*\).*/\1 \2 \3 \4/p')
if [[ -z ${D2X:-} ]]; then
  echo "RESULT $LABEL PAS DE SECOND ÉCRAN"
  kill $PID $VD 2>/dev/null
  exit 0
fi
screencapture -x "$OUT/$LABEL-depart.png" || true

echo "== boutons de la fenêtre : $(se 'get subrole of every button of window 1')"

echo "---- ax : vers le second écran"
se "set position of window 1 to {$((D2X + 150)), $((D2Y + 120))}" >/dev/null
sleep 2; echo "-- +2 s"; info
sleep 6; echo "-- +8 s"; info
screencapture -x -D 2 "$OUT/$LABEL-ax-ecran2.png" 2>/dev/null || true

echo "---- souris : retour sur l'écran principal puis glissement vers le second"
se "set position of window 1 to {100, 120}" >/dev/null
sleep 3
se "set frontmost to true" >/dev/null; sleep 1
read -r FX FY FW FH < <(frame)
if [[ -n $(se 'get subrole of every button of window 1' | grep -o AXCloseButton) ]]; then GY=14; else GY=45; fi
GX=$((FX + FW / 2)); GY=$((FY + GY))
TX=$((D2X + D2W / 2)); TY=$((D2Y + 200))
echo "glisser de ($GX, $GY) vers ($TX, $TY)"
/tmp/drag $GX $GY $TX $TY
sleep 2; echo "-- +2 s"; info
sleep 6; echo "-- +8 s"; info
screencapture -x -D 2 "$OUT/$LABEL-souris-ecran2.png" 2>/dev/null || true
screencapture -x "$OUT/$LABEL-souris-principal.png" || true

ON=$(/tmp/winfo $PID | sed -n 's/^  fenêtre sur le display \([0-9]*\).*/\1/p' | head -1)
echo "RESULT $LABEL souris : fenêtre sur le display $ON après 8 s"

kill $PID $VD 2>/dev/null; wait $PID 2>/dev/null
defaults delete $DOMAIN >/dev/null 2>&1 || true
exit 0
