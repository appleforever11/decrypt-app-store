# Branding assets

The source icon is `macos/Resources/Branding/AppIcon.png`. `script/generate_icon.swift` converts it into the complete macOS icon family; `iconutil` packages it as ICNS. Transparent margins are preserved.

Generated using the built-in image-generation tool with this prompt:

> Create a production macOS app icon for 'Decrypt App Store'. One centered rounded-square macOS icon, front-facing orthographic, no perspective tilt. Elegant cobalt-blue to indigo glass tile with finely beveled luminous edges. Central mark: a substantial frosted-white open padlock, its lower body subtly shaped like a neatly stacked app tile; a small downward arrow cut into the lock body. Premium Apple-like Liquid Glass material and restrained optical depth, beautifully legible silhouette at small sizes. No text, no letters, no Apple logo, no watermark, no extra objects. Icon occupies 88 percent of square canvas, transparent outside rounded square, balanced generous margin. 1024 by 1024.

The 720 × 480 installer background is drawn with AppKit by `script/generate_dmg_background.swift`. Finder places the actual app and Applications shortcut on top. `script/build_dmg.py` uses dmgbuild to write portable Finder bookmarks, the window layout and icon positions; the background is stored as a hidden image inside the disk.

To package locally:

```sh
python3 -m venv work/dmg-venv
work/dmg-venv/bin/pip install -r script/dmg-requirements.txt
DMG_PYTHON="$PWD/work/dmg-venv/bin/python" ./script/package_dmg.sh /absolute/path/to/new.dmg
```
