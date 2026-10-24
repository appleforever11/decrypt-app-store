#!/bin/bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/Decrypt App Store.app"
if [[ "$MODE" != "--build" ]]; then pkill -x DecryptStore >/dev/null 2>&1 || true; fi
swift build --package-path "$ROOT_DIR/macos" -c release
BUILD_DIR="$(swift build --package-path "$ROOT_DIR/macos" -c release --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/DecryptStore" "$APP_BUNDLE/Contents/MacOS/DecryptStore"
if [[ ! -f "$ROOT_DIR/dist/AppIcon.icns" || "$ROOT_DIR/script/generate_icon.swift" -nt "$ROOT_DIR/dist/AppIcon.icns" || "$ROOT_DIR/macos/Resources/Branding/AppIcon.png" -nt "$ROOT_DIR/dist/AppIcon.icns" ]]; then
  swift "$ROOT_DIR/script/generate_icon.swift" "$ROOT_DIR/dist/AppIcon.iconset" "$ROOT_DIR/macos/Resources/Branding/AppIcon.png"
  iconutil -c icns "$ROOT_DIR/dist/AppIcon.iconset" -o "$ROOT_DIR/dist/AppIcon.icns"
fi
cp "$ROOT_DIR/dist/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/macos/Resources/audit.py" "$APP_BUNDLE/Contents/Resources/audit.py"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DecryptStore</string>
<key>CFBundleIdentifier</key><string>app.decryptstore.mac</string>
<key>CFBundleName</key><string>Decrypt App Store</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.4</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
/usr/bin/xattr -dr com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE"
case "$MODE" in
--build) ;;
run) open -n "$APP_BUNDLE" ;;
--verify) open -n "$APP_BUNDLE"; sleep 1; pgrep -x DecryptStore >/dev/null ;;
--debug) lldb -- "$APP_BUNDLE/Contents/MacOS/DecryptStore" ;;
--logs|--telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --predicate 'process == "DecryptStore"' ;;
*) echo 'Usage: build_and_run.sh [--build|--verify|--debug|--logs|--telemetry]'; exit 2 ;;
esac
