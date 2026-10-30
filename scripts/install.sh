#!/usr/bin/env bash
#
# Installe Meld.app depuis un DMG (URL ou chemin) dans /Applications.
#
#   install.sh <url-ou-chemin-du-dmg>

set -euo pipefail

DMG=$1
if [[ $DMG == http* ]]; then
  curl -fsSL -o /tmp/meld.dmg "$DMG"
  DMG=/tmp/meld.dmg
fi
shasum -a 256 "$DMG"
MNT=$(mktemp -d)
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null
rm -rf /Applications/Meld.app
cp -R "$MNT/Meld.app" /Applications/
hdiutil detach "$MNT" >/dev/null
xattr -cr /Applications/Meld.app
plutil -extract CFBundleShortVersionString raw /Applications/Meld.app/Contents/Info.plist
plutil -extract CFBundleVersion raw /Applications/Meld.app/Contents/Info.plist
