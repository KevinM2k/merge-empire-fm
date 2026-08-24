/// The button between the fixture list and the match.
///
/// It owns the whole round trip: spend the pip, simulate, push the takeover,
/// commit at full time and pay on dismissal. A screen that wants to offer a
/// match drops one of these in and nothing else.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/ui/widgets/bar_fill.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/engine/rating_prompt.dart';
import 'package:merge_empire_fc/engine/match_orchestration.dart';
import 'package:merge_empire_fc/engine/sponsor_engine.dart';
import 'package:merge_empire_fc/engine/transfer_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_result_cards.dart';
import 'package:merge_empire_fc/ui/screens/match/match_launcher.dart';
import 'package:merge_empire_fc/ui/screens/match/match_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/match_summary.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_button.dart';
import 'package:merge_empire_fc/services/store_review.dart';
import 'package:merge_empire_fc/ui/screens/season/season_end_screen.dart';
import 'package:merge_empire_fc/ui/screens/match/cup_sponsor_offer.dart';
import 'package:merge_empire_fc/ui/screens/transfers/sponsor_offer_card.dart';
import 'package:merge_empire_fc/ui/screens/transfers/transfer_offer_card.dart';
import 'package:merge_empire_fc/ui/popups/energy_sheet.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/popup_queue.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/time.dart';

/// Why the button is dead, in copy that already ships.
String matchBlockedCopy(String reason, Map<String, dynamic>? state) =>
    switch (reason) {
      'no_energy' => t('toast.no_energy'),
      'squad_too_small' => t('squad.no_players'),
      'season_over' => t('play.season_over'),
      'cooldown' => t('play.cooldown', {
        'time': state == null
            ? ''
            : formatDuration(matchCooldownRemaining(state)),
      }),
      _ => t('settings.comingSoon'),
    };

final matchBlockedProvider = savePick<String?>(matchStartBlocked);

/// The round a due cup tie belongs to, or null when the next match is a league
/// one. A String rather than the record, because `savePick` compares with `==`
/// and the cup object is not what the button needs.
final cupRoundProvider = savePick<String?>((s) => nextCupRound(s)?.roundName);

/// The match's own route, which LEAVES INSTANTLY.
///
/// **The Play tab was on screen between the whistle and the result.** A
/// `MaterialPageRoute` spends three hundred milliseconds sliding a finished
/// match back down, and the awaited push does not resolve until it has — so the
/// summary could not even be asked for until the home page had been fully
/// revealed and sat there. Reported as the home page showing before the
/// end-of-game screen.
///
/// Only the exit is instant, and only for the league match: the entrance is
/// still the takeover it should be, and the summary's own entrance covers the
/// single frame this leaves behind. A cup tie keeps the normal exit, because
/// there is no summary behind it to cover anything.
class MatchRoute<T> extends MaterialPageRoute<T> {
  MatchRoute({required super.builder}) : super(fullscreenDialog: true);

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

/// **THE PLAY BUTTON'S CHROME, as `glass.css` writes it.**
///
/// Six layers and a rim, and the stylesheet's own comment says why there are
/// three shadows rather than one: "the diffuse far shadow alone reads as a
/// glow; what actually lifts a button off the pitch is the tight contact
/// shadow right under its edge, with the mid and far passes carrying the
/// height."
///
/// Named here so a test can compare each number against the CSS rather than
/// against a screenshot. **That is not the same as a device pass** — nobody has
/// looked at this on hardware, which is what the M5 row asks for — but it is
/// the difference between "matched" as a claim and "matched" as something the
/// build re-checks. Pinning it caught the label's shadow at 0.40 where the
/// stylesheet says 0.45.
typedef PlayButtonLayer = ({double dy, double blur, double spread, double alpha});

/// `0 2px 3px`, `0 7px 12px`, `0 16px 32px` — contact, mid, far.
const List<PlayButtonLayer> playButtonChrome = [
  (dy: 2, blur: 3, spread: 0, alpha: 0.4),
  (dy: 7, blur: 12, spread: 0, alpha: 0.34),
  (dy: 16, blur: 32, spread: 0, alpha: 0.46),
];

/// `0 0 20px 2px var(--color-accent-glow)`.
const PlayButtonLayer playButtonGlow = (
  dy: 0,
  blur: 20,
  spread: 2,
  alpha: 0.45,
);

/// `1px solid rgba(255,255,255,0.55)`, and it is ONE pixel: the pop is the
/// bevel and the shadows, and a heavy white stroke over those reads as a
/// sticker.
const double playButtonRimAlpha = 0.55;
const double playButtonRimWidth = 1;

/// `0 1px 3px rgba(0,0,0,0.45)` on the label, which has to clear a gradient
/// running bright at the top and dark at the bottom.
const double playButtonLabelShadowAlpha = 0.45;

class PlayMatchButton extends ConsumerWidget {
  const PlayMatchButton({super.key, this.fast = false});

  final bool fast;

  /// What holds the popup queue shut for the length of a match.
  static const String _matchBlocker = 'match';

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    // A cup tie takes precedence when one is due. Cups sit BETWEEN league games,
    // so this does not cost the league a fixture — it inserts a match.
    if (ref.read(cupRoundProvider) != null) {
      await _playCup(context, ref);
      return;
    }

    final result = game.update(beginMatch);
    if (result == null || !context.mounted) return;

    // **Nothing pops over a match.** The JS suppresses coach tips on
    // `match:open`; blocking the QUEUE covers every popup rather than only that
    // one — the welcome-back card could land on the pitch too.
    blockPopups(_matchBlocker);
    await Navigator.of(context).push<void>(
      MatchRoute(
        builder: (_) => MatchScreen(
          result: result,
          fast: fast,
          // Full time, with the screen still up: commit the outcome so the
          // table and the season move on.
          onFinished: (r) => game.update((s) => settleMatch(s, r)),
        ),
      ),
    );

    // **THE SUMMARY, and only then the money.** `payMatch` has always been
    // deferred to here on purpose — the doubling offer lives on the closing
    // screen — and until the summary existed there was no offer to defer for.
    // It doubles `coinsEarned` on the result in place when the video is
    // watched, so what lands is what the screen last said.
    if (context.mounted) await showMatchSummary(context, result);
    game.update((s) => payMatch(s, result));

    if (!context.mounted) {
      unblockPopups(_matchBlocker);
      return;
    }
    await _afterMatch(context, ref, result);
    // The screen is gone and any bid or sponsor has been answered. **CLOSE, not
    // complete**: a coach tip fired on the whistle would land over the result.
    unblockPopups(_matchBlocker);
    emit('match:close');
  }

  /// The same round trip for a cup tie.
  ///
  /// Two differences, both the engine's: the prize is paid by `commitCupRound` at
  /// full time rather than deferred — a cup has no doubling offer — and a win can
  /// drop a sponsor, which is offered once the screen is gone.
  Future<void> _playCup(BuildContext context, WidgetRef ref) async {
    final game = ref.read(gameProvider);
    final tie = game.update(beginCupRound);
    if (tie == null || !context.mounted) return;
    // **Captured BEFORE the round is committed**, because committing it moves
    // the round counter — so read afterwards, "which round did we just play"
    // is already the wrong answer.
    final cup = getCupById(activeCup(game.state)?['cupId'] as String?);
    final playedRound = tie.prepared.round;

    CupSponsorDrop? drop;
    blockPopups(_matchBlocker);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MatchScreen(
          result: tie.result,
          fast: fast,
          onFinished: (_) => drop = game.update((s) => settleCupRound(s, tie)),
        ),
      ),
    );

    // The cooldown starts once the player is back on the Play screen rather than
    // at the final whistle — `commitCupRound` stamps it too, but only as a floor.
    game.update(startMatchCooldown);
    if (!context.mounted) return;

    // **THE CUP REACTS, and it never did.** Twenty-odd `cup.round_win.*`,
    // `cup.knocked_out.*` and `cup.banner.*` strings shipped in ten languages
    // with no caller: a round won and a run ended were the same event from the
    // screen's side — a scoreline, a toast, and back to the Play tab.
    //
    // BEFORE the sponsor offer, which is the JS's order and the right one: what
    // just happened comes before what it earned you.
    if (cup != null) await _sayHowItWent(context, cup, playedRound, tie);
    if (!context.mounted) return;

    final sponsor = drop;
    if (sponsor != null) await showCupSponsorOffer(context, ref, sponsor);
    unblockPopups(_matchBlocker);
    emit('match:close');
  }

  /// Through, out, or the trophy.
  Future<void> _sayHowItWent(
    BuildContext context,
    Cup cup,
    int round,
    CupTie tie,
  ) async {
    final roundName = round < cup.rounds.length
        ? cup.rounds[round]
        : t('cup.tip.generic_round');
    if (!tie.prepared.won) {
      return showCupKnockedOut(
        context,
        cupName: t('cup.${cup.id}') == 'cup.${cup.id}'
            ? cup.name
            : t('cup.${cup.id}'),
        roundName: roundName,
        wasFinal: round == cup.rounds.length - 1,
        wasSemi: round == cup.rounds.length - 2,
      );
    }
    final next = cupNextRoundName(cup, round);
    if (next == null) {
      // Won the final: the trophy, not a "through to" card for a round that
      // does not exist.
      return showCupWon(
        context,
        cupName: t('cup.${cup.id}') == 'cup.${cup.id}'
            ? cup.name
            : t('cup.${cup.id}'),
      );
    }
    return showCupRoundWin(
      context,
      nextRoundName: next,
      nextIsFinal: round + 1 == cup.rounds.length - 1,
      nextIsSemi: round + 1 == cup.rounds.length - 2,
    );
  }

  /// What arrives once the result screen is gone.
  ///
  /// The order is the JS's and it matters: a transfer bid takes the slot if
  /// there is one, and only a match with no bid rolls for a sponsor. Two cards
  /// stacked on one dismissal is how the JS ended up with three surfaces for
  /// one question.
  ///
  /// **`maybeGenerateOffer` had no caller at all.** Post-match bids never fired,
  /// which left the idle roll as the only source — and nothing showed that
  /// either, so it timed out after five minutes and the timeout is scored as a
  /// decline. Players were collecting grudges from bids they were never shown.
  Future<void> _afterMatch(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> result,
  ) async {
    final game = ref.read(gameProvider);

    // This match's fresh roll. Null when one was already pending, in which case
    // the pending one is what gets answered.
    game.update(
      (s) => maybeGenerateOffer(
        s,
        opponentRating: (result['opponentRating'] as num?) ?? 55,
      ),
    );

    if (ref.read(pendingOfferProvider) != null) {
      if (!context.mounted) return;
      await showTransferOffer(context, ref);
      // A bid answered is enough for one match.
      return;
    }

    final sponsor = game.state == null
        ? null
        : maybeGenerateSponsorshipOffer(game.state!);
    if (sponsor != null) {
      if (!context.mounted) return;
      await showSponsorOffer(
        context,
        ref,
        player: sponsor.player,
        company: sponsor.company,
      );
      // A sponsor answered is enough for one match too — see below.
      return;
    }

    // **AND ONLY IF NOTHING ELSE ASKED FOR ANYTHING: the review sheet.** The
    // JS's own position, at the foot of this chain after every modal branch has
    // returned, and its reasoning is the reasoning for the whole file — a good
    // win is a good moment to be asked, and a good win that has just been
    // followed by a bid and a sponsor is not.
    //
    // **A GOOD win, not a win**: two goals clear, eight matches into a career.
    // `engine/rating_prompt.dart` carries the cap and the cooldown, because the
    // OS will not tell us it has stopped showing the sheet.
    final state = game.state;
    if (state == null) return;
    if (!shouldPromptRating(
      state,
      won: result['won'] == true,
      homeGoals: (result['homeGoals'] as num?)?.toInt() ?? 0,
      awayGoals: (result['awayGoals'] as num?)?.toInt() ?? 0,
    )) {
      return;
    }
    game.update((s) => recordRatingShown(s));
    unawaited(requestNativeReview());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A finished season is not a refusal to explain, it is a different button:
    // the way on is to close the season, and telling the player "no" without
    // offering it is the dead end this replaced.
    if (ref.watch(seasonCompleteProvider)) return const EndSeasonButton();

    final blocked = ref.watch(matchBlockedProvider);
    final pro = ref.watch(hardModeProvider);

    // A due cup tie renames the button, because it is a different match: the
    // round is the headline, and a player who taps Play expecting a league game
    // and gets a semi-final has been ambushed by their own fixture list.
    final cupRound = ref.watch(cupRoundProvider);

    // **Out of energy does not DISABLE it.** A dead button is a dead end, and the
    // footer's refill row is gone — so at zero pips it stays tappable and becomes
    // the route to the energy sheet. Casual only: in Pro the blocker is a tired
    // squad, which no sheet can fix, so that one really is dead and says so.
    final energyDetour = !pro && blocked == 'no_energy';
    // The cooldown must not disable it while that detour is on either. Both
    // clocks run after a match, and at zero energy the cooldown used to fall
    // through and grey the button out with no explanation — leaving a player
    // blocked on two timers and told about neither. Energy is the one they can
    // do something about, so it wins and the cooldown says nothing.
    final inCooldown = blocked == 'cooldown' && !energyDetour;
    final dead = blocked != null && !energyDetour && !inCooldown;

    return _PlayButtonFace(
      cupRound: cupRound,
      dead: dead,
      inCooldown: inCooldown,
      energyDetour: energyDetour,
      pro: pro,
      onTap: dead
          ? null
          : energyDetour
          ? () => showEnergySheet(context, ref)
          : () => _play(context, ref),
    );
  }
}

/// The button's face: the gradient, the sweep, the glyph and the cost.
///
/// Stateful because the cooldown is a CLOCK — the label counts down and the mask
/// sweeps with it, which needs a ticker rather than a rebuild on save changes.
class _PlayButtonFace extends ConsumerStatefulWidget {
  const _PlayButtonFace({
    required this.cupRound,
    required this.dead,
    required this.inCooldown,
    required this.energyDetour,
    required this.pro,
    required this.onTap,
  });

  final String? cupRound;
  final bool dead;
  final bool inCooldown;
  final bool energyDetour;
  final bool pro;
  final VoidCallback? onTap;

  @override
  ConsumerState<_PlayButtonFace> createState() => _PlayButtonFaceState();
}

class _PlayButtonFaceState extends ConsumerState<_PlayButtonFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    // The sweep across the face. 2.8s in the JS, and it is the only thing on the
    // home screen that moves while nothing is happening.
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A glint on an idle button is the first thing reduce-motion should lose, and
    // a looping animation is also what stops a widget test settling.
    if (MediaQuery.of(context).disableAnimations) {
      if (_shimmer.isAnimating) _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final isCup = widget.cupRound != null;

    return RepaintBoundary(
      // **THREE EDGES, and a glow.** A white rim alone was not enough: the face
      // is the club's colours, the club's colours are green as often as not, and
      // this button sits on green turf — so rim, face and background were all
      // one hue apart and the one control the screen exists for read as a patch
      // of the pitch.
      //
      // **THREE SHADOWS, NOT ONE**, and the JS's own comment says why: "the
      // diffuse far shadow alone reads as a glow; what actually lifts a button
      // off the pitch is the tight contact shadow right under its edge, with the
      // mid and far passes carrying the height". The port had the far pass and
      // the glow and neither of the other two, which is exactly why it sat flat
      // on the grass instead of standing off it.
      //
      // The dark outer ring the port added is gone with them. It was there to
      // guarantee an edge on any kit — a green button on green grass — and the
      // contact shadow does that job properly, which is what the JS relies on.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: widget.dead
              ? null
              : [
                  // Contact, mid, far — see [playButtonChrome]. The first is
                  // tight and right under the edge, and it is the one that
                  // does the work.
                  for (final layer in playButtonChrome)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: layer.alpha),
                      blurRadius: layer.blur,
                      spreadRadius: layer.spread,
                      offset: Offset(0, layer.dy),
                    ),
                  // And the accent glow, which is what makes it read as LIT
                  // rather than painted on.
                  BoxShadow(
                    color: kit.accent.withValues(alpha: playButtonGlow.alpha),
                    blurRadius: playButtonGlow.blur,
                    spreadRadius: playButtonGlow.spread,
                  ),
                ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            // The JS's own rim: ONE pixel at 55%, not two at 85%. The pop was
            // never the border's boldness — it is the bevel and the shadows
            // below, and a heavy white stroke on top of those reads as a sticker.
            border: Border.all(
              color: Colors.white.withValues(
                alpha: widget.dead ? 0.22 : playButtonRimAlpha,
              ),
              width: playButtonRimWidth,
            ),
          ),
          child: ClipRRect(
            // A hair inside the rim, so no sliver of face shows past the stroke
            // on the corners.
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: widget.dead
                        ? null
                        : isCup
                        // A cup keeps the old prestige CTA's purple→amber, so the
                        // action holds its colour wherever it turns up.
                        ? const LinearGradient(
                            begin: Alignment(-0.6, -1),
                            end: Alignment(0.6, 1),
                            colors: [
                              Color(0xFF9A46E0),
                              Color(0xFF7B2FBE),
                              Color(0xFFFFB300),
                            ],
                            stops: [0, 0.46, 1],
                          )
                        : LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [kit.accentBright, kit.accent],
                          ),
                    color: widget.dead ? kit.surface2 : null,
                  ),
                  child: const SizedBox(width: double.infinity, height: 48),
                ),
                // **THE BEVEL.** `inset 0 1px 0 rgba(255,255,255,0.55)` and
                // `inset 0 -2px 0 rgba(0,0,0,0.22)` in the JS — a lit line along
                // the top inside edge and a dark one along the bottom. Flutter
                // has no inset shadow, so they are drawn; between them they are
                // most of what makes the face read as a raised surface rather
                // than a coloured rectangle.
                if (!widget.dead) ...[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: ColoredBox(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 2,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ),
                  // The sheen — the JS's `::before`. Bright at the top, gone by
                  // the middle, faintly dark at the foot, which is what curves
                  // the face.
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x47FFFFFF),
                              Color(0x14FFFFFF),
                              Color(0x00FFFFFF),
                              Color(0x1F000000),
                            ],
                            stops: [0, 0.42, 0.54, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // The cooldown fill, sweeping right to left as the timer runs down.
                if (widget.inCooldown) Positioned.fill(child: _CooldownMask()),
                if (!widget.dead && _shimmer.isAnimating)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _shimmer,
                        builder: (context, _) => _Shimmer(t: _shimmer.value),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('play-match'),
                      onTap: widget.onTap,
                      child: Center(child: _Label(widget: widget)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends ConsumerWidget {
  const _Label({required this.widget});

  final _PlayButtonFace widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final ink = widget.dead ? kit.textMuted : Colors.white;
    final blocked = ref.watch(matchBlockedProvider);

    // The glyph says which of three states this is: play, paused on a clock, or
    // a squad with nothing left in it.
    final glyph = widget.inCooldown
        ? 'pause'
        : (widget.pro && blocked == 'no_energy')
        ? 'bolt'
        : 'play';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameIcon(glyph, size: 20, color: ink),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _labelFor(context, ref),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: ink,
              // The shadow lifts the label off a gradient that runs bright at
              // the top and dark at the bottom. A blocked face is lower
              // contrast with more words in the same width, where a blur under
              // every letter is what makes them hard to read rather than what
              // saves them — so it comes off there.
              shadows: widget.dead
                  ? null
                  : const [
                      Shadow(
                        // `0 1px 3px rgba(0,0,0,0.45)` — the stylesheet's own,
                        // and it was 0.40 here. See `playButtonChrome`.
                        color: Color(0x73000000), // playButtonLabelShadowAlpha
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
            ),
          ),
        ),
        // What it costs, on the button. Casual only: Pro spends per-player
        // fatigue instead, and a pip figure there would be a price nothing
        // charges. Hidden during a cooldown, where the clock is the message.
        if (!widget.pro && !widget.inCooldown) ...[
          const SizedBox(width: 6),
          Opacity(
            opacity: 0.8,
            child: Row(
              key: const ValueKey('play-energy-cost'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${Energy.matchCost}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
                Text('⚡', style: TextStyle(fontSize: 13, color: ink)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _labelFor(BuildContext context, WidgetRef ref) {
    if (widget.inCooldown) {
      final state = ref.read(gameProvider).state;
      final remaining = state == null ? 0 : matchCooldownRemaining(state);
      final secs = (remaining / 1000).ceil();
      final time = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
      return t('play.cooldown', {'time': time});
    }
    if (widget.cupRound != null) {
      return '🏆 ${t('cup.play_round_btn', {'round': widget.cupRound})}';
    }
    // Pro's blocker is a tired squad and the button really is dead, so it says
    // so. Casual keeps saying Play Match at zero energy: the intent has not
    // changed, only the road there — relabelling it turned the one fixed button
    // on the screen into a shop door.
    final blocked = ref.watch(matchBlockedProvider);
    if (widget.pro && blocked == 'no_energy') return t('play.squad_tired');
    if (blocked == 'squad_too_small') return t('squad.no_players');
    return t('play.playMatch');
  }
}

/// The cooldown fill. Ticks at 100ms and moves by a sub-percent each time, so
/// the sweep reads as continuous — rounding to whole percent made it jump once
/// every couple of seconds on a thirty-minute clock.
class _CooldownMask extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CooldownMask> createState() => _CooldownMaskState();
}

class _CooldownMaskState extends ConsumerState<_CooldownMask> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.read(gameProvider).state;
    if (state == null) return const SizedBox.shrink();
    final total = effectiveCooldownMs(state);
    final fraction = total <= 0
        ? 0.0
        : (matchCooldownRemaining(state) / total).clamp(0.0, 1.0);
    return BarFill(
      // From the right: what is left of the clock is the part still masked, so
      // the bright face grows out from the left as the wait runs down.
      alignment: Alignment.centerRight,
      fraction: fraction,
      child: ColoredBox(color: Colors.black.withValues(alpha: 0.68)),
    );
  }
}

/// A diagonal band of light crossing the face.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    // -1 → 2 across the cycle, held still for the first part of it so the sweep
    // reads as an occasional glint rather than a constant crawl.
    final x = -1 + (t.clamp(0.43, 1.0) - 0.43) / 0.57 * 3;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(x - 0.4, -1),
          end: Alignment(x + 0.4, 1),
          colors: const [
            Colors.transparent,
            Color(0x1FFFFFFF),
            Colors.transparent,
          ],
          stops: const [0.4, 0.5, 0.6],
        ),
      ),
    );
  }
}
