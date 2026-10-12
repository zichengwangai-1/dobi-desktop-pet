#!/usr/bin/env python3
"""Build an isolated native fixture using the same SDK for core and UI sources."""
import argparse
import pathlib
import plistlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("fixture", choices=["Flowers", "IdlePoop", "StageSwitch"])
parser.add_argument("arguments", nargs=argparse.REMAINDER)
args = parser.parse_args()
domains = {"Flowers": "flowers", "IdlePoop": "poop", "StageSwitch": "stage"}
with tempfile.TemporaryDirectory(prefix="dobi-native-verify-") as temporary:
    temp = pathlib.Path(temporary)
    app = temp / "Verify.app"
    contents = app / "Contents"
    binary = contents / "MacOS" / "Verify"
    binary.parent.mkdir(parents=True)
    (contents / "Resources").symlink_to(root / "Resources", target_is_directory=True)
    domain = f"com.dobipet.{domains[args.fixture]}-validation"
    with (contents / "Info.plist").open("wb") as output:
        plistlib.dump({"CFBundleIdentifier": domain, "CFBundleExecutable": "Verify",
                      "CFBundlePackageType": "APPL", "LSUIElement": True}, output)
    common = ["xcrun", "swiftc", "-module-cache-path", "/tmp/dobi-swift-cache"]
    core = sorted((root / "Sources" / "DobiCore").glob("*.swift"))
    subprocess.run(common + ["-parse-as-library", "-emit-object", "-emit-module",
                            "-whole-module-optimization", "-module-name", "DobiCore",
                            "-emit-module-path", str(temp / "DobiCore.swiftmodule"),
                            *map(str, core), "-o", str(temp / "DobiCore.o")], check=True)
    native = [p for p in sorted((root / "Sources" / "DobiPet").glob("*.swift")) if p.name != "main.swift"]
    subprocess.run(common + ["-I", str(temp), *map(str, native),
                            str(root / "Tools" / f"Verify{args.fixture}.swift"),
                            str(temp / "DobiCore.o"), "-o", str(binary)], check=True)
    subprocess.run(["codesign", "--force", "--sign", "-", str(app)], check=True)
    subprocess.run([str(binary), *args.arguments], check=True, timeout=60)
