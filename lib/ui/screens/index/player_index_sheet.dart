/// The Player Index. Ported from `ui/screens/PlayerIndexScreen.js`.
///
/// A collection screen: every definition in the game, twice — once male, once
/// female — shown found or still hidden. Filters narrow it, and tapping a card
/// opens what it is worth and where it can be scouted.
///
/// **One definition is two entries.** The same striker has male and female art
/// and a name pool each, so the index counts 66 and not 33. The key written to
/// the save is `{definitionId}:{m|f}` — `CardInstance.discoveryKey` owns that
/// format, and `game_wiring` is what writes it.
///
/// The JS mounts its cards lazily behind an `IntersectionObserver` so 66 do not
/// build at once. `GridView.builder` is that, and it is one argument rather than
/// an observer, a shell class, a build callback and a disconnect on every
/// re-fill.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/card_theme.dart';
import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/ui/widgets/trait_copy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/player_portrait.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart'
    show PlayerHeroArt;
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart'
    show showBottomSheetPopup;

/// Reading order down the pitch, which is how a squad is listed everywhere else.
const Map<String, int> _positionOrder = {'FWD': 0, 'MID': 1, 'DEF': 2, 'GK': 3};

/// One row of the index: a definition, seen as one gender.
typedef IndexEntry = ({PlayerDef def, bool female});

String _key(IndexEntry e) => '${e.def.id}:${e.female ? 'f' : 'm'}';

/// The variant index whose art each gender resolves to. The index shows ONE
/// portrait per gender rather than one per variant, so it picks the first of
/// each rather than carrying the variant through.
final int _femaleVariant = variants.indexWhere((v) => v.female);
final int _maleVariant = variants.indexWhere((v) => !v.female);

int _variantFor(bool female) {
  final idx = female ? _femaleVariant : _maleVariant;
  return idx < 0 ? 0 : idx;
}

/// Every entry, tier → position → gender. Built once: the catalogue is const.
final List<IndexEntry> allIndexEntries = () {
  final out = <IndexEntry>[
    for (final def in players) ...[
      (def: def, female: false),
      (def: def, female: true),
    ],
  ];
  out.sort((a, b) {
    if (a.def.tier != b.def.tier) return a.def.tier - b.def.tier;
    final byPosition =
        (_positionOrder[a.def.position] ?? 9) -
        (_positionOrder[b.def.position] ?? 9);
    if (byPosition != 0) return byPosition;
    if (a.female == b.female) return 0;
    return a.female ? 1 : -1;
  });
  return List<IndexEntry>.unmodifiable(out);
}();

/// Which divisions can scout a given tier, derived from the odds table so a
/// weighting change moves this on its own.
final Map<int, List<String>> tierScoutDivisions = () {
  final out = <int, List<String>>{};
  for (final entry in divisionScoutOdds.entries) {
    for (final (tier, _) in entry.value) {
      (out[tier] ??= <String>[]).add(entry.key);
    }
  }
  return Map<int, List<String>>.unmodifiable(out);
}();

/// The name a card of this definition and gender would be given.
String indexCardName(IndexEntry entry) => pickDisplayName(
  entry.def.position,
  entry.def.tier - 1,
  female: entry.female,
);

/// What the index knows about the player's collection.
typedef IndexProgress = ({Set<String> discovered, Map<String, int> counts});

final playerIndexProgressProvider = savePick<IndexProgress>((s) {
  final prog = s['progression'];
  final rawDiscovered = prog is Map<String, dynamic>
      ? prog['discoveredPlayers']
      : null;
  final rawCounts = prog is Map<String, dynamic>
      ? prog['playerFoundCounts']
      : null;
  return (
    discovered: {
      for (final k in rawDiscovered is List ? rawDiscovered : const [])
        if (k is String) k,
    },
    counts: {
      for (final e
          in (rawCounts is Map<String, dynamic>
                  ? rawCounts
                  : const <String, dynamic>{})
              .entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    },
  );
});

/// The four dropdowns across the top. `null` is "All".
typedef IndexFilters = ({
  String? position,
  int? tier,
  bool? female,
  bool? found,
});

const IndexFilters _noFilters = (
  position: null,
  tier: null,
  female: null,
  found: null,
);

bool _matches(IndexEntry entry, IndexFilters f, Set<String> discovered) {
  if (f.position != null && entry.def.position != f.position) return false;
  if (f.tier != null && entry.def.tier != f.tier) return false;
  if (f.female != null && entry.female != f.female) return false;
  if (f.found != null && discovered.contains(_key(entry)) != f.found) {
    return false;
  }
  return true;
}

Future<void> showPlayerIndexSheet(BuildContext context) =>
    openShellSheet(context, ShellSheet.playerIndex, const PlayerIndexView());

class PlayerIndexView extends ConsumerStatefulWidget {
  const PlayerIndexView({super.key});

  @override
  ConsumerState<PlayerIndexView> createState() => _PlayerIndexViewState();
}

class _PlayerIndexViewState extends ConsumerState<PlayerIndexView> {
  IndexFilters _filters = _noFilters;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final progress = ref.watch(playerIndexProgressProvider);
    final entries = [
      for (final e in allIndexEntries)
        if (_matches(e, _filters, progress.discovered)) e,
    ];

    return Padding(
      key: const ValueKey('player-index'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **THE SHEET'S OWN HEADING, not a label this screen invented.**
          // Every other sheet in the game titles itself through [SheetHeader]
          // — centred, 15/w900 in the club accent — and this one drew a
          // left-aligned 11-point caption, so opening the index after the
          // table or the quests read as a different kind of thing. Reported
          // from the couch, asking for consistency.
          SheetHeader(title: t('pi.title'), padding: sheetHeaderPadding),
          _FilterBar(
            filters: _filters,
            onChanged: (f) => setState(() => _filters = f),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                t('pi.no_cards_match'),
                key: const ValueKey('player-index-empty'),
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: entries.length,
              // THREE per row, and a 4:5 card. `.pi-grid` climbs to four and
              // five on a wide viewport, but the JS locks it back to three
              // inside a sheet — the sheet's width is capped at ~520px and does
              // not grow with the viewport, so a viewport-keyed breakpoint packs
              // four cramped cards into a box that has room for three roomy
              // ones. A `maxCrossAxisExtent` had the same effect.
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 4 / 5,
              ),
              itemBuilder: (_, i) {
                final entry = entries[i];
                final key = _key(entry);
                return _IndexCard(
                  entry: entry,
                  discovered: progress.discovered.contains(key),
                  count: progress.counts[key] ?? 0,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The four dropdowns, on ONE row that scrolls sideways.
///
/// The JS's `.pi-filter-row` is `display:flex; overflow-x:auto` with no wrap:
/// four controls do not fit a phone's width, and wrapping them cost a second
/// band of chrome above a grid that needs the height. A `Wrap` put two on each
/// line, which is the layout that band was written to avoid.
///
/// The JS builds these from a shared `FilterDropdownBar`; `DropdownButton` is the
/// same control and knows about overlays already.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged});

  final IndexFilters filters;
  final ValueChanged<IndexFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    // Tier labels come from the catalogue where it has one and the definition's
    // own `tierName` where it does not.
    final tiers = <int>{for (final p in players) p.tier}.toList()..sort();

    // FOUR EQUAL COLUMNS, not a scrolling strip. It was horizontally scrollable,
    // which is the same thing as running off the edge as far as the eye is
    // concerned: two of the four filters were off the right of a phone with no
    // affordance saying so, so they were simply not there. Each one takes a
    // quarter of the width and ellipsises its own label instead — a filter you
    // can see and read half of beats one you cannot see at all.
    return Row(
      spacing: 4,
      children: [
        for (final filter in <Widget>[
          _Dropdown<String?>(
            fieldKey: 'position',
            label: t('pi.filter.position'),
            value: filters.position,
            options: [
              (null, t('pi.filter.all')),
              for (final p in _positionOrder.keys) (p, p),
            ],
            onChanged: (v) => onChanged((
              position: v,
              tier: filters.tier,
              female: filters.female,
              found: filters.found,
            )),
          ),
          _Dropdown<int?>(
            fieldKey: 'tier',
            label: t('pi.filter.tier'),
            value: filters.tier,
            options: [
              (null, t('pi.filter.all')),
              for (final tier in tiers) (tier, tierName(tier)),
            ],
            onChanged: (v) => onChanged((
              position: filters.position,
              tier: v,
              female: filters.female,
              found: filters.found,
            )),
          ),
          _Dropdown<bool?>(
            fieldKey: 'gender',
            label: t('pi.filter.gender'),
            value: filters.female,
            options: [
              (null, t('pi.filter.all')),
              (false, '♂ ${t('pi.gender_male')}'),
              (true, '♀ ${t('pi.gender_female')}'),
            ],
            onChanged: (v) => onChanged((
              position: filters.position,
              tier: filters.tier,
              female: v,
              found: filters.found,
            )),
          ),
          _Dropdown<bool?>(
            fieldKey: 'status',
            label: t('pi.filter.status'),
            value: filters.found,
            options: [
              (null, t('pi.filter.all')),
              (true, t('pi.filter.found')),
              (false, t('pi.filter.missing')),
            ],
            onChanged: (v) => onChanged((
              position: filters.position,
              tier: filters.tier,
              female: filters.female,
              found: v,
            )),
          ),
        ])
          Expanded(child: filter),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String fieldKey;
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // An active filter is marked, so a player who has narrowed the list and
    // scrolled away can see why it is short.
    final active = value != null;

    return Container(
      key: ValueKey('pi-filter-$fieldKey'),
      padding: const EdgeInsets.only(left: 8, right: 2),
      decoration: BoxDecoration(
        color: kit.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? kit.accent : kit.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          // Fills its quarter and ellipsises inside it. Without this the button
          // sizes to its widest ITEM, which is what pushed the row past the
          // screen in the first place.
          isExpanded: true,
          iconSize: 16,
          dropdownColor: kit.surface,
          hint: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: kit.textMuted),
          ),
          selectedItemBuilder: (context) => [
            for (final (optionValue, optionLabel) in options)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  optionValue == null ? label : optionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? kit.accentBright : kit.textMuted,
          ),
          items: [
            for (final (optionValue, optionLabel) in options)
              DropdownMenuItem<T>(
                value: optionValue,
                child: Text(
                  optionValue == null ? label : optionLabel,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({
    required this.entry,
    required this.discovered,
    required this.count,
  });

  final IndexEntry entry;
  final bool discovered;
  final int count;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    final theme = tierThemes[entry.def.tier] ?? tierThemes[1]!;
    final accent = cssColor(theme.accent);
    final accentLight = cssColor(theme.accentLight);
    final name = indexCardName(entry);
    // **THE INDEX IS THE PLAYERS PAGE'S CARD, and it has to know which theme it
    // is in.** Every colour on this card was fixed: the tier's DARK body
    // gradient and a 70% black caption in both themes, so a light-mode index
    // was a page of dark tiles under a light sheet — the one screen that had
    // not been told. `tierBodyGradient` has carried a light half all along;
    // [PlayerCard] has read it since the grid was fixed.
    const captionInk = Color(0xFF1A1F26);

    return GestureDetector(
      key: ValueKey('pi-card-${_key(entry)}'),
      // **A BOTTOM SHEET, like the squad's own player detail.** It was an
      // `AlertDialog` — a window over the page with a Close button on it — on
      // the one screen whose whole content is cards, while tapping a card
      // anywhere else in the game raises a sheet from the bottom. Asked for
      // from the couch, along with the observation that the Close button is
      // unnecessary: tapping outside a sheet is how you shut one.
      onTap: () => showBottomSheetPopup<void>(
        context,
        child: _RecipeSheet(entry: entry, discovered: discovered),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: discovered
              ? tierBodyGradient(light ? theme.bgLight : theme.bg)
              : null,
          color: discovered ? null : kit.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: discovered ? accent : kit.border),
          // Tier 7+ glows, but only once found — the glow is the reward.
          boxShadow: entry.def.tier >= 7 && discovered
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.47),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        // **CLIPPED TO THE INSIDE OF THE BORDER**, the same fault the player
        // card's caption scrim had: `Container.clipBehavior` clips to the
        // decoration's OUTER path, so an opaque child paints over the border's
        // own curve at the corners. Invisible while the caption was black on a
        // dark card; a light one shows it.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Column(
            children: [
              Container(
                // Two, not three: the tier stripe is a hint of which family the
                // card belongs to, and at three it was a bar across the top.
                height: 2,
                decoration: BoxDecoration(
                  gradient: discovered
                      ? LinearGradient(colors: [accent, accentLight, accent])
                      : null,
                  color: discovered ? null : kit.border,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // **AN UNFOUND CARD IS A LOCKED SLOT, not a dark portrait.**
                    // A silhouette is still the card: its build, its stance and
                    // its haircut all read at a glance, which gives away the
                    // thing the page exists to make you want. The recipe dialog
                    // one tap behind this had already settled it — it draws `❓`
                    // for exactly this case — and the tile was the half that
                    // never got the decision.
                    if (!discovered)
                      Center(
                        child: Text(
                          '❓',
                          key: const ValueKey('pi-locked'),
                          style: TextStyle(
                            fontSize: 30,
                            color: kit.textMuted,
                          ),
                        ),
                      )
                    else
                      Positioned.fill(
                        // **`cover`, ANCHORED TO THE TOP — the squad card's own
                        // crop.** It was `contain`, which letterboxes the
                        // figure inside the tile and leaves the art floating in
                        // a box it does not fill: reported from the couch, with
                        // the Players tab as the comparison. `PlayerHeroArt`
                        // has always done this and for the documented reason —
                        // these are portrait crops, so the slack has to come
                        // off the BOTTOM or the head goes with it.
                        child: ArtImage(
                          path: playerImagePath(
                            entry.def.position,
                            entry.def.tier,
                            _variantFor(entry.female),
                          ),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          fallback: PlayerPortrait(
                            variantIndex: _variantFor(entry.female),
                            kitColor: accent,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 3,
                      left: 3,
                      child: _Badge(
                        text: entry.female ? '♀' : '♂',
                        color: entry.female
                            ? const Color(0xFFFF80AB)
                            : const Color(0xFF80D8FF),
                      ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      // **The TIER and the gender are all an unfound slot
                      // says**, which is what makes it worth chasing without
                      // being the answer. The POSITION comes off with the
                      // portrait — the caption below already dropped it and the
                      // badge was still printing it beside a silhouette in the
                      // shape of a keeper.
                      child: _Badge(
                        text: discovered
                            ? '${entry.def.position} T${entry.def.tier}'
                            : 'T${entry.def.tier}',
                        color: discovered ? accentLight : kit.textMuted,
                      ),
                    ),
                    // **THE CAPTION FLOATS ON THE ART, over a fade.** It was a
                    // solid band UNDER it, which is a thumbnail with a label
                    // rather than a card — and the Players tab has drawn its own
                    // the other way since `PlayerCard` was written: the picture
                    // IS the card and the words sit on it. Reported from the
                    // couch, with that comparison. The art fills the tile now
                    // and the scrim is a gradient, so the figure runs to the
                    // bottom edge instead of stopping at a rule.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: light
                                ? [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.92),
                                  ]
                                : [
                                    Colors.black.withValues(alpha: 0),
                                    Colors.black.withValues(alpha: 0.85),
                                  ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 12, 5, 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (discovered ? name : '???').toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: discovered
                                      ? (light ? captionInk : Colors.white)
                                      : kit.textMuted,
                                ),
                              ),
                              Text(
                                discovered
                                    ? '${entry.def.position} · T${entry.def.tier}'
                                    : 'T${entry.def.tier}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  // `accentLight` is a PALE tier colour — it is
                                  // the tier read off a black scrim. On a white
                                  // one it is the accent itself that carries.
                                  color: discovered
                                      ? (light ? accent : accentLight)
                                      : kit.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // A count of nothing is not a fact worth a badge; every
                    // unfound card carried a `×0` in the corner.
                    if (discovered)
                      Positioned(
                        bottom: 3,
                        right: 3,
                        child: _Badge(
                          text: '×$count',
                          color: count > 0 ? accentLight : kit.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        height: 1.4,
        color: color,
      ),
    ),
  );
}

/// What a card is worth and where it can be found.
///
/// The stats half is shown only once discovered — knowing a card's rating
/// before you have ever seen one is the spoiler the whole screen avoids — but
/// the scouting half shows either way, because that is how you go and get it.
/// One card's page, raised from the bottom.
///
/// **It was an `AlertDialog` with a Close button.** Tapping a card anywhere
/// else in this game raises a sheet — the squad's own player detail leads with
/// the full-length figure and puts everything else under it — and this is the
/// screen that is nothing BUT cards. Asked for from the couch, including the
/// observation that the button is unnecessary: tapping outside a sheet is how
/// one is shut, and `showBottomSheetPopup` gives it a drag handle too.
class _RecipeSheet extends StatelessWidget {
  const _RecipeSheet({required this.entry, required this.discovered});

  final IndexEntry entry;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final def = entry.def;
    final theme = tierThemes[def.tier] ?? tierThemes[1]!;
    final accentLight = cssColor(theme.accentLight);
    final divisions = tierScoutDivisions[def.tier] ?? const <String>[];

    // The flavour lines are ordered position-major, gender-minor.
    final flavourIndex =
        (_positionOrder[def.position] ?? 0) * 2 + (entry.female ? 1 : 0);
    final flavour = def.flavourTexts.isEmpty
        ? null
        : def.flavourTexts.length > flavourIndex
        ? def.flavourTexts[flavourIndex]
        : def.flavourTexts.first;

    return ListView(
      key: ValueKey('pi-recipe-${_key(entry)}'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // **THE FIGURE, FULL WIDTH AND FULL LENGTH.** `PlayerHeroArt` is the
        // squad sheet's own — 260 points of him, cropped to the top so the head
        // survives — and this used to be an 80×110 thumbnail beside a column of
        // text. An unfound card keeps its `❓`: a silhouette is still the card,
        // and giving it away is what the whole screen exists not to do.
        // **THE NAME LEADS, above the figure.** It sat in a column beside a
        // thumbnail, and when the thumbnail became a 260-point hero the name
        // went under it — which is the one thing the squad's own sheet does
        // not do: there the name is the sheet's title, written across the
        // portrait, because a bar above it would say his name twice. This sheet
        // has no bar, so the name IS the title and goes where a title goes.
        // Asked for from the couch, with the Players tab as the comparison.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            discovered ? indexCardName(entry) : '???',
            key: ValueKey('pi-recipe-name-${_key(entry)}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: discovered ? accentLight : null,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: discovered
              ? PlayerHeroArt(
                  key: ValueKey('pi-hero-${_key(entry)}'),
                  position: def.position,
                  tier: def.tier,
                  variant: _variantFor(entry.female),
                )
              : Container(
                  height: 200,
                  alignment: Alignment.center,
                  color: kit.surface2,
                  child: const Text('❓', style: TextStyle(fontSize: 56)),
                ),
        ),
        const SizedBox(height: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          '${def.position} · ${tierLabel[def.tier] ?? ''}',
                          style: TextStyle(fontSize: 12, color: kit.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.female
                              ? '♀ ${t('pi.gender_female')}'
                              : '♂ ${t('pi.gender_male')}',
                          style: TextStyle(fontSize: 12, color: kit.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          discovered
                              ? '✓ ${t('pi.discovered')}'
                              : '✗ ${t('pi.not_found')}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: discovered
                                ? kit.accentBright
                                : vsRedOn(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (discovered) ...[
                const SizedBox(height: 16),
                _SectionTitle(t('pi.stats_title')),
                Row(
                  children: [
                    _StatCard(
                      value: '${def.rating}',
                      label: t('pi.stat.rating'),
                      colour: accentLight,
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      value: '+${def.idleIncomePerSec}/s',
                      label: t('pi.stat.income'),
                      colour: accentLight,
                    ),
                  ],
                ),
                if (flavour != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"$flavour"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: kit.textMuted,
                    ),
                  ),
                ],
              ],
              if (divisions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle(t('pi.scout_availability')),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final id in divisions)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kit.surface2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kit.border),
                        ),
                        child: Text(
                          tName('division', id),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                // The Icon cannot be merged into, so where it drops is the ONLY
                // way to get one — worth saying rather than leaving to be
                // inferred from an empty merge chain.
                if (def.tier == 9) ...[
                  const SizedBox(height: 8),
                  Text(
                    t('pi.tier9_note'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: kit.textMuted,
                    ),
                  ),
                ],
              ],
            ],
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: kit.textMuted,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.colour,
  });

  final String value;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kit.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kit.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colour,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(fontSize: 12, color: kit.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
