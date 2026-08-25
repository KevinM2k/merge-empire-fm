/// The manager customiser. Ported from the sheet behind the CUSTOMISE pill in
/// `ui/screens/LeagueScreen.js` and `.mgr-cust-*` in `styles/league-scene.css`.
///
/// **This was missing entirely**, and with it the only reason the walker is a
/// figure rather than a sprite. Every part of the wardrobe was already here —
/// `data/manager_looks.dart` carries the ids, the Fan Zone and cup gates, the
/// packs, the normaliser and the sanitiser — and `ManagerWalker` already draws
/// whatever a look names. What there was no way to do was CHANGE one, so the
/// eight axes, nineteen hair colours and six look packs were all writing to a
/// value nobody could edit.
///
/// **The preview is the same rig that walks the touchline**, standing still.
/// One source of truth means a look can never preview differently from how it
/// walks out — the JS makes the same point about exporting its figure markup,
/// and it is the reason the preview is not a portrait drawn separately.
///
/// **A locked item stays on the grid**, padlocked, and says what would unlock
/// it. Hidden, the reward for building the Fan Zone or lifting a cup would be a
/// surprise nobody was working towards — the kit picker takes exactly this line
/// with the Stadium colours.
///
/// **Every tap writes straight to the save.** There is no cancel, because the
/// walker behind the sheet is repainting as you go: what you are looking at IS
/// the state, and a Done button that could undo it would make the preview a
/// lie.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart' show adOfferInk, adOfferOnInk;
import 'package:merge_empire_fc/util/event_bus.dart';

Future<void> showManagerCustomiser(BuildContext context) =>
    showBottomSheetPopup<void>(
      context,
      heightFraction: 0.86,
      child: const ManagerCustomiser(),
    );

/// One editable part of him: which field of the look it writes, and where the
/// ids come from.
///
/// `kind` is the gate's own word for the axis, not the field's — hair STYLE is
/// gated as `hair:` while it is stored as `style`, and hair COLOUR is gated as
/// `color:` while it is stored under `hair`. The two disagreeing is exactly the
/// sort of thing that silently unlocks the wrong grid, so both are named here
/// rather than derived from each other.
typedef LookAxis = ({String kind, String field, String labelKey});

const List<LookAxis> lookAxes = [
  (kind: 'build', field: 'build', labelKey: 'customise.tab.build'),
  (kind: 'outfit', field: 'outfit', labelKey: 'customise.tab.outfit'),
  (kind: 'skin', field: 'skin', labelKey: 'customise.tab.skin'),
  (kind: 'hair', field: 'style', labelKey: 'customise.tab.hair'),
  (kind: 'color', field: 'hair', labelKey: 'customise.tab.color'),
  (kind: 'beard', field: 'beard', labelKey: 'customise.tab.beard'),
  (kind: 'hat', field: 'hat', labelKey: 'customise.tab.hat'),
  (kind: 'face', field: 'face', labelKey: 'customise.tab.face'),
  // **CELEBRATIONS, which the port had dropped entirely.** Nine gestures, named
  // in ten catalogues under `customise.emote.*` with a tab title of their own,
  // and no way to reach any of it: `lookAxes` stopped at `face`. The unlock
  // gate was already live — `pickGesture` filters the idle rota on
  // `isLookUnlocked(state, 'emote', …)` — so the reward existed and the shelf
  // that shows it did not.
  //
  // **It has no FIELD**, because an emote is not worn: owning one is what puts
  // it in the rota. Its chips equip nothing and play the gesture on the preview
  // instead, which is the only way to show what one actually is.
  (kind: 'emote', field: '', labelKey: 'customise.tab.emote'),
];

List<String> _idsFor(String kind) => switch (kind) {
  'build' => buildIds,
  'outfit' => outfitIds,
  'skin' => [for (final tone in skinTones) tone.$1],
  'hair' => hairStyleIds,
  'color' => hairColorIds,
  'beard' => facialHairIds,
  'hat' => hatIds,
  'face' => faceIds,
  'emote' => [for (final g in gestures) g.id],
  _ => const [],
};

/// What a chip is CALLED.
///
/// **The catalogue's own key scheme, which is not one scheme.** The port asked
/// for `customise.<kind>.<id>` everywhere and only `build`, `outfit` and
/// `emote` live there — hair, beard, face, hat and colour are under
/// `customise.item.<kind>.<id>`, and skin is numbered rather than named. So
/// five of the eight axes fell through to the tidied id and the grid showed
/// "Sunhat" where the catalogue says "Sun Hat", in English and in nothing else.
///
/// Skin tones are NUMBERED, which is the spec's decision and its reasoning: the
/// swatch already carries the information, and a set of invented names for eight
/// shades of human skin is a worse label than "Tone 3" in any language. The port
/// printed the raw hex — `#Eebb8c` — under every one of them.
String lookItemLabel(String kind, String id) {
  if (kind == 'skin') {
    final n = skinTones.indexWhere((tone) => tone.$1 == id);
    return t('customise.item.skin.tone', {'n': n < 0 ? 1 : n + 1});
  }
  final key = switch (kind) {
    'build' || 'outfit' || 'emote' => 'customise.$kind.$id',
    _ => 'customise.item.$kind.$id',
  };
  final named = t(key);
  if (named != key) return named;
  return id.isEmpty ? id : id[0].toUpperCase() + id.substring(1);
}

/// What a locked item is waiting on, in words.
String? lockedReason(Map<String, dynamic>? state, String kind, String id) {
  if (isLookUnlocked(state, kind, id)) return null;
  final req = lookRequirement(kind, id);
  if (req == null) return null;
  if (req.fanTier != null) {
    return t('customise.locked.fanzone', {'tier': req.fanTier});
  }
  if (req.cupId != null) {
    final cup = getCupById(req.cupId);
    return t('customise.locked.cup', {
      'cup': cup == null ? req.cupId! : tName('cup', cup.id),
    });
  }
  return t('customise.locked.pack', {
    'pack': t('customise.pack.${req.packId}'),
  });
}

/// The placement a look-pack video spends. A key from `ad_units.dart`, and it
/// had no caller: the unit was declared, the grant was written and nothing in
/// `lib/` ever asked for the video.
const String lookPackPlacement = 'cosmetic_pack';

/// Whether this item is locked behind a look PACK — the only lock a video can
/// open. A Fan Zone tier or a cup is a refusal with nothing to offer.
bool isPackLocked(Map<String, dynamic>? state, String kind, String id) {
  if (isLookUnlocked(state, kind, id)) return false;
  return lookRequirement(kind, id)?.packId != null;
}

class ManagerCustomiser extends ConsumerStatefulWidget {
  const ManagerCustomiser({super.key});

  @override
  ConsumerState<ManagerCustomiser> createState() => _ManagerCustomiserState();
}

class _ManagerCustomiserState extends ConsumerState<ManagerCustomiser> {
  /// Whether the chip grid has been built yet.
  ///
  /// **THE SHEET OPENS IN ONE FRAME AND THE GRID DOES NOT FIT IN IT.** Measured
  /// on the tap: 209ms on the frame the button is pressed, and 23ms for
  /// everything after — so the whole of "the customise button comes up laggy"
  /// is one enormous build, twelve frames' worth at sixty a second, while the
  /// sheet is trying to slide up.
  ///
  /// The grid is the expensive half and it is the half nobody is looking at
  /// yet: twenty chips, each a full [ManagerWalker] rig, measured at ~60ms
  /// together against ~18ms for an empty grid of the same shape. So the frame
  /// that opens the sheet builds the header, the stage and the picker, and the
  /// chips arrive on the NEXT one — sixteen milliseconds later, which is not a
  /// wait, it is the difference between a sheet that slides and a sheet that
  /// jumps.
  ///
  /// **AND THEY ARRIVE ONE CHIP AT A TIME.** Reported slow twice more after the
  /// deferral, and the third pass measured it instead of guessing again —
  /// `customise_timeline_test.dart` prints the frames. A row of four was the
  /// unit, and a row is not 12ms: it is 39ms on the first and 16ms on the
  /// second, which is two and a half frames and one, so wherever the fill was
  /// put it dropped frames there. Moving it behind the route's animation just
  /// moved the stutter to the moment the sheet LANDS, which is the worst place
  /// for it — the sheet stops, then judders.
  ///
  /// One chip is inside the budget, so the unit is the chip. Twenty of them
  /// fill over twenty frames, the slide is fifteen of those, and the frames it
  /// travels through were measured costing 1.5ms out of 16 — headroom that was
  /// going to waste while the work waited for the end.
  ///
  /// It stops the moment every chip is up, so nothing schedules callbacks for a
  /// sheet that is finished.
  int _chipsReady = 0;

  /// Chips revealed per frame. One, because the point is that a frame's work
  /// fits in a frame.

  /// Whether the fill has been started. Once only, however many times
  /// dependencies change.
  bool _filling = false;

  /// **AND IT STARTS AT ONCE, rather than waiting for the sheet to land.**
  ///
  /// Waiting was the previous pass's answer to a row costing more than a frame,
  /// and it is the wrong one: a chip fits in a frame, and the sliding frames
  /// are the emptiest ones there are.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filling) return;
    _filling = true;
    _fillNextChip();
  }

  /// Reset when the axis changes: a new axis is a new grid of rigs, and
  /// building twenty of those in the frame a tab is tapped is the same cost
  /// arriving through a different door.
  void _fillNextChip() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_chipsReady >= _idsFor(lookAxes[_axis].kind).length) return;
      setState(() => _chipsReady++);
      _fillNextChip();
    });
  }

  int _axis = 0;

  Map<String, dynamic>? get _save => ref.read(gameProvider).state;

  /// Write one field, through the SANITISER rather than straight in.
  ///
  /// A look that names something the player no longer owns has to come back as
  /// a valid figure — a prestige can take a Fan Zone tier away underneath a
  /// stored look, and the sheet is one of the places that would otherwise write
  /// the invalid value straight back out again.
  void _set(String field, Object? value) {
    ref.read(gameProvider).update((s) {
      final club = s.putIfAbsent('club', () => <String, dynamic>{});
      if (club is! Map<String, dynamic>) return;
      final look = <String, dynamic>{
        ...normalizeAvatar(club['managerAvatar']),
        field: value,
      };
      // Skin carries its own shade, and the two are one choice: a base tone
      // with the previous tone's shade reads as a badly printed figure.
      if (field == 'skin') {
        for (final tone in skinTones) {
          if (tone.$1 == value) look['skinShade'] = tone.$2;
        }
      }
      club['managerAvatar'] = sanitizeAvatar(s, look);
    });
    setState(() {});
  }

  /// A gesture to play once on the preview, or null when he is just walking.
  GestureCue? _preview;

  /// One video in flight at a time — a double tap is two videos and one grant.
  bool _adInFlight = false;

  /// A locked chip: watch for it, or be told why not.
  ///
  /// **Every pack-locked item is one video away**, and the tap does exactly
  /// that with no sheet in between. Routing it through a pack popup would make
  /// the player read and dismiss an offer for nine other items to get the one
  /// they had already pointed at — the spec's own argument, and the reason the
  /// pack sheet stays in the Shop where the gem price is sold.
  Future<void> _watchForItem(String kind, String id) async {
    if (_adInFlight) return;
    final why = lockedReason(_save, kind, id);
    if (!isPackLocked(_save, kind, id)) {
      if (why != null) emit('toast:info', why);
      return;
    }
    if (!canWatchPackAd(_save)) {
      emit('toast:info', t('customise.pack.wait', {
        'time': formatAdWait(msUntilPackAd(_save)),
      }));
      return;
    }
    _adInFlight = true;
    final outcome = await ref.read(rewardedAdsProvider).show(lookPackPlacement);
    _adInFlight = false;
    if (outcome != AdOutcome.rewarded) {
      if (outcome == AdOutcome.unavailable) {
        emit('toast:error', t('customise.pack.ad_failed'));
      }
      return;
    }
    var got = false;
    ref.read(gameProvider).update((s) {
      got = grantLookItem(s, '$kind:$id');
      if (got) recordPackAd(s);
    });
    if (!got) return;
    // Bought it, so wear it — except an emote, which is not worn at all.
    final axis = lookAxes.firstWhere((a) => a.kind == kind);
    if (axis.field.isNotEmpty) {
      _set(axis.field, kind == 'color' ? hairColorValue(id) : id);
    } else {
      _play(id);
    }
    emit('toast:success', t('customise.pack.item_unlocked', {
      'item': lookItemLabel(kind, id),
    }));
    if (mounted) setState(() {});
  }

  /// Play a celebration on the preview figure. Tapping the same one twice is
  /// two plays — see [GestureCue], whose identity is what restarts the rig.
  void _play(String id) {
    final gesture = gestures.where((g) => g.id == id).firstOrNull;
    if (gesture == null) return;
    setState(() => _preview = GestureCue(gesture));
  }

  void _randomise() {
    ref.read(gameProvider).update((s) {
      final club = s.putIfAbsent('club', () => <String, dynamic>{});
      // Rolled against the SAVE, so the dice can only land on things he owns.
      if (club is Map<String, dynamic>) club['managerAvatar'] = randomAvatar(s);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final look = ref.watch(managerLookProvider);
    final axis = lookAxes[_axis];

    return Column(
      key: const ValueKey('manager-customiser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t('customise.title'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('customise-randomise'),
                onPressed: _randomise,
                child: Text(t('customise.randomise')),
              ),
              TextButton(
                key: const ValueKey('customise-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t('customise.done')),
              ),
            ],
          ),
        ),
        // **HE WALKS IN HERE, ON GRASS.**
        //
        // He used to stand still on the sheet's own surface, which is a figure
        // in a dressing room rather than the man you watch on the touchline —
        // and the thing being judged is how a look MOVES. The backdrop is the
        // scene's own sky and turf (`theme/sky.dart`), so what you are dressing
        // him for is the ground he will be standing on.
        _PreviewStage(
          child: ManagerWalker(
            key: const ValueKey('customise-preview'),
            kit: kit.accent,
            skin: const Color(0xFFEEBB8C),
            hair: const Color(0xFF3A2A1C),
            look: look,
            mood: Mood.pleased,
            gesture: _preview,
          ),
        ),
        // **ONE CONTROL, NOT EIGHT.**
        //
        // A horizontal strip of eight tabs does not fit across a phone, so Hat
        // and Face lived off the right-hand edge behind a scroll with nothing to
        // say it was there. Wrapping them fixed the reachability and left two
        // lines of little buttons stacked under each other, which reads as a
        // pile rather than as navigation.
        //
        // A picker naming the part you are on is one line, says where you are
        // without being read left to right, and cannot run out of room however
        // many axes the wardrobe grows. `DropdownButton` is the same idiom the
        // Player Index's filters already use.
        // Clear of the stage above it: the picker sat hard against the grass and
        // read as part of the picture rather than as the control under it.
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: _AxisPicker(
            axes: lookAxes,
            index: _axis,
            // The new axis's rows fill the same way the first one did — a
            // tab tap is the same twenty rigs arriving, and building them all
            // in the frame the tab is pressed is the original fault through a
            // different door.
            onPick: (i) {
              setState(() {
                _axis = i;
                _chipsReady = 0;
              });
              _fillNextChip();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          // Empty for one frame, then a chip a frame. See [_chipsReady].
          child: _chipsReady == 0
              ? const SizedBox.shrink()
              : _Grid(
                  axis: axis,
                  look: look,
                  ready: _chipsReady,
                  state: _save,
                  onLocked: (id, watchable) {
                    if (watchable) {
                      unawaited(_watchForItem(axis.kind, id));
                      return;
                    }
                    final why = lockedReason(_save, axis.kind, id);
                    if (why != null) emit('toast:info', why);
                  },
                  onPlay: _play,
                  onPick: (id) => _set(
                    axis.field,
                    // Hair colour is stored as the VALUE, not the id — that is what
                    // the walker paints with and what `hairColorId` reads back.
                    axis.kind == 'color' ? hairColorValue(id) : id,
                  ),
                ),
        ),
      ],
    );
  }
}

/// The patch of ground he is previewed on.
///
/// How tall the preview box is. Named because the grass strip is a fraction of
/// it and the two must not be able to disagree.
const double _stageHeight = 190;

/// The diorama's own sky and turf rather than a colour picked to look like
/// them — one source for the two means a look chosen in here is judged against
/// the light it will actually be seen in.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      // The same 13 either side as the picker and the grid, so the sheet has one
      // margin rather than a full-bleed picture over inset controls.
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: ClipRRect(
        key: const ValueKey('customise-stage'),
        borderRadius: BorderRadius.circular(14),
        child: WalkClock(
          stride: walkDurationFor(Mood.pleased),
          child: SizedBox(
            height: _stageHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // **A DRAWN HORIZON, not a bare wash.** The sky gradient alone left
                // him standing against flat colour, which reads as a swatch rather
                // than as a place. The gradient stays underneath it so the box is
                // never empty if the asset is missing, and so it still darkens with
                // the theme.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: skyGradient(brightness: brightness, tier: 1),
                  ),
                ),
                // **AND IT TRAVELS PAST HIM.** He walks in place and the world
                // moves, so a backdrop holding still is a man on a treadmill. Off
                // the SAME clock his legs are on — see [WalkClock] at the top of
                // this stage — because two clocks in one box is the drift
                // `walk_ramp.dart` exists to stop.
                //
                // **THE WHOLE BOX, and anchored to the TOP of the drawing.** Two
                // faults, and both were the same mistake. At 86% of the height
                // there was a hard horizontal edge across the stage where the
                // picture stopped and the sheet's own sky gradient took over —
                // two skies meeting, which reads as the image being cut off. It
                // fills the box now, so there is nothing to meet.
                //
                // And anchoring it to the BOTTOM was backwards. `cover` on a
                // square drawing in a wide box shows a horizontal slice, so
                // bottom anchoring shows the GROUND — which puts the treeline at
                // the top of the slice, up near his head. Anchored to the top the
                // slice is sky and the treeline falls to the foot of it, which is
                // where a horizon belongs.
                const Positioned.fill(child: _ScrollingBackdrop()),
                // **THE GRASS HAD NO WIDTH, so he was walking in the sky.**
                // `FractionallySizedBox` with a `heightFactor` and no
                // `widthFactor` passes the incoming width constraint through
                // unchanged — and under an `Align` that constraint is LOOSE, so a
                // bare `DecoratedBox` with nothing in it sized itself to zero.
                // The strip was in the tree and painted nothing, which left the
                // backdrop's own cropped-off hedges as the only thing under his
                // feet. Positioned by its edges, which cannot collapse.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // A shallower strip than it was: too much of the box was grass
                  // and not enough of it was the world behind him.
                  height: _stageHeight * 0.2,
                  child: DecoratedBox(
                    key: const ValueKey('customise-grass'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: nightScene(brightness)
                            ? const [Color(0xFF17442A), Color(0xFF2A783F)]
                            : const [Color(0xFF2A7231), Color(0xFF48AD50)],
                      ),
                    ),
                  ),
                ),
                // Standing ON the grass line, not in the middle of the box.
                Align(
                  alignment: const Alignment(0, 0.52),
                  child: SizedBox(
                    width: walkerWidth,
                    height: walkerHeight,
                    child: child,
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

/// The backdrop, travelling past him.
///
/// Two copies side by side and the pair slid by how far the world has gone, which
/// is the same trick the diorama's strips use — a window onto a position rather
/// than a clock of its own. Slow: a treeline twenty metres back barely moves, and
/// anything faster reads as him sprinting.
class _ScrollingBackdrop extends StatelessWidget {
  const _ScrollingBackdrop();

  /// How far the world travels before the drawing repeats, in pixels at his row.
  static const double _period = 620;

  @override
  Widget build(BuildContext context) {
    final beat = WalkBeat.maybeOf(context);
    final art = ArtImage(
      key: const ValueKey('customise-backdrop'),
      path: backdropPath(Backdrop.grass),
      fit: BoxFit.cover,
      // TOP, so the visible slice is sky and the treeline lands low — see the
      // note at the call site.
      alignment: Alignment.topCenter,
      fallback: const SizedBox.shrink(),
    );
    if (beat == null) return art;
    return LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: ValueListenableBuilder<double>(
          valueListenable: beat,
          builder: (context, halfStrides, _) {
            final world = halfStrides * halfStridePx();
            return Transform.translate(
              // Right to left: the world moves past him, he walks in place.
              offset: Offset(
                -(world % _period) / _period * constraints.maxWidth,
                0,
              ),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: constraints.maxWidth * 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: constraints.maxWidth, child: art),
                    SizedBox(width: constraints.maxWidth, child: art),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Which part of him is being edited.
///
/// One line, and it NAMES the part rather than leaving you to read a strip left
/// to right — see the note at the call site. Styled off the kit rather than
/// Material's defaults so it belongs to the sheet it sits in.
class _AxisPicker extends StatelessWidget {
  const _AxisPicker({
    required this.axes,
    required this.index,
    required this.onPick,
  });

  final List<LookAxis> axes;
  final int index;
  final void Function(int) onPick;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('customise-axis-picker'),
      // Vertical padding as well as horizontal: `isDense` shrink-wraps a
      // dropdown to its text, which is a tap target the height of a word.
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kit.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: index,
          isDense: true,
          isExpanded: true,
          dropdownColor: kit.surface,
          iconEnabledColor: kit.textMuted,
          borderRadius: BorderRadius.circular(10),
          // The theme's own body colour: `KitTheme` names only the muted one,
          // and the sheet's text elsewhere takes the default.
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: DefaultTextStyle.of(context).style.color,
          ),
          items: [
            for (var i = 0; i < axes.length; i++)
              DropdownMenuItem<int>(
                value: i,
                // Keyed on the axis rather than the index: a test asking for the
                // hat should not have to know it is seventh.
                key: ValueKey('customise-axis-${axes[i].kind}'),
                child: Text(t(axes[i].labelKey)),
              ),
          ],
          onChanged: (i) {
            if (i != null) onPick(i);
          },
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.axis,
    required this.look,
    required this.ready,
    required this.state,
    required this.onPick,
    required this.onLocked,
    required this.onPlay,
  });

  final LookAxis axis;
  final ManagerLook? look;

  /// How many chips are allowed on screen yet — see `_chipsReady`. The grid
  /// keeps its full extent so the scrollbar and the scroll position do not jump
  /// as they arrive; what this caps is how many are BUILT.
  final int ready;
  final Map<String, dynamic>? state;
  final void Function(String id) onPick;

  /// A locked chip: either an offer to watch for it, or a refusal to explain.
  final void Function(String id, bool adUnlockable) onLocked;

  /// An emote chip, which equips nothing and plays on the preview instead.
  final void Function(String id) onPlay;

  /// What is selected on THIS axis, as the gate's own id.
  String? get _current {
    final stored = look?[axis.field];
    if (axis.kind == 'color') return hairColorId(stored as String?);
    return stored as String?;
  }

  @override
  Widget build(BuildContext context) {
    final ids = _idsFor(axis.kind);
    final current = _current;

    return GridView.builder(
      key: ValueKey('customise-grid-${axis.kind}'),
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: ids.length,
      itemBuilder: (context, i) {
        // Still filling. An empty box costs nothing and holds the row open.
        if (i >= ready) return const SizedBox.shrink();
        final id = ids[i];
        final locked = lockedReason(state, axis.kind, id);
        final watchable = isPackLocked(state, axis.kind, id);
        return _Chip(
          axis: axis,
          id: id,
          look: look,
          // An emote is never "worn", so nothing on that tab is current.
          selected: axis.field.isNotEmpty && id == current,
          lockedReason: locked,
          adUnlockable: watchable,
          onTap: () {
            // **THROUGH THE APP'S OWN TOAST, not a `SnackBar`.**
            // `ScaffoldMessenger.of` walks up to the Scaffold BEHIND this
            // modal sheet, so the explanation was posted underneath the thing
            // the player was looking at — reported as tapping a locked item
            // doing nothing at all. Every other message in the game goes on
            // the bus and `toast_host` draws it over the top.
            if (locked != null) {
              onLocked(id, watchable);
              return;
            }
            if (axis.field.isEmpty) {
              onPlay(id);
              return;
            }
            onPick(id);
          },
        );
      },
    );
  }
}

/// What part of the figure an axis actually changes, in the rig's own units.
///
/// **This is what makes a picture per choice work.** The first cut of this sheet
/// argued against miniatures and it was half right: at four to a row a WHOLE
/// manager is sixty pixels tall, and a moustache is four of them. The answer is
/// not a word, it is a CROP — frame the head for the head axes and the body for
/// the body ones, and the thing being chosen fills the box.
Rect _regionFor(String kind) => switch (kind) {
  // The skull is a circle at (62, 48.5) r12.5, and hair, hats and beards all
  // hang off it — with room above for a tall hat and below for a full beard.
  'hair' ||
  'color' ||
  'beard' ||
  'hat' ||
  'face' => const Rect.fromLTWH(42, 26, 40, 40),
  // Shoulders to the hem, which is where a build and an outfit live.
  _ => const Rect.fromLTWH(38, 54, 44, 44),
};

/// One choice, as a picture of itself.
/// A picture of ONE choice, cropped to the part of him the axis changes.
///
/// **Public because the shop needs it.** A pack's contents were a list of
/// NAMES with an axis glyph beside them — "Bucket", "Viking", "Party" — which
/// tells a player nothing about what they are buying, and this widget has been
/// drawing exactly that picture in the customiser all along. Reported as
/// wanting to see what each thing looks like before unlocking it.
class LookPreview extends StatelessWidget {
  const LookPreview({required this.axis, required this.look, super.key});

  final LookAxis axis;

  /// The player's current look with this one choice swapped in — so a beard is
  /// previewed on HIS face, under HIS hat, in HIS colour.
  final ManagerLook look;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final region = _regionFor(axis.kind);
    return LayoutBuilder(
      builder: (context, box) {
        final k = box.maxWidth / region.width;
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(-region.left * k, -region.top * k),
              child: SizedBox(
                width: walkerWidth * k,
                height: walkerHeight * k,
                // Its own layer: twenty rigs in a scrollable grid otherwise
                // repaint together on every scroll pixel, and a rig is a deep
                // tree of clipped SVG layers.
                child: RepaintBoundary(
                  child: ManagerWalker(
                    kit: kit.accent,
                    skin: const Color(0xFFEEBB8C),
                    hair: const Color(0xFF3A2A1C),
                    look: look,
                    mood: Mood.neutral,
                    // Still, and that is what keeps nineteen of these free: a
                    // walker that is not walking starts no clock at all.
                    walking: false,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One choice.
///
/// **A picture of what it is**, cropped to the part the axis changes — see
/// [_regionFor]. The colour axes keep their swatch, because a skin tone or a
/// hair colour IS a colour and a head drawn to show one is a worse look at it.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.axis,
    required this.id,
    required this.look,
    required this.selected,
    required this.lockedReason,
    required this.adUnlockable,
    required this.onTap,
  });

  final LookAxis axis;
  final String id;

  /// The player's current look, for the preview to swap this choice into.
  final ManagerLook? look;
  final bool selected;
  final String? lockedReason;

  /// Whether this lock is one a video can open — a look PACK — as against a Fan
  /// Zone tier or a cup, which patience cannot reach.
  final bool adUnlockable;

  final VoidCallback onTap;

  /// The colour axes show the colour; everything else shows its name.
  Color? get _swatch {
    if (axis.kind == 'skin') return _hex(id);
    if (axis.kind == 'color') return _hex(hairColorValue(id));
    return null;
  }

  static Color? _hex(String? value) {
    if (value == null || !value.startsWith('#') || value.length != 7) {
      return null;
    }
    final v = int.tryParse(value.substring(1), radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  /// **STILL THE NAME, for anyone who cannot see the picture.** The chips draw
  /// themselves now, and a control whose entire content is a drawing has no
  /// accessible name at all unless one is said out loud. See [lookItemLabel]
  /// for why one key pattern was not enough.
  String get _label => lookItemLabel(axis.kind, id);

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final locked = lockedReason != null;
    final swatch = _swatch;

    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$_label — $lockedReason' : _label,
      child: GestureDetector(
        key: ValueKey('customise-chip-${axis.kind}-$id'),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Opacity(
                // Knocked back rather than emptied. **A LOCKED ITEM STILL SHOWS
                // WHAT IT WOULD LOOK LIKE**: the padlock used to REPLACE the
                // preview, which made the reward for building the Fan Zone or
                // lifting a cup a surprise — the exact opposite of what keeping
                // it on the grid was for. It sits over the drawing now.
                opacity: locked ? 0.55 : 1,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: swatch ?? kit.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? kit.accentBright : kit.border,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (swatch == null)
                        LookPreview(
                          axis: axis,
                          // **`defaultManagerLook` when the save has none**,
                          // which is every fresh one — without the fallback the
                          // whole grid was words on exactly the saves most likely
                          // to be opening this sheet for the first time.
                          look: <String, dynamic>{
                            ...(look ?? defaultManagerLook),
                            axis.field: axis.kind == 'color'
                                ? hairColorValue(id)
                                : id,
                          },
                        ),
                      // **A PADLOCK IS THE WRONG MARK ON AN OFFER.** Every
                      // pack-locked item is one rewarded video away and the
                      // port drew all of them shut — reported as the
                      // customisations being watchable with nothing to say so.
                      // The spec's own rule: a corner badge in the watch-ad
                      // yellow carrying the same play-in-a-frame glyph as every
                      // other rewarded-video button in the game, so this reads
                      // as an offer rather than a refusal. A Fan Zone tier or a
                      // cup keeps the padlock, because there is nothing to
                      // offer for those.
                      if (locked)
                        Align(
                          alignment: Alignment.topRight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: adUnlockable
                                  ? adOfferInk
                                  : kit.bg.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: adUnlockable
                                  ? const GameIcon(
                                      'video',
                                      size: 12,
                                      color: adOfferOnInk,
                                    )
                                  : Icon(
                                      Icons.lock,
                                      size: 12,
                                      color: kit.textMuted,
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // **THE NAME, under the picture.** A grid of thumbnails does not say
            // which one is the beanie: the label was on the control for a screen
            // reader and nowhere at all for anybody else.
            const SizedBox(height: 2),
            Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: locked ? kit.textMuted : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
