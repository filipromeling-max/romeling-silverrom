#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
APP="$PWD/dist/Romeling Silverroom.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Silverroom" "$APP/Contents/MacOS/Silverroom"
rm -rf "$APP/Contents/Resources/Silverroom_Silverroom.bundle"
cp -R "$BIN_DIR/Silverroom_Silverroom.bundle" "$APP/Contents/Resources/"
swift scripts/make-icon.swift
iconutil -c icns .build/Romeling.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Romeling Silverroom</string>
<key>CFBundleDisplayName</key><string>Romeling Silverroom</string>
<key>CFBundleIdentifier</key><string>studio.silverroom.mac</string>
<key>CFBundleVersion</key><string>11</string>
<key>CFBundleShortVersionString</key><string>1.9.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleExecutable</key><string>Silverroom</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Photograph</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>LSItemContentTypes</key><array><string>public.image</string><string>public.camera-raw-image</string></array>
</dict></array>
<key>NSHumanReadableCopyright</key><string>Silverroom. Film names belong to their respective owners.</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP"
printf 'Built %s\n' "$APP"
