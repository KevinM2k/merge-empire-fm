# The manager, as Spine assets

**For later.** This is the brief for generating every piece the manager rig
needs, in a form that can be dropped straight into a Spine skeleton — written
now, while the catalogue is in front of us, so that when the Spine decision is
made (see the Spine section of `ANDROID_PLAYTHROUGH2.md`) nobody has to
re-derive what "everything" means.

**Nothing here is a guess.** Every id below is read off the shipping catalogue —
`lib/data/manager_looks.dart` for the axes and `lib/data/manager_art.g.dart` for
what is actually drawn — so a sheet built to this brief is a like-for-like
replacement rather than a new wardrobe.

---

## What the rig is now, which is what the assets have to fit

The art space is **120 × 170 units**, and the figure **faces +x (right)**. Every
generated SVG is authored in that box, and the pivots are fixed — a prettier
figure that moved any of them would put a hat on his ear:

| Joint | Position |
|---|---|
| Skull | circle at (62, 48.5), r 12.5 |
| Skull as the arm sees it | (59, 41.5) — `skullOnScreen`, after the head set-back and lift |
| Shoulder | (56, 62) |
| Elbow | (56, 80) |
| Hips | (58 ± 2, 95) |
| Whole-body pivot | 50% / 92% — his boots |

Limbs are **tapered capsules**, not constant-width tubes: thick at the hip,
narrow at the knee, swelling at the calf and tucking into the ankle. Everything
is **lit from the up-left**, with a highlight down the leading (+x) edge.

The pieces that must be **separately posable bones**:

```
root → hips → torso → neck → head
                        ├── hair-back      (behind the skull)
                        ├── head/face      (skin, eye, mouth)
                        ├── face-under     (paint: on the skin, under the fringe)
                        ├── hair-front     (the fall over the brow)
                        ├── face-over      (hardware: glasses, cigar, whistle)
                        └── hat
       ├── near upper arm → near forearm → near hand
       ├── far  upper arm → far  forearm → far  hand
       ├── near thigh → near shin → near boot
       └── far  thigh → far  shin → far  boot
```

Two rules that are easy to miss and expensive to get wrong:

- **Hair is TWO pieces**, a mass behind the skull and a fall over it, with the
  head drawn between them. Every style needs both (several have an empty back).
- **Face items are one axis to the player and TWO draw layers to the rig.**
  Paint sits on the skin, under the fringe and under the eye; hardware sits in
  front of everything. `facepaint`, `warpaint` and `eyeblack` are paint;
  everything else is hardware.

---

## The prompt

Generate this as **several sheets**, not one — the full catalogue is far too
much for a 4×4 grid, and mixing scales across sheets is what makes a rig
impossible to assemble. Keep the style block and the background/edge block
**identical on every sheet**, and state the shared scale on each.

### Shared preamble — put this at the top of every sheet's prompt

> STYLE: Clean 2D vector art, bold outlines, flat colors, no drop shadows.
> Side-on three-quarter view, character facing RIGHT. Lighting is consistent
> across every piece: light source up and to the LEFT, a highlight down the
> right-hand (leading) edge of every form, a core shadow behind it. Limbs taper
> — thick at the upper joint, narrow at the lower.
>
> SCALE: Every sheet is drawn to the same figure. The complete standing
> character is 170 units tall and 120 wide; the head is a circle 25 units
> across. Draw every piece at the size it would be on that figure — do NOT
> scale pieces to fill their cell.
>
> BACKGROUND: Solid flat chroma key green background, EXACT hex #00FF00 with NO
> gradients, NO noise, NO shadows, NO lighting variation.
>
> EDGES: Add a clean solid white outline/border 2-3 pixels wide around every
> sprite piece. The white border must fully separate the sprite from the green
> background with no gaps. Keep identical scale across all items.
>
> SEPARATION: Every piece is a SEPARATE cutout with its own white border. Pieces
> must not touch, overlap, or share an outline. Leave clear green between them.

### Sheet 1 — the body, 4×4

> Create a 2D game asset sprite sheet arranged in a 4x4 grid of a football
> manager character facing right.
>
> Row 1: bare head/skull with a neutral open eye and no hair; the same skull
> with no eye (a clean base for eye overlays); near-side upper arm; near-side
> forearm.
> Row 2: far-side upper arm; far-side forearm; near-side open hand; far-side
> open hand.
> Row 3: near-side thigh; near-side shin; far-side thigh; far-side shin.
> Row 4: near-side boot; far-side boot; bare neck; a plain scarf worn round the
> neck, hanging down the chest.

### Sheet 2 — builds and outfits, 4×4

Six builds × four outfits is the combinatorial trap; the torso is the only part
a build changes, so ask for **torsos only**.

> Create a 2D game asset sprite sheet arranged in a 4x4 grid of football manager
> character TORSOS (shoulders to hips, no head, no arms, no legs), facing right.
>
> Row 1: four torso builds in a plain football training top — REGULAR (average),
> LEAN (narrow, slight), BROAD (wide shoulders, thick chest), BELLY (round
> stomach, softer chest).
> Row 2: two more builds in the same top — ATHLETIC (V-shaped, defined
> shoulders), CURVY (fuller hips and chest); then the REGULAR build in a zipped
> TRACKSUIT top, and the REGULAR build in a long buttoned COAT.
> Row 3: the REGULAR build in a tailored SUIT jacket with a shirt and tie; then
> the LEAN, BROAD and BELLY builds in the tracksuit top.
> Row 4: the ATHLETIC and CURVY builds in the tracksuit top; then the LEAN and
> BROAD builds in the coat.
>
> (Repeat this sheet's Rows 3-4 pattern until all 6 builds × 4 outfits exist:
> kit, tracksuit, coat, suit.)

### Sheet 3 — hair, BACK pieces, 4×4

> Create a 2D game asset sprite sheet arranged in a 4x4 grid of HAIR MASSES seen
> from behind and to the side — the volume of hair that sits BEHIND the skull,
> with no face and no head. Each is a solid silhouette in ONE flat mid-brown so
> it can be recoloured. Facing right.
>
> Row 1: CROP (barely any, close to the scalp), BUZZ (none — draw an empty cell
> of plain green), SHAVED (none — empty cell), AFRO (large round volume).
> Row 2: PONYTAIL (gathered tail out the back), BUN (round knot at the back of
> the crown), FLOW (long, swept back past the collar), MOHAWK (narrow, none at
> the back).
> Row 3: SPIKES (short, none at the back), MULLET (long at the back, over the
> collar), CURTAINS (medium, level with the jaw), DREADS (thick ropes to the
> shoulders).
> Row 4: SLICK (swept back flat to the skull), FAUXHAWK (short at the back),
> BRAIDS (tight rows running back over the crown), and one spare empty cell.

### Sheet 4 — hair, FRONT pieces, 4×4

> Create a 2D game asset sprite sheet arranged in a 4x4 grid of HAIR FRINGES —
> the part of the hair that falls OVER the brow and the side of the head, drawn
> as if seen on a character facing right, with no face and no head behind it.
> Each is a solid silhouette in ONE flat mid-brown so it can be recoloured.
>
> Row 1: CROP (short, neat, a low fringe), BUZZ (a thin shadow of stubble over
> the whole crown), SHAVED (bare — a faint hairline only), AFRO (round mass
> above the brow).
> Row 2: PONYTAIL (pulled back off the face), BUN (pulled back off the face),
> FLOW (long, swept back off the forehead), MOHAWK (a tall narrow fin along the
> centre).
> Row 3: SPIKES (short upward spikes), MULLET (short and forward at the front),
> CURTAINS (parted in the middle, falling either side of the brow), DREADS
> (ropes forward over the brow).
> Row 4: SLICK (combed back and flat, high shine), FAUXHAWK (a raised centre
> strip, short sides), BRAIDS (tight rows from the hairline back), and one spare
> empty cell.

### Sheet 5 — facial hair, 3×3

Nine pieces; `none` is nothing to draw.

> Create a 2D game asset sprite sheet arranged in a 3x3 grid of FACIAL HAIR
> pieces only — no face, no head — for a character facing right, each drawn to
> sit on a jaw and chin. Flat mid-brown so they can be recoloured.
>
> Row 1: STUBBLE (light shadow over jaw and chin), MOUSTACHE (upper lip only),
> GOATEE (chin and a thin moustache).
> Row 2: BEARD (short, jawline and chin), FULL (thick, jaw to chest), PENCIL (a
> thin line on the upper lip).
> Row 3: HANDLEBAR (moustache with curled waxed ends), MUTTONCHOPS (wide
> sideburns down the jaw, bare chin), BRAIDED (a full beard plaited into one or
> two braids).

### Sheet 6 — hats, 4×5 (17 pieces)

> Create a 2D game asset sprite sheet arranged in a 4x5 grid of HEADWEAR pieces
> only — no head, no face, no hair — each drawn at the angle it would sit on a
> character facing right.
>
> Row 1: HEADBAND (a narrow band round the brow), BASEBALL CAP (peak forward and
> right), BEANIE (knitted, with a bobble), CROWN (gold, five points), FLAT CAP
> (tweed).
> Row 2: BUCKET HAT (soft, all-round brim), SNAPBACK (flat peak, structured
> front), VISOR (a peak and a strap, open crown), SUN HAT (wide floppy brim),
> SANTA HAT (red with white trim and a pom).
> Row 3: TOP HAT (tall, black, silk band), VIKING HELMET (horned), PARTY HAT
> (striped cone with a pom), HARD HAT (yellow, ridged), HEADPHONES (over-ear,
> a band across the crown).
> Row 4: LAUREL WREATH (open at the top — leaves on the stem, growing UP and
> BACK from the brow, not centred on the stem), DIAMOND (a jewel worn on the
> brow), and three spare empty cells.
>
> IMPORTANT: the four BANDS — headband, visor, laurel and headphones — must
> leave the top of the crown OPEN, because hair shows through them. The other
> thirteen cover the crown.

### Sheet 7 — face items, 4×3 (11 pieces)

> Create a 2D game asset sprite sheet arranged in a 4x3 grid of FACE ACCESSORIES
> only — no head, no face behind them — drawn at the angle they would sit on a
> character facing right.
>
> Row 1: SPECTACLES (round wire frames), SHADES (dark rectangular sunglasses),
> AVIATORS (teardrop metal frames).
> Row 2: GOGGLES (sports goggles with a strap), MONOCLE (single lens on a
> chain), CIGAR (in the corner of the mouth, with a lit ember at the tip AND a
> separate small puff of smoke drawn as three round clouds in a second cell).
> Row 3: WHISTLE (on a lanyard, at the lips), NOSE STRIP (a pale adhesive strip
> across the bridge of the nose), EYE BLACK (two black smears under the eye).
> Row 4: WAR PAINT (bold stripes across the cheek and brow), FACE PAINT (a
> two-colour half-and-half design over the whole face), and one spare cell.
>
> The last three — eye black, war paint, face paint — are PAINT ON SKIN and must
> have no hard outer edge of their own; the rest are hardware and keep the white
> border.

### Sheet 8 — mouths and eyes, 3×2

> Create a 2D game asset sprite sheet arranged in a 3x2 grid of MOUTH shapes
> only — no face — for a character facing right, each a small simple dark shape.
>
> Row 1: ELATED (wide open grin), PLEASED (a smile), NEUTRAL (a short flat
> line).
> Row 2: GLUM (a downturned line), CRUSHED (a deep frown, open), and one open
> EYE with a highlight.

---

## What is NOT art, and must not be asked for

- **The 19 hair colours** — `black darkbrown brown auburn blonde ginger grey
  platinum pink blue green purple gold white silver teal tangerine lilac
  crimson`. These are runtime TINTS on one silhouette, which is why Sheets 3-5
  say "one flat mid-brown so it can be recoloured". Nineteen painted variants of
  fifteen hairstyles is 285 pieces of art for a colour multiply.
- **The 8 skin tones** — each is a base and a shade:
  `#f7d9bd/#e0bd98`, `#eebb8c/#cf9f77`, `#e3b183/#c4926a`, `#d99a6c/#bd7f52`,
  `#b87a49/#9a5f34`, `#8d5a2b/#6e421c`, `#6f462a/#53321c`, `#5e3a1f/#452a15`.
  Same argument: one skin silhouette, tinted.
- **The 16 gestures** — `fistpump applaud point checkwatch armsfolded
  handsonhips handsonhead wave blowkiss badgekiss shush salute bow robot
  fingerwag facepalm`. These are ANIMATIONS on the skeleton, not art. They are
  the reason the arms have to be separate bones at all, and in Spine they are
  the thing that gets authored once and reused across every skin — which is the
  whole argument for going there.
- **The 10 balls** — `classic retro winter beach gold disco flame eightball star
  futsal` — belong to the pitch scene rather than to the manager.

---

## The counts, so nothing is quietly dropped

| Axis | Count | Art needed |
|---|---|---|
| Builds | 6 | 6 torsos × 4 outfits = 24 |
| Outfits | 4 | (counted above) |
| Hair styles | 15 | 15 back + 15 front = 30 |
| Hair colours | 19 | none — tint |
| Skin tones | 8 | none — tint |
| Beards | 9 (+ none) | 9 |
| Hats | 17 (+ none) | 17 |
| Face items | 11 (+ none) | 11, split paint/hardware |
| Neck | 1 (+ none) | 1 scarf |
| Mouths | 5 moods | 5 |
| Body | — | head, neck, 2×(upper arm, forearm, hand), 2×(thigh, shin, boot) = 15 |
| Gestures | 16 | none — animation |

**Roughly 112 pieces of art**, plus the skeleton.
