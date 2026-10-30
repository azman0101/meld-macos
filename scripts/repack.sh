#!/usr/bin/env bash
#
# Repackage un DMG officiel de Meld avec les correctifs de patches/ appliqués
# au code Python embarqué, puis le signe ad hoc.
#
#   repack.sh <url-ou-chemin-du-dmg> <patch> <dmg-de-sortie> [<dmg-du-code>]
#
# Seul le code Python de Meld change : GTK, PyGObject et Python sont ceux
# du build d'origine.
#
# Avec <dmg-du-code>, le code et les ressources de Meld (Python, gresource,
# styles, traductions, icônes) viennent de ce second DMG, posés sur le
# runtime du premier. Sert à faire tourner Meld 3.24.1 sur le runtime de
# 3.22.3+105, dont Pango n'écrase pas les espaces de l'interface.
#
# EXTRA_PATCH=<patch> applique en plus un correctif expérimental.

set -euo pipefail

SRC=$1
PATCH=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
OUT=$3
CODE=${4:-}

"$(dirname "$0")"/install.sh "$SRC"
APP=/Applications/Meld.app
SITE=$(echo "$APP"/Contents/Resources/lib/python3.*/site-packages)

if [[ -n $CODE ]]; then
  if [[ $CODE == http* ]]; then
    curl -fsSL -o /tmp/meld-code.dmg "$CODE"
    CODE=/tmp/meld-code.dmg
  fi
  MNT=$(mktemp -d)
  hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$CODE" >/dev/null
  FROM=$MNT/Meld.app/Contents
  FROM_SITE=$(echo "$FROM"/Resources/lib/python3.*/site-packages)
  if [[ $(basename "$(dirname "$FROM_SITE")") != $(basename "$(dirname "$SITE")") ]]; then
    echo "versions de Python différentes : $FROM_SITE / $SITE"; exit 1
  fi
  rm -rf "$SITE/meld" "$APP/Contents/Resources/share/meld"
  cp -R "$FROM_SITE/meld" "$SITE/"
  cp -R "$FROM/Resources/share/meld" "$APP/Contents/Resources/share/"
  (cd "$FROM/Resources/share" && find locale icons -name 'meld.mo' -o -name 'org.gnome.Meld*' | while read -r f; do
    mkdir -p "$APP/Contents/Resources/share/$(dirname "$f")"
    cp "$f" "$APP/Contents/Resources/share/$f"
  done)
  for k in CFBundleShortVersionString CFBundleVersion; do
    v=$(plutil -extract $k raw "$FROM/Info.plist")
    plutil -replace $k -string "$v" "$APP/Contents/Info.plist"
  done
  hdiutil detach "$MNT" >/dev/null
  find "$SITE/meld" -name '*.pyc' -delete
  echo "code de Meld $(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist") sur le runtime de $SRC"
  # Le schéma GSettings du runtime reste valable : 3.24.1 n'a fait que
  # retirer la clé is-fullscreen.
fi

patch -d "$SITE" -p1 --forward < "$PATCH"
if [[ -n ${EXTRA_PATCH:-} ]]; then
  patch -d "$SITE" -p1 --forward < "$EXTRA_PATCH"
fi
find "$SITE/meld" -name '*.pyc' -delete
find "$SITE/meld" -name "windowstate*.pyc" -delete

# la signature d'origine n'est plus valide après modification
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

STAGE=$(mktemp -d)
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
hdiutil create -volname Meld -srcfolder "$STAGE" -format UDZO -fs HFS+ "$OUT" >/dev/null
shasum -a 256 "$OUT"
