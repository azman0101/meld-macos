#!/usr/bin/env bash
#
# Test du placement de la fenêtre de Meld au lancement (bug meld#966).
#
#   placement.sh <Meld.app> <label> <dossier-de-sortie>
#
# Scénarios, chacun avec un état de préférences différent :
#   fresh   : aucune préférence
#   relaunch: relance après une première exécution
#   large   : taille sauvegardée plus grande que l'écran
#   small   : petite taille sauvegardée
# Chaque scénario échoue si la fenêtre dépasse la zone utile de l'écran.

set -uo pipefail

APP=$1
LABEL=$2
OUT=$3
HERE=$(cd "$(dirname "$0")/.." && pwd)
DOMAIN=org.gnome.Meld
mkdir -p "$OUT"
exec > >(tee -a "$OUT/placement.txt") 2>&1

swiftc -O -o /tmp/winfo "$HERE/diag/winfo.swift" 2>&1 | grep -v warning || true

reset_prefs() {
  defaults delete $DOMAIN >/dev/null 2>&1 || true
  rm -rf ~/Library/"Saved Application State"/$DOMAIN.savedState
}

# clés GSettings stockées par le backend NSUserDefaults de GLib
set_size() {
  defaults write $DOMAIN /org/gnome/meld/window-state/width -int "$1"
  defaults write $DOMAIN /org/gnome/meld/window-state/height -int "$2"
}

run() {
  local name=$1
  echo "---- scénario $name"
  defaults read $DOMAIN 2>/dev/null | grep -i -E "window|width|height|maxim" || echo "(pas de préférences)"
  "$APP/Contents/MacOS/Meld" "$HERE/testdata/left.py" "$HERE/testdata/right.py" &
  local pid=$!
  sleep 15
  /tmp/winfo $pid
  local rc=$?
  screencapture -x "$OUT/$LABEL-placement-$name.png" || true
  osascript -e "tell application \"System Events\" to tell (first process whose unix id is $pid) to get {position, size} of every window" 2>/dev/null || true
  kill $pid 2>/dev/null; wait $pid 2>/dev/null
  sleep 2
  case $rc in
    0) echo "RESULT $LABEL $name OK" ;;
    1) echo "RESULT $LABEL $name ÉCHEC (hors zone utile)"; FAIL=1 ;;
    *) echo "RESULT $LABEL $name ÉCHEC (pas de fenêtre)"; FAIL=1 ;;
  esac
}

FAIL=0
reset_prefs; run fresh
echo "préférences après la 1re exécution :"; defaults read $DOMAIN 2>/dev/null || true
ls -laR ~/Library/"Application Support"/$DOMAIN 2>/dev/null | head -20 || true
run relaunch
reset_prefs; set_size 2400 1600; run large
reset_prefs; set_size 500 300; run small
reset_prefs
exit $FAIL
