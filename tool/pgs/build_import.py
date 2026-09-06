#!/usr/bin/env python3
"""Builds the Play Console achievements import zip: 81 icons and three CSVs.

    dart run tool/pgs/dump_achievements.dart > build/pgs/achievements.json
    python3 tool/pgs/build_import.py

Output is `build/pgs/merge-empire-achievements.zip`, uploaded by hand at
Play Console -> Grow -> Play Games Services -> Setup and management ->
Achievements -> Import achievements. `build/` is git-ignored: this is a
derived artefact and it goes stale the moment the catalogue moves.

**The zip rather than the Publishing API, and that is not a preference.** The
API can create an achievement (`achievementConfigurations.insert`) but it
cannot give it a picture: `draft.iconUrl` is documented "writes are ignored",
`draft.sortRank` likewise, and the one endpoint that did upload an image --
`imageConfigurations.upload` -- is marked Deprecated in Google's own reference.
The import zip is the only route that carries metadata, icons, ordering and
nine translations in one go. `sync_ids.py` uses the API afterwards for the one
thing it is good at: reading back the ids the import minted.

Format, from Google's reference (see docs/PGS_ACHIEVEMENTS.md for the links):

  AchievementsMetadata.csv      Name, Description, Incremental value,
                                Steps Needed, Initial State, Points, List Order
  AchievementsLocalizations.csv Name, Localized name, Localized description,
                                locale
  AchievementsIconsMappings.csv Name, icon filename

No header rows. Name and Description may not contain commas -- there is no
quoting in this format, a comma is a column break wherever it appears -- so
`sanitise` takes them out and the run prints every string it touched. Icons are
512x512 PNG; Play generates the greyed "revealed" variant itself.

Requires nothing but the standard library and the Chromium that is already on
the box (the Playwright one, or any `chrome`/`chromium` on PATH).
"""

import csv
import hashlib
import html
import json
import os
import re
import struct
import shutil
import subprocess
import sys
import tempfile
import zipfile
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "build", "pgs")
ICONS = os.path.join(OUT, "icons")
SRC = os.path.join(OUT, "achievements.json")
ZIP = os.path.join(OUT, "merge-empire-achievements.zip")

# --- Play's own limits -------------------------------------------------------
# https://developer.android.com/games/pgs/achievements
MAX_NAME = 100
MAX_DESC = 500
MAX_TOTAL_POINTS = 2000
MAX_ACHIEVEMENTS = 400
MAX_ZIP_FILES = 403
MAX_FILE_BYTES = 1024 * 1024

# The app's ten catalogues, as Play names them. English is the game's default
# locale in the Console, and the format forbids naming the default in the
# localizations file -- English travels in AchievementsMetadata.csv instead.
#
# ASSUMPTIONS, both one line to change and both worth confirming against the
# Console's own language list before the import:
#   pt -> pt-BR   the catalogue reads Brazilian ("voce" 29 times) and Brazil is
#                 the larger Play market, but the copy would pass as pt-PT.
#   es -> es-ES   the copy is "tu"-form and region-neutral; es-419 is equally
#                 defensible if the audience is Latin America.
# zh is Simplified (1,440 simplified characters against 0 traditional), so
# zh-CN is not a guess.
PLAY_LOCALES = {
    "es": "es-ES",
    "pt": "pt-BR",
    "fr": "fr-FR",
    "de": "de-DE",
    "it": "it-IT",
    "ja": "ja-JP",
    "ko": "ko-KR",
    "zh": "zh-CN",
    "ar": "ar",
}

# One background per achievement category. Google's advice is that icons be
# colourful, because the locked state a player sees most is a GREY version of
# this one and a flat icon greys into a smudge.
PALETTE = {
    "progression": ("#1b4d3e", "#37a06e"),
    "seasons": ("#123a63", "#3d86c6"),
    "merges": ("#4a1d5c", "#a052c8"),
    "squad": ("#5c3a12", "#d08c2e"),
    "weird": ("#1f2a44", "#5a6fa8"),
    "hardmode": ("#5c1620", "#c8434f"),
    "events": ("#0f4b52", "#2fb3a8"),
    "reset": ("#33323a", "#7d7b8a"),
}

ICON_PX = 512

# Copy written FOR THE CONSOLE, where the mechanical rule below reads badly.
# Keyed by (achievement id, locale, "title"|"description"); the locale is the
# app's own two-letter id, "en" included. Anything in here is used verbatim and
# still has to survive the comma rule, so do not put a comma in one.
#
# Twenty-five strings hit the rule and twenty-three of them survive it: a
# thousands separator becoming a space ("10 000 coins") is the international
# digit grouping and correct in all ten languages, and a dropped vocative comma
# ("Goodbye Legend") reads as a title either way. If the CJK catalogues would
# rather have "10000" than "10 000", this is where that goes.
#
# The two below do NOT survive it, because in those two languages the comma is
# grammar rather than punctuation, so the rule was producing an error a
# translator would be blamed for. Both are rewritten to say the same thing
# without needing one -- they are Console copy only and do not touch what the
# game shows.
CSV_OVERRIDES = {
    # A German relative clause takes a comma; without it "Besiege einen Rivalen
    # der einen Groll hegt" is simply wrong. Said with a prepositional phrase
    # instead: "beat a rival with a grudge".
    ("grudge_revenge", "de", "description"): "Besiege einen Rivalen mit einem Groll.",
    # Korean separates a short list with a middle dot as readily as a comma, and
    # "(1위 무패배)" without either reads as one run-on parenthetical.
    ("win_league_undefeated", "ko", "description"): "무패로 리그 우승 (1위·무패배).",
}


def sanitise(text):
    """Play's CSV has no quoting, so a comma or a newline is a column break.

    `t()` turns a catalogue `<br>` into a real newline, which is right on a card
    and fatal in a CSV row, so both go the same way: to a space. A comma becomes
    a space rather than nothing, because it is a thousands separator in four of
    these ("10,000 coins" -> "10 000 coins", which is the international form and
    reads correctly in all ten languages) as often as it is punctuation
    ("Goodbye, Legend" -> "Goodbye Legend").
    """
    out = re.sub(r"[,\r\n\t]+", " ", text)
    out = re.sub(r"\s{2,}", " ", out).strip()
    return out


def icon_html(glyph, category, key):
    """A 512x512 tile: category gradient, a ring, and the achievement's glyph.

    The ring's angle and the gradient's are derived from the id, so the six
    glyphs the catalogue uses twice or three times ("crown" is on three) still
    produce six distinct pictures -- Google asks for unique icons and a duplicate
    would also be indistinguishable in the player's own list.

    The glyph is kept inside the middle 62%: an achievement icon in an Android
    toast is overlaid with a circle that hides the corners.
    """
    dark, light = PALETTE[category]
    seed = int(hashlib.sha1(key.encode()).hexdigest()[:8], 16)
    angle = seed % 360
    ring = 6 + (seed >> 9) % 10
    return f"""<!doctype html><meta charset="utf-8">
<style>
  html,body {{ margin:0; padding:0; width:{ICON_PX}px; height:{ICON_PX}px; }}
  .tile {{
    width:{ICON_PX}px; height:{ICON_PX}px; box-sizing:border-box;
    display:flex; align-items:center; justify-content:center;
    background:
      radial-gradient(circle at 32% 26%, rgba(255,255,255,.30), transparent 58%),
      linear-gradient({angle}deg, {dark}, {light});
    /* Full-bleed rather than a rounded tile. A rounded tile leaves the four
       corners as whatever the page behind it is -- white, here -- and Play
       draws this icon on its own surfaces in both themes, so those corners
       show up as white notches on a dark one. The ring is inset instead of a
       border for the same reason: it stays inside the circle a toast overlays. */
    box-shadow: inset 0 0 0 {ring}px rgba(255,255,255,.30);
  }}
  .glyph {{
    font-family:"Noto Color Emoji","Apple Color Emoji",sans-serif;
    font-size:264px; line-height:1;
    width:62%; text-align:center;
    filter:drop-shadow(0 10px 18px rgba(0,0,0,.42));
  }}
</style>
<div class="tile"><div class="glyph">{html.escape(glyph)}</div></div>
"""


def find_chromium():
    for path in (
        "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
        shutil.which("chromium"),
        shutil.which("chromium-browser"),
        shutil.which("google-chrome"),
    ):
        if path and os.path.exists(path):
            return path
    for base in ("/opt/pw-browsers",):
        if os.path.isdir(base):
            for entry in sorted(os.listdir(base)):
                cand = os.path.join(base, entry, "chrome-linux", "chrome")
                if os.path.exists(cand):
                    return cand
    sys.exit(
        "no chromium found. Install one, or point this at your own: the icons "
        "are rendered by a headless browser rather than an image library so the "
        "build needs nothing from pip."
    )


def png_size(path):
    """Width and height out of the IHDR, without asking for an image library."""
    with open(path, "rb") as handle:
        head = handle.read(24)
    return struct.unpack(">II", head[16:24])


def read_png(path):
    """(width, height, bytes-per-pixel, unfiltered scanlines) for an 8-bit PNG.

    There is no image library on this box and adding one to build a coloured
    square would be its own kind of silly, so the fifty lines here and in
    `write_png` are the whole dependency list.
    """
    with open(path, "rb") as handle:
        blob = handle.read()
    pos, idat, width, height, kind = 8, b"", None, None, None
    while pos < len(blob):
        length = struct.unpack(">I", blob[pos:pos + 4])[0]
        chunk = blob[pos + 4:pos + 8]
        if chunk == b"IHDR":
            width, height, depth, kind = struct.unpack(">IIBB", blob[pos + 8:pos + 18])
            if depth != 8 or kind not in (2, 6):
                sys.exit(f"{path}: not an 8-bit RGB/RGBA PNG (colour type {kind})")
        elif chunk == b"IDAT":
            idat += blob[pos + 8:pos + 8 + length]
        pos += 12 + length
    step = 4 if kind == 6 else 3
    stride = width * step
    raw = zlib.decompress(idat)
    lines, prev, offset = [], bytearray(stride), 0
    for _ in range(height):
        filt = raw[offset]
        offset += 1
        line = bytearray(raw[offset:offset + stride])
        offset += stride
        for x in range(stride):
            left = line[x - step] if x >= step else 0
            up = prev[x]
            upleft = prev[x - step] if x >= step else 0
            if filt == 1:
                line[x] = (line[x] + left) & 255
            elif filt == 2:
                line[x] = (line[x] + up) & 255
            elif filt == 3:
                line[x] = (line[x] + (left + up) // 2) & 255
            elif filt == 4:
                guess = left + up - upleft
                da, db, dc = abs(guess - left), abs(guess - up), abs(guess - upleft)
                near = left if (da <= db and da <= dc) else (up if db <= dc else upleft)
                line[x] = (line[x] + near) & 255
        lines.append(bytes(line))
        prev = line
    return width, height, step, lines


def write_png(path, width, height, step, lines):
    """Writes an 8-bit PNG back out, every scanline unfiltered."""
    kind = 6 if step == 4 else 2
    raw = b"".join(b"\x00" + line for line in lines)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, kind, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        handle.write(chunk(b"IEND", b""))


def crop_to_tile(path):
    """Cuts the top-left ICON_PX square out of whatever chromium screenshotted.

    **Chromium's headless viewport is smaller than the window it is given, and
    `--screenshot` writes the WINDOW.** A 512x512 window paints about 492x429 of
    itself and pads the rest with white, so asking for the icon's exact size
    produces a correct-looking 512x512 PNG with an unpainted band down two
    edges -- no warning, no error, and it survives straight into the Console.
    Three headless modes were tried and all three do it.

    So the page is rendered in a window comfortably bigger than the tile, where
    the whole tile is inside the real viewport, and the square is cut back out
    here.
    """
    width, height, step, lines = read_png(path)
    if (width, height) == (ICON_PX, ICON_PX):
        return
    if width < ICON_PX or height < ICON_PX:
        sys.exit(f"{path}: chromium wrote {width}x{height}, smaller than the tile")
    cut = [line[: ICON_PX * step] for line in lines[:ICON_PX]]
    write_png(path, ICON_PX, ICON_PX, step, cut)


def bottom_right_pixel(path):
    """The last scanline's last pixel, as (r, g, b) -- the corner the bug ate."""
    _, _, step, lines = read_png(path)
    return tuple(lines[-1][-step:][:3])


def render_icons(rows, chrome):
    os.makedirs(ICONS, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="pgs-icons-")
    for n, row in enumerate(rows, 1):
        page = os.path.join(tmp, f"{row['id']}.html")
        with open(page, "w", encoding="utf-8") as handle:
            handle.write(icon_html(row["glyph"], row["category"], row["id"]))
        png = os.path.join(ICONS, f"{row['id']}.png")
        subprocess.run(
            [
                chrome,
                "--headless",
                "--disable-gpu",
                "--no-sandbox",
                "--hide-scrollbars",
                "--force-device-scale-factor=1",
                f"--screenshot={png}",
                # Bigger than the tile ON PURPOSE -- see `crop_to_tile`.
                f"--window-size={ICON_PX + 160},{ICON_PX + 200}",
                "file://" + page,
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if not os.path.exists(png):
            sys.exit(f"chromium produced no icon for {row['id']}")
        crop_to_tile(png)
        size = png_size(png)
        if size != (ICON_PX, ICON_PX):
            sys.exit(f"{row['id']}: icon is {size[0]}x{size[1]}, not {ICON_PX} square")
        # The corner the viewport bug ate. White there means the tile did not
        # reach the bottom-right of its own square again.
        if bottom_right_pixel(png) == (255, 255, 255):
            sys.exit(
                f"{row['id']}: the icon's bottom-right corner is unpainted white "
                "-- chromium's viewport is smaller than the tile again. Raise "
                "the --window-size margins in render_icons."
            )
        sys.stdout.write(f"\r  icons {n}/{len(rows)}")
        sys.stdout.flush()
    shutil.rmtree(tmp, ignore_errors=True)
    print()


def write_csv(path, rows):
    # `\r\n` is csv's default and Play accepts it; lineterminator is pinned so
    # the file is byte-identical on every machine that builds it.
    with open(path, "w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator="\n").writerows(rows)


def main():
    if not os.path.exists(SRC):
        sys.exit(
            f"{SRC} is missing. Run:\n"
            "  dart run tool/pgs/dump_achievements.dart > build/pgs/achievements.json"
        )
    rows = json.load(open(SRC, encoding="utf-8"))
    os.makedirs(OUT, exist_ok=True)

    touched = []
    names = {}
    problems = []
    meta, local, icons = [], [], []

    def field(row_id, locale, kind, raw):
        """The string as the CSV will carry it, noting anything the rule moved."""
        source = CSV_OVERRIDES.get((row_id, locale, kind), raw)
        clean = sanitise(source)
        if clean != source:
            touched.append((f"{row_id} {locale} {kind}", source, clean))
        return clean

    for row in rows:
        name = field(row["id"], "en", "title", row["title"])
        desc = field(row["id"], "en", "description", row["description"])
        if name in names:
            problems.append(f"duplicate Name {name!r} ({names[name]} and {row['id']})")
        names[name] = row["id"]
        if len(name) > MAX_NAME:
            problems.append(f"{row['id']}: name is {len(name)} chars (max {MAX_NAME})")
        if len(desc) > MAX_DESC:
            problems.append(f"{row['id']}: description is {len(desc)} chars")
        points = row["points"]
        if points is None:
            problems.append(f"{row['id']}: no entry in pgsAchievementPoints")
        elif points % 5 or not 5 <= points <= 200:
            problems.append(f"{row['id']}: {points} points is not 5-200 in fives")

        # Incremental value is False for every one of them, and that is a
        # correctness constraint rather than a simplification: an INCREMENTAL
        # achievement is completed by `increment()` calls and refuses `unlock()`,
        # and `play_games_service.dart` only ever calls unlock. Declaring one
        # incremental here would leave it permanently locked on a player's
        # device. In-game progress bars stay in-game.
        #
        # Initial State is Revealed for all of them: a hidden achievement shows
        # a player a placeholder, and this list is the game's own to-do list --
        # even the event one, whose window is stated in its description.
        meta.append([name, desc, "False", "", "Revealed", points, row["order"]])
        icons.append([name, f"{row['id']}.png"])

        for locale, copy in row["locales"].items():
            if locale == "en":
                continue  # the default locale travels in the metadata file
            play = PLAY_LOCALES.get(locale)
            if play is None:
                problems.append(f"{row['id']}: no Play code for locale {locale}")
                continue
            # Play requires a localized NAME; a row with only a description is
            # not expressible, so such a locale keeps the English name.
            lname = field(row["id"], locale, "title", copy.get("title", row["title"]))
            ldesc = field(row["id"], locale, "description", copy.get("description", ""))
            if len(lname) > MAX_NAME or len(ldesc) > MAX_DESC:
                problems.append(f"{row['id']} {play}: localized copy is too long")
            local.append([name, lname, ldesc, play])

    total = sum(r["points"] for r in rows if r["points"])
    if total > MAX_TOTAL_POINTS:
        problems.append(f"points total {total} is over Play's {MAX_TOTAL_POINTS}")
    if len(rows) > MAX_ACHIEVEMENTS:
        problems.append(f"{len(rows)} achievements is over Play's {MAX_ACHIEVEMENTS}")

    if problems:
        print("REFUSING TO BUILD:")
        for problem in problems:
            print("  -", problem)
        sys.exit(1)

    print(f"rendering {len(rows)} icons at {ICON_PX}x{ICON_PX}")
    render_icons(rows, find_chromium())

    write_csv(os.path.join(OUT, "AchievementsMetadata.csv"), meta)
    write_csv(os.path.join(OUT, "AchievementsLocalizations.csv"), local)
    write_csv(os.path.join(OUT, "AchievementsIconsMappings.csv"), icons)

    members = [
        os.path.join(OUT, "AchievementsMetadata.csv"),
        os.path.join(OUT, "AchievementsLocalizations.csv"),
        os.path.join(OUT, "AchievementsIconsMappings.csv"),
    ] + [os.path.join(ICONS, f"{row['id']}.png") for row in rows]

    oversized = [m for m in members if os.path.getsize(m) > MAX_FILE_BYTES]
    if oversized:
        sys.exit("over Play's 1MB per-file limit: " + ", ".join(oversized))
    if len(members) > MAX_ZIP_FILES:
        sys.exit(f"{len(members)} files is over Play's {MAX_ZIP_FILES}")

    # Flat: the format allows no subdirectories inside the archive.
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as archive:
        for member in members:
            archive.write(member, os.path.basename(member))

    print()
    print(f"  {ZIP}")
    print(f"  {len(rows)} achievements, {len(local)} localized rows, "
          f"{len(members)} files, {os.path.getsize(ZIP) // 1024} KB")
    print(f"  {total} of Play's {MAX_TOTAL_POINTS} points "
          f"({MAX_TOTAL_POINTS - total} left for achievements added later)")
    if touched:
        print()
        print(f"  {len(touched)} strings had a comma or a line break taken out:")
        for what, before, after in touched:
            print(f"    {what}: {before!r} -> {after!r}")


if __name__ == "__main__":
    main()
