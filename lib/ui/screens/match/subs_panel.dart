/// Substitutions, mid-match.
///
/// **Nothing in the port could make one**, and the tells were the usual ones:
/// twenty `match.subs.*` strings translated in ten catalogues with nothing able
/// to reach one; `subsUsed` and `subbedOnIds` written into every result at
/// kickoff and never moved off zero; and `match_use_subs` and `match_sub_scores`
/// — two quests that could not advance.
///
/// **A substitution does NOT re-decide the match**, and that is the source's own
/// rule rather than a limitation here: the ninety minutes were settled at
/// kickoff and a change of personnel is a change the manager made, counted as
/// such. Only a change of TACTIC re-rolls the remainder. What a sub does is swap
/// the lineup in the save, and the match screen puts the kickoff eleven back at
/// full time so a substitution cannot quietly become next week's team.
///
/// **IT IS THE SAME PITCH AS THE SQUAD TAB.** It was two scrolling lists, which
/// asks the manager to hold the shape in their head and rebuild it from position
/// labels — while the shape is the whole information, and they have already
/// learnt where everybody is from the Squad tab. So: the eleven in position on
/// [PitchBoard], a tap opens the bench from the bottom the way the Squad tab
/// does, and a tap there asks before it does anything. A hurt player wears a
/// cross and reads zero, because zero is what the sim scores him.
///
/// One rule survives from the lists and it is the important one: an EMPTY slot
/// needs no first tap. There is nobody to withdraw, which is the injury case.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/screens/grid/grid_providers.dart';
import 'package:merge_empire_fc/ui/screens/squad/pitch_token.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_pitch.dart';
import 'package:merge_empire_fc/ui/screens/squad/squad_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
import 'package:merge_empire_fc/ui/widgets/match_stat_rows.dart'
    show vsGreenOn, vsRedOn;
import 'package:merge_empire_fc/ui/theme/app_theme.dart' show minFontSize;
import 'package:merge_empire_fc/ui/screens/squad/squad_pickers.dart'
    show PositionFilterBar;
import 'package:merge_empire_fc/engine/squad_rating.dart'
    show CardStats, getCardStats;

/// One change, as the match screen needs to hear about it.
typedef SubMade = ({String? offId, String onId, String slotId});

/// Open the panel. Resolves when the manager is done with it.
Future<void> showSubsPanel(
  BuildContext context, {
  required int used,
  required Set<String> withdrawn,
  required void Function(SubMade) onSub,
  String? openOn,
}) => showBottomSheetPopup<void>(
  context,
  heightFraction: 0.92,
  child: SubsPanel(
    used: used,
    withdrawn: withdrawn,
    onSub: onSub,
    openOn: openOn,
  ),
);

class SubsPanel extends ConsumerStatefulWidget {
  const SubsPanel({
    super.key,
    required this.used,
    required this.withdrawn,
    required this.onSub,
    this.openOn,
  });

  /// How many changes have already been made this match.
  final int used;

  /// Everyone already taken off, THIS MATCH.
  ///
  /// The match screen's own set, handed in live rather than copied: the rule is
  /// about the ninety minutes, not about one opening of this sheet, and holding
  /// it here is what let a closed-and-reopened panel put a substituted man back
  /// on. Additions land through [onSub], so the set this reads is the same one
  /// the screen is writing.
  final Set<String> withdrawn;

  final void Function(SubMade) onSub;

  /// A slot to arrive with the bench already open on.
  ///
  /// The injury case: somebody has gone down, the sim has already vacated their
  /// slot, and asking the manager to tap the hole before they can tap a
  /// replacement is asking them to answer a question they were just told the
  /// answer to.
  final String? openOn;

  @override
  ConsumerState<SubsPanel> createState() => SubsPanelState();
}

class SubsPanelState extends ConsumerState<SubsPanel> {
  /// Changes made since the panel opened, on top of [SubsPanel.used].
  int _made = 0;

  /// The slot whose bench is open, or was opened for it.
  String? _openFor;

  @override
  void initState() {
    super.initState();
    final open = widget.openOn;
    if (open == null) return;
    _openFor = open;
    // Straight to the bench, because the manager has just been TOLD there is a
    // hole. Deferred a frame: there is no route to push a sheet onto until this
    // one is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openBench(open, null);
    });
  }

  /// Test seams.
  int get left => PlayerEnergy.maxSubs - widget.used - _made;
  String? get selectedSlot => _openFor;

  /// Tapping somebody on the pitch: he is the one coming off, and the bench
  /// opens to answer with.
  void _pick(PitchSlot slot) {
    if (left <= 0) return;
    final on = slot.cardInstanceId;
    // Somebody already withdrawn cannot be withdrawn again. An empty slot is
    // always a candidate — that is the injury case.
    if (on != null && widget.withdrawn.contains(on)) return;
    setState(() => _openFor = slot.slotId);
    _openBench(slot.slotId, on);
  }

  /// The bench, from the bottom, the way the Squad tab opens it. A null
  /// [slotId] is a look rather than a choice — see [_BenchSheet.slotId].
  Future<void> _openBench(String? slotId, String? offId) async {
    await showBottomSheetPopup<void>(
      context,
      heightFraction: 0.66,
      child: _BenchSheet(
        slotId: slotId,
        offId: offId,
        spent: widget.withdrawn,
        onChosen: (onId) => slotId == null
            ? Future.value(false)
            : _confirmAndApply(slotId, offId, onId),
      ),
    );
    if (mounted) setState(() => _openFor = null);
  }

  /// Ask, then do it.
  ///
  /// Returns whether the change went through, so the bench sheet knows whether
  /// to close: a manager who says no is still choosing, and taking the bench
  /// away from them would make trying somebody else cost a whole extra journey.
  Future<bool> _confirmAndApply(
    String slotId,
    String? offId,
    String onId,
  ) async {
    if (left <= 0) return false;
    // The write path enforces availability too, not just the list: a panel
    // rendered before a deal went through must never put a player who is at
    // another club onto the pitch.
    final state = ref.read(gameProvider).state;
    final coming = _cardById(state, onId);
    if (coming == null || !coming.isSelectable) return false;
    final going = offId == null ? null : _cardById(state, offId);

    // **HE SHOWS THE SWAP, he does not just name it.** The card was a
    // `showCoachCard` — the heading `match.subs` over the FEED line, which is
    // the sentence written for the commentary after the change has happened —
    // so a confirmation that decides who plays the rest of the match read as
    // "Subs" and a caption. Reported from the couch as the coach not confirming
    // who you are swapping.
    //
    // Two faces and an arrow between them is the answer: the manager has been
    // picking from cards for the whole journey here, and the two cards are what
    // they picked. The line stays underneath — `match.subs.feed` already says
    // "{off} off, {on} on." in ten languages and `match.subs.feed_on` covers
    // the hole, and no new key can be added from this repo — and the buttons
    // carry the question, which is what Confirm and Cancel are for.
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: coachCardScrim,
      builder: (dialogContext) => CoachCardFrame(
        key: const ValueKey('subs-confirm'),
        title: t('match.subs'),
        body: t(
          going == null ? 'match.subs.feed_on' : 'match.subs.feed',
          {
            if (going != null) 'off': going.name(),
            'on': coming.name(),
          },
        ),
        actions: [
          CoachAction(
            labelKey: 'common.confirm',
            tone: CoachTone.confirm,
            onTap: () {},
            result: true,
          ),
          CoachAction(
            labelKey: 'common.cancel',
            tone: CoachTone.decline,
            onTap: () {},
            result: false,
          ),
        ],
        child: _SwapPreview(going: going, coming: coming),
      ),
    );
    if (ok != true || !mounted) return false;

    ref.read(gameProvider).update((s) {
      final squad = s['squad'];
      if (squad is! Map<String, dynamic>) return;
      final lineup = squad['lineup'];
      if (lineup is! List) return;
      for (final row in lineup) {
        if (row is Map<String, dynamic> && row['slotId'] == slotId) {
          row['cardInstanceId'] = onId;
        }
      }
    });
    // The screen adds him to `withdrawn` off the back of `onSub`, so nothing
    // here has to remember it too.
    setState(() => _made++);
    widget.onSub((offId: offId, onId: onId, slotId: slotId));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(pitchSlotsProvider);
    final none = left <= 0;

    return Column(
      key: const ValueKey('subs-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('match.subs'),
          subtitle: none ? t('match.subs.none_left') : t('match.subs.pick_off'),
        ),
        Expanded(
          child: PitchBoard(
            slots: slots,
            slotBuilder: (context, slot) => _SubSlot(
              slot: slot,
              enabled:
                  !none &&
                  (slot.cardInstanceId == null ||
                      !widget.withdrawn.contains(slot.cardInstanceId)),
              onTap: () => _pick(slot),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            children: [
              // **The bench, before nominating anybody.** Who is available is
              // half of deciding who to take off, and needing to pick a man
              // first to find out made that a chicken and an egg.
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('subs-view-bench'),
                  onPressed: () => _openBench(null, null),
                  child: Text(t('match.subs.bench')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('subs-done'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(t('match.subs.done')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One place on the pitch, as this panel needs it: tappable, and dimmed once the
/// man in it has already been withdrawn.
class _SubSlot extends ConsumerWidget {
  const _SubSlot({
    required this.slot,
    required this.enabled,
    required this.onTap,
  });

  final PitchSlot slot;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = slot.card;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        key: ValueKey('sub-slot-${slot.slotId}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        // **THE INJURED MAN STAYS ON THE PITCH.** The slot empties when he goes
        // down, and a gap says somebody is missing without saying WHICH — on
        // the one panel whose whole job is picking his replacement. So he is
        // drawn in his own slot, rated zero (which is what the sim scores him
        // anyway) and crossed through by the token's own [InjuryCross]. If the
        // manager does not tap him he is off the pitch and worth nothing
        // regardless; drawn is the version they can act on.
        //
        // A slot that is empty for any OTHER reason still reads as a hole.
        child: card == null
            ? (slot.vacatedBy == null
                  ? Tooltip(
                      message: t('match.subs.injury_hole'),
                      child: PitchEmptySlot(position: slot.slotPosition),
                    )
                  : PitchToken(
                      slot: (
                        slotId: slot.slotId,
                        slotPosition: slot.slotPosition,
                        x: slot.x,
                        y: slot.y,
                        cardInstanceId: null,
                        card: slot.vacatedBy,
                        vacatedBy: null,
                        outOfPosition: false,
                        effRating: 0,
                        penalty: 0,
                        seasons: 0,
                      ),
                      proMode: ref.watch(proModeProvider),
                    ))
            : PitchToken(slot: slot, proMode: ref.watch(proModeProvider)),
      ),
    );
  }
}

/// The bench, as real cards — the Squad tab's own sheet, with a different answer
/// to a tap.
class _BenchSheet extends ConsumerStatefulWidget {
  const _BenchSheet({
    required this.slotId,
    required this.offId,
    required this.spent,
    required this.onChosen,
  });

  /// The slot being filled, or null when the manager is only LOOKING.
  ///
  /// Seeing who is on the bench is half of deciding who to take off, and the
  /// panel used to make that a chicken and an egg: you had to nominate somebody
  /// before you were shown the alternatives.
  final String? slotId;
  final String? offId;
  final Set<String> spent;

  /// Resolves true once the change has gone through, which is when this closes.
  final Future<bool> Function(String onId) onChosen;

  @override
  ConsumerState<_BenchSheet> createState() => _BenchSheetState();
}

class _BenchSheetState extends ConsumerState<_BenchSheet> {
  /// Which line the bench is narrowed to, or null until the sheet has worked
  /// out what the hole is.
  ///
  /// **PRE-SET TO THE MAN COMING OFF.** A bench of nineteen is a wall of faces
  /// and the one question being asked is "who else plays HERE" — the ordering
  /// answers it first but does not answer it only. Asked for from the couch: a
  /// quick GK/DEF/MID/ATK filter, auto-selected to the outgoing player's
  /// position. `PositionFilterBar` is the Squad tab's own and is on every other
  /// bench in the game.
  String? _line;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final slotId = widget.slotId;
    final spent = widget.spent;
    // **ORDERED FOR THE HOLE, not by where the card sits in the grid.** The men
    // who play there lead, best first, and the rest follow in the same order —
    // see [benchForSlotProvider]. A bench in grid order is a bench in no order
    // at all, and this is the one moment a manager reads it against a clock.
    final slotPosition = slotId == null
        ? null
        : ref
              .watch(pitchSlotsProvider)
              .where((slot) => slot.slotId == slotId)
              .map((slot) => slot.slotPosition)
              .firstOrNull;
    final all = ref.watch(benchForSlotProvider(slotPosition));
    final state = ref.watch(gameProvider).state;
    final light = Theme.of(context).brightness == Brightness.light;

    // The hole's own line leads, and `ALL` is the fallback for a sheet opened
    // with nobody nominated — there is no position to pre-set to then.
    final line = _line ?? slotPosition ?? benchAllLines;
    final bench = [
      for (final entry in all)
        if (line == benchAllLines || entry.card.position == line) entry,
    ];

    // **WHAT THE MAN COMING OFF IS WORTH**, so the bench can be read against
    // him rather than in the abstract. Null when nobody is nominated, and then
    // no card carries a comparison — a green ATK against nothing is a claim
    // about nothing.
    final off = widget.offId == null
        ? null
        : _cardById(state, widget.offId!);
    final offStats = off == null
        ? null
        : getCardStats(
            off,
            slotPosition: slotPosition,
            definitionRatios: _ratios(state),
          );

    return Column(
      key: const ValueKey('subs-bench-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: t('match.subs.bench'),
          subtitle: slotId == null
              ? t('match.subs.pick_off')
              : t('match.subs.pick_on'),
        ),
        // **THE FILTER, AND THE LEGEND FOR THE ARROWS, on one row.** That is
        // where `SquadScreen.js` puts both — see its bench sheet — and the
        // legend is `squad.form.good` / `squad.form.bad`, translated in ten
        // catalogues and until now unreachable in the port.
        Row(
          children: [
            Expanded(
              child: PositionFilterBar(
                value: line,
                keyPrefix: 'subs-bench-filter',
                onChanged: (next) => setState(() => _line = next),
              ),
            ),
            const _FormLegend(),
            const SizedBox(width: 12),
          ],
        ),
        if (bench.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              t('match.subs.empty_bench'),
              key: const ValueKey('subs-bench-empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: kit.textMuted),
            ),
          )
        else
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // **THREE ACROSS on a phone, and it counts rather than
                // measures.** A max-extent delegate fits as many 92px cards as
                // the width allows, which is four on most phones — four cards
                // across a sheet an inch or two wide leaves each of them too
                // small to read the face on. Three is the floor; a tablet gets
                // the extra columns its width actually earns.
                crossAxisCount: benchColumns(
                  MediaQuery.sizeOf(context).width,
                ),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: benchCardAspect,
              ),
              itemCount: bench.length,
              itemBuilder: (context, i) {
                final entry = bench[i];
                // Unavailable is not merely unwise: a player at another club or
                // advertised for sale cannot take the field. And nobody who has
                // been withdrawn goes back on.
                final can =
                    slotId != null &&
                    !spent.contains(entry.instanceId) &&
                    (_cardById(state, entry.instanceId)?.isSelectable ?? false);
                return Opacity(
                  opacity: can ? 1 : 0.45,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: can
                        ? () async {
                            final done = await widget.onChosen(
                              entry.instanceId,
                            );
                            // Only on a YES. A manager who said no is still
                            // choosing, and taking the bench away would make
                            // trying somebody else a whole extra journey.
                            if (done && context.mounted) {
                              await Navigator.of(context).maybePop();
                            }
                          }
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: PlayerCard(
                            key: ValueKey('sub-bench-${entry.instanceId}'),
                            view: entry.card,
                            light: light,
                          ),
                        ),
                        if (offStats case final against?) ...[
                          const SizedBox(height: 3),
                          _VsOff(
                            instanceId: entry.instanceId,
                            them: getCardStats(
                              _cardById(state, entry.instanceId),
                              slotPosition: slotPosition,
                              definitionRatios: _ratios(state),
                            ),
                            against: against,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// **THE POSITION SPLIT IS RATIOED**, and the ratios live in the save — a card
/// asked for its ATK/DEF without them is asked a different question from the one
/// the pitch asks. See `squad_rating.dart`.
Map<String, dynamic> _ratios(Map<String, dynamic>? state) {
  final raw = state?['definitionRatios'];
  return raw is Map<String, dynamic> ? raw : const {};
}

/// What `PositionFilterBar` calls "no filter".
const String benchAllLines = 'ALL';

/// The legend for the arrows on the cards, where `SquadScreen.js` puts it.
///
/// Two words and two glyphs: a green ▲ is a rating point on, a red ▼ is one
/// off. `squad.form.good` and `squad.form.bad` shipped in ten catalogues with
/// nothing able to print either of them, which is the tell this whole row came
/// out of — see [CardView.form].
class _FormLegend extends StatelessWidget {
  const _FormLegend();

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    Widget half(int form, String key, String delta) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formGlyph(form),
          style: TextStyle(
            fontSize: minFontSize,
            height: 1,
            color: formInk(form),
          ),
        ),
        const SizedBox(width: 2),
        Text(
          t(key),
          style: TextStyle(fontSize: minFontSize, color: kit.textMuted),
        ),
        const SizedBox(width: 2),
        Text(
          delta,
          style: TextStyle(
            fontSize: minFontSize,
            fontWeight: FontWeight.w800,
            color: formInk(form),
          ),
        ),
      ],
    );
    // It shares a row with a scrolling filter bar on a phone, so it gives way
    // rather than pushing the chips off the end.
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          key: const ValueKey('subs-form-legend'),
          mainAxisSize: MainAxisSize.min,
          children: [
            half(1, 'squad.form.good', '+1'),
            const SizedBox(width: 8),
            half(-1, 'squad.form.bad', '-1'),
          ],
        ),
      ),
    );
  }
}

/// A bench card's ATK and DEF, against the man he would replace.
///
/// **THE FIGURE ALONE IS NOT THE ANSWER**, which is the whole of why this
/// exists: a manager reading `62` on a bench card has to remember what the man
/// coming off is worth, in the ninety seconds a substitution actually takes.
/// Green is better than him and red is worse — the same pair every stat row and
/// every quest verdict in the game already uses. Asked for from the couch in
/// exactly those terms.
///
/// Level is MUTED rather than green: "no change" is not good news, and colouring
/// it as though it were is what makes a scale stop meaning anything.
class _VsOff extends StatelessWidget {
  const _VsOff({
    required this.instanceId,
    required this.them,
    required this.against,
  });

  final String instanceId;
  final CardStats them;
  final CardStats against;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    Widget cell(String label, int mine, int theirs) {
      final delta = mine - theirs;
      return Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: minFontSize,
                  fontWeight: FontWeight.w900,
                  color: kit.textMuted,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$mine',
                style: TextStyle(
                  fontSize: minFontSize,
                  fontWeight: FontWeight.w900,
                  color: delta == 0
                      ? kit.textMuted
                      : delta > 0
                      ? vsGreenOn(context)
                      : vsRedOn(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      key: ValueKey('sub-bench-vs-$instanceId'),
      children: [
        cell('ATK', them.attack, against.attack),
        cell('DEF', them.defence, against.defence),
      ],
    );
  }
}

CardInstance? _cardById(Map<String, dynamic>? state, String instanceId) {
  final cells = (state?['grid'] as Map<String, dynamic>?)?['cells'];
  if (cells is! List) return null;
  for (final raw in cells) {
    final card = CardInstance.from(raw);
    if (card != null && card.instanceId == instanceId) return card;
  }
  return null;
}

/// The two cards a substitution swaps, side by side, with the arrow between
/// them pointing at the man coming on.
///
/// **The one bit of the confirmation that is not words**, and the reason the
/// card exists at all: a manager confirms a swap by looking at it. The faces
/// are the same [PlayerCard] the bench sheet was just tapped in, so the card
/// under the thumb and the card on the confirmation are the same object.
///
/// A hole has nobody going off — an injury, or a slot that started empty — so
/// the left half is dropped rather than drawn as a blank card.
class _SwapPreview extends ConsumerWidget {
  const _SwapPreview({required this.going, required this.coming});

  final CardInstance? going;
  final CardInstance coming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    // Pro mode's per-player fitness bar. The bench cards behind this one carry
    // it, so the confirmation must too or the swap loses the number the whole
    // decision was made on.
    final pro = isProMode(ref.watch(gameProvider).state);
    final off = going == null ? null : cardViewFor(going!.raw, proMode: pro);
    final on = cardViewFor(coming.raw, proMode: pro);
    if (on == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (off != null) ...[
            // Dimmed, because he is the half of the swap that is ENDING. The
            // bench sheet dims an unavailable card at the same 0.45; this is
            // the same statement about the same kind of card.
            Flexible(
              child: Opacity(
                opacity: 0.55,
                child: SizedBox(
                  width: _swapCardWidth,
                  height: _swapCardWidth / benchCardAspect,
                  child: PlayerCard(
                    key: const ValueKey('subs-confirm-off'),
                    view: off,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: kit.textMuted,
              ),
            ),
          ],
          Flexible(
            child: SizedBox(
              width: _swapCardWidth,
              height: _swapCardWidth / benchCardAspect,
              child: PlayerCard(
                key: const ValueKey('subs-confirm-on'),
                view: on,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Narrower than the bench's own cards: two of them and an arrow have to sit
/// inside a coach card, which is narrower than the sheet they were picked in.
const double _swapCardWidth = 96;

/// The bench grid's own `childAspectRatio`. A [PlayerCard] fills the box it is
/// given and has an `Expanded` in it, so a width with no height is an unbounded
/// column — the shape has to come from somewhere, and it comes from the grid
/// the cards were just tapped in so both look the same.
const double benchCardAspect = 0.78;
