# Increasing retention and usage

Measured 2026-09-01 from GA4 (property 535292671, data complete through 31 Aug
2026). This describes what the numbers **say**, and what to do about it, in the
order worth doing it. Everything here is re-measurable — see
`~/.claude/.../memory/reference_ga4_access.md` for how to query.

**Read the bot-traffic caveat first.** Roughly half of Android "new users" are
Google Play's pre-launch crawler and emulators, all on `(direct) / (none)` at
~2% D1. Every number below is measured on `google-play / organic` or on a named
referral source. Never read a blended Android figure.

---

## 1. The arithmetic

Usage is two numbers multiplied together:

```
DAU  ≈  installs per day  ×  days an install stays alive
```

Today that is about **7 real installs/day × ~2 days ≈ 12–20 Android DAU**, which
is what the property reports. There is no third lever. Everything below moves one
of those two terms.

The second term is the broken one, and not in the way it looks.

---

## 2. What the data actually shows

### D1 is fine. Depth is not.

Android `google-play / organic` cohorts:

| Cohort | N | D1 | D7 | Week 2 | D30 |
|---|---|---|---|---|---|
| June | 146 | 33.6% | 7.5% | — | 2.1% |
| July | 106 | 20.8% | 5.7% | — | 0.0% |
| 1–16 Aug | 51 | 29.4% | 5.9% | 0–6% | 3.9% (D14) |
| 17–31 Aug | 69 | ~19% | ~1% | 0.0% | — |

Weekly D1 has bounced between 16% and 35% all summer at N≈30. **That is noise,
not a trend** — don't diagnose a release from it. The latest complete week
(24–30 Aug) is 21.1%.

What is genuinely broken is everything after: **week-2 retention is 0–8%, D30 is
0–2%.** Almost nobody survives a fortnight.

### The first session is good

Average first session is ~22 minutes. 74% of new users play a match. This is not
a "the game is bad" problem and it is not a content problem in session one.
**People leave because nothing brings them back on day 2.**

### Half of new players never see the merge

New Android `google-play / organic` users, 14–31 Aug (N=87 first_open):

```
tutorial_started 91% → scout 83% → match_played 74% → tutorial_completed 59% → merge 26%
                                                                    app_remove 46%
```

Of 446 new Android users in August, only 222 ever opened the merge grid at all.
`App.js:74` boots the app on the **League** tab, and `Tutorial.js` STEPS run
welcome → scout_1 → scout_2 → loan_boost → play_match → play_match_action →
match_result_reaction → loan_depart → done. **There is no merge step.** The
onboarding of a merge game never once asks the player to merge two cards.

`logAppEvent('merge')` has fired on every grid merge since Apr 2026 (f1dbd735),
so this is not an instrumentation gap.

### The best cohort ever measured came from Instagram, twice

| Cohort | N | D1 | Week 1 | Week 2 | Tutorial done | Merge rate | Uninstall |
|---|---|---|---|---|---|---|---|
| IG/FB, 14–20 Aug | 100 | **35.6%** | 31.2% | 7.8% | 67% | **44%** | 32% |
| Play organic, same dates | 87 | 24% | 13.8% | 0.0% | 59% | 26% | 46% |

Two organic bursts two months apart (~70 installs in late June, 100 in the week
of 14 Aug, peaking at 45 in a day against a 5–8/day baseline), both the best
traffic the app has ever had, both free. Traffic stopped dead on 21 Aug and has
been zero since.

Self-selected traffic, so the funnel gap is not proof that merging causes
retention. But it is the widest gap in the table.

### The re-engagement engine is unmeasured

**There is not a single notification event in GA4.** Firebase auto-logs
`notification_receive` / `notification_open` only for FCM push, not for
`@capacitor/local-notifications`. So the energy-full, daily-streak, comeback and
Deadline Day alerts — the only mechanism in the app that can recover a lapsed
player — are completely invisible.

The release notes already flag the Deadline Day notification as UNPROVEN, and
`daily_reward_claimed` is 463 events across 217 users — **2.1 per user**, i.e.
streaks die on day two.

### Rewarded video fails a quarter to two-thirds of the time

`ad_failed` fires only on a user-initiated show (`energyEngine.js:247`), so every
one of these is a player who asked for a video and got "No video available right
now". Weekly, Android:

| Week | watched | failed | failure rate |
|---|---|---|---|
| 27 Jul | 203 | 80 | 28% |
| 3 Aug | 92 | 110 | 54% |
| 10 Aug | 173 | 127 | 42% |
| 17 Aug | 100 | 164 | **62%** |
| 24 Aug | 39 | 27 | 41% |

Rewarded video is the energy faucet and energy is playtime. It cannot currently
be split rewarded-vs-interstitial, because `placement` and `type` are not
registered as GA custom dimensions.

---

## 3. What to do, in order

### 3.1 Post to Instagram/Facebook every week — free, today

The only thing that has ever moved installs. No code. Three fixes to how it's
been done:

- **Schedule it.** Both bursts died the moment posting stopped.
- **Use a platform-routing smart link, not the Play URL.** Both bursts delivered
  *zero* iOS users. iOS is at 67 weekly actives and falling; that is free volume
  being discarded.
- **Tag the link** (`?utm_source=instagram&utm_campaign=post_YYYYMMDD`) so a post
  is attributable to a post, not just to a month.

Do not spend money on this again until the destination is a store link — both
paid runs pointed at the web build and returned 0% D1.

### 3.2 Teach the merge — ~~hours~~ **DONE**

~~Add a merge step to `Tutorial.js`, between the two scouts and the first match~~
— shipped, in both repos. The script is ten steps now and `merge` is step four,
between `scout_2` and `loan_boost`.

Three things had to move together and none works alone:

- **The step itself cost no copy.** `tut.merge.title` and `tut.merge.body` have
  shipped in all ten catalogues the whole time — they belong to a step the JS
  had cut. The catalogues are generated from the JS, so a step needing new words
  could not have been added from the Flutter repo at all.
- **The third scout is forced to pair with one of the first two**
  (`tutorialPairTwin`), gender included. The draw is weighted, not fixed, so
  three Sunday League cards pair often and are in no way guaranteed to — and a
  merge step in front of three cards that cannot merge is a dead end. The draw
  is still made and still consumed, so the seeded sequence every later roll
  depends on is untouched; only which definition lands changes.
- **It goes BEFORE the loan**, so the player is down to two of their own when
  the loan is worked out. Nothing there needed changing: `lendTutorialPlayers`
  fills by position SHORTAGE rather than a flat count, so it lends one more and
  the side is still eleven.

The step also steps aside when the board genuinely has no pair — a save resumed
from the older nine-step script, or a grid the pair-forcing could not fix. A step
asking for something the board cannot do is worse than a step that steps aside.

**The cue teaches the GESTURE, not just the screen.** A merge is the one thing
in this game that starts on one card and finishes on another, and the tutorial's
hand only knew how to tap — so the first cut pointed at a card and mimed pressing
it. It now highlights both cards, walks the hand to the first, closes it into a
grab, runs a dotted line across to the second, follows it, and opens again to let
go. Which two cards it points at is asked of the GRID (`tutorialMergePair`)
rather than assumed to be squares 0 and 2, because a twin forced onto the second
card makes the pair 0 and 1 — and the first version rang the wrong two cards and
mimed a drag that was a swap. While the step is up, a drag that is not the merge
does nothing at all: the input seal is one rectangle and has to hold both cards,
so the squares between them are inside it, and a swap there shuffles the board
out from under the cue's own rings.

**The boot tab is NOT changed, and that is a decision rather than an omission.**
The recommendation above was to land new saves on the Merge tab; the owner's call
is that Home is right. The funnel gap this section is about was never "the grid
is hard to reach" — it was that nothing ever asked the player to use it — and
that is the half that has been fixed. Worth re-measuring the merge rate before
spending the boot tab on it.

### 3.3 Instrument the notifications, then fix what that shows — a day

Log an event when each notification is scheduled, and stamp the launch intent so
an open can be logged too. Until that exists, "notifications never arrive" and
"they arrive and nobody taps them" are indistinguishable, and they are completely
different problems with completely different fixes.

This is the one that matters most for week-2 retention, which is the number that
is actually broken. It is worth doing before any new day-2 content, because
without it there is no way to tell whether the content was seen.

### 3.4 Fix the rewarded-video failure rate — minutes, then unknown

Register `placement` and `type` as event-scoped custom dimensions (Admin → Custom
definitions), then re-measure to separate rewarded from interstitial. If rewarded
is a real share of the failures, an energy wall is turning into a dead end
several times a session for the players who are still there.

---

## 4. What to stop doing

**Stop building depth.** Of 443 new Android users in August, 69 ever reached a
division promotion, 83 ever finished a season, 22 opened the Deadline Day screen
and **6 opened the leaderboard**. Boot Room (Training tier 7), Pitch Invaders
(tier 4), the dugout cam and the full-page match view all land on a few dozen
people. Every hour spent past the first session is spent on an audience that
mostly isn't there yet — and 22 items of unverified device-testing debt have
accumulated behind that work.

**Slow the release cadence.** GA Android `newUsers` ≈ real installs + ~4.8 ×
releases uploaded that day. Roughly three releases a day is why half the install
graph is a crawler, and it is why heavy release weeks read as growth.

---

## 5. Still open

- A GA4 data filter for internal/developer traffic (Admin → Data Settings → Data
  filters), so the crawler stops poisoning the property at source. Nothing has
  been changed yet.
- `step_id` and `at_step_id` as custom dimensions, to get a per-step tutorial
  funnel instead of a single completion rate.
- `iap_purchase` reads 230 events from 4 users in August — worth a look; that
  ratio is not a purchase pattern.
