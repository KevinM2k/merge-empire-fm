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
import 'package:merge_empire_fc/data/quests.dart' show getQuest;
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show displayText;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/screens/match/shootout_row.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show managerLookProvider;
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/ui/widgets/report_scroll.dart';
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

/// How long the doubled figure takes to climb — see
/// [MatchSummaryScreenState._tally].
///
/// Long enough to read as counting rather than as a number changing, short
/// enough that it is not standing between the player and the grid: the screen
/// is holding open for the whole of it.
const Duration coinTallyRun = Duration(milliseconds: 900);

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

/// The score to PRINT, which is the ninety minutes.
///
/// **A shootout's winning goal is folded into the engine's scoreline** so `won`
/// and the recorded score agree — `cup_launcher` and `match_orchestration` both
/// do it, and a parity fixture reads those fields. On the SCREEN that number is
/// a lie: a tie drawn 1–1 and lost on penalties printed `1–2`, with the pens
/// reported further down the page under the fold. Read from the couch as "it
/// should have gone to pens, instead it came up defeat and said they won 1–2" —
/// which is the JS's own warning about this field, word for word. So the
/// divergence lives on the screen and the field is left to the harness.
///
/// [_score] is unchanged and still the engine's: the manager's reaction is
/// about who went through, and a shootout win is not a draw to him.
(int, int) regulationScore(Map<String, dynamic> result) {
  final (ours, theirs) = _score(result);
  if (shootoutFrom(result) case final penalties?) {
    final ourReg = penalties.won ? ours - 1 : ours;
    final theirReg = penalties.won ? theirs : theirs - 1;
    return (ourReg < 0 ? 0 : ourReg, theirReg < 0 ? 0 : theirReg);
  }
  return (ours, theirs);
}

class MatchSummaryScreen extends ConsumerStatefulWidget {
  const MatchSummaryScreen({required this.result, super.key});

  /// The match, as the engine settled it. **Mutated by the offer**: taking the
  /// video doubles `coinsEarned` in place, which is what the caller then pays.
  final Map<String, dynamic> result;

  @override
  ConsumerState<MatchSummaryScreen> createState() => MatchSummaryScreenState();
}

class MatchSummaryScreenState extends ConsumerState<MatchSummaryScreen>
    with SingleTickerProviderStateMixin {
  /// One tap only. A second while the video is opening would double twice.
  bool _answering = false;

  /// **THE FIGURE CLIMBS TO WHAT THE VIDEO JUST BOUGHT.**
  ///
  /// The reward used to land with the screen already leaving: the number the
  /// button had been promising was never once seen. Asked for from the couch —
  /// show it increasing to the new amount, on the button itself.
  ///
  /// On the BUTTON rather than on the plate above it, and deliberately: the
  /// button is what the player just pressed and where their eye already is, and
  /// the plate's figure is a strike-through-and-arrow the moment the answer is
  /// in. The screen holds for exactly this run and then pops.
  /// **BUILT IN `initState`, NOT LAZILY.** A `late final` initialiser runs on
  /// first ACCESS, and the first access on a screen nobody doubled anything on
  /// is `dispose` — which then constructs an `AnimationController` while the
  /// element is being unmounted, and `SingleTickerProviderStateMixin` looks up
  /// `TickerMode` to do it: "Looking up a deactivated widget's ancestor is
  /// unsafe". Caught by the one test that closes this screen without pressing
  /// anything.
  late final AnimationController _tally;

  /// Whether the climb has started, so the button knows to print the running
  /// figure rather than the offer.
  bool _tallying = false;

  @override
  void dispose() {
    _tally.dispose();
    super.dispose();
  }

  /// Run the climb, or skip it under reduce-motion — where a count-up is a
  /// number changing several times for no reason.
  Future<void> _runTally() async {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    setState(() => _tallying = true);
    await _tally.forward();
  }

  /// What the match paid before any doubling — the figure the offer is about.
  late final int _base;

  /// What the three match quests paid, which is ALREADY in the bank — a match
  /// quest pays itself at the whistle. Held here rather than recomputed per
  /// build, because both answers are totals built out of it.
  ///
  /// **And the offer doubles it too now.** It used to double the fee alone,
  /// which meant the one figure on screen was two figures with different rules
  /// behind it and no way to tell which the button was about. Asked for from the
  /// couch: 2× works for both, and then the breakdown that explained the split
  /// is not needed at all.
  late final int _quests;

  @override
  void initState() {
    super.initState();
    _tally = AnimationController(vsync: this, duration: coinTallyRun);
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
    final outcome = await watchRewardedAd(ref, doubleMatchPlacement);
    if (!mounted) return;
    if (outcome == AdOutcome.rewarded) {
      // **THE QUEST MONEY IS PAID A SECOND TIME, which is what doubling it
      // means.** `settleMatch` already banked one lot at the whistle, and the
      // caller pays whatever `coinsEarned` says on top — so the player ends on
      // `2 * (fee + quests)` and this is the half of it still owed.
      widget.result['coinsEarned'] = _base * 2 + _quests;
      // Count it up where the offer was, then leave — see [_tally].
      await _runTally();
      if (!mounted) return;
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
    final (shownOurs, shownTheirs) = regulationScore(result);
    final trophies = _num(result['trophiesEarned']).toInt();
    // **THE OFFER IS ABOUT THE WHOLE FIGURE NOW**, so a match whose fee was
    // nothing but whose quests paid still has something to double.
    final canDouble = _base + _quests > 0;
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
                // **CENTRED WHEN IT IS SHORT** — see `report_scroll.dart`. A
                // ListView puts a stack of cards at the top of its viewport and
                // the money block below is pinned, so a report that did not
                // fill the phone left 125 points of nothing between the manager
                // and the payout.
                child: ReportScroll.list(
                  // **TOP, not centred.** The first card is the scoreline, and
                  // a scoreline that floats down the page as the report below
                  // it grows or shrinks reads as the page settling rather than
                  // as the result. Asked for directly; the season summary keeps
                  // the centring, which is what `report_scroll.dart` is about.
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                  children: [
                    // **ONE BOX, not three things loose around one.** The
                    // verdict, the money and the quest outcomes each sat on the
                    // bare sky with only the scoreline in a panel — so the four
                    // halves of the same statement, what happened and what it
                    // paid, read as four unrelated notes.
                    // **THE VERDICT STANDS ON THE SKY, not inside the card.**
                    // It was the card's own first line, which made the biggest
                    // word on the screen a label ON a panel — and the panel
                    // below it already says the same thing in figures. Out
                    // here it is a headline over the report rather than a row
                    // in it. Taken from the shot asked for from the couch.
                    _Verdict(won: won, drawn: drawn),
                    const SizedBox(height: 10),
                    _ResultCard(
                      won: won,
                      drawn: drawn,
                      left:
                          '${isHome ? result['clubName'] : result['opponentName'] ?? ''}',
                      right:
                          '${isHome ? result['opponentName'] : result['clubName'] ?? ''}',
                      leftGoals: isHome ? shownOurs : shownTheirs,
                      rightGoals: isHome ? shownTheirs : shownOurs,
                      trophies: trophies,
                      result: result,
                    ),
                    // **A TIE DECIDED ON PENALTIES SAYS SO, DIRECTLY UNDER THE
                    // SCORE IT COMPLETES.** It used to sit below the league
                    // table and the scorers, which on any phone is below the
                    // fold — so the one thing that explains a level scoreline
                    // was the one thing the player never reached. It is not a
                    // footnote to the result; it is the rest of it.
                    if (shootoutFrom(result) case final penalties?) ...[
                      const SizedBox(height: 10),
                      ShootoutRow(
                        ours: penalties.ours,
                        theirs: penalties.theirs,
                        won: penalties.won,
                      ),
                    ],
                    const SizedBox(height: 12),
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
                    // inside an `IntrinsicHeight`: the taller of the two sets
                    // the row and the other fills it.
                    IntrinsicHeight(
                      child: Row(
                        key: const ValueKey('summary-reaction-row'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        // **AND HE IS NOT LEFT STANDING IN A CORNER.** With no
                        // quests the other half of the row was an empty
                        // `Expanded`, so the shot sat in a 120-point column
                        // against the left edge with two thirds of the row
                        // blank beside it — one small square and a lot of
                        // nothing, which is the worst-looking thing on the
                        // page. A cup tie and an early match both land here.
                        mainAxisAlignment: hasQuests
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          // **WIDER, because he was a stamp.** 120 points
                          // against a quest panel that had grown tiles read as
                          // a thumbnail beside a list; the shot asked for from
                          // the couch gives the cam about a third of the row.
                          // The pair are still the same height — that is the
                          // `IntrinsicHeight` above, not a number here.
                          SizedBox(
                            width: 138,
                            child: _Manager(result: result),
                          ),
                          if (hasQuests) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: GlassPanel(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: QuestOutcomes(result: result),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // **THE MONEY SITS WITH THE BUTTON THAT CHANGES IT.** The
                    // figure was at the top of the scroll and the offer to
                    // double it at the foot, which is one decision split across
                    // a page — the player had to remember a number to
                    // understand the button.
                    //
                    // **AND IT SCROLLS WITH THE REST NOW.** It was pinned under
                    // the scroll, which buys nothing on a report built to fit
                    // one screen and costs a hole: a defeat with a short table
                    // left a hand's width of empty sky between the quest panel
                    // and the money. Asked for from the couch — it is fine for
                    // it to scroll. `ReportScroll` centres a short report, so
                    // the block travels with what it is reporting on.
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
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
                                      hasQuests: hasQuests,
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
                                    // Rebuilt off the tally so the figure on the face
                                    // climbs — see [_tally]. `AnimatedBuilder` rather
                                    // than `setState` on every tick, so nothing else
                                    // on the report rebuilds sixty times a second.
                                    AnimatedBuilder(
                                      animation: _tally,
                                      builder: (context, _) {
                                        final single = _base + _quests;
                                        final both = single * 2;
                                        final climbing =
                                            _tallying || _tally.value > 0;
                                        final shown = climbing
                                            ? (single +
                                                    (both - single) *
                                                        Curves.easeOutCubic.transform(
                                                          _tally.value,
                                                        ))
                                                .round()
                                            : both;
                                        return StoreButton(
                                          key: const ValueKey('summary-double'),
                                          tone: StoreTone.ad,
                                          // While it climbs the label is the figure
                                          // and nothing else: the offer has been
                                          // taken, so "2× Coins" is a description of
                                          // something that already happened.
                                          label: climbing
                                              ? formatCoins(shown)
                                              : _answering
                                              ? t('common.loading')
                                              : '${t('match.double_reward')} → '
                                                    '${formatCoins(both)}',
                                          leading: climbing
                                              ? const CoinIcon(size: 14, solid: true)
                                              : _answering
                                              ? null
                                              : const GameIcon('video', size: 14),
                                          // Dead for the whole of it: the answer is
                                          // in and the screen is on its way out.
                                          onTap: _answering ? null : _double,
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // **AND SO DOES THE WAY OUT.** It was pinned on its own
                    // for a while — unpinning the payout had put "No Thanks" at
                    // 673 on a 600-point screen. Asked for anyway: it does not
                    // need to be fixed either. So the page is one scroll from
                    // the scoreline to the decline, and a phone short enough to
                    // cut the link off is a phone the player scrolls.
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child:
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
                                  // **A FIGURE IN THIS GAME COMES WITH THE GLYPH.**
                                  // Every other coin total on the report wears one
                                  // and this line did not, so the one number the
                                  // player is comparing against the button above it
                                  // was the one that did not say what it was counted
                                  // in. Asked for from the couch, and consistency is
                                  // the whole of the reason.
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${t('match.no_thanks')} - '),
                                      const CoinIcon(size: 12, onGlass: true),
                                      const SizedBox(width: 3),
                                      Text(formatCoins(_base + _quests)),
                                    ],
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
          _Score(
            left: left,
            right: right,
            leftGoals: leftGoals,
            rightGoals: rightGoals,
          ),
          // **WHO SCORED IS INSIDE THIS CARD, in a well of its own.** It was
          // its own panel twelve points below, which is two cards telling one
          // story: the scoreline and the names that made it. A scoreboard puts
          // them together and so does the shot this was taken from — one card,
          // the score across the top, the goals recessed underneath.
          _ScorersCard(result: result),
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
    final ink = verdictInk(context, won: won, drawn: drawn);
    return Text(
      label.toUpperCase(),
      key: const ValueKey('summary-verdict'),
      textAlign: TextAlign.center,
      // **THE DISPLAY FACE, and this is what it is for.** One word, read at a
      // glance, at a size where Barlow's `w900` is still a text weight. See
      // [displayText] — it drops the weight on purpose, because Lilita One
      // ships one cut and a `fontWeight` beside it is a synthesised smear.
      style: displayText(
        TextStyle(
          fontSize: 38,
          // Tighter than the 2 it wore: that was spacing chosen to give a
          // text face some presence, and a display face already has it — at
          // 38 points the same 2 reads as the letters coming apart.
          letterSpacing: 1,
          // **STILL THROUGH THE PANE RULE, even though there is no pane.**
          // Dropping `glassAccent` here looked right — the card it used to
          // clear is gone — and `light_mode_contrast_test` caught it at
          // 2.80:1: the daylight sky is as pale as the pane ever was, so the
          // scale's own green needs taking down exactly as much out here. The
          // shadow is on top of that, not instead of it.
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.45),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
          color: glassAccent(context, ink),
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
          '$leftGoals-$rightGoals',
          key: const ValueKey('summary-score'),
          // The other display run on this screen: two digits, read before any
          // word on the page. Tabular still, so 1-1 and 0-11 sit on the same
          // centre line.
          style: displayText(
            const TextStyle(
              fontSize: 34,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
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
    // **A WELL INSIDE THE RESULT CARD, not a card of its own.** It was a
    // second `GlassPanel` twelve points below the scoreline; it now sits in the
    // same card, in a recess — the same whisper-and-a-hairline the home
    // screen's quest block uses, because a solid wash inside a pane reads as a
    // hole punched through it rather than as depth.
    return Container(
      key: const ValueKey('summary-scorers'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
      decoration: BoxDecoration(
        color: glassInk(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: glassInk(context).withValues(alpha: 0.12)),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final g in goals)
              Row(
                children: [
                  // **A BALL, so the row reads as a goal before it is read at
                  // all.** Three names and three minutes in a box is a list of
                  // something; the glyph is what says of what. Asked for from
                  // the couch with the rest of the shot.
                  GameIcon('ball', size: 13, color: ink),
                  const SizedBox(width: 6),
                  // **THE MINUTE IS A COLUMN, on the left.** It trailed the
                  // name, so with three scorers the names started in three
                  // different places and the list had no left edge to read
                  // down. Fixed width and tabular figures, which is what makes
                  // it a column rather than a prefix.
                  SizedBox(
                    width: 26,
                    child: Text(
                      "${g.minute}'",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: ink.withValues(alpha: 0.75),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  // **THE WORD IS BESIDE THE GLYPH.** A bare ↺ on a row of
                  // scorers is a guess — it could as easily undo something —
                  // and this is the one control on the report a player has to
                  // discover rather than be told about. Asked for from the
                  // couch: say what the button does.
                  //
                  // `match.replay` is real shipped copy in all ten catalogues,
                  // added to the spec's `en.js` and regenerated, because there
                  // was no key for it and inventing one here would print
                  // English to nine other languages.
                  TextButton.icon(
                    key: ValueKey('summary-replay-${g.minute}'),
                    // A text link, not a moulded button: it sits on a row of
                    // names, and a face on it would outweigh the goal.
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: Icon(
                      _minute == g.minute ? Icons.stop : Icons.replay,
                      size: 16,
                      color: ink,
                    ),
                    label: Text(
                      t('match.replay'),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
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
    );
  }
}

class _Payout extends StatelessWidget {
  const _Payout({
    required this.base,
    required this.quests,
    required this.hasQuests,
    required this.doubled,
  });

  final int base;

  /// What the three match quests paid — already in the bank, and doubled by the
  /// same offer the fee is.
  final int quests;

  /// Whether the match had a quest TRACK, which is not the same as the track
  /// having paid. A defeat that missed all three is exactly the match whose
  /// total most needs breaking down — the split is the answer to "why only
  /// ten?" — so the rows follow the track's existence, not its takings.
  final bool hasQuests;

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
                    '+${formatCoins(doubled ? total * 2 : total)}',
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
        // **THE FIGURE IS TWO THINGS, so it says which.** The breakdown came
        // off when `2×` stopped applying to the fee alone: with no split left
        // in the OFFER, two rows adding up to the total above them looked like
        // clutter. What that missed is that the split is not about the offer —
        // a player who has just won 900 for the result and 300 off the quests
        // reads one gold `+1,200` and cannot tell which part the ninety minutes
        // earned. Asked for back in exactly those terms.
        //
        // Only when there are genuinely two parts: a row restating a total it
        // is the whole of is the clutter the removal was right about. And the
        // rows follow the offer — `2×` covers both now, so both double.
        //
        // **A MISSED TRACK STILL GETS ITS ROW, and that was the bug in the
        // first cut of this.** The condition was `quests > 0`, so the one
        // result that most needs explaining — a defeat, ten coins, all three
        // quests missed — was the one that showed no breakdown at all.
        // Reported from a live save with that exact screen.
        if (hasQuests) ...[
          const SizedBox(height: 8),
          _Split(
            // **THE SAME WORDS WHATEVER HAPPENED.** This read the verdict —
            // "Won", "Drew", "Lost" — which says a third time what the banner
            // and the scoreline above it have already said, and makes the two
            // rows a mismatched pair: one named after an outcome, one after a
            // thing. `play.match_prizes` is what the Play screen calls this
            // money before the match is played, so it is the same purse under
            // the same name at both ends. Asked for from the couch: something
            // that does not change on a defeat.
            label: t('play.match_prizes'),
            amount: doubled ? base * 2 : base,
          ),
          _Split(
            label: t('quests.match'),
            amount: doubled ? quests * 2 : quests,
          ),
        ],
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

/// One half of the payout, named.
///
/// Muted and small against the gold total above it: this is the working, and
/// the answer is the figure it sits under. The amount is tabular so the two
/// rows' digits line up under each other rather than drifting by a comma.
class _Split extends StatelessWidget {
  const _Split({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: glassMuted(context),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        key: ValueKey('summary-split-$label'),
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(
            '+${formatCoins(amount)}',
            style: style.copyWith(
              color: glassText(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
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
    return Column(
      key: const ValueKey('match-quests'),
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
        // **ONE TILE PER QUEST, and the tile is what does the work.**
        //
        // The verdict used to sit on its own line UNDER the ask, because with
        // the two side by side a long quest wrapped and "✕ Missed" parked
        // itself against the first of the two lines. That is a real problem and
        // it had a real cause, but the answer was the wrong one: three asks
        // each with a result stacked under it is six lines of loose text, and
        // it was reported twice.
        //
        // A tile fixes what the stacking was reaching for. The ask and its
        // verdict are on ONE line, the verdict right where a column of results
        // belongs — and when a long ask does take two lines, the fill and the
        // hairline are what keep the pair reading as one row, with the verdict
        // centred against both. That is the difference between a wrapped row
        // and two orphaned lines, and it is the shot this was taken from.
        for (final row in rows) _QuestTile(row: row, passed: passedInk, missed: missedInk),
        // **THE TOTAL IS A ROW, label left and figure right.** It was one
        // right-aligned sentence — "Total reward: 36 coins" — which is a
        // caption under a list rather than the list's own bottom line. Split,
        // it lines up with the three rows above it and reads as their sum.
        if (total > 0)
          Container(
            key: const ValueKey('match-quests-total'),
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              // The recess the tiles and the scorers' well wear, not a green
              // wash: with the figure in gold a green ground under it was two
              // colours arguing about what the row is.
              color: glassInk(context).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: glassInk(context).withValues(alpha: 0.12),
              ),
            ),
            // The label takes what the figure does not. This panel shares its
            // row with the dugout cam, so on a narrow phone it is barely a
            // hundred points wide — and once the figure is a glyph and a number
            // rather than "36 coins", there is room for the label to have the
            // rest without either overflowing.
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t('quests.total_reward').toUpperCase(),
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: glassMuted(context),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const CoinIcon(size: 12, onGlass: true),
                const SizedBox(width: 3),
                // The figure alone, for the same reason the rows dropped it:
                // the glyph beside it already says coins.
                Text(
                  formatCoins(total.toInt()),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  // Gold, for the same reason the rows are — see above.
                  style: TextStyle(
                    fontSize: 11.5,
                    color: coinFigureInk(context, onGlass: true),
                    shadows: coinFigureShadows(context, onGlass: true),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One quest at full time: what was asked, and how it went.
///
/// **The same shape the home screen's block uses** — glyph, ask, then a cell on
/// the right — so a quest looks like the same object before kick-off and after
/// the whistle. What changes is only what the right-hand cell holds: a target
/// there, a verdict here.
class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.row,
    required this.passed,
    required this.missed,
  });

  final Map<String, dynamic> row;
  final Color passed;
  final Color missed;

  @override
  Widget build(BuildContext context) {
    final won = row['passed'] == true;
    final ink = won ? passed : missed;
    // The data file names an icon and stays UI-free; this resolves it, the same
    // way `matchQuestRowsProvider` does. A quest with no definition still gets
    // a glyph rather than a hole in the row.
    final glyph = getQuest('${row['id']}')?.icon ?? 'target';
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: glassInk(context).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: glassInk(context).withValues(alpha: 0.12)),
      ),
      child: Row(
        // **CENTRED, and that is what makes a two-line ask survive.** Against
        // the top, a verdict beside a wrapped ask sticks to its first line and
        // the row comes apart — which is exactly the fault that drove the
        // verdict onto its own line last time.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // A passed quest wears the tick rather than its own glyph: it has
          // already paid, and what it asked for no longer matters. The home
          // block makes the same trade for a completed row.
          GameIcon(won ? 'check' : glyph, size: 14, color: ink),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              // Per-division text, interpolated off the target the quest was
              // set at rather than today's — a quest is judged on what it asked
              // for when it was drawn.
              t('quest.${row['id']}', {'n': row['target'] ?? 0}),
              // Two, for the one translated ask that cannot make a line even
              // with the whole width, and at the SAME size as every other row.
              // Ellipsising is not an option: a report that says the player
              // missed something without saying what is the fault this was all
              // for.
              maxLines: 2,
              style: TextStyle(
                color: won
                    ? glassText(context)
                    : glassText(context).withValues(alpha: 0.8),
                fontSize: 11.5,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // **THE RIGHT-HAND CELL IS GLYPHS AND A FIGURE, not a sentence.**
          //
          // It read "✓ 18 coins" and "✕ Missed", and in a cell this narrow both
          // wrapped onto two lines — so a column whose whole job is to be
          // scanned was the wordiest thing on the row. Asked for from the
          // couch: the coin glyph instead of the word "coins", and the cross on
          // its own instead of "Missed".
          //
          // **Nothing is lost by dropping them.** The coin is the currency and
          // says so better than the noun; a red ✕ against three rows where the
          // others show money is unambiguous. Both are also translation-free,
          // which is how this cell stopped needing two lines in any language.
          Row(
            key: ValueKey('match-quest-${row['id']}'),
            mainAxisSize: MainAxisSize.min,
            children: won
                ? [
                    const CoinIcon(size: 11, onGlass: true),
                    const SizedBox(width: 3),
                    Text(
                      formatCoins(((row['coins'] as num?) ?? 0).toInt()),
                      maxLines: 1,
                      // **GOLD, NOT THE VERDICT'S GREEN — always.** It took the
                      // pass colour, so the one coin figure on the report drawn
                      // in green sat two inches from four drawn in gold.
                      // Reported from the couch: coins are the yellow, always.
                      // The tick beside it is what says the quest passed; the
                      // figure says what it paid, and a currency does not change
                      // colour with the news. Same `coinFigureInk` every other
                      // total on this screen reads.
                      style: TextStyle(
                        color: coinFigureInk(context, onGlass: true),
                        shadows: coinFigureShadows(context, onGlass: true),
                        fontSize: 11.5,
                      ),
                    ),
                  ]
                : [Icon(Icons.close_rounded, size: 15, color: ink)],
          ),
        ],
      ),
    );
  }

}
