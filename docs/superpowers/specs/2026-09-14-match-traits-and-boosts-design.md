# Match traits and manager boosts

Two features on one branch, at the user's call. They are independent and go in
separate files and separate commits, because the diff is large and a reviewer
has to be able to read one without the other.

- **Match traits** — a second, gem-gated trait slot on a player, rolling from a
  new pool of *conditional* traits that fire only in some matches or some
  minutes.
- **Manager boosts** — four consumables, bought with gems and seeded into the
  daily calendar, spent during a live match.

They share one piece of plumbing (a timed re-simulation) and are otherwise
separate.

---

## Why the balance rule shapes everything

`gem_engine.dart` states the catalogue's own law:

> NEVER RAW RATING. The division bands are tuned against a no-trait maxed squad
> with a shrinking edge per division; anything that adds ★ punches straight
> through the curve.

Both features would break it if built the obvious way. The escape is that
**every match trait is conditional** — it fires away from home, or in a cup, or
in the last fifteen minutes, or never in a given match at all. A trait that is
dark most of the time does not move the baseline squad star the division bands
are tuned against. The boosts are consumables with a window, closer in kind to
`trophy_polish_gem`'s half-hour than to a permanent unlock.

This is not a technicality to route around. It is the reason the pool looks the
way it does, and any new trait added later has to clear the same bar.

---

## The one channel both features use

`computeSquadRatings` takes `ratingMultipliers`, a `Map<String, double>` by
instance id, and applies it as a single scalar on `effectiveRating`
(`squad_rating.dart:277`). `booking_engine.bookedRatingMultipliers` is its only
caller today. `reSimulateRemainder` and `hardLiveRatings` both pass it down.

**A match trait is another contributor to that same map.** One new pure
function —

```dart
Map<String, double> matchTraitMultipliers(state, MatchContext ctx)
```

— merged with the booking map at every call site. Consequences worth stating:

- **`squad_rating.dart` does not change.** Nothing new reaches the sim; an
  existing input carries more.
- **The scalar is not directional.** It moves ATK and DEF together, because the
  split is derived from `effectiveRating`. So no match trait is ATK-only or
  DEF-only, and the pool's identity comes from *when* a trait fires rather than
  which stat it touches. That is the trade taken deliberately in exchange for
  leaving the rating engine alone.
- **Nothing may be stamped on `result`.** `match_orchestration_parity_test`
  compares the result object field-for-field against a node dump and rejects a
  field the JS has never heard of. Live output goes through the existing
  `liveRatingsOut` out-parameter, exactly as the booking work did.

---

## The trigger constraint

A condition only takes effect at a re-simulation. Today those are: a tactic
switch, a substitution, a booking, a sending-off.

The boosts need a **timed** re-sim anyway — Crowd Roar's 25-minute window has to
end somehow — and the minute-gated traits ride along on it for free. That
shared piece is the only real coupling between the two features.

Scoreline-conditional traits would need a re-sim on a goal, a trigger that does
not exist and that sits directly against what the 13 Sep scoreline audit was
written to protect. **Comeback King is therefore round two**, with its own test
group, and is specified here only so the pool's shape is on record.

---

## Part 1 — Match traits

### Save shape

Two new keys on the card, beside the existing `trait`, which does not change and
needs no migration:

- `card.raw['matchSlot'] = true` — the gem has been spent.
- `card.raw['matchTrait'] = {id, level}` — a trait has been rolled into it.

Two keys because unlocking and spinning are two acts: a player can open the slot
and not yet be able to afford the roll.

### Economy

- **Unlock: 1 gem, per player.** A full XI is 11 gems — about five weeks of the
  day-7 daily, or a pack. That is the point: it makes the slot a decision about
  *which* player rather than a box everyone ticks.
- **Roll: coins, through the existing `traitRollCost`** — tier-scaled, the same
  ladder the first slot uses.
- Selling a card with an unlocked slot burns the gem. The existing sell confirm
  gets a warning.

### The pool

Twelve, on the existing `_levelWeights` (I 70%, II 26.2%, III 3.8%). Values are
multipliers on that player's rating contribution while the condition holds — the
same channel and the same units as `yellowCardRatingMult = 0.9`, which the couch
reported as clearly noticeable at ten per cent.

**Rarer condition, bigger number.** That is the ladder, and it is what keeps any
one trait from dominating another. It is the match-trait equivalent of the
distinctness rule already enforced per-pool in `traits_test.dart`, and the same
test file should grow a group for this pool.

| Trait | Fires | ~Freq | I | II | III |
|---|---|---|---|---|---|
| 🏰 Fortress | at home | 50% | +4% | +7% | +11% |
| ✈️ Away Day Hero | away from home | 50% | +4% | +7% | +11% |
| 🎩 Big Game Player | opponent rated above us | ~40% | +5% | +9% | +14% |
| 🚀 Fast Starter | minutes 1–20 | 22% of match | +7% | +13% | +20% |
| 🌧 Mudlark | rain or snow | ~20% | +7% | +13% | +20% |
| ⏱ Last Gasp | minute 76 → the whistle | 17% of match | +8% | +15% | +23% |
| 🏆 Cup Fighter | any cup tie | ~15% | +8% | +15% | +23% |
| 🔄 Super Sub | brought on with ≤20 min left | manager's choice | +12% | +20% | +30% |
| 😈 Derby Devil | a grudge match | ~10% | +10% | +18% | +28% |

Three own an axis outright rather than taking a percentage — the "one owner per
superlative" rule `traits.dart` already states:

| Trait | Effect |
|---|---|
| 🧱 Ten Man Wall | while we are down to ten, **every** man on the pitch gets +3% / +5% / +8%. Squad-wide, so capped at +12% total, the way `maxSquadInjuryReduction` caps its own axis. |
| 🧊 Ice Veins | cancels the yellow-card penalty on him: `0.9` becomes **0.94 / 0.97 / 1.00**. Level III plays exactly the same booked. Owns discipline. |
| 🦿 Warrior | when an in-match injury lands on him, a **25% / 45% / 70%** chance he shrugs it off and plays on. Touches no rating — it hooks `injuryRoll`. Distinct from the existing `tough`, which lowers the *chance*; this survives the outcome. |

👑 **Comeback King** — +ATK while behind — is round two. It needs the
goal-triggered re-sim.

**The ceiling.** A full XI can only be lit by whichever conditions hold in that
match, and most are mutually exclusive: Fortress xor Away Day Hero, cup xor
league. A realistic best case is one band firing at ~+11% across a few players,
comparable to today's `traitXiStarTarget = 5` — but only sometimes. That
intermittency is what buys the feature past the "never raw rating" rule, so a
later trait whose condition is always true would break the whole argument.

### Where the conditions come from

Each maps to something the engine already knows, which is why the pool is the
shape it is:

| Condition | Source |
|---|---|
| home / away | `result['isHome']` |
| cup tie | `result['isCup']` |
| grudge | the existing `grudgeBoost` in `match_orchestration.dart` |
| opponent stronger | `opponentRating` vs `squadRating` |
| weather | `weather_engine` |
| subbed on late | the substitution path, which already re-sims |
| down to ten | the sending-off path, which already re-sims |
| booked | `booking_engine`, which already re-sims |
| minute window | the timed re-sim built for the boosts |

### UI

A second `TraitBlock` under the first in `player_detail_sheet.dart`. That widget
is already a reusable reel — looping delegate, ratchet click, pay-before-it-
spins — so the second slot passes it a different pool and a different cost
rather than duplicating it. Locked state is a padlock and a `💎 1` button.

---

## Part 2 — Manager boosts

### The four

| | Boost | Effect | Lives | Window |
|---|---|---|---|---|
| 📣 | **Crowd Roar** | +10% squad ATK & DEF for 25 in-game minutes | main screen strip | any time |
| 🚌 | **Park the Bus** | goal rate for **both** sides × 0.45 for 25 in-game minutes | main screen strip | any time |
| 📺 | **VAR Review** | the sending-off is overturned and the man comes back on | the bench, only | while the panel is open for that red |
| 🩹 | **Physio Sponge** | the man who just went down is patched up and stays on | the bench, only | while the panel is open for that injury |

**Proactive on the pitch, retrospective on the bench.** The two that change how
the side plays are tapped while watching; the two that undo something the
referee or the physio did are taken at the bench, in front of the consequence,
with the clock stopped. Close the panel and the chance is gone — you cannot
bring that player back once play has restarted.

Roar chases a game; Bus protects one — and Bus is deliberately *not* a rating
change, so it is distinct from the
ultra-defensive tactic already on the tactic strip. A tactic makes you harder to
score against; Bus makes the game a non-event for both sides. It is a damping
factor on the Poisson rate in `reSimulateRemainder`, one new named parameter
beside the `oppRatingMult` already there.

### Placement — and why the bench, not the coach card

A red card and an injury both pause the match into a Coach Colin card and then
open the subs panel behind it (`match_screen.dart:1871`, `:1990`). The card
looks like the obvious place to offer a retrospective boost. It is not:

- **The red-card card shows only ONCE, ever.** It is gated on
  `hasSeenTip(state, redCardTipId)`, while `await openSubs()` runs
  unconditionally. A boost on the card would be invisible at every red card
  after the first.
- **A Coach Colin card has no barrier**, so it is the least reliable surface on
  the screen to hang a control from.
- **The panel already carries the state both boosts need.** `showSubsPanel`
  takes `sentOff`, `sentOffSlots` and `cautioned`, and `_sentOffSlots` exists
  precisely so a man can be drawn back into the square he was taken from. VAR
  is that map read in the other direction.

So the bench is the only door for the retrospective pair, and the coach card
**mentions** it in text without being a button — the door is signposted where
the player is already looking.

**VAR is sendings-off only.** A yellow does not open the panel; only
`cardSendsOff` reaches `_onSendingOff`. Taken deliberately rather than worked
around: it matches what VAR reviews in the real game, it is the more dramatic
moment, and it drops the `_bookingRecords` yellow cleanup entirely.

**The injury guard has to move.** `_onInjuryShown` ends with
`if (spent || nobody) return;` — the panel does not open when the changes are
spent or nobody fit is on the bench. That is exactly when a Physio is worth
most, so bench-only would make the boost unreachable in its best case. The
guard becomes "…unless a Physio is held": a panel with nobody to bring on is
pointless, which is why the guard exists, and with a Physio in hand it is not.

**The deadline is the panel closing, and the lock is per PLAYER per MATCH.**
Injury lands, the bench opens, the boost is offered. Replace him, or dismiss
without using it, and that player cannot be Physio'd again for the rest of the
match — the same for a sending-off and VAR. A different casualty later in the
same match gets its own offer; the man you passed on does not come back.

Two screen-owned sets carry it, beside `_withdrawn` and `_sentOffSlots` which
are already screen-owned for the same reason (the panel forgets, the screen
must not): `_physioSpent` and `_varSpent`, by instance id.

The bench can be reopened from the subs button at any time, so a locked tile
greys **with a reason** — "too late, play has restarted" — rather than going
silently dead. A greyed control with no explanation is what generates "is this
broken?" reports.

### What a retrospective boost actually undoes

Neither boost prevents anything: by the time either is reachable the damage is
already written.

- **Physio.** The sim vacates the injured man's slot before the screen sees the
  event, and `_dropBookingsForInjuriesUpTo` has already struck his remaining
  cards off the referee's list. So Physio is the reverse of `_playerSentOff`:
  put the card back in its slot, clear the injury, restore any card he had
  legitimately collected, re-simulate. Injuries need their own slot map, the
  way sendings-off have `_sentOffSlots`.
- **VAR.** Restore him to the slot `_sentOffSlots` banked, drop the red from
  both lists — `_bookings`, which feeds the ban the whistle writes, and
  `_bookingRecords`, which puts the red on his career card — and re-simulate.

**Both re-simulate from the CURRENT minute, never from the incident minute.**
Overturning a 20th-minute red at 85 minutes would rewrite sixty-five minutes of
a match the player has already watched, which is the thing the 13 Sep audit
exists to prevent. The man returns *now*; goals already scored stand. This is
the contract a substitution already plays by (`_resimulate(_minute, …)`), and
it self-balances the window: a late overturn is simply worth less.

### How an injury is identified

The feed event `type: 'injury'` is the JS's — minute, type and a NAME, with no
instance id, and none can be added because the parity harness compares that
array field for field. The port inserts a `no_sub` marker on the same minute
which **does** carry `instanceId`, and that is the hook.
`_dropBookingsForInjuriesUpTo` already reads it for the same reason.

### Commentary

**Every boost says so in the feed.** A boost that changes the match without
appearing in the commentary is the same fault as the card that "looked like
theatre" — the player reads the feed, so the feed is where it becomes real.

The vehicle is `_notes`, the port's own `List<FeedLine>` that already carries
the tactic changes. It is stable-merged into the feed by minute and a note
lands **after** the events of its own minute, because — in the file's own words
— "the switch answers what just happened". A VAR line under the red card that
prompted it is exactly that rule working. It also keeps this clear of the
`events` array, which the parity harness compares field for field.

Pools, `|`-separated like the rest of the commentary, so a repeat playthrough
does not read the same line twice:

| Key | Fires |
|---|---|
| `boost.var.overturned` | the red is rescinded — "VAR has overturned it. The card is withdrawn and {player} stays on." |
| `boost.physio.recovered` | the injury is undone — "{player} is back on his feet, waving the stretcher away. He's carrying on." |
| `boost.roar.live` | Crowd Roar tapped — "The manager turns to the crowd, and the ground erupts." |
| `boost.roar.over` | its window ends — "The noise settles, and the game finds its rhythm again." |
| `boost.bus.live` | Park the Bus tapped — "Everyone behind the ball. They are going to see this one out." |
| `boost.bus.over` | its window ends — "The shackles come off, and there is space again." |

The two `.over` lines are not decoration: the burning bar shows the window
visually, and the feed is what a player reading rather than watching gets.

### Stacking and signalling

Boosts stack. Windows may overlap. Two Crowd Roars stack the multiplier and take
the later end minute, under a cap so the strip cannot be emptied into one
unbeatable ten minutes.

**A live boost must be unmissable.** The progress bar at the foot of the
scoreboard is already `minute / 90`, clipped into the card's bottom corners
(`match_screen.dart:3850`) — so a window is literally a segment of it. While
anything is live the bar grows from 3px to 6px and each live window draws its
own animated band across its own minute range: flame for Roar, a slow grey wash
for Bus. That gives the player when it started *and* when it ends, in the one
control that already means time. Plus a full-width flash across the pitch at the
moment of the tap.

### Sound

`sound_defs.dart`'s header records a deferral:

> **What is NOT here: the crowd cheers.** The JS carries three
> (`crowdCheerSmall/Mid/Roar`)… its own comment says they are unwired…
> Two hundred lines of DSP for a call nobody makes is the thing the standing
> rules say not to port; when a real cheer is wanted it will be a sample, and
> the tier→size decision belongs with it.

Crowd Roar is the caller that makes it wanted, so the deferral is cashed in —
by porting the spec's own synth rather than by sourcing a sample, because the
synth exists, is documented, and the hard part is already here:

- `audio_render.dart:114` has `Biquad.bandpass`, and its comment says it is the
  constant-0dB-peak-gain form "which is the one Web Audio's `bandpass` uses" —
  the exact variant `_voice` needs.
- Sounds render **once in a background isolate and cache as WAV bytes**
  (`sound_service.dart`), so the cost is warm-up, not per-play.

Porting `_crowd`/`_voice` also brings `crowdCheerSmall` and `crowdCheerMid`,
which is the tier→size ladder the note said belongs with the cheer.

**The one unknown is the room.** `_crowd` uses a convolver over an
exponentially-decaying noise impulse and there is no convolution in
`audio_render.dart`. A naive FIR convolve of 1.05s against a 0.34s tail is
~700M multiply-adds — fine once in an isolate at a second or two, not fine at
ten. **Measure it before committing to it**; the fallback is a multi-tap
decaying delay wash, which for a diffuse crowd is close to indistinguishable.
The JS calls reverb the strongest of its four tier cues, so it cannot simply be
dropped.

Cues: Roar → the ported `crowdCheerRoar`, **without** `overlap`, so a double-tap
cannot stack two roars. Bus → `crowdOoh`, which already exists and is close to a
murmur of discontent. VAR → a low drone while the decision is checked, then a
bright resolve; the drama is the pause. Physio → a short filtered-noise spray
and a small chime.

Sound marks the tap; the burning bar marks the window. A sustained crowd bed
would fight `game.mp3` on the music channel for very little.

### Save shape

`state['matchBoosts'] = {'crowd_roar': 2, 'park_the_bus': 0, ...}`

Deliberately **not** `state['boosts']`, which is already taken by the season
flags — kit sponsor, TV deal, trophy polish.

A boost is debited **on tap, before the animation**, the same rule the trait
reel plays by: an effect that charged and then failed to apply is the worst
possible bug in a paid feature.

### Shop and dailies

- A row of gem tiles in the existing `BoostsSection` (`shop_spend.dart:112`),
  through the existing `ShopGrid`/`ShopTile`. **3-packs at 2 gems** — roughly a
  week of dailies buys one pack, cheap enough to be spent rather than hoarded,
  which is what makes a consumable teach its own value. Four tiles wrap 3 + 1.
- Day 4 of the daily calendar is the ex-Scout-Voucher day the engine's own
  comment calls flat. It gets a Crowd Roar alongside its coins, via a new
  `boost` field on the `DailyReward` typedef — which already carries `freeScout`
  and `healOne` unused, for exactly this kind of addition.

### Layout cost

Only the two proactive boosts sit on the match screen, so the strip is two tiles
rather than four — roughly half the height the earlier four-tile design would
have taken off the commentary feed, on a screen `match_screen.dart` repeatedly
says has none to spare. `_MatchLayout` still needs a `hasBoostStrip` beside its
`hasTacticStrip`, and the strip is shorter than the tactic strip (34px vs 46px).

The bench pair cost the match screen nothing at all: the subs panel is a
`heightFraction: 0.92` bottom sheet with room for a boost row.

---

## Testing

Both features are the port's own, not the JS's. There is no node fixture to
generate and none can be: `../merge-empire-fc` has neither feature, and this
repo's rule is that a deliberate divergence belongs on the screen.

- **Parity must stay green.** Nothing may be stamped on `result`. The existing
  `match_orchestration_parity_test` and `deadline_day_parity_test` are the check
  that this held.
- **A distinctness group in `traits_test.dart`** for the match pool, on the same
  three rules: nothing dominated, a shared shape needs a different lean, one
  owner per superlative.
- **The frequency ladder is an assertion, not a comment.** A trait with a rarer
  condition must carry a bigger number at every level.
- **The trigger matrix**: for each trait, a test that plays a match where the
  condition holds and one where it does not, and reads the multiplier map.
- **Boosts**: debit-on-tap, the window's two re-sims, stacking and the cap, and
  that an abandoned match does not refund.
- **The retrospective pair**, each needing a widget test that plays to a real
  red card and a real injury: that the panel opens with the boost lit, that
  dismissing it greys the tile with a reason, that a restored man is back in his
  own slot and off both booking lists, and that the re-sim ran from the current
  minute rather than the incident's. The injury case must cover the
  subs-spent/nobody-fit path, which is the one the guard used to close.
- **The per-player lock**: a second injury in the same match still offers a
  Physio, and the man who was passed on never does again.
- **The feed lines**, in all ten locales, each landing after the event of its
  own minute rather than before it.
- **Reachability**: `bash tool/unreached.sh` and `bash tool/unreached_ui.sh`
  after, because a trait nobody can roll is exactly the failure those scripts
  exist to find.
- **i18n**: every new key in all ten locales. Twelve traits × name + description,
  plus four boosts and their shop and coach strings — 300+ entries across
  `en_copy.dart` and the nine `copy/<id>_copy.dart` files. `t()` falls back to
  English for a missing translation, which is right for one string and wrong for
  a screen built out of a pool.

## Out of scope

- 👑 Comeback King and any other scoreline-conditional trait — needs the
  goal-triggered re-sim, round two.
- A third trait slot.
- Boosts in the IAP shelf. Gems only for now.
- A sustained crowd bed under the boost window.
