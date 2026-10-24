#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:?Provide a new destination DMG path}"
if [[ -e "$DESTINATION" ]]; then echo 'Destination already exists; refusing to overwrite.' >&2; exit 1; fi
"$ROOT_DIR/script/build_and_run.sh" --build
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/decrypt-store-dmg.XXXXXX")"
ditto --norsrc --noextattr "$ROOT_DIR/dist/Decrypt App Store.app" "$STAGING/Decrypt App Store.app"
/usr/bin/xattr -dr com.apple.FinderInfo "$STAGING/Decrypt App Store.app" 2>/dev/null || true
codesign --verify --deep --strict "$STAGING/Decrypt App Store.app"
cp "$ROOT_DIR/macos/README.md" "$STAGING/Read Me.md"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname 'Decrypt App Store' -srcfolder "$STAGING" -format UDZO "$DESTINATION"
