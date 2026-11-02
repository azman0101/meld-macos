#!/usr/bin/env bash
#
# Déplacement de la fenêtre de Meld entre deux écrans.
#
#   VD_SCALE=1|2 display.sh <Meld.app> <label> <dossier-de-sortie>
#
# Crée un second écran virtuel (diag/vdisplay.m), en 1x ou en 2x (VD_SCALE),
# puis déplace la fenêtre de l'un à l'autre, aller et retour :
#   ax     : par l'accessibilité (AXPosition)
#   souris : glisser-déposer de la barre de titre
# Après chaque déplacement, l'écran où se trouve la fenêtre est relevé 2 s puis
# 8 s plus tard : la fenêtre est-elle restée, ou revenue en arrière ?
# Relève aussi les boutons de la fenêtre (AXCloseButton, ... si la barre de
# titre est celle de macOS).
# N'échoue pas : c'est un banc de mesure, à lire dans display.txt.

set -uo pipefail

APP=$1
LABEL=$2
OUT=$3
SCALE=${VD_SCALE:-1}
HERE=$(cd "$(dirname "$0")/.." && pwd)
DOMAIN=org.gnome.Meld
mkdir -p "$OUT"
exec > >(tee -a "$OUT/display.txt") 2>&1

swiftc -O -o /tmp/winfo "$HERE/diag/winfo.swift" 2>&1 | grep -v warning || true
swiftc -O -o /tmp/drag "$HERE/diag/drag.swift" 2>&1 | grep -v warning || true
clang -fobjc-arc -framework Foundation -framework CoreGraphics -framework AppKit \
  -o /tmp/vdisplay "$HERE/diag/vdisplay.m" 2>&1 | grep -v warning || true

# F11 = « Afficher le bureau » (raccourcis 36 et 37) : à désactiver
for k in 36 37; do
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $k \
    "<dict><key>enabled</key><false/></dict>"
done
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true

defaults delete $DOMAIN >/dev/null 2>&1 || true

echo "== $LABEL : écran virtuel en ${SCALE}x"
/tmp/vdisplay 1280 800 900 "$SCALE" > /tmp/vdisplay.log 2>&1 &
VD=$!
# la création de l'écran (surtout en 2x) peut prendre plusieurs dizaines de secondes
for _ in $(seq 1 60); do
  grep -qE '^(display id [0-9]+$|échec)' /tmp/vdisplay.log 2>/dev/null && break
  kill -0 $VD 2>/dev/null || break
  sleep 1
done
sleep 4
cat /tmp/vdisplay.log

"$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" &
PID=$!
sleep 15

se() { osascript -e "tell application \"System Events\" to tell (first process whose unix id is $PID) to $1" 2>&1; }
info() { /tmp/winfo $PID | grep -E "^display|fenêtre" | grep -v '^fenêtre ""'; }
frame() { /tmp/winfo $PID | sed -n 's/^fenêtre "Meld" x=\(-*[0-9]*\) y=\(-*[0-9]*\) w=\([0-9]*\) h=\([0-9]*\).*/\1 \2 \3 \4/p' | head -1; }
where() { /tmp/winfo $PID | sed -n 's/^  fenêtre sur le display \([0-9]*\).*/\1/p' | head -1; }
displays() { /tmp/winfo $PID | sed -n "s/^display $1 frame x=\\(-*[0-9]*\\) y=\\(-*[0-9]*\\) w=\\([0-9]*\\) h=\\([0-9]*\\).*/\\1 \\2 \\3 \\4/p"; }

echo "== écrans et fenêtre au départ"
info
read -r D1X D1Y D1W D1H < <(displays 1)
read -r D2X D2Y D2W D2H < <(displays 2)
if [[ -z ${D2X:-} ]]; then
  echo "RESULT $LABEL PAS DE SECOND ÉCRAN"
  kill $PID $VD 2>/dev/null
  exit 0
fi
START=$(where)
echo "== boutons de la fenêtre : $(se 'get subrole of every button of window 1')"

# check <description> <display attendu>
check() {
  sleep 2; local a; a=$(where)
  sleep 6; local b; b=$(where)
  local verdict=OK
  [[ $b == "$2" ]] || verdict="ÉCART (attendu display $2)"
  echo "RESULT $LABEL $1 : display $a à +2 s, display $b à +8 s : $verdict"
  info | grep 'fenêtre "Meld"' | sed 's/^/    /'
}

# glisser la barre de titre jusqu'au centre du display $1 (CG : x y w h)
drag_to() {
  local fx fy fw fh gy
  se "set frontmost to true" >/dev/null; sleep 1
  read -r fx fy fw fh < <(frame)
  if se 'get subrole of every button of window 1' | grep -q AXCloseButton; then gy=14; else gy=45; fi
  local gx=$((fx + fw / 2)); gy=$((fy + gy))
  echo "glisser de ($gx, $gy) vers ($2, $3)"
  /tmp/drag $gx $gy "$2" "$3"
}

echo "---- ax : vers le display 2, puis retour au display 1"
se "set position of window 1 to {$((D2X + 150)), $((D2Y + 120))}" >/dev/null
check "ax vers display 2" 2
screencapture -x -D 2 "$OUT/$LABEL-ax-ecran2.png" 2>/dev/null || true
se "set position of window 1 to {$((D1X + 150)), $((D1Y + 120))}" >/dev/null
check "ax retour display 1" 1

echo "---- souris : vers le display 2, puis retour au display 1"
drag_to 2 $((D2X + D2W / 2)) $((D2Y + 200))
check "souris vers display 2" 2
screencapture -x -D 2 "$OUT/$LABEL-souris-ecran2.png" 2>/dev/null || true
drag_to 1 $((D1X + D1W / 2)) $((D1Y + 200))
check "souris retour display 1" 1
screencapture -x "$OUT/$LABEL-souris-principal.png" || true

echo "---- plein écran depuis le display 2 : la fenêtre doit y rester à la sortie"
f11() {
  se "set frontmost to true" >/dev/null; sleep 1
  osascript -e 'tell application "System Events" to key code 103'
}
se "set position of window 1 to {$((D2X + 100)), $((D2Y + 100))}" >/dev/null
sleep 3
f11; sleep 4
echo "-- en plein écran (F11)"; info | grep 'fenêtre "Meld"' | sed 's/^/    /'
f11
check "sortie de plein écran (F11) depuis le display 2" 2
se "set position of window 1 to {$((D2X + 100)), $((D2Y + 100))}" >/dev/null
sleep 3
se 'set value of attribute "AXFullScreen" of window 1 to true' >/dev/null; sleep 4
echo "-- en plein écran (natif)"; info | grep 'fenêtre "Meld"' | sed 's/^/    /'
se 'set value of attribute "AXFullScreen" of window 1 to false' >/dev/null
check "sortie du plein écran natif depuis le display 2" 2
screencapture -x -D 2 "$OUT/$LABEL-apres-plein-ecran-ecran2.png" 2>/dev/null || true
screencapture -x "$OUT/$LABEL-apres-plein-ecran-principal.png" || true

kill $PID $VD 2>/dev/null; wait $PID 2>/dev/null
defaults delete $DOMAIN >/dev/null 2>&1 || true
exit 0
