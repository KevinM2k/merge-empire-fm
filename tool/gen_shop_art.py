#!/usr/bin/env python3
"""Rendered illustrations for the Shop's tiles — **run this LOCALLY, not in CI.**

    pip install pillow
    python3 tool/gen_shop_art.py --backend pollinations
    python3 tool/gen_shop_art.py --backend openai   # needs OPENAI_API_KEY
    python3 tool/gen_shop_art.py --backend gemini   # needs GEMINI_API_KEY

**Why local.** Every image host is refused at the cloud session's proxy — see the
artwork row in docs/REMAINING.md — so this cannot be run from a Claude Code web
session at all. On a developer's own machine there is no such policy.

**What it is for.** The shop's pictures are `CustomPainter` vector art today
(`coin_pack_art.dart`, `gem_pack_art.dart`) and the reference shops we are
chasing use rendered 3D illustrations. `lib/ui/screens/shop/shop_art.dart` is
already the seam: every picture in the shop goes through `ShopArt`, which draws a
bundled illustration when `shopArtManifest` has one for that product id and the
painter when it does not. This script fills that manifest.

**The prompts are the deliverable, not the plumbing.** Twelve pictures that each
look good on their own and do not look like ONE SET is the failure mode, and it
is the one a hand-rolled loop of curl calls walks straight into. So there is a
single [STYLE] preamble every prompt inherits, the palette in it is lifted from
the painters this art replaces (`_leather`, `gemInk`, the coin gold), and every
subject is described as the same camera on the same shelf. Change the preamble,
regenerate everything — never half a set.

**And it POST-PROCESSES, which is most of the value.** Generators return opaque
squares with a background; the tiles want a transparent picture that fills its
box. So each render is background-knocked-out from its corners, trimmed to its
own alpha, padded back to square and resampled. `--no-cutout` turns the first
step off for a backend that already returns alpha.

Nothing here is wired into the build. It writes PNGs and, with
`--write-manifest`, the two lines that make Flutter use them.
"""

import argparse
import base64
import json
import os
import re
import sys
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "shop")
SHOP_ART_DART = os.path.join(ROOT, "lib", "ui", "screens", "shop", "shop_art.dart")
IAP_ENGINE_DART = os.path.join(ROOT, "lib", "engine", "iap_engine.dart")
PUBSPEC = os.path.join(ROOT, "pubspec.yaml")

# ---------------------------------------------------------------------------
# The style every subject inherits.
#
# The palette is the painters' own, so a rendered coin pack and the drawn one it
# replaces are the same object at two fidelities — which matters more than it
# sounds: the art lands one file at a time, and a shelf that is half rendered and
# half drawn should still read as one shelf.
#
# "No text, no numbers" is not a nicety. Every tile prints its own figure and its
# own price, and a generator that letters "5000" onto the bag gives the player
# two numbers that will disagree the moment the division multiplier applies.
STYLE = (
    "mobile game store icon, 3D rendered, glossy stylised cartoon realism, "
    "soft studio key light from the upper left with a warm rim light, "
    "gentle contact shadow, rich saturated colours, thick rounded forms, "
    "clean silhouette that reads at 44 pixels, centred, "
    "isolated on a plain flat mid-grey background, no scene, no floor line, "
    "no text, no numbers, no letters, no watermark, no logo, no UI frame, "
    "no border, single object"
)

# Product id -> what to draw. Keys are `IapProduct.id`, which is what
# `shopArtManifest` is keyed by and what `ShopArt` asks with.
#
# The nouns come from each product's shipped NAME, and the objects from the
# painter enums beside them — a pouch, a heap, a strongbox, a peak — so the
# rendered set is the drawn set rather than a second interpretation of the
# catalogue.
SUBJECTS = {
    # Coins. The gold is the HUD's own #FFD700; the leather is the painter's
    # _leather #6B4A2F and the strongbox steel its _steel #5A6472.
    "coins_small": (
        "a small brown leather drawstring pouch, #6B4A2F leather with darker "
        "stitching, tipped over with a handful of bright #FFD700 gold coins "
        "spilling from its mouth"
    ),
    "coins_medium": (
        "a heaped pile of bright #FFD700 gold coins, three rows deep, a few "
        "coins face-on at the front and the rest edge-on, no container"
    ),
    "coins_large": (
        "an open steel strongbox with a heavy hinged lid, #5A6472 brushed steel "
        "with gold corner brackets, brimming with bright #FFD700 gold coins"
    ),
    "coins_mega": (
        "a towering mountain peak of bright #FFD700 gold coins, wide at the base "
        "and rising to a point, two coins tumbling off the near slope"
    ),
    # Gems. The stone is the painter's gemInk #7FD4FF with a #2E93C9 deep face.
    "gems_5": (
        "a small brown leather pouch with three large faceted #7FD4FF cyan "
        "diamond gemstones spilling out of it, each cut with a flat top table "
        "and a lit crown"
    ),
    "gems_15": (
        "an open wooden casket with brass corners, #7A5330 wood, filled with "
        "faceted #7FD4FF cyan diamond gemstones showing over the rim"
    ),
    "gems_35": (
        "a large heaped hoard of faceted #7FD4FF cyan diamond gemstones, spread "
        "wide and stacked several deep, no container"
    ),
    # The offers. These are concepts rather than objects, so each is pinned to
    # one prop — a shelf of abstractions is a shelf nothing is recognisable on.
    "starter_pack": (
        "a wrapped gift box with a big glossy ribbon bow, in club green and "
        "gold, its lid lifting slightly with warm light escaping the gap"
    ),
    "vip_pass": (
        "an ornate golden VIP membership card with a raised crown emblem on it, "
        "standing at a slight angle, a soft purple #B77BFF glow behind it"
    ),
    "energy_director": (
        "a glowing blue #64B5F6 lightning bolt striking down into a chunky "
        "battery cell, the battery's charge bars lit bright"
    ),
    "style_vault": (
        "an open wardrobe trunk in deep purple #B98BFF with gold clasps, a "
        "manager's flat cap and a folded scarf resting on top of it"
    ),
}

# ---------------------------------------------------------------------------
# Backends. Each takes a prompt and returns PNG/JPEG bytes.
#
# The MODEL is a flag with a documented default on every one of them, because a
# provider renaming a model should cost a command-line argument rather than a
# patch to this file.

DEFAULT_MODELS = {
    "pollinations": "flux",
    "openai": "gpt-image-1",
    "gemini": "gemini-2.5-flash-image",
}


def _get(url, timeout=180):
    req = urllib.request.Request(url, headers={"User-Agent": "merge-empire-fm/gen_shop_art"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def _post_json(url, payload, headers, timeout=300):
    body = json.dumps(payload).encode()
    hdrs = {"Content-Type": "application/json", **headers}
    req = urllib.request.Request(url, data=body, headers=hdrs, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


def render_pollinations(prompt, model, seed, px):
    """Keyless, and the one to try first — nothing to sign up for."""
    q = urllib.parse.urlencode(
        {"width": px, "height": px, "seed": seed, "model": model, "nologo": "true"}
    )
    url = f"https://image.pollinations.ai/prompt/{urllib.parse.quote(prompt)}?{q}"
    return _get(url)


def render_openai(prompt, model, seed, px):
    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("OPENAI_API_KEY is not set")
    # gpt-image-1 returns base64 and can return real alpha, which is why
    # --no-cutout is worth trying with this backend.
    out = _post_json(
        "https://api.openai.com/v1/images/generations",
        {
            "model": model,
            "prompt": prompt,
            "size": "1024x1024",
            "background": "transparent",
            "n": 1,
        },
        {"Authorization": f"Bearer {key}"},
    )
    return base64.b64decode(out["data"][0]["b64_json"])


def render_gemini(prompt, model, seed, px):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY is not set")
    out = _post_json(
        f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        {"contents": [{"parts": [{"text": prompt}]}]},
        {"x-goog-api-key": key},
    )
    for part in out["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            return base64.b64decode(part["inlineData"]["data"])
    raise RuntimeError(f"no image in response: {json.dumps(out)[:400]}")


BACKENDS = {
    "pollinations": render_pollinations,
    "openai": render_openai,
    "gemini": render_gemini,
}

# ---------------------------------------------------------------------------
# Post-processing.


def knockout(img, tolerance=40):
    """Make the flat background transparent, from the CORNERS inward.

    **A flood fill from the edge, not "delete every pixel near this colour".** A
    gold coin has grey in its shading and a steel strongbox is mostly the
    background's own hue, so a global colour match eats holes out of the
    subject. A fill only reaches what is CONNECTED to the border, which is what
    a background is.

    Done in two C-backed passes rather than a Python loop: a million-pixel flood
    fill written in Python takes longer than the render did. First a mask of
    every pixel close to a corner's colour, then `ImageDraw.floodfill` over that
    mask to keep only the part of it joined to the edge.
    """
    from PIL import Image, ImageChops, ImageDraw

    img = img.convert("RGBA")
    rgb = img.convert("RGB")
    w, h = img.size
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]

    # 255 where the pixel looks like SOME corner, 0 where it does not.
    near = Image.new("L", (w, h), 0)
    for c in corners:
        seed = Image.new("RGB", (w, h), rgb.getpixel(c))
        diff = ImageChops.difference(rgb, seed).convert("L")
        near = ImageChops.lighter(near, diff.point(lambda v: 255 if v <= tolerance else 0))

    # Keep only the part of that joined to the border. 128 marks reached; the
    # threshold is 0 because the mask is already two-valued.
    for c in corners:
        if near.getpixel(c) == 255:
            ImageDraw.floodfill(near, c, 128, thresh=0)

    alpha = near.point(lambda v: 0 if v == 128 else 255)
    # Multiplied into whatever alpha the render already had, so a backend that
    # returns real transparency does not have it overwritten.
    img.putalpha(ImageChops.darker(img.getchannel("A"), alpha))
    return img


def trim_and_square(img, size, pad_frac=0.04):
    """Crop to the artwork, then centre it in a square of [size].

    **This is what makes a shelf look composed rather than assembled.** Two
    renders of the same prompt put the object at different scales in the frame,
    so a shelf of raw outputs has one coin bag filling its tile and the next
    floating in the middle of its own. Trimming to alpha and re-padding gives
    every picture the same margin, whatever the generator framed.
    """
    from PIL import Image

    box = img.getbbox()
    if box:
        img = img.crop(box)
    side = int(max(img.size) * (1 + pad_frac * 2))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    return canvas.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------------------
# The manifest, and the check that keeps it honest.


def product_ids():
    """Every product id in `iap_engine.dart`, in the order it ships.

    Read from the Dart rather than listed again here, so that a product added to
    the catalogue is a LOUD failure of this script rather than a silent gap on
    the shelf. That is the same reason `unreached.sh` reads `lib/` instead of
    keeping its own list.
    """
    src = open(IAP_ENGINE_DART, encoding="utf-8").read()
    return re.findall(r"^\s+id: '([a-z0-9_]+)',", src, re.M)


def write_manifest(ids):
    """Patch `shopArtManifest` and the pubspec's asset list."""
    src = open(SHOP_ART_DART, encoding="utf-8").read()
    rows = "".join(f"  '{i}': 'assets/shop/{i}.png',\n" for i in sorted(ids))
    body = "{\n" + rows + "}" if rows else "{}"
    new = re.sub(
        r"const Map<String, String> shopArtManifest = \{.*?\};",
        f"const Map<String, String> shopArtManifest = {body};",
        src,
        count=1,
        flags=re.S,
    )
    if new == src:
        sys.exit("could not find shopArtManifest in shop_art.dart")
    open(SHOP_ART_DART, "w", encoding="utf-8").write(new)

    # **Only once there is something in the directory.** `flutter pub get`
    # fails outright on an asset directory that does not exist, so adding the
    # line before the first render would break the build rather than prepare it.
    spec = open(PUBSPEC, encoding="utf-8").read()
    if ids and "assets/shop/" not in spec:
        spec = spec.replace("    - assets/ui/\n", "    - assets/ui/\n    - assets/shop/\n", 1)
        open(PUBSPEC, "w", encoding="utf-8").write(spec)
    print("\npatched shop_art.dart and pubspec.yaml — now run `flutter test`")


# ---------------------------------------------------------------------------


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--backend", choices=sorted(BACKENDS), default="pollinations")
    ap.add_argument("--model", help=f"defaults per backend: {DEFAULT_MODELS}")
    ap.add_argument(
        "--size",
        type=int,
        default=384,
        help="output side in px. The biggest on-screen use is the 96pt gem hero, "
        "so 384 covers a 4x screen with headroom (default: 384)",
    )
    ap.add_argument("--render-px", type=int, default=1024, help="what to ask the model for")
    ap.add_argument("--seed", type=int, default=7, help="same seed, same set, on a re-run")
    ap.add_argument("--only", nargs="*", help="regenerate just these product ids")
    ap.add_argument("--no-cutout", action="store_true", help="backend already returns alpha")
    ap.add_argument("--write-manifest", action="store_true", help="patch the Dart and the pubspec")
    ap.add_argument("--list", action="store_true", help="print the prompts and exit")
    args = ap.parse_args()

    # **Every product must have a subject.** A catalogue entry with no prompt
    # would otherwise ship as the one tile on the shelf still wearing its
    # drawing, which is exactly the half-and-half this script exists to avoid.
    missing = [i for i in product_ids() if i not in SUBJECTS]
    if missing:
        sys.exit(
            "these products have no subject in SUBJECTS and would be left "
            f"undrawn: {', '.join(missing)}"
        )

    ids = args.only or list(SUBJECTS)
    unknown = [i for i in ids if i not in SUBJECTS]
    if unknown:
        sys.exit(f"unknown product ids: {', '.join(unknown)}")

    if args.list:
        for i in ids:
            print(f"\n=== {i} ===\n{SUBJECTS[i]}, {STYLE}")
        return

    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        sys.exit("Pillow is needed for the post-processing: pip install pillow")

    os.makedirs(OUT_DIR, exist_ok=True)
    model = args.model or DEFAULT_MODELS[args.backend]
    render = BACKENDS[args.backend]
    from PIL import Image

    done = []
    for n, pid in enumerate(ids, 1):
        prompt = f"{SUBJECTS[pid]}, {STYLE}"
        print(f"[{n}/{len(ids)}] {pid} … ", end="", flush=True)
        try:
            raw = render(prompt, model, args.seed + n, args.render_px)
        except Exception as e:  # noqa: BLE001 — one failure must not lose the rest
            print(f"FAILED: {e}")
            continue
        tmp = os.path.join(OUT_DIR, f".{pid}.raw")
        open(tmp, "wb").write(raw)
        img = Image.open(tmp).convert("RGBA")
        os.remove(tmp)
        if not args.no_cutout:
            img = knockout(img)
        img = trim_and_square(img, args.size)
        out = os.path.join(OUT_DIR, f"{pid}.png")
        img.save(out)
        done.append(pid)
        print(f"{os.path.relpath(out, ROOT)}")

    if not done:
        sys.exit("\nnothing was generated")

    # Only what is actually on disk goes in the manifest — a row naming a file
    # that a failed render never wrote is the exact case `shop_art_test` fails
    # the build over.
    have = [i for i in SUBJECTS if os.path.exists(os.path.join(OUT_DIR, f"{i}.png"))]
    print(f"\n{len(done)} generated, {len(have)} on disk of {len(SUBJECTS)}")
    if args.write_manifest:
        write_manifest(have)
    else:
        print("\nre-run with --write-manifest to wire them up, or paste:\n")
        for i in sorted(have):
            print(f"  '{i}': 'assets/shop/{i}.png',")


if __name__ == "__main__":
    main()
