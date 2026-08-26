/// Full time, on a screen of its own.
///
/// **It used to be the bottom of the match screen.** The result, the coins and
/// the three quest outcomes were appended under a ninety-minute commentary feed
/// — so the payoff for the match arrived below the fold of the thing you had
/// just watched, on a page still showing a tactic strip and a Skip button. What
/// a player wants at the whistle is one screen that says what happened.
///
/// **It is also the only place the doubling offer can live.** `match_launcher`
/// has always deferred `applyMatchRewards` until the screen is dismissed,
/// deliberately — "the doubling offer lives on the closing screen, and crediting
/// coins before it is answered would make the offer meaningless" — and until now
/// there was no offer and nothing on the closing screen. The screen pops with
/// `true` when the player took the video and earned the double; the caller pays
/// what the result now says.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsAmberOn, vsGreenOn, vsRedOn;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout_row.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show managerLookProvider;
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/ui/screens/match/cutaway/cutaway_stage.dart'
    show CutawayClip, CutawayStage, clipFor, lineupNames, cardDisplayName;
import 'package:merge_empire_fc/ui/screens/match/match_clock.dart'
    show timelineOf;
import 'package:merge_empire_fc/ui/screens/match/summary_league_move.dart';
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// What the match's three quests paid, which is money the player already has.
///
/// A match quest auto-pays at full time — `settleMatch` resolves the track
/// before this screen is pushed — so it never passes through the doubling offer
/// and never through `applyMatchRewards`. It is still part of what the match
/// was worth, and every figure on this screen that claims to be a total has to
/// carry it.
int questCoins(Map<String, dynamic> result) {
  final raw = result['questResults'];
  if (raw is! List) return 0;
  var total = 0;
  for (final entry in raw) {
    final row = _map(entry);
    if (row != null) total += _num(row['coins']).toInt();
  }
  return total;
}

/// The result's own colour, and it is the scale the rest of the game uses —
/// the form dots, the pitch tokens and the HUD all read green, amber, red.
///
/// **Not the kit accent.** The verdict wore `accentBright`, which is the CLUB's
/// colour: a side in red shirts was told it had won in the same red the game
/// uses for a goal against, and a green-shirted defeat looked like a win.
///
/// **And it is theme-aware**, which it was not: `#4ADE80` and `#F87171` are the
/// dark-mode pair and neither of them carries on a light card — the same fault
/// this queue reported on four screens at once, always with dark mode right.
Color verdictInk(
  BuildContext context, {
  required bool won,
  required bool drawn,
}) => won
    ? vsGreenOn(context)
    : drawn
    ? vsAmberOn(context)
    : vsRedOn(context);

/// The AdMob placement this screen asks for.
const String doubleMatchPlacement = 'double_match';

/// Show it, and answer the offer. Resolves once the player has continued.
Future<void> showMatchSummary(
  BuildContext context,
  Map<String, dynamic> result,
) => Navigator.of(context).push<void>(matchSummaryRoute(result));

/// The summary as a ROUTE, so a caller can REPLACE the match with it rather
/// than push it afterwards — see `play_button.dart`.
Route<void> matchSummaryRoute(Map<String, dynamic> result) => MaterialPageRoute(
  fullscreenDialog: true,
  builder: (_) => MatchSummaryScreen(result: result),
);

/// **OUR goals and THEIRS, off the keys the engine actually writes.**
///
/// The engine's result map carries `homeGoals`/`awayGoals`, and in that map
/// `homeGoals` is always OURS whichever ground the fixture is on — the
/// orchestration says so in its own comment. `ourGoals`/`theirGoals` exist too,
/// but only on `progression.lastMatchResult`, which is a DIFFERENT map, written
/// at full time for the diorama and the manager's mood.
///
/// **This screen was reading the wrong pair and its own fixture hid it**: the
/// test hand-wrote `ourGoals`, so the summary showed a scoreline in the suite
/// and 0–0 in the game. Reported from a live save as "a victory screen with
/// four goalscorers and a 0–0". The fallback keeps the settled map working, so
/// either can be handed in.
(int, int) _score(Map<String, dynamic> result) => (
  _num(result['homeGoals'] ?? result['ourGoals']).toInt(),
  _num(result['awayGoals'] ?? result['theirGoals']).toInt(),
);

class MatchSummaryScreen extends ConsumerStatefulWidget {
  const MatchSummaryScreen({required this.result, super.key});

  /// The match, as the engine settled it. **Mutated by the offer**: taking the
  /// video doubles `coinsEarned` in place, which is what the caller then pays.
  final Map<String, dynamic> result;

  @override
  ConsumerState<MatchSummaryScreen> createState() => MatchSummaryScreenState();
}

class MatchSummaryScreenState extends ConsumerState<MatchSummaryScreen> {
  /// One tap only. A second while the video is opening would double twice.
  bool _answering = false;

  /// What the match paid before any doubling — the figure the offer is about.
  late final int _base;

  /// What the three match quests paid, which is already in the bank. Held here
  /// rather than recomputed per build: the offer doubles the FEE, and both
  /// answers have to add the same quest money to it.
  late final int _quests;

  @override
  void initState() {
    super.initState();
    _base = _num(widget.result['coinsEarned']).toInt();
    _quests = questCoins(widget.result);
    if (_base > 0) {
      ref.read(rewardedAdsProvider).prepare(doubleMatchPlacement);
    }
  }

  /// Take the video, and pay double if it was watched.
  ///
  /// Every other answer is the same answer: the player keeps what the match
  /// paid. An unavailable video is not their fault, so it says so — the JS
  /// toasts and closes, and so does this.
  Future<void> _double() async {
    if (_answering) return;
    setState(() => _answering = true);
    final outcome = await ref
        .read(rewardedAdsProvider)
        .show(doubleMatchPlacement);
    if (!mounted) return;
    if (outcome == AdOutcome.rewarded) {
      widget.result['coinsEarned'] = _base * 2;
    } else if (outcome == AdOutcome.unavailable) {
      // The UI's own refusal line, on the bus the toast host listens to.
      emit('toast:info', t('toast.ad_unavailable'));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final result = widget.result;
    final won = result['won'] == true;
    final drawn = result['drawn'] == true;
    final isHome = result['isHome'] == true;
    final (ourGoals, theirGoals) = _score(result);
    final trophies = _num(result['trophiesEarned']).toInt();
    final canDouble = _base > 0;
    final questRows = result['questResults'];
    final hasQuests = questRows is List && questRows.isNotEmpty;

    // **A DARK TAKEOVER IN BOTH THEMES**, the same as the match it closes —
    // see [darkTakeoverThemeProvider]. Every panel here is dark glass on the
    // match's own sky and the ink over them was the app's, which in light mode
    // is near-black. Reported as the end-of-game screen being unreadable.
    final page = Scaffold(
      key: const ValueKey('match-summary'),
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        // The same backdrop the match itself stands under — see
        // [matchBackdrop]. Full time is the same evening.
        decoration: matchBackdrop(
          context: context,
          tier: ref.watch(stadiumTierProvider),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                  children: [
                    // **ONE BOX, not three things loose around one.** The
                    // verdict, the money and the quest outcomes each sat on the
                    // bare sky with only the scoreline in a panel — so the four
                    // halves of the same statement, what happened and what it
                    // paid, read as four unrelated notes.
                    _ResultCard(
                      won: won,
                      drawn: drawn,
                      left:
                          '${isHome ? result['clubName'] : result['opponentName'] ?? ''}',
                      right:
                          '${isHome ? result['opponentName'] : result['clubName'] ?? ''}',
                      leftGoals: isHome ? ourGoals : theirGoals,
                      rightGoals: isHome ? theirGoals : ourGoals,
                      trophies: trophies,
                      result: result,
                    ),
                    const SizedBox(height: 12),
                    // **THEIR OWN CARD, so each goal can carry its replay.**
                    // The scorers were a line inside the result card, which
                    // left nowhere to put a control beside a name.
                    _ScorersCard(result: result),
                    // **THE TABLE IS SECOND, and that is the whole ordering
                    // decision on this screen.** It is the one thing here that
                    // MOVES — every club sliding to where the round left it —
                    // and it was below the manager, the scorers and the quest
                    // list, which is to say below the fold, which is to say the
                    // animation played to nobody. A league match is only half
                    // told by its own scoreline; this is the other half, and it
                    // now sits directly under the half it completes.
                    if (result['isCup'] != true) ...[
                      // **ON A PANE, like every other band on this report.**
                      // It was the one block drawn straight onto the sky, which
                      // in dark mode looked deliberate and in light mode left a
                      // column of figures on a daylight blue — the points at
                      // 1.9:1. A panel is what the rest of the page is made of
                      // and it is what gives these rows a ground. `LeagueMove`
                      // draws that pane ITSELF now, so a second one round it
                      // was a card inside a card.
                      const LeagueMove(key: ValueKey('summary-table')),
                      const SizedBox(height: 12),
                    ],
                    // **THE MANAGER AND THE QUESTS SHARE A ROW, so the whole
                    // report fits one screen.** They were stacked, which put
                    // the quest list below the fold on any phone — and the two
                    // are a natural pair: he is reacting to the match and they
                    // are what the match was played for. The shot goes smaller
                    // to pay for it; it is a reaction, not a portrait.
                    // **AND THEY ARE THE SAME HEIGHT.** The row was
                    // top-aligned, so the shot and the quest panel finished at
                    // whatever height each happened to want and the pair read
                    // as two things dropped next to each other. Reported as the
                    // dugout cam and the quests wanting to match. `stretch`
                    // **A TIE DECIDED ON PENALTIES SAYS SO.** Above the
                    // reaction, because it is not a reaction — it is the rest
                    // of the result, and without it the scoreline above is a
                    // one-goal defeat the player never saw decided.
                    if (shootoutFrom(result) case final penalties?) ...[
                      ShootoutRow(
                        ours: penalties.ours,
                        theirs: penalties.theirs,
                        won: penalties.won,
                      ),
                      const SizedBox(height: 10),
                    ],
                    // inside an `IntrinsicHeight`: the taller of the two sets
                    // the row and the other fills it.
                    IntrinsicHeight(
                      child: Row(
                        key: const ValueKey('summary-reaction-row'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 120,
                            child: _Manager(result: result),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: hasQuests
                                ? GlassPanel(
                                                                        padding: const EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      12,
                                    ),
                                    child: QuestOutcomes(result: result),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // **THE MONEY SITS WITH THE BUTTON THAT CHANGES IT.** The
              // figure was at the top of the scroll and the offer to double it
              // at the foot, which is one decision split across a page — the
              // player had to remember a number to understand the button. It
              // is the same `_Payout`, moved, and the strike-through it draws
              // while the video runs is now a hand's width from the control
              // that started it.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // **THE MONEY GETS A SURFACE, like everything else here.**
                    // It was the one figure on the report drawn straight onto
                    // the sky, directly under a column of panels — so the
                    // biggest number on the screen read as a caption.
                    // **THE BUTTON GOES INSIDE THE CARD.** The offer and the
                    // figure it changes were a panel with a button sitting
                    // under it, which is two objects for one decision — the
                    // card says what you have and the button says what it
                    // could be, so they are the same thing. Asked for
                    // directly, and "No thanks" stays outside and at the
                    // bottom, on its own.
                    if (_base + _quests > 0 || canDouble)
                      GlassPanel(
                                                key: const ValueKey('summary-payout-card'),
                        // **MORE ROOM UNDER THE BUTTON than over the figure.**
                        // Ten and ten put the rewarded-video control hard
                        // against the card's bottom edge, which on the one
                        // control here that costs the player something reads as
                        // the card having been cut off. Asked for directly.
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_base + _quests > 0)
                              _Payout(
                                base: _base,
                                quests: _quests,
                                doubled: canDouble && _answering,
                              ),
                            if (canDouble) ...[
                              const SizedBox(height: 10),
                              // **THE SHOP'S OWN BUTTON, in the ad tone.** It
                              // was a bespoke `ElevatedButton` painted gold by
                              // hand, on a game whose rule is one button and
                              // four colours where the colour answers "what
                              // does this cost me?". A rewarded video is
                              // yellow and wears the video chip, here as it
                              // does on the energy sheet and the free shelf.
                              StoreButton(
                                key: const ValueKey('summary-double'),
                                tone: StoreTone.ad,
                                label: _answering
                                    ? t('common.loading')
                                    : '${t('match.double_reward')} → '
                                          '${formatCoins(_base * 2 + _quests)}',
                                leading: _answering
                                    ? null
                                    : const GameIcon('video', size: 14),
                                onTap: _answering ? null : _double,
                              ),
                            ],
                          ],
                        ),
                      ),
                    // **TWO, not eight.** The card already ends in fourteen of
                    // its own padding and the text button brings its own; eight
                    // more here was the widest seam on the page, under the one
                    // control the eye is meant to fall straight onto.
                    const SizedBox(height: 2),
                    canDouble
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // **Stripped to TEXT, not a quieter button.** Two
                          // buttons stacked read as a choice between two offers,
                          // and a muted one still invites a press. This is the
                          // decline, so it looks like walking away.
                          TextButton(
                            key: const ValueKey('summary-no-thanks'),
                            onPressed: _answering
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: kit.textMuted,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 32),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                            ),
                            // **BOTH FIGURES ARE WHAT YOU WALK AWAY WITH**,
                            // and the quest money is part of both. The link
                            // said `_base` — the match fee alone — while the
                            // player was actually leaving with the fee plus
                            // whatever the three quests paid at the whistle, so
                            // the one line naming the outcome of declining
                            // understated it. Totals on both sides also make
                            // the two answers comparable: the difference
                            // between them is exactly what the video is worth.
                            child: Text(
                              '${t('match.no_thanks')} — '
                              '${formatCoins(_base + _quests)}',
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const ValueKey('summary-continue'),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(t('common.continue')),
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
    return page;
  }
}

/// The result, and everything the result was worth, on ONE surface.
///
/// **Four notes on the sky is not a statement.** The verdict, the money and the
/// quest outcomes each sat loose on the gradient with only the scoreline in a
/// panel — on a screen whose whole job is to say "this is what happened and
/// this is what it paid". They are one thing, so they get one box, ruled into
/// what happened and what it came to.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.won,
    required this.drawn,
    required this.left,
    required this.right,
    required this.leftGoals,
    required this.rightGoals,
    required this.trophies,
    required this.result,
  });

  final bool won;
  final bool drawn;
  final String left;
  final String right;
  final int leftGoals;
  final int rightGoals;
  final int trophies;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
            density: GlassDensity.deep,
      // **TIGHTER TOP AND BOTTOM, and the dugout cam is what it buys.** This
      // card is the tallest thing on the report and the two things under it —
      // the cam and the quest list — were falling below the fold on a short
      // phone. It gives out of its own padding rather than out of the gaps
      // between the panels, which is what keeps the report reading as a stack
      // of cards rather than a squeezed column.
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Verdict(won: won, drawn: drawn),
          const SizedBox(height: 8),
          _Score(
            left: left,
            right: right,
            leftGoals: leftGoals,
            rightGoals: rightGoals,
          ),
          // **WHO SCORED BELONGS UNDER THE SCORE, which is a scoreboard's own
          // convention and not a design choice.** It was its own panel further
          // down with a portrait on every row, which is a second card telling
          // the same story as the number above it — and the number is the part
          // that has to be found first. Names and minutes, on one line each.
          if (trophies > 0) ...[
            // The rule wears the verdict's colour rather than the pane's
            // hairline grey: both halves are about the same result.
            _Rule(ink: verdictInk(context, won: won, drawn: drawn)),
            // A figure and the glyph, not a sentence: there is no shipped copy
            // for "you won N trophies", and inventing a key the catalogues have
            // never seen would print English in ten languages.
            _Trophies(trophies: trophies),
          ],
        ],
      ),
    );
  }
}

/// The seam inside the card, in the result's own colour.
class _Rule extends StatelessWidget {
  const _Rule({required this.ink});

  final Color ink;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(height: 1, color: ink.withValues(alpha: 0.28)),
  );
}

class _Trophies extends StatelessWidget {
  const _Trophies({required this.trophies});

  final int trophies;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Row(
      key: const ValueKey('summary-trophies'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GameIcon('trophy', size: 16, color: glassAccent(context, kit.accentBright)),
        const SizedBox(width: 6),
        Text(
          '+$trophies',
          style: TextStyle(
            color: glassAccent(context, kit.accentBright),
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// VICTORY, DRAW or DEFEAT, in the one size that says which without reading.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.won, required this.drawn});

  final bool won;
  final bool drawn;

  @override
  Widget build(BuildContext context) {
    final label = won
        ? t('match.victory')
        : drawn
        ? t('match.draw')
        : t('match.defeat');
    return Text(
      label.toUpperCase(),
      key: const ValueKey('summary-verdict'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        // **THE RESULT'S OWN COLOUR**, off the green-amber-red scale the form
        // dots, the pitch tokens and the HUD all read. It wore the kit accent,
        // which belongs to the CLUB: a side in red was told it had won in the
        // same red this game uses for a goal against.
        // **AND THROUGH THE PANE RULE.** The scale's own colours are chosen
        // against a dark ground; on a light pane over a daylight sky the
        // winner's green is 2.4:1. `glassAccent` takes any colour down until it
        // clears the pane, which is what this file is for.
        color: glassAccent(
          context,
          verdictInk(context, won: won, drawn: drawn),
        ),
      ),
    );
  }
}

/// The two clubs and the score between them, home side left as football writes
/// a scoreline.
class _Score extends StatelessWidget {
  const _Score({
    required this.left,
    required this.right,
    required this.leftGoals,
    required this.rightGoals,
  });

  final String left;
  final String right;
  final int leftGoals;
  final int rightGoals;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Club(name: left, align: TextAlign.right),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '$leftGoals–$rightGoals',
          key: const ValueKey('summary-score'),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
      Expanded(
        child: _Club(name: right, align: TextAlign.left),
      ),
    ],
  );
}

class _Club extends StatelessWidget {
  const _Club({required this.name, required this.align});

  final String name;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    name,
    textAlign: align,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  );
}

/// Him, taking it. The same rig and the same policy the touchline shot uses, so
/// the face at the whistle is the face the League tab shows a second later.
class _Manager extends ConsumerWidget {
  const _Manager({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final (ourGoals, theirGoals) = _score(result);
    final ours = (result['squadRating'] as num?)?.toDouble();
    final theirs = (result['opponentRating'] as num?)?.toDouble();
    final mood = camMood(
      trigger: CamTrigger.fullTime,
      ourGoals: ourGoals,
      theirGoals: theirGoals,
      trophiesEarned: _num(result['trophiesEarned']),
      ratingGap: ours != null && theirs != null ? theirs - ours : 0,
      // A cup tie is always at home, so "at home" carries none of the meaning
      // it does in the league.
      isHome: result['isCup'] == true ? null : result['isHome'] == true,
    );
    final margin = ourGoals - theirGoals;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: DugoutCam(
          key: const ValueKey('summary-manager'),
          mood: mood,
          kit: kit.accent,
          skin: const Color(0xFFEEBB8C),
          hair: const Color(0xFF3A2A1C),
          look: ref.read(managerLookProvider),
          gesture: camGesture(mood, null, ref.read(gameProvider).state, true),
          tone: margin > 0
              ? CamTone.good
              : margin < 0
              ? CamTone.bad
              : CamTone.flat,
          variant: CamVariant.inline,
          // He keeps reacting for as long as the screen is up: one gesture and
          // then a statue reads as a man who has finished having feelings about
          // the result.
          // **IN A HURRY HERE.** The rota's own gaps are the JS's and a node
          // fixture pins them; this screen wanted him twice as busy, so the
          // divergence is applied at the call site rather than in the table.
          // See [camRotaHurry].
          rota: (recent) {
            final beat = camRotaBeat(
              mood,
              null,
              ref.read(gameProvider).state,
              recent,
            );
            return (
              gesture: beat.gesture,
              gap: beat.gap * camRotaHurry,
            );
          },
        ),
      ),
    );
  }
}

/// Who scored, with their faces. Ours only — the engine picks scorers from our
/// squad, and a face for one of theirs cannot be drawn.
/// Who scored and when, under the score they made.
///
/// **A scoreboard's own convention rather than a design choice**, and it
/// replaces a panel of its own further down the report: a portrait per scorer
/// is a second card telling the story the number above it already told, and the
/// number is the part that has to be found first. Ours only — a goal against is
/// on the opposition's teamsheet, not on ours.
class _ScorersCard extends ConsumerStatefulWidget {
  const _ScorersCard({required this.result});

  final Map<String, dynamic> result;

  @override
  ConsumerState<_ScorersCard> createState() => _ScorersCardState();
}

/// How long the screen takes to come down, and to go back up.
const Duration replayScreenDrop = Duration(milliseconds: 520);
const Duration replayScreenRise = Duration(milliseconds: 420);

/// How long the last frame holds before the screen goes back up — long enough
/// to see the ball in the net, short enough not to be a freeze.
const Duration replayScreenHold = Duration(milliseconds: 900);

class _ScorersCardState extends ConsumerState<_ScorersCard>
    with SingleTickerProviderStateMixin {
  /// The goal being replayed, or null when the screen is up.
  int? _minute;
  CutawayClip? _clip;
  Timer? _hold;

  /// **A PROJECTOR SCREEN, not a popup.** The replay opened a dialog over the
  /// report — a window on top of a page that already had the goals on it. It
  /// now unrolls from under the goal it belongs to, plays, and rolls back up:
  /// forward is the screen coming down, reverse is it going back.
  late final AnimationController _screen;

  @override
  void initState() {
    super.initState();
    _screen = AnimationController(
      vsync: this,
      duration: replayScreenDrop,
      reverseDuration: replayScreenRise,
    );
  }

  @override
  void dispose() {
    _hold?.cancel();
    _screen.dispose();
    super.dispose();
  }

  /// Replay one of our goals: the same clip the match drew, rebuilt from the
  /// result the way `MatchScreen._replayClip` does.
  void _replay(int minute, String scorerName) {
    // The same button again while it is down is the way to stop it.
    if (_minute == minute) {
      _rollUp();
      return;
    }
    final result = widget.result;
    final event = timelineOf(result)
        .where(
          (e) => e.type == 'goal' && e.team == 'home' && e.minute == minute,
        )
        .firstOrNull;
    if (event == null) return;
    final save = ref.read(gameProvider).state;
    final clip = clipFor(
      event,
      ourSideLeft: result['isHome'] == true,
      ours: true,
      seed: ((result['seed'] as num?)?.toInt() ?? 0) + minute,
      names: lineupNames(save),
      scorerName: scorerName,
    );
    if (clip == null) return;
    _hold?.cancel();
    setState(() {
      _minute = minute;
      _clip = clip;
    });
    if (MediaQuery.of(context).disableAnimations) {
      _screen.value = 1;
    } else {
      _screen.forward();
    }
  }

  /// The clip has ended: hold the last frame, then take the screen back up.
  void _onDone() {
    _hold?.cancel();
    _hold = Timer(replayScreenHold, _rollUp);
  }

  Future<void> _rollUp() async {
    _hold?.cancel();
    if (!mounted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _screen.value = 0;
    } else {
      await _screen.reverse();
    }
    if (!mounted) return;
    setState(() {
      _minute = null;
      _clip = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final result = widget.result;
    final raw = result['events'];
    if (raw is! List) return const SizedBox.shrink();
    final save = ref.read(gameProvider).state;

    final goals = <({String name, int minute})>[];
    for (final entry in raw) {
      final e = _map(entry);
      if (e == null || e['type'] != 'goal' || e['team'] != 'home') continue;
      // By the card if it is still on the grid, else the name the result
      // recorded — a scorer who has since been sold still scored.
      final name =
          cardDisplayName(save, '${e['scorerInstanceId'] ?? ''}') ??
          '${e['scorer'] ?? ''}';
      if (name.isEmpty) continue;
      goals.add((name: name, minute: _num(e['minute']).toInt()));
    }
    if (goals.isEmpty) return const SizedBox.shrink();

    final ink = glassAccent(context, kit.accentBright);
    final clip = _clip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        key: const ValueKey('summary-scorers'),
        density: GlassDensity.deep,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in goals)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "${g.name} ${g.minute}'",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('summary-replay-${g.minute}'),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _minute == g.minute ? Icons.stop : Icons.replay,
                      size: 18,
                      color: ink,
                    ),
                    onPressed: () => _replay(g.minute, g.name),
                  ),
                ],
              ),
            // **THE SCREEN.** Clipped and measured off the top, so it unrolls
            // downward — the top edge stays put and the bottom edge descends,
            // which is what a screen coming down looks like. It is in the
            // column, so the report below it moves out of the way rather than
            // being covered.
            if (clip != null)
              AnimatedBuilder(
                animation: _screen,
                builder: (context, child) => ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: Curves.easeOutCubic.transform(_screen.value),
                    child: child,
                  ),
                ),
                child: Padding(
                  key: const ValueKey('summary-replay-screen'),
                  padding: const EdgeInsets.fromLTRB(0, 6, 8, 4),
                  child: CutawayStage(
                    key: ValueKey('summary-replay-stage-$_minute'),
                    clip: clip,
                    scorerFromLeft: result['isHome'] == true,
                    onDone: (_) => _onDone(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Payout extends StatelessWidget {
  const _Payout({
    required this.base,
    required this.quests,
    required this.doubled,
  });

  final int base;
  final int quests;
  final bool doubled;

  @override
  Widget build(BuildContext context) {
    final total = base + quests;
    if (total <= 0) return const SizedBox.shrink();
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('summary-payout'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (doubled) ...[
              Text(
                '+${formatCoins(total)}',
                style: TextStyle(
                  fontSize: 15,
                  color: kit.textMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 8),
              Text('➜', style: TextStyle(color: kit.textMuted)),
              const SizedBox(width: 8),
            ],
            // **GOLD in both themes, on a plate.** `coinFigureInk` answers a
            // deep bronze for a light page — reported as not liking the coins
            // in bronze — and the fix the quests sheet already made is the one
            // here: the hue is the currency and does not change, so the
            // contrast is bought with the surface. A dark plate under the
            // figure in light mode, a faint gold wash in dark.
            Container(
              padding: const EdgeInsets.fromLTRB(10, 2, 12, 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF1A1F26).withValues(alpha: 0.88)
                    : gameGold.withValues(alpha: 0.12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 20, solid: true, color: gameGold),
                  const SizedBox(width: 6),
                  Text(
                    '+${formatCoins(doubled ? base * 2 + quests : total)}',
                    key: const ValueKey('summary-coins'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: gameGold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // The teaser is about an offer, so it goes when there is no offer to
        // make: a match that paid no fee still shows its quest money, and
        // "watch to keep 2× coins" under a figure nothing can double is a
        // button that is not there.
        if (base > 0) ...[
          const SizedBox(height: 4),
          Text(
            t('match.double_teaser'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: kit.textMuted),
          ),
        ],
      ],
    );
  }
}

/// What the match's three quests came to.
///
/// All three, not just the winners: the player is being shown what they MISSED
/// as much as what they won, which is what makes the next set worth reading. The
/// coins have already been paid — a match quest auto-pays at full time — so this
/// is a report, not a claim.
class QuestOutcomes extends StatelessWidget {
  const QuestOutcomes({required this.result, this.rule, super.key});

  final Map<String, dynamic> result;

  /// The seam drawn ABOVE the list when it shares a box with the result — the
  /// verdict's colour, the same rule the money sits under. Null for a caller
  /// that lays the list out itself.
  final Color? rule;

  @override
  Widget build(BuildContext context) {
    final raw = result['questResults'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final rows = [
      for (final entry in raw)
        if (entry is Map<String, dynamic>) entry,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final total = rows.fold<num>(
      0,
      (sum, r) => sum + ((r['coins'] as num?) ?? 0),
    );

    // **A MISS IS RED, and the line stays readable.** Both the quest and its
    // "Missed" were the kit's muted ink, which on deep glass is grey on grey —
    // reported as the misses being hard to read. The quest keeps the pane's own
    // text and only the verdict takes a colour, the same green-or-red every
    // stat row on the report uses.
    final passedInk = vsGreenOn(context);
    final missedInk = vsRedOn(context);
    return Padding(
      key: const ValueKey('match-quests'),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rule case final ink?) _Rule(ink: ink),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              t('quests.match').toUpperCase(),
              key: const ValueKey('match-quests-title'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: glassMuted(context),
              ),
            ),
          ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      // Per-division text, interpolated off the target the quest
                      // was set at rather than today's — a quest is judged on
                      // what it asked for when it was drawn.
                      t('quest.${row['id']}', {'n': row['target'] ?? 0}),
                      style: TextStyle(
                        color: row['passed'] == true
                            ? glassText(context)
                            : glassText(context).withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row['passed'] == true
                        ? '✓ ${t('quests.reward_coins', {'n': row['coins'] ?? 0})}'
                        : '✕ ${t('quests.missed')}',
                    key: ValueKey('match-quest-${row['id']}'),
                    style: TextStyle(
                      color: row['passed'] == true ? passedInk : missedInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${t('quests.total_reward')}: '
                '${t('quests.reward_coins', {'n': total.toInt()})}',
                key: const ValueKey('match-quests-total'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: passedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
