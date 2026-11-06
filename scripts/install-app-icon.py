"""Install content-versioned artwork so Finder can distinguish changed app icons."""
import hashlib
import plistlib
import sys
from pathlib import Path

source, app = map(Path, sys.argv[1:])
artwork = source.read_bytes()
filename = f"LoongTodo-{hashlib.sha256(artwork).hexdigest()[:12]}.icns"
resources = app / "Contents/Resources"
resources.mkdir(parents=True, exist_ok=True)
(resources / filename).write_bytes(artwork)

plist = app / "Contents/Info.plist"
info = plistlib.loads(plist.read_bytes())
info["CFBundleIconFile"] = filename
plist.write_bytes(plistlib.dumps(info, sort_keys=False))

# Remove only obsolete icon files produced by this build pipeline.
for old in [resources / "AppIcon.icns", *resources.glob("LoongTodo-*.icns")]:
    if old.name != filename and old.exists():
        old.unlink()
app.touch()
print(f"Installed app icon: {filename}")
