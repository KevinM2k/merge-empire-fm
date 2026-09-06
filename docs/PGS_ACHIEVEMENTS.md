# Publishing the achievements to Play Games Services

Eighty-one achievements exist in the game and six of them exist in the Play
Console. This is how the other seventy-five get there, with their icons, their
points and their nine translations, and how their Console ids come back into the
port afterwards.

Nothing here changes what the game does. `play_games_service.dart` already
listens for `achievement:unlocked` and calls `GamesServices.unlock` with the id
in `pgs_achievements.dart`; an achievement with no id is skipped. Filling that
map in is the whole job.

## The short version

```bash
dart run tool/pgs/dump_achievements.dart > build/pgs/achievements.json
python3 tool/pgs/build_import.py
# upload build/pgs/merge-empire-achievements.zip in the Play Console, publish
python3 tool/pgs/sync_ids.py path/to/service-account.json
flutter test test/data/pgs_import_test.dart
```

## Two things the importer will not do, learned the hard way

**It inserts. It never updates.** The first import was refused with *"Duplicate
names — remove or rename"* naming the six achievements that were already in the
Console, and then with a *name mismatch* on their rows in the other two files.
Google's wording is that the import "cannot be used to upload translations for
already existing achievements". So `build_import.py` leaves out anything that
already has an id in `pgs_achievements.dart`, and says which. Editing one that
already exists is a Console job, or `achievementConfigurations.update` — which
can change a name, a description and a point value, just not an icon.

That makes the build self-maintaining: once `sync_ids.py` has written every id
back, a rebuild produces nothing, which is the right answer to "import what is
not in the Console yet". `--all` overrides it for a game with an empty list.

**A locale has to be added to the GAME before an achievement can use it.** The
same import was refused with *"Locale not supported"* against every achievement
that had translations. The fix is not in the CSV: in Play Console, under Play
Games Services → the game → **Game details**, add each language first — "Add
translations for your game before specifying a locale" — and only then will
`AchievementsLocalizations.csv` be accepted for it.

If the languages are not set up yet, build without them and do the translations
as a second import:

```bash
python3 tool/pgs/build_import.py --locales none          # metadata and icons only
python3 tool/pgs/build_import.py --locales fr-FR,de-DE   # or just the ones added
```

## Why a zip and not the API

The Play Games Services Publishing API can create an achievement —
`achievementConfigurations.insert` — and it cannot give it a picture. In
Google's own reference `draft.iconUrl` is **"writes are ignored"**, `sortRank`
likewise, and `imageConfigurations.upload`, the one endpoint that ever uploaded
an image, is marked **Deprecated**. An API-built list would be eighty-one
achievements with no icons, in an arbitrary order, which is worse than none.

The Console's bulk import takes metadata, icons, ordering and every translation
in one upload. So the API is used for the one thing it is good at: reading back
the ids the import minted, which is `sync_ids.py`.

## What the three scripts do

**`tool/pgs/dump_achievements.dart`** reads the catalogue and the ten
catalogues and writes `build/pgs/achievements.json`.

It is Dart because the catalogue is Dart. Three of the eighty-one entries are
quoted with `"` rather than `'` — `Gaffer's Call` and two beside it carry an
apostrophe — and a regex sweep over the file returns seventy-eight rows without
complaining. The three it drops are real achievements that would simply never
have reached the Console.

A locale's copy is exported only when that locale's OWN catalogue has the key.
`t()` falls back to English, so asking it blind fills the French column with
English, and Play then shows that English to French players believing it is a
translation. Sixty of the eighty-one have copy in all ten languages; the other
twenty-one are English-only in the catalogue and are English-only in the Console
too, where Play's own fallback handles them.

**`tool/pgs/build_import.py`** renders the icons and writes the zip.

- **Icons** are 512×512 PNGs, one per achievement: the achievement's own emoji
  on a gradient keyed to its category. Play generates the greyed "revealed"
  variant itself, which is why the backgrounds are colourful — a flat icon greys
  into a smudge. Six glyphs are used more than once in the catalogue (`👑` on
  three), so the gradient angle and ring width are derived from a hash of the id
  and no two icons come out identical.
- **The four `iconAsset` achievements** — three coin ones and the International
  Cup — get `🪙` and `🏆`. In game they currently draw the `🏅` fallback, because
  `Achievement.iconAsset` is read by nothing in `lib/ui`. That is a real bug in
  the port and it is not fixed here; the Console list should not inherit it.
- **Commas are removed** from every name and description. The CSV format has no
  quoting, so a comma is a column break wherever it appears. The rule is one
  line — comma or line break becomes a space — and the run prints all
  twenty-three strings it rewrites, mostly thousands separators
  (`10,000` → `10 000`, the international grouping, correct in all ten
  languages). Two are handled by hand in `CSV_OVERRIDES`, because in German and
  Korean the comma was grammar rather than punctuation.
- **Everything is checked before anything is written**: name uniqueness and
  length, description length, the points budget, the file count and the 1 MB
  per-file cap. A failure names the row.

**`tool/pgs/sync_ids.py`** reads the ids back.

The Console mints a `CgkI…` id per achievement and there is no way to predict
or choose one, so the map can only be filled in by asking. Matching is by
English name — the Console has no idea what a local id is — which is why
`pgs_import_test.dart` enforces that those names are unique. A name edited in
the Console by hand stops matching and the script says which, rather than
guessing.

It needs a service account with the `androidpublisher` scope: the same one
`docs/RELEASE.md` calls `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`. The JWT is signed by
shelling out to `openssl`, so neither script needs anything from pip; the icons
are rendered by the Chromium already on the box.

## Points

Play caps the **whole game** at 2,000 XP points, each achievement 5 to 200 in
multiples of five.

The Console reports **140 of 2,000 already used** by the six published
achievements, and the import cannot change them, so that 140 is a fixed cost
rather than something to allocate. The seventy-five in the zip spend **1,515**,
which lands the game at **1,655 of 2,000** with 345 left for achievements added
later — Google's own advice is to keep some back.

`pgsAchievementPoints` still carries a value for each of the six (165 between
them, against the Console's 140) because the map is one list and those six
numbers are never applied to anything. The Console's own split of that 140 is
not recorded here; if it is worth having exactly, it has to be read off the six
achievement pages by hand.

The values are in `pgsAchievementPoints` in `lib/data/pgs_achievements.dart`,
banded off the in-game coin reward in `achievement_engine.dart`:

| Coin reward | Points | | Coin reward | Points |
|---|---|---|---|---|
| ≤ 100 | 5 | | 1,501–3,000 | 30 |
| 101–300 | 10 | | 3,001–5,000 | 40 |
| 301–750 | 15 | | > 5,000 | 50 |
| 751–1,500 | 20 | | | |

with hand-set values where the coin reward does not describe the difficulty:
prestige pays no coins at all by design, and every Pro-mode and cup achievement
pays the flat 100 default. `pgs_import_test.dart` enforces the cap, so a tuning
change that overspends fails the suite instead of the upload.

## Two decisions worth knowing about

**Every achievement is STANDARD, not INCREMENTAL.** An incremental achievement
in Play is completed by `increment()` calls and refuses `unlock()`, and
`play_games_service.dart` only ever calls `unlock`. Declaring the countable ones
incremental — which the catalogue has the progress data for — would leave them
permanently locked on a player's device. The in-game progress bars stay in-game.

**Every achievement is Revealed, not Hidden.** A hidden achievement shows the
player a placeholder. This list is the game's own to-do list, including the
event one, whose window is stated in its description.

## Before the upload, check these

Two locale codes are assumptions, both one line in `PLAY_LOCALES`:

- `pt` → **pt-BR**. The catalogue reads Brazilian and Brazil is the larger
  market, but the copy would pass as pt-PT.
- `es` → **es-ES**. The copy is region-neutral `tú`-form; es-419 is equally
  defensible.

`zh` → zh-CN is not an assumption: the catalogue is 1,440 simplified characters
and no traditional ones.

Also worth confirming in the Console before importing: that the game's default
locale really is English (the format forbids naming the default locale in
`AchievementsLocalizations.csv`, so English travels in the metadata file), and
that each of the nine languages has been added under **Game details** — see the
locale section above, which is what the first import failed on.

## Sources

- [Achievements — limits, points budget, name and description caps](https://developer.android.com/games/pgs/achievements)
- [Integrate achievements — icon guidelines and the import CSV formats](https://developer.android.com/games/pgs/integrate-achievements)
- [Publishing API reference](https://developer.android.com/games/services/publishing/api)
- [achievementConfigurations resource — which fields are writable](https://developer.android.com/games/services/publishing/api/achievementConfigurations)
- [achievementConfigurations.list — endpoint and scope](https://developer.android.com/games/services/publishing/api/achievementConfigurations/list)
