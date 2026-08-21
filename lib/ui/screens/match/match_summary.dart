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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/dugout_cam_policy.dart';
import 'package:merge_empire_fc/data/players.dart' show getPlayerDef;
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart'
    show managerLookProvider;
import 'package:merge_empire_fc/ui/screens/match/dugout_cam.dart';
import 'package:merge_empire_fc/ui/screens/squad/player_detail_sheet.dart'
    show cardById;
import 'package:merge_empire_fc/ui/theme/glass.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart' show PlayerFace;
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// The AdMob placement this screen asks for.
const String doubleMatchPlacement = 'double_match';

/// Show it, and answer the offer. Resolves once the player has continued.
Future<void> showMatchSummary(
  BuildContext context,
  Map<String, dynamic> result,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => MatchSummaryScreen(result: result),
  ),
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

  @override
  void initState() {
    super.initState();
    _base = _num(widget.result['coinsEarned']).toInt();
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
    final ourGoals = _num(result['ourGoals']).toInt();
    final theirGoals = _num(result['theirGoals']).toInt();
    final trophies = _num(result['trophiesEarned']).toInt();
    final canDouble = _base > 0;

    return Scaffold(
      key: const ValueKey('match-summary'),
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: skyGradient(
            brightness: Theme.of(context).brightness,
            tier: ref.watch(stadiumTierProvider),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                  children: [
                    _Verdict(won: won, drawn: drawn),
                    const SizedBox(height: 10),
                    _Score(
                      left:
                          '${isHome ? result['clubName'] : result['opponentName'] ?? ''}',
                      right:
                          '${isHome ? result['opponentName'] : result['clubName'] ?? ''}',
                      leftGoals: isHome ? ourGoals : theirGoals,
                      rightGoals: isHome ? theirGoals : ourGoals,
                    ),
                    const SizedBox(height: 12),
                    // **The manager, reacting to it.** The full-time shot used
                    // to be laid into the head of the commentary feed, where it
                    // sat above a wall of text nobody scrolls back to.
                    Center(
                      child: SizedBox(
                        width: 210,
                        child: _Manager(result: result),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Scorers(result: result),
                    const SizedBox(height: 10),
                    _Payout(base: _base, doubled: canDouble && _answering),
                    if (trophies > 0) ...[
                      const SizedBox(height: 8),
                      Center(
                        // A figure and the glyph, not a sentence: there is no
                        // shipped copy for "you won N trophies", and inventing a
                        // key the catalogues have never seen would print English
                        // in ten languages.
                        child: Row(
                          key: const ValueKey('summary-trophies'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GameIcon(
                              'trophy',
                              size: 16,
                              color: kit.accentBright,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+$trophies',
                              style: TextStyle(
                                color: kit.accentBright,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    QuestOutcomes(result: result),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: canDouble
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // **YELLOW, and it dominates.** This is the offer; the
                          // other answer is walking away, and walking away should
                          // not look like a second offer.
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('summary-double'),
                              onPressed: _answering ? null : _double,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: gameGold,
                                foregroundColor: const Color(0xFF2A1E00),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _answering
                                  ? Text(t('common.loading'))
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.play_circle_fill,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            '${t('match.double_reward')} → '
                                            '${formatCoins(_base * 2)}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
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
                            ),
                            child: Text(
                              '${t('match.no_thanks')} — '
                              '${formatCoins(_base)}',
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
      ),
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
    final kit = Theme.of(context).extension<KitTheme>()!;
    final (label, colour) = won
        ? (t('match.victory'), kit.accentBright)
        : drawn
        ? (t('match.draw'), kit.textMuted)
        : (t('match.defeat'), const Color(0xFFE07A5F));
    return Text(
      label.toUpperCase(),
      key: const ValueKey('summary-verdict'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        color: colour,
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
  Widget build(BuildContext context) => GlassPanel(
    density: GlassDensity.deep,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    child: Row(
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
    ),
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
    final ourGoals = _num(result['ourGoals']).toInt();
    final theirGoals = _num(result['theirGoals']).toInt();
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
          rota: (recent) =>
              camRotaBeat(mood, null, ref.read(gameProvider).state, recent),
        ),
      ),
    );
  }
}

/// Who scored, with their faces. Ours only — the engine picks scorers from our
/// squad, and a face for one of theirs cannot be drawn.
class _Scorers extends ConsumerWidget {
  const _Scorers({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final raw = result['events'];
    if (raw is! List) return const SizedBox.shrink();
    final save = ref.read(gameProvider).state;

    final rows = <Widget>[];
    for (final entry in raw) {
      final e = _map(entry);
      if (e == null || e['type'] != 'goal' || e['team'] != 'home') continue;
      final card = cardById(save, '${e['scorerInstanceId'] ?? ''}');
      final def = getPlayerDef(card?.definitionId);
      final name = card != null && def != null
          ? card.name(def.name)
          : '${e['scorer'] ?? ''}';
      if (name.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              if (card != null && def != null)
                PlayerFace(
                  position: def.position,
                  tier: def.tier,
                  variant: card.variant,
                  size: 26,
                  ring: kit.accentBright,
                )
              else
                Icon(Icons.sports_soccer, size: 18, color: kit.accentBright),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                "${_num(e['minute']).toInt()}'",
                style: TextStyle(color: kit.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return GlassPanel(
      key: const ValueKey('summary-scorers'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }
}

/// What the match paid — struck through and doubled while the video runs.
class _Payout extends StatelessWidget {
  const _Payout({required this.base, required this.doubled});

  final int base;
  final bool doubled;

  @override
  Widget build(BuildContext context) {
    if (base <= 0) return const SizedBox.shrink();
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Column(
      key: const ValueKey('summary-payout'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (doubled) ...[
              Text(
                '+${formatCoins(base)}',
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
            CoinIcon(size: 20, solid: true, color: coinFigureInk(context)),
            const SizedBox(width: 6),
            Text(
              '+${formatCoins(doubled ? base * 2 : base)}',
              key: const ValueKey('summary-coins'),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: coinFigureInk(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          t('match.double_teaser'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: kit.textMuted),
        ),
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
  const QuestOutcomes({required this.result, super.key});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
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

    return Padding(
      key: const ValueKey('match-quests'),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            ? kit.accentBright
                            : kit.textMuted,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    row['passed'] == true
                        ? t('quests.reward_coins', {'n': row['coins'] ?? 0})
                        : t('quests.missed'),
                    key: ValueKey('match-quest-${row['id']}'),
                    style: TextStyle(
                      color: row['passed'] == true
                          ? kit.accentBright
                          : kit.textMuted,
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
                  color: kit.accentBright,
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
