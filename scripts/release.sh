#!/usr/bin/env bash
#
# Construit le DMG corrigé correspondant à un tag, le teste et le publie en
# release GitHub.
#
#   release.sh <tag>      ex. v3.22.3+105-fix1, v3.24.1-fix1
#
# Le tag donne la version de Meld d'origine et le numéro du correctif.
# Nécessite GH_TOKEN (droit contents: write).

set -euo pipefail

TAG=$1
HERE=$(cd "$(dirname "$0")/.." && pwd)
VERSION=${TAG#v}          # 3.22.3+105-fix1
UPSTREAM=${VERSION%-fix*} # 3.22.3+105

case $UPSTREAM in
  3.22.*)
    URL=https://gitlab.com/api/v4/projects/51547804/packages/generic/meld_macos/$UPSTREAM/Meld-${UPSTREAM}_arm64.dmg
    PATCH=$HERE/patches/meld-3.22-window-placement.patch ;;
  3.24.*)
    URL=https://gitlab.gnome.org/api/v4/projects/301/packages/generic/meld/$UPSTREAM/Meld-$UPSTREAM-arm64.dmg
    PATCH=$HERE/patches/meld-3.24-window-placement.patch ;;
  *)
    echo "version non prise en charge : $UPSTREAM"; exit 1 ;;
esac

DMG=out/Meld-$VERSION-arm64.dmg
"$HERE/scripts/repack.sh" "$URL" "$PATCH" "$DMG"
"$HERE/scripts/placement.sh" /Applications/Meld.app "$VERSION" out

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo "sha256 $SHA"
gh release create "$TAG" "$DMG" --title "Meld $VERSION" --notes "\
Meld $UPSTREAM (arm64) avec le correctif du placement de fenêtre (meld#966).

Construit à partir de $URL, signé ad hoc seulement.

sha256 : \`$SHA\`"
