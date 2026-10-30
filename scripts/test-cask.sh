#!/usr/bin/env bash
#
# Installe un cask meld-patched* (celui du dépôt azman0101/homebrew-tap) depuis
# un tap local, en le faisant pointer sur un DMG local, puis vérifie
# l'installation (app, commande meld, quarantaine, lancement).
#
#   test-cask.sh <Casks/meld-patched*.rb> <dmg>

set -euo pipefail

CASK=$1
NAME=$(basename "$CASK" .rb)
DMG=$(cd "$(dirname "$2")" && pwd)/$(basename "$2")
SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')

rm -rf /Applications/Meld.app
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_FROM_API=1
brew tap-new --no-git azman0101/test >/dev/null
TAP=$(brew --repository azman0101/test)
mkdir -p "$TAP/Casks"
# même cask, mais sha256 du DMG local et URL file:// à la place de la release
sed -E -e "s|^(  sha256 )\".*\"|\\1\"$SHA\"|" \
  -e "s|https://github.com/azman0101/meld-macos/releases/download/[^/]+/|file://$(dirname "$DMG")/|" \
  "$CASK" > "$TAP/Casks/$NAME.rb"

brew style "$TAP/Casks/$NAME.rb"
# les taps tiers doivent être approuvés explicitement
brew trust azman0101/test
brew audit --cask --strict azman0101/test/$NAME
brew install --cask azman0101/test/$NAME

echo "== vérifications"
test -d /Applications/Meld.app
codesign --verify --deep --strict /Applications/Meld.app
if xattr -r /Applications/Meld.app | grep -q com.apple.quarantine; then
  echo "quarantaine encore présente"; exit 1
fi
command -v meld
cat "$(command -v meld)"
spctl --assess --type execute -vv /Applications/Meld.app || echo "(Gatekeeper : attendu pour une signature ad hoc)"
meld --version
