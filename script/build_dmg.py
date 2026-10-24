"""Package the app with a portable Finder background and icon layout."""
from pathlib import Path
import sys
import dmgbuild
root = Path(sys.argv[1]).resolve()
app = Path(sys.argv[2]).resolve()
destination = Path(sys.argv[3]).resolve()
if destination.exists():
    raise SystemExit('Destination exists; refusing to overwrite')
dmgbuild.build_dmg(str(destination), 'Decrypt App Store 0.1.1', settings={
    'format': 'UDZO', 'filesystem': 'HFS+',
    'files': [str(app)], 'symlinks': {'Applications': '/Applications'},
    'background': str(root / 'macos/Resources/Branding/DMGBackground.png'),
    'badge_icon': str(root / 'dist/AppIcon.icns'),
    'icon_locations': {'Decrypt App Store.app': (200, 255), 'Applications': (520, 255)},
    'window_rect': ((180, 160), (720, 480)), 'icon_size': 104, 'text_size': 13,
    'show_toolbar': False, 'show_sidebar': False, 'show_status_bar': False,
    'show_pathbar': False, 'default_view': 'icon-view',
})
