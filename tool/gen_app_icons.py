#!/usr/bin/env python3
"""Launcher icons and native launch screens, from tool/art/app_icon_master.png.

The master is the shipped app's own icon: `app-icon-source.jpeg` in
../merge-empire-fc, centre-cropped, which is what that repo's generate-icon.py
feeds its own densities from. It is vendored here because the spec repo is not
cloned in a cloud container and this has to stay regenerable without it.

One deliberate divergence from the JS's generator: it writes the full-bleed
master as the Android adaptive FOREGROUND, and Android 8+ crops the outer sixth
of each edge off that layer, so the shield loses its border. Here the shield is
inset into the 66/108 safe zone over a background layer of the master's own
field colour — same artwork, nothing clipped.
"""

import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, "tool", "art", "app_icon_master.png")

# Filename -> pixel size. Every entry in the Runner AppIcon Contents.json.
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

# The JS splash box is 148 CSS px; @2x and @3x follow.
IOS_LAUNCH = {"LaunchImage.png": 148, "LaunchImage@2x.png": 296, "LaunchImage@3x.png": 444}

ANDROID_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icons are 108dp with only the middle 72dp guaranteed visible.
ADAPTIVE_DP = 108
SAFE_DP = 72


def main():
    master = Image.open(MASTER).convert("RGB")
    field = master.getpixel((4, 4))
    field_hex = "#{:02X}{:02X}{:02X}".format(*field)

    # ── iOS ──────────────────────────────────────────────────────────────
    # Flattened to RGB: the App Store rejects a marketing icon with alpha.
    ios = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")
    appicon = os.path.join(ios, "AppIcon.appiconset")
    for name, px in IOS_ICONS.items():
        master.resize((px, px), Image.LANCZOS).save(os.path.join(appicon, name), "PNG")
    print(f"  iOS AppIcon.appiconset ({len(IOS_ICONS)} sizes)")

    launch = os.path.join(ios, "LaunchImage.imageset")
    for name, px in IOS_LAUNCH.items():
        master.resize((px, px), Image.LANCZOS).save(os.path.join(launch, name), "PNG")
    print("  iOS LaunchImage.imageset (148/296/444)")

    # ── Android ──────────────────────────────────────────────────────────
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for density, size in ANDROID_DENSITIES.items():
        out = os.path.join(res, f"mipmap-{density}")
        os.makedirs(out, exist_ok=True)
        icon = master.resize((size, size), Image.LANCZOS)
        icon.save(os.path.join(out, "ic_launcher.png"), "PNG")
        icon.save(os.path.join(out, "ic_launcher_round.png"), "PNG")

        # Foreground layer: the shield at safe-zone scale on a transparent 108dp
        # canvas, so the adaptive mask crops padding rather than artwork.
        canvas_px = round(size * ADAPTIVE_DP / SAFE_DP)
        shield_px = size
        fg = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        off = (canvas_px - shield_px) // 2
        fg.paste(master.resize((shield_px, shield_px), Image.LANCZOS), (off, off))
        fg.save(os.path.join(out, "ic_launcher_foreground.png"), "PNG")

        # Launch screen logo, at the same 148dp box the JS splash uses.
        drawable = os.path.join(res, f"drawable-{density}")
        os.makedirs(drawable, exist_ok=True)
        logo_px = round(148 * size / 48)
        master.resize((logo_px, logo_px), Image.LANCZOS).save(
            os.path.join(drawable, "splash_logo.png"), "PNG"
        )
    print(f"  Android mipmaps + splash_logo ({len(ANDROID_DENSITIES)} densities)")

    anydpi = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w") as f:
            f.write(adaptive)
    print("  Android mipmap-anydpi-v26 (adaptive icon)")

    colors = (
        f'<?xml version="1.0" encoding="utf-8"?>\n'
        f"<resources>\n"
        f'    <color name="ic_launcher_background">{field_hex}</color>\n'
        f'    <color name="splash_background">{field_hex}</color>\n'
        f"</resources>\n"
    )
    with open(os.path.join(res, "values", "colors.xml"), "w") as f:
        f.write(colors)
    print(f"  Android values/colors.xml ({field_hex})")


if __name__ == "__main__":
    main()
