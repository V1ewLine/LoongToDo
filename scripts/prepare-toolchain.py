"""Work around duplicate SwiftBridging maps in mixed CLT installs, locally only."""
import json
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parent.parent / ".build" / "toolchain"
root.mkdir(parents=True, exist_ok=True)
compiler = Path(subprocess.check_output(["xcrun", "--find", "swiftc"], text=True).strip())
include = compiler.parent.parent / "include" / "swift"
old, new = include / "module.modulemap", include / "bridging.modulemap"
roots = []
if old.exists() and new.exists() and "module SwiftBridging" in old.read_text() and "module SwiftBridging" in new.read_text():
    empty = root / "empty.modulemap"
    empty.write_text("// Duplicate legacy module map hidden for this build only.\n")
    roots.append({"type": "file", "name": str(old), "external-contents": str(empty)})
(root / "overlay.json").write_text(json.dumps({"version": 0, "roots": roots}))
