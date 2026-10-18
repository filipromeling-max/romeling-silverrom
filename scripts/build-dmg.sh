#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
./scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' 'dist/Romeling Silverroom.app/Contents/Info.plist')
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/silverroom-dmg.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
ditto 'dist/Romeling Silverroom.app' "$STAGING/Romeling Silverroom.app"
ln -s /Applications "$STAGING/Applications"
cat > "$STAGING/Read me.txt" <<'INFO'
ROMELING SILVERROOM

Drag Romeling Silverroom into Applications, then eject this disk.
Requires macOS 14 or later. Supports Apple silicon and Intel Macs.

This release is ad-hoc signed and has not been notarized by Apple.
If macOS blocks it, first attempt to open the installed app, then use
System Settings > Privacy & Security > Open Anyway if you trust this download.
Do not disable system security protections.

Your photographs are processed locally. Original files are not modified.
Film profiles are creative interpretations, not calibrated reproductions.

https://filipromeling-max.github.io/romeling-silverrom/
INFO
hdiutil create -volname 'Romeling Silverroom' -srcfolder "$STAGING" -ov -format UDZO "dist/Romeling-Silverroom-$VERSION-universal.dmg"
(cd dist && shasum -a 256 "Romeling-Silverroom-$VERSION-universal.dmg" > SHA256SUMS.txt)
hdiutil verify "dist/Romeling-Silverroom-$VERSION-universal.dmg"
