#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:?Provide a new destination DMG path}"
DMG_PYTHON="${DMG_PYTHON:-python3}"
if [[ -e "$DESTINATION" ]]; then echo 'Destination already exists; refusing to overwrite.' >&2; exit 1; fi
"$DMG_PYTHON" -c 'import dmgbuild' || { echo 'Install script/dmg-requirements.txt in a virtual environment and set DMG_PYTHON.' >&2; exit 1; }
"$ROOT_DIR/script/build_and_run.sh" --build
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/decrypt-store-dmg.XXXXXX")"
ditto --norsrc --noextattr "$ROOT_DIR/dist/Decrypt App Store.app" "$STAGING/Decrypt App Store.app"
cp "$ROOT_DIR/macos/README.md" "$STAGING/Decrypt App Store.app/Contents/Resources/Read Me.md"
codesign --force --sign - "$STAGING/Decrypt App Store.app"
codesign --verify --deep --strict "$STAGING/Decrypt App Store.app"
"$DMG_PYTHON" "$ROOT_DIR/script/build_dmg.py" "$ROOT_DIR" "$STAGING/Decrypt App Store.app" "$DESTINATION"
hdiutil verify "$DESTINATION"
