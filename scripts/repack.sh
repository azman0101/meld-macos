#!/usr/bin/env bash
#
# Repackage un DMG officiel de Meld avec les correctifs de patches/ appliqués
# au code Python embarqué, puis le signe ad hoc.
#
#   repack.sh <url-ou-chemin-du-dmg> <patch> <dmg-de-sortie>
#
# Seul le code Python de Meld change : GTK, PyGObject et Python sont ceux
# du build d'origine.

set -euo pipefail

SRC=$1
PATCH=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
OUT=$3

"$(dirname "$0")"/install.sh "$SRC"
APP=/Applications/Meld.app

SITE=$(echo "$APP"/Contents/Resources/lib/python3.*/site-packages)
patch -d "$SITE" -p1 --forward < "$PATCH"
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
