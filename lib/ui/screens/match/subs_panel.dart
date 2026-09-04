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
import 'package:merge_empire_fc/engine/booking_engine.dart';
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
import 'package:merge_empire_fc/ui/widgets/card_glyph.dart';
import 'package:merge_empire_fc/ui/widgets/player_card.dart';
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
  Set<String> sentOff = const {},
  Map<String, PitchSlot> sentOffSlots = const {},
  Set<String> cautioned = const {},
}) => showBottomSheetPopup<void>(
  context,
  heightFraction: 0.92,
  child: SubsPanel(
    used: used,
    withdrawn: withdrawn,
    onSub: onSub,
    openOn: openOn,
    sentOff: sentOff,
    sentOffSlots: sentOffSlots,
    cautioned: cautioned,
  ),
);

class SubsPanel extends ConsumerStatefulWidget {
  const SubsPanel({
    super.key,
    required this.used,
    required this.withdrawn,
    required this.onSub,
    this.openOn,
    this.sentOff = const {},
    this.sentOffSlots = const {},
    this.cautioned = const {},
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

  /// **WHO HAS BEEN SENT OFF, and is therefore not coming off.** A red card
  /// leaves a hole nobody fills, so his slot is drawn with the card over it and
  /// refuses a tap — the panel is open precisely so the other ten can be moved
  /// around him. Asked for from the couch in those words.
  final Set<String> sentOff;

  /// Where a sent-off man was standing, keyed on his slot.
  ///
  /// **The save empties his square and the panel has to un-empty it.** Clearing
  /// `cardInstanceId` is what makes the engine field ten — `reSimulateRemainder`
  /// reads the live lineup, and a row it can still see is a row it still
  /// counts — and the same clearing turns his square into an ordinary hole, so
  /// the panel offered to fill it. Reported from the couch, in those words:
  /// "it took me to the bench and allowed me to replace them with someone
  /// else, this can't be the case." So the screen hands over the slot as it
  /// stood the instant before, and the panel draws him back into it.
  final Map<String, PitchSlot> sentOffSlots;

  /// Who is on a caution, and playing within themselves for it.
  ///
  /// The ninety minutes are already decided by the time this screen exists —
  /// the sim ran before the whistle — so the ten per cent is not a change to the
  /// result. It is what the MANAGER is looking at when they decide whether a
  /// booked defender sees out the half, which is the decision this panel is for.
  final Set<String> cautioned;

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
      if (!mounted) return;
      // **AND THE HOLE STILL BELONGS TO SOMEBODY, on this path too.** [_pick]
      // has resolved an empty square to `vacatedById` since the confirmation
      // card grew two faces — but the INJURY never goes through [_pick]. It
      // arrives here preselected, precisely because the manager has already
      // been told who went down, and this handed the bench a null: so the one
      // substitution the game makes you make was the one whose card could not
      // say who it was for. It read "Subs" over "{on} comes on." with a single
      // player on it, while an ordinary swap two minutes earlier had shown
      // both. Reported from the couch in exactly those terms.
      final slot = ref
          .read(pitchSlotsProvider)
          .where((s) => s.slotId == open)
          .firstOrNull;
      _openBench(open, slot?.cardInstanceId ?? slot?.vacatedById);
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
    // And a man who is off the pitch cannot be taken off it.
    if (on != null && widget.sentOff.contains(on)) return;
    setState(() => _openFor = slot.slotId);
    // **AN INJURED MAN IS STILL THE MAN COMING OFF.** The sim empties his slot
    // before the panel opens, so `cardInstanceId` is null and the confirmation
    // had nobody to show — it fell back to the one-sided "{on} comes on" line
    // while every other substitution got two cards and an arrow. Reported from
    // the couch. `vacatedById` is who the hole belongs to.
    _openBench(slot.slotId, on ?? slot.vacatedById);
  }

  /// The bench, from the bottom, the way the Squad tab opens it. A null
  /// [slotId] is a look rather than a choice — see [_BenchSheet.slotId].
  Future<void> _openBench(String? slotId, String? offId) async {
    await showBottomSheetPopup<void>(
      context,
      heightFraction: 0.66,
      child: _BenchSheet(
        slotId: slotId,
        sentOff: widget.sentOff,
        offId: offId,
        cautioned: widget.cautioned,
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
    // **NOBODY FILLS A SENT-OFF MAN'S SQUARE, and the tap was not the only way
    // in.** [_pick] refuses his slot and [_SubSlot] draws him back into it
    // greyed out, but the INJURY path arrives through `openOn` and never goes
    // near either: it is handed a slot id and opens the bench on it directly.
    // A red card empties his row too — that is what makes the engine field ten
    // — so a hole the panel opened onto could be his, and answering it put a
    // twelfth man on the pitch and quietly undid the dismissal. The rule
    // belongs on the WRITE, which is the one thing every path goes through.
    if (widget.sentOffSlots.containsKey(slotId)) return false;
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
            slotBuilder: (context, slot) {
              // His square reads as a hole in the save, so the panel puts him
              // back in it — rated zero, which is what the sim scores the ten
              // men anyway, and refusing every tap.
              final gone = slot.card == null
                  ? widget.sentOffSlots[slot.slotId]
                  : null;
              final shown = gone == null ? slot : _zeroed(gone);
              return _SubSlot(
                slot: shown,
                enabled:
                    gone == null &&
                    !none &&
                    (slot.cardInstanceId == null ||
                        (!widget.withdrawn.contains(slot.cardInstanceId) &&
                            !widget.sentOff.contains(slot.cardInstanceId))),
                sentOff:
                    gone != null ||
                    widget.sentOff.contains(slot.cardInstanceId),
                cautioned: widget.cautioned.contains(slot.cardInstanceId),
                onTap: () => _pick(slot),
              );
            },
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
/// The same man, worth nothing.
PitchSlot _zeroed(PitchSlot slot) => (
  slotId: slot.slotId,
  slotPosition: slot.slotPosition,
  x: slot.x,
  y: slot.y,
  cardInstanceId: slot.cardInstanceId,
  card: slot.card,
  vacatedBy: null,
  vacatedById: null,
  outOfPosition: slot.outOfPosition,
  effRating: 0,
  penalty: slot.penalty,
  seasons: slot.seasons,
);

class _SubSlot extends ConsumerWidget {
  const _SubSlot({
    required this.slot,
    required this.enabled,
    required this.onTap,
    this.sentOff = false,
    this.cautioned = false,
  });

  final PitchSlot slot;
  final bool enabled;
  final bool sentOff;
  final bool cautioned;
  final VoidCallback onTap;

  /// The slot as the rest of this match sees it: a booked player is carrying
  /// ten per cent less. Nothing else about him changes.
  PitchSlot get _shown => cautioned
      ? (
          slotId: slot.slotId,
          slotPosition: slot.slotPosition,
          x: slot.x,
          y: slot.y,
          cardInstanceId: slot.cardInstanceId,
          card: slot.card,
          vacatedBy: slot.vacatedBy,
          vacatedById: slot.vacatedById,
          outOfPosition: slot.outOfPosition,
          effRating: (slot.effRating * yellowCardRatingMult).round(),
          penalty: slot.penalty,
          seasons: slot.seasons,
        )
      : slot;

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
                        vacatedById: null,
                        outOfPosition: false,
                        effRating: 0,
                        penalty: 0,
                        seasons: 0,
                      ),
                      proMode: ref.watch(proModeProvider),
                    ))
            // **HE IS DRAWN, AND THE CARD IS ON HIM.** A sent-off man leaves
            // his square empty in the save's eyes, and an empty square says the
            // side is a man light without saying WHICH man — on the one panel
            // whose job is rearranging the other ten around him. So he stays,
            // greyed by [enabled] and refusing a tap, wearing the card that
            // explains both.
            : Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  PitchToken(slot: _shown, proMode: ref.watch(proModeProvider)),
                  if (sentOff || cautioned)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: CardGlyph(
                        card: sentOff ? cardRed : cardYellow,
                        height: 18,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// The bench, as real cards — the Squad tab's own sheet, with a different answer
/// to a tap.
class _BenchSheet extends ConsumerStatefulWidget {
  const _BenchSheet({
    this.sentOff = const {},
    required this.slotId,
    required this.offId,
    required this.cautioned,
    required this.spent,
    required this.onChosen,
  });

  /// Sent off this match — on no bench, whatever the lineup says.
  final Set<String> sentOff;

  /// The slot being filled, or null when the manager is only LOOKING.
  ///
  /// Seeing who is on the bench is half of deciding who to take off, and the
  /// panel used to make that a chicken and an egg: you had to nominate somebody
  /// before you were shown the alternatives.
  final String? slotId;
  final String? offId;

  /// Who is carrying a yellow. The comparison the bench draws is against what
  /// the man coming off is worth NOW — see the note at [_BenchSheetState.build].
  final Set<String> cautioned;
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
    // **A MAN SENT OFF IS NOT ON THE BENCH.** The sending-off takes him out of
    // the lineup so the side is a man short, and a bench that is "everyone not
    // in the lineup" then offered him straight back — a duplicate of the red
    // card on the bench who could be put on and sent off again.
    final bench = [
      for (final entry in all)
        if ((line == benchAllLines || entry.card.position == line) &&
            !widget.sentOff.contains(entry.instanceId))
          entry,
    ];

    // **WHAT THE MAN COMING OFF IS WORTH**, so the bench can be read against
    // him rather than in the abstract. Null when nobody is nominated, and then
    // no card carries a comparison — a green ATK against nothing is a claim
    // about nothing.
    final off = widget.offId == null
        ? null
        : _cardById(state, widget.offId!);
    // **AND HE IS COMPARED AT WHAT HE IS WORTH NOW.** Reported from the couch:
    // "when a player has a yellow and ratings drop and we go to bench, it's
    // still comparing the player's rating before the game vs the subs — it
    // should use his rating now, which is the one after his yellow card."
    //
    // The ten per cent was coming off the token drawn on the pitch and off
    // nothing else, so the tile that says "this man is better than the one
    // coming off" was answering a question about a player who no longer
    // existed — and answering it in the one place a manager acts on it.
    final offBooked = widget.cautioned.contains(widget.offId);
    final offStats = off == null
        ? null
        : bookedStats(
            getCardStats(
              off,
              slotPosition: slotPosition,
              definitionRatios: _ratios(state),
            ),
            offBooked,
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
        // **THE FILTER, AND THEN THE LEGEND UNDER IT.** They shared a row —
        // which is where `SquadScreen.js` puts both — and on a phone the four
        // filter pills and two glyph-and-word pairs do not fit one line, so the
        // legend sat on top of the buttons. Reported from the couch.
        //
        // The legend is `squad.form.good` / `squad.form.bad`, translated in ten
        // catalogues and until recently unreachable in the port.
        PositionFilterBar(
          value: line,
          keyPrefix: 'subs-bench-filter',
          onChanged: (next) => setState(() => _line = next),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Align(alignment: Alignment.centerRight, child: _FormLegend()),
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
                    // **THE COMPARISON IS THE RATING, not a second one.** It
                    // was an ATK/DEF strip across the bottom of the portrait —
                    // reported from the couch as "a different rating
                    // underneath them, it's a bit weird" — so a tile carried
                    // the card's own number in the corner and two more,
                    // smaller, in a different colour scheme, for the same
                    // player. Now the chip that already holds a rating holds
                    // THIS one: what he is worth in the hole being filled,
                    // green over the man coming off, amber level with him, red
                    // under. See `PlayerCard.ratingInstead`.
                    child: PlayerCard(
                      key: ValueKey('sub-bench-${entry.instanceId}'),
                      view: entry.card,
                      light: light,
                      ratingInstead: offStats == null
                          ? null
                          : _against(
                              getCardStats(
                                _cardById(state, entry.instanceId),
                                slotPosition: slotPosition,
                                definitionRatios: _ratios(state),
                              ),
                              offStats,
                            ),
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

/// The same man, carrying a caution.
///
/// `yellowCardRatingMult` on all three live figures. The BASE trio is left
/// alone: those are what the card is worth, and a booking is a fact about this
/// afternoon rather than about him.
///
/// Public because it is the whole of the fix and the only part worth pinning: a
/// widget test can see that the bench draws the same values either way — the
/// comparison lives in the CHIP's colour, not its number — so the assertion
/// that means anything is about the basis, and this is the basis.
CardStats bookedStats(CardStats stats, bool cautioned) => cautioned
    ? CardStats(
        attack: (stats.attack * yellowCardRatingMult).round(),
        defence: (stats.defence * yellowCardRatingMult).round(),
        rating: (stats.rating * yellowCardRatingMult).round(),
        baseAttack: stats.baseAttack,
        baseDefence: stats.baseDefence,
        baseRating: stats.baseRating,
      )
    : stats;

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
    // **A LINE OF ITS OWN**, so it never has to give way. It shared a row with
    // the filter bar and there is not room for both on a phone — the legend sat
    // over the pills. The `Flexible` that was managing that is gone with the
    // row it belonged to; a bare one outside a `Flex` is an assertion.
    return FittedBox(
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
    );
  }
}

/// His rating in the hole, and whether it is an upgrade.
///
/// Amber for level, because "the same" is a real answer to "is he better" and
/// colouring it green or red would make a lateral swap look like a decision.
/// The colours are `penaltyColor`/`penaltyBg` — the pitch token's three, asked
/// for the same question about a different thing — so the two sheets a manager
/// swaps players on do not use two palettes for one judgement.
({int value, Color ink, Color background}) _against(CardStats them, CardStats off) {
  final band = them.rating > off.rating
      ? 0.0
      : them.rating == off.rating
      ? 0.2
      : 1.0;
  return (
    value: them.rating,
    ink: penaltyColor(band),
    background: penaltyBg(band),
  );
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
    final ratios = _ratios(ref.watch(gameProvider).state);
    final off = going == null
        ? null
        : cardViewFor(going!.raw, proMode: pro, definitionRatios: ratios);
    final on = cardViewFor(coming.raw, proMode: pro, definitionRatios: ratios);
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
