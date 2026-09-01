/// The table and the fixture list, as quick-nav sheets.
///
/// These were sub-tabs across the top of the home screen, which is the
/// arrangement the JS moved away from: they are DESTINATIONS — places you go to
/// check something and then leave — rather than places you live, so they belong
/// behind the burger with the index, the quests and the trophies.
///
/// The Play button does NOT come with them. It used to sit under the fixture
/// list, which put the one control the whole screen exists for two taps deep;
/// it lives in the home screen's sticky footer now.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show
        semanticInk,
        semanticPlate,
        vsAmberBright,
        vsGreenBright,
        vsRedBright,
        vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/engine/league_table.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/sub_tab_coach_line.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Future<void> showLeagueTableSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.85,
      child: const LeagueTableView(),
    );

Future<void> showFixturesSheet(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.85,
      child: const FixturesView(),
    );

/// The division as it stands. Ported from `_standingsHtml` in
/// `ui/screens/LeagueScreen.js`.
///
/// **Points is the hero** — a big gold figure — and P/W/D/L is a quiet
/// micro-line under it. The port had four equal columns of 12px grey, which made
/// the one number that decides the season the same weight as the games played.
///
/// **Promotion and relegation are BANDS with a hairline label**, not a colour on
/// a row: a tint on its own says "this row is special" without saying which kind
/// of special, and the label is what names it.
///
/// **Your own row is marked WITHOUT a hue** — a neutral lift, so it can never be
/// confused with the green promotion or red relegation band it might be sitting
/// in. Identity comes from the division-coloured left bar and the heavier name.
/// The port tinted your row with the accent, which in a green-accented division
/// made mid-table look exactly like a promotion place.
class LeagueTableView extends ConsumerWidget {
  const LeagueTableView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _PyramidPager(start: currentDivisionIndex(ref.watch(gameProvider).state));
}

/// **The table is the whole PYRAMID, not just your division.**
///
/// `buildPyramidTable` plays every AI fixture in any division through the same
/// sampler the player's own league pre-simulates with, seeded off (season,
/// division) so a league renders identically every time it is drawn — and it
/// had no caller in `lib/`. `table.swipe_to_cycle` and `table.back_to_league`
/// sat translated in ten languages with nothing able to print either. Engine,
/// copy and control were all built; only the join was missing.
///
/// **Your own division is NOT drawn by that function**, and that is deliberate
/// rather than an oversight to tidy up. `buildLeagueTable` writes movement back
/// into the save — `prevPos` and `posDelta`, which the next-match card reads —
/// and it takes your real results rather than sampling them. Swiping to a
/// neighbour must not stamp a "position last round" for a league you were only
/// looking at, so the pager asks the provider for your league and the engine
/// for everyone else's.
/// The division's name in the player's own language.
///
/// `Division.name` is the English literal on the data record and
/// `division.<id>` has shipped translated in all ten catalogues since the
/// generator first ran. See `divisionNameProvider`.
String _divisionName(Division d) =>
    tName('division', {'id': d.id, 'name': d.name});

class _PyramidPager extends ConsumerStatefulWidget {
  const _PyramidPager({required this.start});

  /// The player's own rung, which is where the pager opens.
  final int start;

  @override
  ConsumerState<_PyramidPager> createState() => _PyramidPagerState();
}

class _PyramidPagerState extends ConsumerState<_PyramidPager> {
  late final PageController _controller = PageController(
    initialPage: widget.start,
  );
  late int _page = widget.start;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToOwn() => _controller.animateToPage(
    widget.start,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final home = _page == widget.start;
    return Column(
      key: const ValueKey('league-table'),
      children: [
        SheetHeader(
          title: _divisionName(divisions[_page]),
          // The shared gap — see [sheetHeaderPadding]. This was 8 over the
          // title and 2 under it, which put the division name hard against
          // the drag handle.
          padding: sheetHeaderPadding,
        ),
        // The hint sits under the heading and says the same thing the dots do,
        // in words, because a row of dots is only a hint once you have already
        // guessed it is a pager.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            t('table.swipe_to_cycle'),
            key: const ValueKey('league-swipe-hint'),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: kit.textMuted,
            ),
          ),
        ),
        _RungDots(count: divisions.length, active: _page, home: widget.start),
        // **Only over your OWN division**, and in the bottom-left corner every
        // other screen puts him in — see [withSubTabCoach]. As a row in this
        // column it had to reserve its own height or the sheet grew and shrank
        // under a finger mid-swipe; an overlay cannot.
        Expanded(
          child: withSubTabCoach(
            which: CoachLineFor.table,
            enabled: home,
            child: PageView.builder(
            controller: _controller,
            itemCount: divisions.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => _DivisionTable(divisionIndex: i),
            ),
          ),
        ),
        // **Only when you have swiped away.** On your own rung it would be a
        // button that does nothing, and the pager opens there.
        if (!home)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('league-back-to-own'),
                onPressed: _backToOwn,
                child: Text(
                  t(
                    'table.back_to_league',
                  ).replaceAll(
                    '{division}',
                    _divisionName(divisions[widget.start]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Which rung you are on, and which one is yours.
class _RungDots extends StatelessWidget {
  const _RungDots({
    required this.count,
    required this.active,
    required this.home,
  });

  final int count;
  final int active;
  final int home;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Container(
                width: i == active ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  // Your own rung keeps a mark of its own even when you are
                  // looking at another, so "where am I" survives the swipe.
                  color: i == active
                      ? kit.accentBright
                      : i == home
                      ? kit.accent.withValues(alpha: 0.55)
                      : kit.textMuted.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One division's table.
///
/// **The port had four equal columns of 12px grey**, which made the one number
/// that decides the season the same weight as the games played. Points is the
/// hero — a big gold figure — and P/W/D/L is a quiet micro-line under it.
///
/// **Promotion and relegation are BANDS with a hairline label**, not a colour on
/// a row: a tint on its own says "this row is special" without saying which kind
/// of special, and the label is what names it.
///
/// **Your own row is marked WITHOUT a hue** — a neutral lift, so it can never be
/// confused with the green promotion or red relegation band it might be sitting
/// in. Identity comes from the division-coloured left bar and the heavier name.
/// The port tinted your row with the accent, which in a green-accented division
/// made mid-table look exactly like a promotion place.
class _DivisionTable extends ConsumerWidget {
  const _DivisionTable({required this.divisionIndex});

  final int divisionIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final division = divisions[divisionIndex];
    final divisionId = division.id;
    final own = divisionId == ref.watch(currentDivisionProvider);

    // Your league from the provider — it stamps movement back into the save and
    // reads your real results. Everyone else's is sampled, and nothing is
    // stored.
    final rows = own
        ? ref.watch(leagueTableProvider)
        : buildPyramidTable(ref.watch(gameProvider).state!, divisionId);
    final form = own ? ref.watch(leagueFormProvider) : const <String, List<String>>{};
    final lastSeason = ref.watch(lastSeasonStatusProvider);

    final isTop = divisionId == 'champions_cup';
    final isBottom = divisionId == 'sunday_league';
    final relegStart = rows.length - 2;

    return ListView(
      key: ValueKey('league-table-$divisionId'),
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (!isTop && i == 0)
            _ZoneLabel(
              // The shared zone strings carry a ↑/↓; the band already reads as
              // promotion from its colour and position, so the glyph comes off.
              text: _stripArrows(t('play.zone_promo')),
              colour: kit.accentBright,
            ),
          if (!isBottom && relegStart >= 2 && i == relegStart)
            _ZoneLabel(
              text: _stripArrows(t('play.zone_relegation')),
              colour: dangerInk,
            ),
          _TableRow(
            position: i + 1,
            row: rows[i],
            zone: leagueZoneFor(i + 1, rows.length, divisionId),
            divisionColour: cssColor(division.color),
            // A sampled table carries its own form on the row; yours is keyed
            // by club name out of the real fixture results.
            form: own ? (form[rows[i].name] ?? const []) : rows[i].form,
            lastSeason: lastSeason[divisionId]?[rows[i].name],
          ),
        ],
        // **Only when a marker is actually on the table.** Season one has no
        // last season, and a key to symbols nobody can see is furniture.
        if ((lastSeason[divisionId] ?? const {}).isNotEmpty)
          const _LastSeasonLegend(),
      ],
    );
  }
}

String _stripArrows(String s) => s.replaceAll(RegExp(r'^[↑↓\s]+'), '').trim();

/// A hairline with a word on it, marking where a zone begins.
class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.text, required this.colour});

  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 9, 8, 5),
    child: Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: colour,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: colour.withValues(alpha: 0.3)),
        ),
      ],
    ),
  );
}

/// What a club did last season, as one glyph.
///
/// **A glyph rather than a word, and the arrows are already the game's.**
/// `play.zone_promo` and `play.zone_relegation` carry ↑ and ↓ — the strings the
/// bands above strip them OFF, because there the colour and the position
/// already say which way. On a row they are the whole message. The trophy is
/// the same one `play.champion_spot` uses.
///
/// The long string is the tooltip and the short one is the legend, which is
/// what the catalogue ships: `table.was_promoted` is a sentence, `table.
/// legend_promoted` is a word.
({String glyph, Color colour, String legendKey, String longKey})? _marker(
  String? status,
  KitTheme kit,
  // **The drop's red is theme-aware and was not.** `#F87171` is the DARK
  // value, printed unchanged on a light page — the same bug this queue
  // reported on four screens at once, always with dark mode right.
  BuildContext context,
) => switch (status) {
  'champion' => (
    glyph: '🏆',
    colour: const Color(0xFFFFD700),
    legendKey: 'table.legend_champion',
    longKey: 'table.was_champion',
  ),
  'promoted' => (
    glyph: '↑',
    colour: kit.accentBright,
    legendKey: 'table.legend_promoted',
    longKey: 'table.was_promoted',
  ),
  'relegated' => (
    glyph: '↓',
    colour: vsRedOn(context),
    legendKey: 'table.legend_relegated',
    longKey: 'table.was_relegated',
  ),
  _ => null,
};

/// The key to the glyphs, under the table.
class _LastSeasonLegend extends StatelessWidget {
  const _LastSeasonLegend();

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      key: const ValueKey('league-last-season-legend'),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            t('table.last_season').toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kit.textMuted,
            ),
          ),
          for (final status in ['champion', 'promoted', 'relegated'])
            if (_marker(status, kit, context) case final m?)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.glyph,
                    style: TextStyle(fontSize: 11, color: m.colour),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    t(m.legendKey),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kit.textMuted,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.position,
    required this.row,
    required this.zone,
    required this.divisionColour,
    required this.form,
    this.lastSeason,
  });

  final int position;
  final LeagueRow row;
  final LeagueZone zone;
  final Color divisionColour;
  final List<String> form;

  /// `champion`, `promoted`, `relegated`, or null for a club that stayed put.
  final String? lastSeason;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = Theme.of(context).colorScheme.onSurface;

    final zoneWash = switch (zone) {
      LeagueZone.promotion ||
      LeagueZone.champion => kit.accent.withValues(alpha: 0.08),
      LeagueZone.relegation => dangerInk.withValues(alpha: 0.08),
      LeagueZone.midtable => null,
    };
    final posColour = switch (zone) {
      LeagueZone.champion => const Color(0xFFFFD700),
      LeagueZone.promotion => kit.accentBright,
      LeagueZone.relegation => vsRedOn(context),
      LeagueZone.midtable => kit.textMuted,
    };

    return Container(
      key: ValueKey('league-row-$position'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: zoneWash,
        borderRadius: BorderRadius.circular(12),
        // A neutral lift, layered OVER the zone wash rather than replacing it —
        // so "this is me" and "I am in the drop zone" are both readable at once.
        gradient: row.isPlayer
            ? LinearGradient(
                colors: [
                  ink.withValues(alpha: 0.11),
                  ink.withValues(alpha: 0.11),
                ],
              )
            : null,
        border: row.isPlayer
            ? Border(left: BorderSide(color: divisionColour, width: 3))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$position',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: posColour,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: row.isPlayer
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: row.isPlayer ? kit.accentBright : ink,
                        ),
                      ),
                    ),
                    // AFTER the name and inside the same Row, so a long club
                    // name ellipsises around the marker rather than pushing it
                    // off the row.
                    if (_marker(lastSeason, kit, context) case final m?) ...[
                      const SizedBox(width: 5),
                      Tooltip(
                        message: t(m.longKey),
                        child: Text(
                          m.glyph,
                          key: ValueKey('league-last-season-$position'),
                          style: TextStyle(fontSize: 11, color: m.colour),
                        ),
                      ),
                    ],
                  ],
                ),
                if (form.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      for (final r in form)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: _FormDot(result: r),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${row.pts}',
                style: TextStyle(
                  fontSize: 21,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  // Pure `#FFD700` on a white table is a figure nobody can
                  // read, and the points are the column the table is FOR.
                  color: semanticInk(context, const Color(0xFFFFD700)),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kit.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  // **The letters are TRANSLATED and this printed English.**
                  // `table.col_played`, `col_won`, `col_drawn` and `col_lost`
                  // sit in all ten catalogues — German is S/S/U/N, French
                  // M/V/N/D — and a German player was reading `7W 3D 2L`. The
                  // port dropped the JS's four-column header for this
                  // micro-line deliberately, which is why nothing referenced
                  // the keys; the letters came with the header.
                  children: [
                    TextSpan(text: '${t('table.col_played')}${row.played} · '),
                    TextSpan(
                      text: '${row.won}${t('table.col_won')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: ink.withValues(alpha: 0.82),
                      ),
                    ),
                    TextSpan(
                      text: ' ${row.drawn}${t('table.col_drawn')}'
                          ' ${row.lost}${t('table.col_lost')}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One result in the last five, on a DARK PLATE in both themes.
///
/// **Reported as "the red and green on the home page are too dark".** They were:
/// a tinted fill behind a light-mode ink that has to be near-black to be legible
/// on white, so a win chip in daylight was a grey box with a dark green letter
/// in it. The plate is what lets the DARK-MODE colours be used in both themes —
/// see [semanticPlate] — which is what the report was asking for.
class _FormDot extends StatelessWidget {
  const _FormDot({required this.result, super.key});

  final String result;

  @override
  Widget build(BuildContext context) {
    final colour = semanticInk(
      context,
      switch (result) {
        'W' => vsGreenBright,
        'D' => vsAmberBright,
        _ => vsRedBright,
      },
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 2),
      decoration: BoxDecoration(
        color: semanticPlate(context, colour),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colour.withValues(alpha: 0.45)),
      ),
      child: Text(
        result,
        style: TextStyle(
          fontSize: 8.5,
          height: 1,
          fontWeight: FontWeight.w900,
          color: colour,
        ),
      ),
    );
  }
}

/// The manager's own season.
///
/// **It was showing the wrong list.** The panel rendered `seasonFixtures` — the
/// whole division's grid — as neutral "Ayton v Beeches" rows with a round
/// number, which is a table that exists to feed the standings' form dots and is
/// not what a manager opens Fixtures for. Every fixture here involves US, so a
/// row names only the OPPONENT.
///
/// The venue chip leads every row and is always the same width in the same
/// place, so it can be scanned straight down: it answers "am I at home" for the
/// whole season at a glance. The score sits in a fixed right column coloured by
/// the OUTCOME rather than by whether it has been played, because "2 - 1" tells
/// you nothing until you know which way round it went.
class FixturesView extends ConsumerWidget {
  const FixturesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final fixtures = ref.watch(ourFixturesProvider);
    // **The ties, keyed by the league match they FOLLOW.** A cup does not take
    // a fixture slot — it runs between league games — so the tie is interleaved
    // rather than replacing a row, which is `cupInsertAt` in the JS.
    final ties = <int, CupTie>{
      for (final tie in ref.watch(ourCupTiesProvider)) tie.afterMatch: tie,
    };

    if (fixtures.isEmpty) {
      return Padding(
        key: const ValueKey('league-fixtures-empty'),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            t('common.loading'),
            style: TextStyle(color: kit.textMuted),
          ),
        ),
      );
    }

    // Three headings, in the order the season runs: what has happened, what is
    // next, and what is left. A heading is emitted at the point the group
    // changes rather than by splitting the list, so the rows stay one column.
    var comingUpShown = false;
    final rows = <Widget>[];
    for (final fixture in fixtures) {
      if (fixture.matchNum == 0 && fixture.played) {
        rows.add(_When(kit: kit, text: t('play.previousMatches')));
      }
      if (fixture.isNext) {
        rows.add(_When(kit: kit, text: t('play.nextMatch')));
      }
      if (!fixture.played && !fixture.isNext && !comingUpShown) {
        rows.add(_When(kit: kit, text: t('play.comingUp')));
        comingUpShown = true;
      }
      rows.add(_FixtureRow(fixture: fixture));
      if (ties[fixture.matchNum] case final tie?) rows.add(_CupRow(tie: tie));
    }

    // **HE IS IN THE CORNER, not at the head of the list.** A portrait and two
    // lines of grey text pushed the fixture you came to look at down the page,
    // and put the same man in a different place from every other screen.
    return withSubTabCoach(
      which: CoachLineFor.fixtures,
      child: ListView(
        key: const ValueKey('league-fixtures'),
        // Room at the foot for the corner to sit over, so the last fixture is
        // not underneath him.
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 84),
        children: [
          // Named, like the table it shares a sheet with — see the note in the
          // trophy room. `subnav.fixtures` is the word this tab already wears.
          SheetHeader(
            title: t('subnav.fixtures'),
            padding: sheetHeaderPadding,
          ),
          ...rows,
        ],
      ),
    );
  }
}

/// A cup tie, between two league rows.
///
/// **It looks deliberately unlike a league row.** A tie is a different
/// competition on a different night, and a row that matched its neighbours
/// would read as a fifteenth league game — which is the one thing the fixture
/// count must not suggest. So it is inset, tinted, and led by the competition
/// rather than by a venue chip: at a cup tie the venue is neutral and the
/// interesting fact is which round it is.
class _CupRow extends StatelessWidget {
  const _CupRow({required this.tie});

  final CupTie tie;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = tie.played
        ? (tie.won ? kit.accentBright : kit.textMuted)
        : kit.accentBright;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 3, 24, 3),
      child: Container(
        key: ValueKey('fixture-cup-${tie.afterMatch}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: kit.surface2,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: tie.isNext ? kit.accentBright : kit.border,
            width: tie.isNext ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.emoji_events, size: 14, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tie.roundName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    // Once it has been played the OPPONENT is the fact worth
                    // having; before that, the competition is.
                    tie.opponent ?? tie.competition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: kit.textMuted),
                  ),
                ],
              ),
            ),
            if (tie.played)
              Text(
                '${tie.ourGoals}-${tie.theirGoals}',
                key: ValueKey('fixture-cup-score-${tie.afterMatch}'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _When extends StatelessWidget {
  const _When({required this.kit, required this.text});

  final KitTheme kit;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: kit.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _FixtureRow extends StatelessWidget {
  const _FixtureRow({required this.fixture});

  final OurFixture fixture;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;

    // Football's own convention: the home side's goals on the left. A stored
    // result keeps OURS in `homeGoals` whatever the venue was, so an away
    // fixture is flipped here — and the colour still says who won, which is the
    // half the orientation cannot carry.
    final String score;
    final Color scoreInk;
    if (fixture.played) {
      final left = fixture.isHome ? fixture.ourGoals : fixture.theirGoals;
      final right = fixture.isHome ? fixture.theirGoals : fixture.ourGoals;
      score = '$left - $right';
      scoreInk = fixture.won
          ? kit.accentBright
          : fixture.drawn
          ? kit.textMuted
          : Colors.redAccent;
    } else if (fixture.isNext) {
      score = t('common.vs');
      scoreInk = kit.accentBright;
    } else {
      // An em dash, not `-:-`: a placeholder shaped like a score reads as a
      // score that failed to load.
      score = '-';
      scoreInk = kit.textMuted;
    }

    // **HOW IT WENT, as the dot the standings already use.** The result was
    // carried by the SCORE'S COLOUR and nothing else — a green `2 - 1` against
    // a red `0 - 3` — which asks the player to read a hue off two digits, and
    // says nothing at all on a row they have not played. The form dot is this
    // file's own widget, three rows up, and it is the same green-amber-red the
    // standings, the summary and the HUD all read. No new copy: W, D and L are
    // the letters the table already prints.
    final String? outcome = !fixture.played
        ? null
        : fixture.won
        ? 'W'
        : fixture.drawn
        ? 'D'
        : 'L';

    return Container(
      key: ValueKey('league-fixture-${fixture.matchNum}'),
      // **THE NEXT ONE IS A CARD, not a grey band across the sheet.** It was a
      // full-bleed `surface2` fill with no rounding and no edge, which on a
      // column of otherwise identical rows reads as a highlight that has gone
      // wrong rather than as the fixture you are about to play.
      // The card wants a gap of its own; the rows are separated by a hairline
      // and want the air INSIDE them rather than between them.
      margin: EdgeInsets.symmetric(
        horizontal: fixture.isNext ? 8 : 0,
        vertical: fixture.isNext ? 6 : 0,
      ),
      decoration: BoxDecoration(
        color: fixture.isNext ? kit.accentBright.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(fixture.isNext ? 10 : 0),
        border: fixture.isNext
            ? Border.all(color: kit.accentBright.withValues(alpha: 0.5))
            // A hairline under every other row, so a season of them is a list
            // of fixtures rather than a paragraph of club names.
            : Border(
                bottom: BorderSide(color: kit.border.withValues(alpha: 0.45)),
              ),
      ),
      // **MORE AIR.** Eight top and bottom on a row carrying a chip, two club
      // names and a scoreline is a list nobody can pick a line out of —
      // reported as needing more padding between the fixtures.
      padding: EdgeInsets.symmetric(
        horizontal: fixture.isNext ? 8 : 12,
        vertical: 12,
      ),
      child: Row(
        children: [
          // FIXED WIDTH, always first: the chip is scanned down the column
          // rather than read per row.
          SizedBox(
            width: 46,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: fixture.isHome
                    ? kit.accent.withValues(alpha: 0.25)
                    : kit.surface2,
              ),
              child: Text(
                t(fixture.isHome ? 'play.home' : 'play.away'),
                key: ValueKey('fixture-venue-${fixture.matchNum}'),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: fixture.isHome ? kit.accentBright : kit.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fixture.opponent,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: fixture.isNext ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          // Their rating, tilde'd until we have actually played them — an
          // estimate that does not say it is one is a number the player will
          // hold the game to. In its own slot, because jammed against the score
          // the two numbers ran together into one.
          //
          // **And the tilde was the ONLY thing saying so.** A bare number in an
          // unlabelled column, in a row of other numbers, is a number nobody
          // can identify — and the catalogue has shipped the sentence that
          // identifies it, in ten languages, since the generator first ran:
          // `fixtures.opp_rating` and `fixtures.opp_rating_est`, the second of
          // which explains the tilde in as many words. Both had no caller.
          // Sentences do not fit a 34px slot, so they are what it says when you
          // hold it — the same shape as the table's last-season markers.
          SizedBox(
            width: 34,
            child: Tooltip(
              message: t(
                fixture.ratingEstimated
                    ? 'fixtures.opp_rating_est'
                    : 'fixtures.opp_rating',
                {'rating': fixture.rating},
              ),
              child: Text(
                fixture.ratingEstimated
                    ? '~${fixture.rating}'
                    : '${fixture.rating}',
                key: ValueKey('fixture-rating-${fixture.matchNum}'),
                textAlign: TextAlign.right,
                style: TextStyle(color: kit.textMuted, fontSize: 11),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              score,
              key: ValueKey('fixture-score-${fixture.matchNum}'),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scoreInk,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // A fixed slot whether or not there is a dot in it, so the scores
          // above and below an unplayed fixture stay in one column.
          SizedBox(
            width: 24,
            child: outcome == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: _FormDot(
                      key: ValueKey('fixture-result-${fixture.matchNum}'),
                      result: outcome,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
