#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi
.venv/bin/python -m pip install -r requirements.txt pyinstaller
.venv/bin/pyinstaller --noconfirm --clean --onedir --name spoofy-backend --collect-all pymobiledevice3 --collect-all pykdebugparser backend.py
rm -rf 'dist/Spoofy.app'
mkdir -p 'dist/Spoofy.app/Contents/MacOS' 'dist/Spoofy.app/Contents/Resources'
cp -R dist/spoofy-backend 'dist/Spoofy.app/Contents/MacOS/backend'
ln -sf backend/spoofy-backend 'dist/Spoofy.app/Contents/MacOS/spoofy-backend'
cp AppIcon.icns 'dist/Spoofy.app/Contents/Resources/'
cat > 'dist/Spoofy.app/Contents/Info.plist' <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Spoofy</string>
<key>CFBundleIdentifier</key><string>org.spoofy.desktop</string>
<key>CFBundleName</key><string>Spoofy</string>
<key>CFBundleDisplayName</key><string>Spoofy</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon.icns</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
swiftc -module-cache-path "${TMPDIR:-/tmp}/spoofy-swift-cache" -parse-as-library Spoofy.swift -o 'dist/Spoofy.app/Contents/MacOS/Spoofy' -framework SwiftUI -framework MapKit -framework CoreLocation
'dist/Spoofy.app/Contents/MacOS/spoofy-backend' developer dvt simulate-location set --help >/dev/null
ditto -c -k --sequesterRsrc --keepParent 'dist/Spoofy.app' dist/Spoofy-macOS.zip
