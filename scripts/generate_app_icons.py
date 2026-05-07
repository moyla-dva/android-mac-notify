#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets" / "app-icons"
SOURCE_PNG = ASSET_DIR / "app-icon-source.png"
PREVIEW_PNG = ASSET_DIR / "android-mac-notify-icon.png"
ICONSET_DIR = ASSET_DIR / "AppIcon.iconset"
MAC_RESOURCE_DIR = ROOT / "mac" / "AppBundle" / "Resources"
MAC_ICNS = MAC_RESOURCE_DIR / "AppIcon.icns"
ANDROID_RES_DIR = ROOT / "android" / "app" / "src" / "main" / "res"

ANDROID_DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

MAC_ICONSET_SIZES = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]


def load_source() -> Image.Image:
    if not SOURCE_PNG.exists():
        raise FileNotFoundError(f"Missing source icon: {SOURCE_PNG}")
    return Image.open(SOURCE_PNG).convert("RGBA")


def write_android_icons(source: Image.Image) -> None:
    for folder, size in ANDROID_DENSITIES.items():
        output_dir = ANDROID_RES_DIR / folder
        output_dir.mkdir(parents=True, exist_ok=True)
        resized = source.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(output_dir / "ic_launcher.png")
        resized.save(output_dir / "ic_launcher_round.png")
        for stale in ("ic_launcher.webp", "ic_launcher_round.webp"):
            stale_path = output_dir / stale
            if stale_path.exists():
                stale_path.unlink()


def write_mac_iconset(source: Image.Image) -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)
    for points, scale, filename in MAC_ICONSET_SIZES:
        size = points * scale
        source.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET_DIR / filename)


def write_mac_icns() -> None:
    MAC_RESOURCE_DIR.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(MAC_ICNS)], check=True)


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    source = load_source()
    source.save(PREVIEW_PNG)
    write_android_icons(source)
    write_mac_iconset(source)
    write_mac_icns()
    print(PREVIEW_PNG)
    print(MAC_ICNS)


if __name__ == "__main__":
    main()
