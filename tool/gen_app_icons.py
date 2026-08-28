#!/usr/bin/env python3
"""Launcher icons and native launch screens, from tool/art/app_icon_master.png.

The master is `e08bdf35-5ae9-4a01-bb2f-115b5f44d89b.jpeg`, delivered at 512 and
vendored as-is rather than upscaled — every output but the App Store's 1024
marketing icon is smaller than the master, and that one is better resampled once
here than baked soft into the master.

**The artwork is FULL BLEED, and the old one was not.** The shield it replaces
sat on a flat dark-green field, so the field colour could be sampled from a
corner and used for both the adaptive background and the launch screen, and the
splash logo could be a cut-out with nothing behind it. A scene that runs to all
four edges gives neither:

- The adaptive FOREGROUND still inlays at the 72/108 safe zone, which is the
  region a mask is guaranteed to show — so the scene fills the visible icon and
  the mask crops padding, not artwork. Scaling it to the full 108 instead would
  hand a circle mask the middle two thirds and cut the manager in half.
- The adaptive BACKGROUND is the master's own perimeter average, so a mask that
  shows more than 72dp reveals a band that belongs to the picture. Near-black
  read as a frame around it.
- The launch screen stays #0A1A0F: it is most of the screen, the game it hands
  over to is dark, and `LaunchScreen.storyboard` and `boot_splash.dart` both
  hardcode that same value so the handover has no seam. The logo takes iOS's
  corner radius instead, so a square of scenery on a near-black screen reads as
  an app icon rather than as a stray crop.
"""

import os
from PIL import Image, ImageDraw

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

# iOS's icon corner radius, as a fraction of the side.
CORNER = 0.2237

# The launch screen, matched by LaunchScreen.storyboard and boot_splash.dart.
SPLASH_BG = "#0A1A0F"

# The in-app boot splash draws its logo in a 148dp box; 512 covers a 3x screen.
APP_SPLASH_PX = 512


def rounded(master, px):
    """The master at [px], corners cut to iOS's radius, on transparency."""
    art = master.resize((px, px), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, px - 1, px - 1], radius=round(px * CORNER), fill=255
    )
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(art, (0, 0), mask)
    return out


def circular(master, px):
    """The master at [px], cut to a circle — the pre-API-26 round launcher icon."""
    art = master.resize((px, px), Image.LANCZOS).convert("RGBA")
    mask = Image.new("L", (px, px), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, px - 1, px - 1], fill=255)
    out = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    out.paste(art, (0, 0), mask)
    return out


def perimeter(master):
    """The average of the master's outermost 4px, as a hex colour."""
    px = master.load()
    w, h = master.size
    band = [px[x, y] for x in range(w) for y in (0, 1, 2, 3, h - 4, h - 3, h - 2, h - 1)]
    band += [px[x, y] for y in range(h) for x in (0, 1, 2, 3, w - 4, w - 3, w - 2, w - 1)]
    return "#{:02X}{:02X}{:02X}".format(
        *(sum(c[i] for c in band) // len(band) for i in range(3))
    )


def main():
    master = Image.open(MASTER).convert("RGB")
    edge_hex = perimeter(master)

    # ── iOS ──────────────────────────────────────────────────────────────
    # Flattened to RGB: the App Store rejects a marketing icon with alpha.
    ios = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")
    appicon = os.path.join(ios, "AppIcon.appiconset")
    for name, px in IOS_ICONS.items():
        master.resize((px, px), Image.LANCZOS).save(os.path.join(appicon, name), "PNG")
    print(f"  iOS AppIcon.appiconset ({len(IOS_ICONS)} sizes)")

    launch = os.path.join(ios, "LaunchImage.imageset")
    for name, px in IOS_LAUNCH.items():
        rounded(master, px).save(os.path.join(launch, name), "PNG")
    print("  iOS LaunchImage.imageset (148/296/444)")

    # ── Android ──────────────────────────────────────────────────────────
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for density, size in ANDROID_DENSITIES.items():
        out = os.path.join(res, f"mipmap-{density}")
        os.makedirs(out, exist_ok=True)
        master.resize((size, size), Image.LANCZOS).save(
            os.path.join(out, "ic_launcher.png"), "PNG"
        )
        circular(master, size).save(os.path.join(out, "ic_launcher_round.png"), "PNG")

        # Foreground layer: the scene at safe-zone scale on a transparent 108dp
        # canvas, so the adaptive mask crops padding rather than artwork.
        canvas_px = round(size * ADAPTIVE_DP / SAFE_DP)
        fg = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
        off = (canvas_px - size) // 2
        fg.paste(master.resize((size, size), Image.LANCZOS), (off, off))
        fg.save(os.path.join(out, "ic_launcher_foreground.png"), "PNG")

        # Launch screen logo, at the same 148dp box the JS splash uses.
        drawable = os.path.join(res, f"drawable-{density}")
        os.makedirs(drawable, exist_ok=True)
        rounded(master, round(148 * size / 48)).save(
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
        f'    <color name="ic_launcher_background">{edge_hex}</color>\n'
        f'    <color name="splash_background">{SPLASH_BG}</color>\n'
        f"</resources>\n"
    )
    with open(os.path.join(res, "values", "colors.xml"), "w") as f:
        f.write(colors)
    print(f"  Android values/colors.xml ({edge_hex} / {SPLASH_BG})")

    # ── Flutter ──────────────────────────────────────────────────────────
    # The first frame after the native window: same logo, so the handover from
    # LaunchImage to boot_splash.dart is the picture staying put.
    rounded(master, APP_SPLASH_PX).save(
        os.path.join(ROOT, "assets", "ui", "splash_logo.png"), "PNG"
    )
    print(f"  assets/ui/splash_logo.png ({APP_SPLASH_PX}px)")


if __name__ == "__main__":
    main()
