#!/usr/bin/env python3
"""Export transparent widget poses from the already segmented macOS clips."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / "DobiNative/Resources"
CATALOG = ROOT / "Resources/Assets.xcassets"


def contents(path, data):
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main():
    info = {"author": "xcode", "version": 1}
    contents(CATALOG, {"info": info})
    clips = {
        "puppy_walk": 0.6, "adult_walk": 0.6,
        "puppy_sit": 2.8, "adult_bark": 2.0,
        "puppy_eat": 0.7, "adult_eat": 0.7,
    }
    for name, second in clips.items():
        target = CATALOG / f"{name}.imageset"
        contents(target, {"images": [{"filename": f"{name}.png", "idiom": "universal"}], "info": info})
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(second), "-i", str(SOURCE / f"Videos/{name}.mov"),
                        "-frames:v", "1", "-vf", "scale=400:400", "-pix_fmt", "rgba", str(target / f"{name}.png")], check=True)
    target = CATALOG / "poop.imageset"
    contents(target, {"images": [{"filename": "poop.png", "idiom": "universal"}], "info": info})
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(SOURCE / "Images/poop.png"),
                    "-vf", "scale=180:-1", "-frames:v", "1", "-pix_fmt", "rgba", str(target / "poop.png")], check=True)
    icon = CATALOG / "AppIcon.appiconset"
    contents(icon, {"images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": info})
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=0xF7F5EB:s=1024x1024",
                    "-i", str(CATALOG / "puppy_walk.imageset/puppy_walk.png"),
                    "-filter_complex", "[1:v]scale=950:950[pet];[0:v][pet]overlay=(W-w)/2:(H-h)/2,format=rgb24[out]",
                    "-map", "[out]", "-frames:v", "1", str(icon / "AppIcon.png")], check=True)
    icons = ROOT / "Resources/AppIcons"
    icons.mkdir(parents=True, exist_ok=True)
    for points in [20, 29, 40, 60]:
        for scale in [2, 3]:
            pixels = points * scale
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(icon / "AppIcon.png"), "-vf", f"scale={pixels}:{pixels}",
                            "-frames:v", "1", str(icons / f"AppIcon{points}@{scale}x.png")], check=True)
    print(f"Exported 7 alpha images and one opaque app icon: {CATALOG}")


if __name__ == "__main__":
    main()
