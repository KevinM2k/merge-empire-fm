/// The season-end takeover.
///
/// Without it a player finishes their fourteenth match and the game stops: the
/// engine sets `progression.seasonComplete`, every gate refuses, and there is no
/// route onward. This is that route.
///
/// It shows a season that `endSeason` has ALREADY settled — the table, the
/// movement, the payout, the ageing and the next campaign are all its work, done
/// in one call. Nothing here decides any of it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/engine/league_table.dart' show LeagueRow;
import 'package:merge_empire_fc/ui/screens/quests/quests_sheet.dart'
    show QuestRow;
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/report_scroll.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Is the season over and waiting to be closed?
final seasonCompleteProvider = savePick<bool>((s) {
  final prog = s['progression'];
  return prog is Map<String, dynamic> && prog['seasonComplete'] == true;
});

final seasonJustEndedProvider = savePick<int>((s) {
  final prog = s['progression'];
  final n = prog is Map<String, dynamic> ? prog['seasonCount'] : null;
  return n is num ? n.toInt() : 1;
});

class SeasonEndScreen extends ConsumerStatefulWidget {
  const SeasonEndScreen({
    super.key,
    required this.outcome,
    required this.seasonNumber,
    this.record,
    this.winnerName,
    this.winnerIsUs = false,
    this.cup,
    this.finalTable = const [],
    this.quests = const [],
    this.onContinue,
  });

  final SeasonOutcome outcome;

  /// The season's own record, read off the save BEFORE `endSeason` rolled the
  /// counters on — see [seasonRecordOf]. Null draws the page without the stats
  /// band, for a caller that has not got one.
  final SeasonRecord? record;

  /// Who won the division, captured before `endSeason` rebuilt the table for
  /// the new campaign. **The one fact the summary can give that the player's
  /// own row cannot**, which is the JS's reason for it.
  final String? winnerName;
  final bool winnerIsUs;

  /// The division as it finished, for the fold. Captured with the winner, and
  /// for the same reason: `endSeason` rebuilds it for the new campaign.
  final List<LeagueRow> finalTable;

  /// The season's quest track as it finished, captured before `endSeason` swept
  /// it. **A scorecard rather than a list you can act on**, and that is what
  /// the copy describes: `season.end.quests_autopay` says unclaimed rewards are
  /// paid when the new season starts, which is exactly what the sweep does.
  final List<QuestRow> quests;

  /// This season's finished cup run, or null when there was not one — see
  /// [seasonCupRun].
  final ({String cupId, String outcome, int roundReached})? cup;

  /// The season that just finished, captured BEFORE `endSeason` rolled it on.
  final int seasonNumber;

  final VoidCallback? onContinue;

  @override
  ConsumerState<SeasonEndScreen> createState() => _SeasonEndScreenState();
}

class _SeasonEndScreenState extends ConsumerState<SeasonEndScreen> {
  /// **SHUT to begin with.** Twenty rows of a table the player has just spent a
  /// season in is not what they came to this page for — the verdict is, and the
  /// table is there for the one who wants to check the club below them. The JS
  /// folds it the same way.
  bool _tableOpen = false;

  /// The league you have just moved into, in the player's own language.
  ///
  /// This card is the one screen a promotion exists for, and it named the
  /// league in English to every player in the world — `Division.name` is the
  /// data record's literal and `division.<id>` is translated in all ten
  /// catalogues. See `divisionNameProvider`.
  String get _newDivisionName {
    final div = getDivision(widget.outcome.newDivision);
    return tName('division', {'id': div.id, 'name': div.name});
  }

  /// The division this season was played in, in the player's own language.
  String get _divisionName {
    final div = getDivision(widget.outcome.oldDivision);
    return tName('division', {'id': div.id, 'name': div.name});
  }

  /// The cup run as one sentence, or null when there was not one.
  String? get _cupLine {
    final run = widget.cup;
    if (run == null) return null;
    final def = getCupById(run.cupId);
    if (def == null) return null;
    // `tName` takes an id or a map, not a `Cup` — the definition's own name is
    // the fallback, so pass the id and let the catalogue answer. Same as
    // `fixture_caption.dart`.
    final name = tName('cup', {'id': def.id, 'name': def.name});
    if (run.outcome == 'won') return t('season.end.cup_won', {'cup': name});
    final rounds = def.rounds;
    // **The round is NAMED, not numbered.** `roundReached` is an index into the
    // cup's own list and printing it would read "out in the 2".
    final reached = run.roundReached.clamp(0, rounds.length - 1);
    return t('season.end.cup_out', {'cup': name, 'round': rounds[reached]});
  }

  String get _headline => switch (widget.outcome.outcome) {
    'promoted' => t('season.end.promoted', {
      'div': _newDivisionName,
    }),
    'relegated' => t('season.end.relegated', {
      'div': _newDivisionName,
    }),
    _ => t('season.end.stayed', {
      'div': _newDivisionName,
    }),
  };

  /// The page's one colour, from the outcome — the spec's `--se-tone`.
  ///
  /// "Set once on the root from the outcome and every accent below inherits
  /// from it, so a title, a promotion, survival and the drop are four
  /// different-coloured pages rather than four copies of the same one with a
  /// different sentence in the middle."
  ///
  /// Mid-table has no colour of its own, and the spec says what to do about it:
  /// the big number goes gold, because `--se-tone` there is the body ink and a
  /// 54pt figure in plain text is not a headline. The SENTENCE stays plain.
  ({Color tone, Color sentence}) _tone(KitTheme kit, bool champion) {
    const gold = Color(0xFFFFD700);
    if (champion) return (tone: gold, sentence: gold);
    return switch (widget.outcome.outcome) {
      'promoted' => (tone: kit.accentBright, sentence: kit.accentBright),
      'relegated' => (tone: Colors.redAccent, sentence: Colors.redAccent),
      _ => (tone: gold, sentence: Theme.of(context).colorScheme.onSurface),
    };
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // First place is worth saying out loud even when it did not move you: the
    // top division has nowhere to be promoted to.
    final champion = widget.outcome.position == 1;
    final tone = _tone(kit, champion);

    return Scaffold(
      key: const ValueKey('season-end'),
      backgroundColor: kit.bg,
      // **THE PAGE IS FOUR GROUPS, NOT ONE COLUMN, and the spec has been the
      // whole time.** Every line of this screen sat loose on the background —
      // a title, a number, three figures, two sentences, a payout, a quest
      // count and a table toggle, all at the same distance from the page and
      // from each other, so nothing said which of them belonged together.
      // Reported exactly that way.
      //
      // `screens.css` carries the structure under `.season-end`: an
      // `.se-eyebrow`, then `.se-hero` (the division, the place, the verdict
      // and three `.se-stat` tiles), `.se-line` rows for the one-line facts,
      // `.se-card` for the blocks that hold rows, and a PINNED `.se-cta` at the
      // foot so "the way out of this screen is never more than a thumb away,
      // however long the summary above it runs". The port had ported the
      // contents of all of it and none of the containers.
      //
      // **The material is the app's own, not the spec's glass.** `.se-*` is
      // takeover glass because the JS's season end sits on the sky; this one is
      // a flat `kit.bg` page, and the club screen already settled what happens
      // when glass is put on a page with no sky — "rejected on sight, twice".
      // These are the same lifted surface the club's asset cards wear.
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // **CENTRED WHEN IT IS SHORT** — see `report_scroll.dart`. The
              // foot below is pinned, so a season that fits left 420 points of
              // nothing between the last card and it: half the page.
              child: ReportScroll(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // `.se-eyebrow` — small, spaced and muted. It was 20pt
                      // and the loudest thing above the result.
                      Text(
                        t('season.end.title', {'n': widget.seasonNumber}),
                        key: const ValueKey('season-end-title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                          color: kit.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SeasonCard(
                        tone: tone.tone,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                        child: Column(
                          children: [
                            // **WHERE HE FINISHED, as the figure the page is
                            // about.** It was a row labelled
                            // `season.end.stat_record` — which is "Record", the
                            // W-D-L line — with the POSITION as its value, so
                            // the one number a season comes down to was
                            // mislabelled and the size of a caption.
                            Text(
                              tName('division', {
                                'id': widget.outcome.oldDivision,
                                'name': getDivision(
                                  widget.outcome.oldDivision,
                                ).name,
                              }).toUpperCase(),
                              key: const ValueKey('season-end-division'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: kit.textMuted,
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: '${widget.outcome.position}'),
                                  TextSpan(
                                    text: ordinalSuffix(
                                      widget.outcome.position,
                                    ),
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ],
                              ),
                              key: const ValueKey('season-end-position'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 54,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                                color: tone.tone,
                              ),
                            ),
                            if (champion)
                              Text(
                                t('season.end.champion'),
                                key: const ValueKey('season-end-champion'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: tone.tone,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text(
                              _headline,
                              key: const ValueKey('season-end-outcome'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.25,
                                fontWeight: FontWeight.w900,
                                color: tone.sentence,
                              ),
                            ),
                            // **THE SEASON IN THREE FIGURES.**
                            // `season.end.stat_record` and
                            // `season.end.stat_goals` sat translated in ten
                            // catalogues with nothing able to print either —
                            // the band is the spec's `.se-stats`, and it is
                            // what makes this a season OVERVIEW rather than a
                            // verdict with a payout under it. Three tiles
                            // INSIDE the hero, on a wash: the spec's own rule
                            // is that a panel is the surface and the rows on it
                            // are a wash, or the two compound.
                            if (widget.record case final r?) ...[
                              const SizedBox(height: 13),
                              Row(
                                key: const ValueKey('season-end-stats'),
                                children: [
                                  Expanded(
                                    child: _Stat(
                                      value: '${seasonPoints(r)}',
                                      label: t('table.col_pts'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _Stat(
                                      value:
                                          '${r.wins}-${r.draws}-${r.losses}',
                                      label: t('season.end.stat_record'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _Stat(
                                      value:
                                          '${r.goalsFor}:${r.goalsAgainst}',
                                      label: t('season.end.stat_goals'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      // **WHO ACTUALLY WON IT.** `season.end.won_by` and its
                      // `won_by_you` twin sat translated in ten catalogues with
                      // nothing able to print either, and it is the one fact
                      // this page can give that the player's own row cannot.
                      // `.se-line`, and the spec is explicit that these are
                      // deliberately NOT cards: "they're single sentences, and
                      // boxing each one would have the page read as four
                      // competing panels".
                      if (widget.winnerName case final name?) ...[
                        const SizedBox(height: 10),
                        _SeasonLine(
                          lineKey: 'season-end-winner',
                          icon: 'trophy',
                          ink: widget.winnerIsUs
                              ? kit.accentBright
                              : kit.textMuted,
                          gold: widget.winnerIsUs,
                          text: widget.winnerIsUs
                              ? t('season.end.won_by_you', {
                                  'div': _divisionName,
                                })
                              : t('season.end.won_by', {
                                  'team': name,
                                  'div': _divisionName,
                                }),
                        ),
                      ],
                      // **AND HOW THE CUP WENT.** `cup_won` and `cup_out` are
                      // two more of them, and a season with a cup run in it is
                      // not summarised by its league finish alone.
                      if (_cupLine case final line?) ...[
                        const SizedBox(height: 10),
                        _SeasonLine(
                          lineKey: 'season-end-cup',
                          icon: widget.cup!.outcome == 'won'
                              ? 'trophy'
                              : 'cross',
                          ink: widget.cup!.outcome == 'won'
                              ? kit.accentBright
                              : kit.textMuted,
                          gold: widget.cup!.outcome == 'won',
                          text: line,
                        ),
                      ],
                      // **AND WHAT THE SEASON'S QUESTS CAME TO.**
                      // `quests_done` and `quests_autopay` are the last two
                      // keys off this page's shelf. Read-only by construction:
                      // `endSeason` has already swept the track by the time
                      // this is on screen, and the autopay line is the copy
                      // that says so. The spec's `.se-quests` is a `.se-card`
                      // with a head that carries the count — the rows it folds
                      // open are a separate port, and this card is the shape
                      // they will land in.
                      if (widget.quests.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _SeasonCard(
                          title: t('quests.season'),
                          count: Text(
                            t('season.end.quests_done', {
                              'n': widget.quests
                                  .where((q) => q.completed)
                                  .length,
                              'total': widget.quests.length,
                            }),
                            key: const ValueKey('season-end-quests'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: kit.accentBright,
                            ),
                          ),
                          child: Text(
                            t('season.end.quests_autopay'),
                            style: TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              color: kit.textMuted,
                            ),
                          ),
                        ),
                      ],
                      // **THE FINAL TABLE, FOLDED.** Twenty rows of a division
                      // the player has just spent a season in is not what they
                      // came to this page for — the verdict is — but the one
                      // who wants to check the club below them should not have
                      // to leave to do it. `season.end.view_table` and
                      // `hide_table` are two more keys that shipped in ten
                      // languages with nothing able to print either. The JS
                      // folds it exactly this way: the toggle is its own
                      // control ABOVE the card, and the card is what appears.
                      if (widget.finalTable.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          key: const ValueKey('season-end-table-toggle'),
                          onPressed: () =>
                              setState(() => _tableOpen = !_tableOpen),
                          child: Text(
                            t(
                              _tableOpen
                                  ? 'season.end.hide_table'
                                  : 'season.end.view_table',
                            ),
                          ),
                        ),
                        if (_tableOpen)
                          _SeasonCard(
                            child: Column(
                              key: const ValueKey('season-end-table'),
                              children: [
                                for (
                                  var i = 0;
                                  i < widget.finalTable.length;
                                  i++
                                )
                                  _TableRow(
                                    row: widget.finalTable[i],
                                    place: i + 1,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // **`.se-cta` — WHAT IT PAID AND THE WAY OUT, pinned together.**
            // The spec's own comment: "the way out of this screen is never more
            // than a thumb away, however long the summary above it runs". The
            // payout belongs to it rather than to the scroll — it is what the
            // button is collecting, and the JS puts the prize block inside the
            // same pinned foot.
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
              decoration: BoxDecoration(
                color: kit.surface,
                border: Border(top: BorderSide(color: kit.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Line(
                    label: t('season.end.prize_label'),
                    value: formatCoins(widget.outcome.payout),
                    valueKey: 'season-end-payout',
                  ),
                  if (widget.outcome.gemsAwarded > 0)
                    _Line(
                      label: t('shop.section.gems'),
                      value: '${widget.outcome.gemsAwarded}',
                      valueKey: 'season-end-gems',
                    ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    key: const ValueKey('season-end-continue'),
                    onPressed: widget.onContinue,
                    child: Text(
                      t('season.end.continue', {
                        'n': widget.seasonNumber + 1,
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One group on the season-end page — the spec's `.se-hero` and `.se-card`.
///
/// A [tone] paints the hairline the spec draws across the hero's top edge: "the
/// same trick the division colour plays on your row in the table". A [title]
/// and [count] make the `.se-card-head` the quests block wants; both off, it is
/// a plain box for rows.
class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    required this.child,
    this.tone,
    this.title,
    this.count,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color? tone;
  final String? title;
  final Widget? count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    final head = title;
    return DecoratedBox(
      // The club screen's asset cards, which is where this page's material
      // question was settled: a flat fill reads as page, and the app's answer
      // to "on top of the screen" is `surface2 → surface` with a shadow.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.35, -1),
          end: const Alignment(0.35, 1),
          colors: [kit.surface2, Color.lerp(kit.surface2, kit.surface, 0.65)!],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tone == null
              ? kit.border
              : Color.lerp(kit.border, tone, 0.34)!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.08 : 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            Padding(
              padding: padding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (head != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            head.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: kit.textMuted,
                            ),
                          ),
                        ),
                        ?count,
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  child,
                ],
              ),
            ),
            // `.se-hero::before` — a 3px band of the tone, fading out at both
            // ends, so the page's verdict is legible before a word of it is.
            if (tone case final t?)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        t.withValues(alpha: 0),
                        t.withValues(alpha: 0.85),
                        t.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final String valueKey;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: kit.textMuted)),
          Text(
            value,
            key: ValueKey(valueKey),
            style: TextStyle(
              color: kit.accentBright,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// One figure and its word, from the spec's `.se-stat`.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final light = Theme.of(context).brightness == Brightness.light;
    // **A WASH, not a second card.** These tiles sit INSIDE the hero, which is
    // already a surface, and the spec's own note says why: "the panel is the
    // surface, the rows on it are a wash" — a card on a card compounds into
    // something visibly denser than the panels beside it.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      decoration: BoxDecoration(
        color: light
            ? Colors.black.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: light
              ? Colors.black.withValues(alpha: 0.07)
              : Colors.white.withValues(alpha: 0.11),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                height: 1.1,
                fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: kit.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// One fact about the season, on its own line — the spec's `.se-line`.
class _SeasonLine extends StatelessWidget {
  const _SeasonLine({
    required this.lineKey,
    required this.icon,
    required this.ink,
    required this.text,
    this.gold = false,
  });

  final String lineKey;
  final String icon;
  final Color ink;
  final String text;

  /// `.se-line.is-win` — a trophy earns the row a gold edge. A cup exit does
  /// not, and neither does a division somebody else won.
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    const goldInk = Color(0xFFFFD700);
    return Container(
      key: ValueKey(lineKey),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gold ? Color.lerp(kit.border, goldInk, 0.42)! : kit.border,
        ),
      ),
      child: Row(
        children: [
          GameIcon(icon, size: 16, color: gold ? goldInk : ink),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One club in the folded final table.
///
/// Place, name, played and points — the four a player scans for. Not the whole
/// standings widget: that one is a live table with form dots and a movement
/// chevron, and neither means anything about a season that has finished.
class _TableRow extends StatelessWidget {
  const _TableRow({required this.row, required this.place});

  final LeagueRow row;
  final int place;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = row.isPlayer ? kit.accentBright : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$place',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ink ?? kit.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: row.isPlayer ? FontWeight.w900 : FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          Text(
            '${row.played}',
            style: TextStyle(
              fontSize: 11,
              color: kit.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${row.pts}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
