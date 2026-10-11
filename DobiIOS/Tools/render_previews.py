#!/usr/bin/env python3
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
work = Path(tempfile.mkdtemp(prefix="dobi-widget-preview-"))
try:
    contents = work / "Render.app/Contents"
    (contents / "MacOS").mkdir(parents=True)
    resources = contents / "Resources"
    resources.mkdir()
    (contents / "Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": "com.dobipet.widget-preview", "CFBundleExecutable": "Render",
        "CFBundlePackageType": "APPL", "LSUIElement": True,
    }))
    for file in (root / "Resources/Assets.xcassets").glob("*.imageset/*.png"):
        shutil.copy(file, resources / file.name)
    sources = sorted(map(str, (root / "Shared").rglob("*.swift")))
    executable = contents / "MacOS/Render"
    subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", "/tmp/dobi-ios-preview-cache",
                    *sources, str(root / "Tools/RenderWidgets.swift"), "-o", str(executable)], check=True)
    subprocess.run([str(executable), str(root / "Previews")], check=True, timeout=30)
finally:
    shutil.rmtree(work)
