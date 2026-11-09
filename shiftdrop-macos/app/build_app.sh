#!/bin/zsh
# Builds ShiftDrop.app (a menu-bar app) so macOS can attach the Input Monitoring permission to it.
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release 2>&1 | grep -v "ld: warning" || true
APP=build/ShiftDrop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/ShiftDrop "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>dev.shiftdrop.mac</string>
  <key>CFBundleName</key><string>ShiftDrop</string>
  <key>CFBundleExecutable</key><string>ShiftDrop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.0.1</string>
  <key>LSMinimumSystemVersion</key><string>13.4</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
KC="$HOME/Library/Keychains/shiftdrop-dev.keychain-db"
if [ -f "$KC" ] && security unlock-keychain -p sdlocal "$KC" 2>/dev/null; then
  # Stable identity: macOS keeps the Input Monitoring permission across rebuilds.
  codesign --force --sign "ShiftDrop Dev" --keychain "$KC" "$APP"
else
  echo "no ShiftDrop Dev identity: ad-hoc signing (permissions reset on every build)"
  codesign --force --sign - "$APP"
fi
echo "built $APP  (run: open $APP)"
