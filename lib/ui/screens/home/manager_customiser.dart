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
import 'dart:math' as math;

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
import 'package:merge_empire_fc/ui/screens/home/gesture_poses.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/screens/home/pitch_scene.dart';
import 'package:merge_empire_fc/ui/screens/home/walk_ramp.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_looks.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/screens/minigames/penalty_view.dart'
    show backdropRectFor;
import 'package:merge_empire_fc/ui/theme/sky.dart';
import 'package:merge_empire_fc/engine/ad_gate_engine.dart';
import 'package:merge_empire_fc/services/rewarded_ads.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/engine/look_pack_engine.dart';
import 'package:merge_empire_fc/ui/screens/shop/purchase_flow.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';
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
  ///
  /// **A NOTIFIER RATHER THAN STATE, because `setState` made the fill O(n²).**
  /// The count lived on this State, so every increment rebuilt the whole sheet
  /// — and `GridView.builder` re-runs `itemBuilder` for every live item, so
  /// each frame rebuilt every chip already up as well as the new one. Measured
  /// on the Hat axis: eighteen chips cost 171 rig builds, which is 18×19/2
  /// exactly. Celebrations 136, Hair 120 — triangular numbers, the signature of
  /// the whole grid rebuilding once per chip.
  ///
  /// Worse than the total, the SHAPE was backwards: the point of a chip a frame
  /// is that a frame's work is constant, and this made the last frame of the
  /// fill the most expensive one. The frames were measured at a p50 of 15-17ms
  /// against a 16ms budget, so the fill dropped frames the whole way down.
  ///
  /// Off a notifier each chip watches for itself, only the chip crossing its
  /// own threshold rebuilds: eighteen builds for eighteen chips. See [_Reveal].
  final ValueNotifier<int> _ready = ValueNotifier<int>(0);

  /// Whether the fill has been started. Once only, however many times
  /// dependencies change.
  bool _filling = false;

  @override
  void dispose() {
    _ready.dispose();
    _preview.dispose();
    super.dispose();
  }

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
      if (_ready.value >= _idsFor(lookAxes[_axis].kind).length) return;
      _ready.value++;
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
    // **AND PICKING SOMETHING ELSE ANSWERS THE OFFER.** A try-on is a locked
    // item laid over the save for the preview only, so a player who taps a
    // hat they DO own while one is up would otherwise still be looking at the
    // locked one, under a bar selling it, with no way out but the ✕.
    setState(() => _offer = null);
  }

  /// A gesture to play once on the preview, or null when he is just walking.
  ///
  /// **A NOTIFIER, because the GRID does not depend on it.** Playing one used to
  /// `setState` the whole sheet, and on the Celebrations axis that rebuilt all
  /// sixteen chip rigs to change one figure that is not in the grid at all —
  /// measured at 30-42ms on the frame of every tap, against 7ms for a tap on
  /// any other axis. Two dropped frames every time the player tried a
  /// celebration, which is the one thing that tab is for.
  final ValueNotifier<GestureCue?> _preview = ValueNotifier<GestureCue?>(null);

  /// **A LOCKED ITEM BEING TRIED ON, and the offer standing beside it.**
  ///
  /// A player who taps a locked hat wants to see the hat. Writing it would be
  /// giving it away, so `field`/`value` are laid over the saved look for the
  /// PREVIEW figure only, and the rest of the record is what the bar on the
  /// stage needs to sell it.
  /// **AND IT IS NO LONGER ONLY FOR THE ONES WITH SOMETHING TO SELL.** A lock a
  /// video cannot open — a Fan Zone tier, a cup — used to be a toast: a
  /// sentence about a hat, with the hat still not on him. Asked for directly,
  /// and the copy for it already ships: `customise.locked.fanzone` is "Unlocks
  /// at Fan Zone Tier {tier}" and `customise.locked.cup` is "Win the {cup} to
  /// unlock", both translated in all ten catalogues and neither ever printed
  /// anywhere but a toast. So every lock tries the item on now; [packId] null
  /// is the one that has nothing to offer, and the bar drops its buttons and
  /// prints [reason] instead.
  ({
    String kind,
    String id,
    String? packId,
    String reason,
    String field,
    Object? value,
  })?
  _offer;

  /// A locked chip: watch for it, or be told why not.
  ///
  /// **Every pack-locked item is one video away**, and the tap does exactly
  /// that with no sheet in between. Routing it through a pack popup would make
  /// the player read and dismiss an offer for nine other items to get the one
  /// they had already pointed at — the spec's own argument, and the reason the
  /// pack sheet stays in the Shop where the gem price is sold.
  Future<void> _watchForItem(String kind, String id) async {
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
    // One video in flight at a time — a double tap is two videos and one
    // grant — and the flag is app-wide now rather than this sheet's own. See
    // `watchRewardedAd`.
    final outcome = await watchRewardedAd(ref, lookPackPlacement);
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

  /// **A LOCKED ITEM IS SHOWN, AND THEN OFFERED** — in that order, and both on
  /// the same screen.
  ///
  /// Tapping one used to fire a rewarded video on the spot, on the argument
  /// that a pack popup makes the player read and dismiss an offer for nine
  /// other items to get the one they had already pointed at. The playtest asked
  /// for the other half of that: nothing said what a tap was about to do, and
  /// nothing showed the item.
  ///
  /// So he WEARS it — on the preview only, because nothing reaches the save
  /// until it is paid for — and the two routes appear as buttons ON THE STAGE
  /// he is walking across. That placement is the point and it was asked for
  /// directly: the touchline box is the biggest and emptiest thing on the
  /// sheet, the item being sold is standing in the middle of it, and a sheet
  /// rising over the bottom half would cover the very thing the tap was for.
  ///
  /// A locked chip: SEE it, then be told what it costs or what it waits on.
  ///
  /// A lock a video cannot open used to stop here with a toast — a sentence
  /// about an item the player had just pointed at and still could not see. The
  /// showing is the part that has nothing to do with whether there is anything
  /// to sell, so it happens either way and the bar decides what to put under
  /// it. See [_offer].
  void _offerLockedItem(LookAxis axis, String id) {
    final why = lockedReason(_save, axis.kind, id);
    if (why == null) return;
    // A celebration is not worn at all; it is played.
    if (axis.field.isEmpty) _play(id);
    setState(
      () => _offer = (
        kind: axis.kind,
        id: id,
        packId: isPackLocked(_save, axis.kind, id)
            ? lookRequirement(axis.kind, id)?.packId
            : null,
        reason: why,
        field: axis.field,
        value: axis.kind == 'color' ? hairColorValue(id) : id,
      ),
    );
  }

  /// Take it off again. Anything the player does that is not answering the
  /// offer ends it — picking something else, changing axis, or the ✕ on the
  /// bar itself.
  void _clearOffer() {
    if (_offer != null) setState(() => _offer = null);
  }

  /// **THE WHOLE PACK, for gems** — the Shop's own three beats, run from here.
  ///
  /// The Shop has sold these for as long as they have existed and the
  /// customiser — the one screen where a player is looking at what is IN one —
  /// never mentioned it. `offerToBuy` asks, charges and receipts; if the
  /// balance will not cover it, it opens the gem packs rather than printing a
  /// sentence about not being able to.
  Future<void> _buyPackFor(String packId) async {
    final tile = lookTileState(_save, packId);
    if (tile == null || tile.status == 'owned') return;
    await offerToBuy(context, ref, (
      key: 'pack-$packId',
      title: t('customise.pack.$packId'),
      // **THE SAME CARD THE SHOP SHOWS.** This asked with a bare count — "5
      // items", things the player cannot see — while the shop's identical
      // offer names the axes and draws every one of them on the player's own
      // figure. Reported from the couch with the two side by side. Both halves
      // come from `shop_looks.dart` now rather than being written twice.
      subtitle: packContentsLine(packId),
      body: PackContents(packId: packId),
      glyph: 'shirt',
      currency: SpendCurrency.gems,
      cost: tile.cost,
      buy: () =>
          ref.read(gameProvider).update((s) => buyLookPack(s, packId)).reason,
    ));
    if (mounted) setState(() {});
  }

  /// Play a celebration on the preview figure. Tapping the same one twice is
  /// two plays — see [GestureCue], whose identity is what restarts the rig.
  void _play(String id) {
    final gesture = gestures.where((g) => g.id == id).firstOrNull;
    if (gesture == null) return;
    _preview.value = GestureCue(gesture);
  }

  /// The same for a celebration, which equips nothing: playing another one is
  /// the player moving on from the offer. Called from the chip rather than from
  /// [_play], because [_offerLockedItem] plays the locked one itself.
  void _playOwned(String id) {
    _clearOffer();
    _play(id);
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
    // What the PREVIEW figure wears: the saved look, plus whatever locked item
    // is currently being tried on. The grid below still reads `look`, so a
    // try-on cannot make a chip look selected.
    // What the PREVIEW figure wears: the saved look, plus whatever locked item
    // is currently being tried on. The grid below still reads `look`, so a
    // try-on cannot make a chip read as selected.
    final offer = _offer;
    final worn = offer == null || offer.field.isEmpty
        ? look
        : <String, dynamic>{...?look, offer.field: offer.value};

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
          overlay: offer == null
              ? null
              : _LockedOfferBar(
                  kind: offer.kind,
                  id: offer.id,
                  packId: offer.packId,
                  reason: offer.reason,
                  onWatch: () {
                    _clearOffer();
                    unawaited(_watchForItem(offer.kind, offer.id));
                  },
                  onBuy: () {
                    final pack = offer.packId;
                    _clearOffer();
                    // Only a bar with a pack draws a Buy, so this cannot fire
                    // without one — the guard is the type's, not a doubt.
                    if (pack != null) unawaited(_buyPackFor(pack));
                  },
                  onClose: _clearOffer,
                ),
          child: ValueListenableBuilder<GestureCue?>(
            valueListenable: _preview,
            builder: (context, cue, _) => ManagerWalker(
              key: const ValueKey('customise-preview'),
              kit: kit.accent,
              skin: const Color(0xFFEEBB8C),
              hair: const Color(0xFF3A2A1C),
              look: worn,
              mood: Mood.pleased,
              gesture: cue,
            ),
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
              _ready.value = 0;
              setState(() {
                _axis = i;
                // Whatever was being tried on belongs to the axis it came
                // from; a hat left on the rig while the player picks a beard
                // is a hat they were never given.
                _offer = null;
              });
              _fillNextChip();
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          // Empty for one frame, then a chip a frame. See [_ready] and
          // [_Reveal] — the GRID waits for the first chip's turn, so the frame
          // that opens the sheet builds no part of it, and after that it is
          // built once per axis while the chips let themselves in.
          child: _Reveal(
            ready: _ready,
            index: 0,
            builder: (context) => _Grid(
              axis: axis,
              look: look,
              ready: _ready,
              state: _save,
              onLocked: (id, watchable) => _offerLockedItem(axis, id),
              onPlay: _playOwned,
              onPick: (id) => _set(
                axis.field,
                // Hair colour is stored as the VALUE, not the id — that is
                // what the walker paints with and what `hairColorId` reads
                // back.
                axis.kind == 'color' ? hairColorValue(id) : id,
              ),
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

/// How much of the stage is grass — and so where the HORIZON is, which the
/// backdrop has to stand on. Named for the same reason the height is: the strip
/// and the treeline cannot be allowed to disagree.
const double _grassShare = 0.2;

/// How big he is drawn on it, against the art's own 120×170.
///
/// **Asked for — "the body needs to be slightly more zoomed out".** At full
/// size he was 170 of the box's 190, so the world he is being dressed for was
/// a strip either side of his shoulders and the top of his hat was a few
/// pixels off the sky. The camera steps back rather than the figure shrinking:
/// he keeps the ground under him, and there is now air above his head and turf
/// in front of his boots.
const double _previewScale = 0.86;

/// Where his soles meet the turf, from the top of the stage.
///
/// A fixed line, so scaling him moves the CAMERA rather than lifting him off
/// the ground: it is where he already stood at full size, a little under
/// halfway into the grass strip.
const double _soleLine = _stageHeight * 0.883;

/// The alignment that lands his soles on [_soleLine] at [_previewScale].
///
/// `Align` centres the BOX, so a figure scaled down under a fixed alignment
/// rises by half of what came off his height — his feet leave the grass and
/// the shadow goes with them. Derived, so neither number can go stale.
final double _standAlignment =
    2 * (_soleLine - walkerFootline * _previewScale) /
        (_stageHeight - walkerHeight * _previewScale) -
    1;

/// The diorama's own sky and turf rather than a colour picked to look like
/// them — one source for the two means a look chosen in here is judged against
/// the light it will actually be seen in.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.child, this.overlay});

  final Widget child;

  /// **THE OFFER FOR A LOCKED ITEM, drawn ON the stage.** Asked for directly:
  /// the touchline box is the biggest thing on the sheet and the emptiest, the
  /// item being sold is standing in the middle of it, and two full CTA buttons
  /// have somewhere obvious to go. See `_LockedOfferBar`.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      // The same 13 either side as the picker and the grid, so the sheet has one
      // margin rather than a full-bleed picture over inset controls.
      padding: const EdgeInsets.symmetric(horizontal: 13),
      // Its own layer: the only thing on this sheet that moves every frame,
      // and without the boundary the whole sheet re-rasterised with it.
      child: RepaintBoundary(
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
                // **AND IT IS PLACED, not fitted.** The picture filled the box
                // top-anchored, which left the drawing's own ground line below
                // the bottom edge and its hedges cut off by the grass strip —
                // shrubs growing out of the turf rather than standing behind
                // it, reported from the couch with a screenshot. `cover` cannot
                // fix that at any alignment: the slice it shows is decided by
                // the box, so the seam lands wherever the arithmetic puts it.
                //
                // [backdropRectFor] is the placement the penalty screen and
                // Goalkeeper Practice already use on these same four Kenney
                // drawings, for this same fault seen down the pitch: size the
                // art so ITS ground line is the seam, and let the surplus go off
                // the top, which is sky.
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
                  height: _stageHeight * _grassShare,
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
                  alignment: Alignment(0, _standAlignment),
                  child: SizedBox(
                    width: walkerWidth * _previewScale,
                    height: walkerHeight * _previewScale,
                    child: child,
                  ),
                ),
                if (overlay case final bar?)
                  Positioned(left: 0, right: 0, bottom: 0, child: bar),
              ],
            ),
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
    return LayoutBuilder(
      builder: (context, box) {
        final view = Size(box.maxWidth, box.maxHeight);
        // Sized and offset so the drawing's own ground line is the top of the
        // grass strip — see the note at the call site.
        final laid = backdropRectFor(view.height * (1 - _grassShare), view);
        // **Both dimensions, or it is a square in the middle.** A `Row` hands
        // its children a LOOSE height, and an image with no height sizes itself
        // to its own aspect.
        final art = SizedBox(
          width: laid.width,
          height: laid.height,
          child: ArtImage(
            key: const ValueKey('customise-backdrop'),
            path: backdropPath(Backdrop.grass),
            fit: BoxFit.cover,
            fallback: const SizedBox.shrink(),
          ),
        );
        // The pair, slid by how far the world has gone. Two tiles of the art's
        // own width cover the view at every offset, because the placement never
        // makes it narrower than the box.
        Widget pair(double travelled) => Transform.translate(
          offset: Offset(laid.left - travelled, laid.top),
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: laid.width * 2,
            maxHeight: laid.height,
            child: Row(mainAxisSize: MainAxisSize.min, children: [art, art]),
          ),
        );

        if (beat == null) return ClipRect(child: pair(0));
        return ClipRect(
          child: ValueListenableBuilder<double>(
            valueListenable: beat,
            builder: (context, halfStrides, _) {
              final world = halfStrides * halfStridePx();
              // Right to left: the world moves past him, he walks in place.
              return pair((world % _period) / _period * laid.width);
            },
          ),
        );
      },
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

  /// How many chips are allowed on screen yet — see `_ready`. The grid keeps its
  /// full extent so the scrollbar and the scroll position do not jump as they
  /// arrive; what this caps is how many are BUILT.
  final ValueNotifier<int> ready;
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
        final id = ids[i];
        // Still filling. An empty box costs nothing and holds the row open, and
        // the chip watches [ready] for its own turn rather than the grid being
        // rebuilt to hand it one — see [_Reveal].
        return _Reveal(
          ready: ready,
          index: i,
          builder: (context) => _chip(id),
        );
      },
    );
  }

  Widget _chip(String id) {
    final locked = lockedReason(state, axis.kind, id);
    final watchable = isPackLocked(state, axis.kind, id);
    return _Chip(
      axis: axis,
      id: id,
      look: look,
      // An emote is never "worn", so nothing on that tab is current.
      selected: axis.field.isNotEmpty && id == _current,
      lockedReason: locked,
      adUnlockable: watchable,
      onTap: () {
        // **THROUGH THE APP'S OWN TOAST, not a `SnackBar`.**
        // `ScaffoldMessenger.of` walks up to the Scaffold BEHIND this modal
        // sheet, so the explanation was posted underneath the thing the player
        // was looking at — reported as tapping a locked item doing nothing at
        // all. Every other message in the game goes on the bus and
        // `toast_host` draws it over the top.
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
  }
}

/// One thing's turn to be built — a chip, or the grid they all sit in.
///
/// **The fill's cost has to be per CHIP, not per grid.** `_ready` used to be
/// State on the sheet, so raising it rebuilt everything — and `GridView.builder`
/// re-runs `itemBuilder` for every live item, so the frame that revealed the
/// eighteenth chip rebuilt eighteen full [ManagerWalker] rigs. 171 rig builds
/// for eighteen chips, and the last frame the most expensive.
///
/// This listens for its own index instead and drops the listener the moment it
/// is in, so a fill costs one chip's work per frame all the way down. It still
/// rebuilds normally when the sheet above it does, which is what keeps every
/// chip previewing the look the player just picked.
class _Reveal extends StatefulWidget {
  const _Reveal({
    required this.ready,
    required this.index,
    required this.builder,
  });

  final ValueNotifier<int> ready;
  final int index;
  final WidgetBuilder builder;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _shown = widget.ready.value > widget.index;
    if (!_shown) widget.ready.addListener(_check);
  }

  void _check() {
    if (_shown || widget.ready.value <= widget.index) return;
    widget.ready.removeListener(_check);
    setState(() => _shown = true);
  }

  @override
  void dispose() {
    widget.ready.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _shown ? widget.builder(context) : const SizedBox.shrink();
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
  const LookPreview({
    required this.axis,
    required this.look,
    this.pose,
    super.key,
  });

  final LookAxis axis;

  /// The player's current look with this one choice swapped in — so a beard is
  /// previewed on HIS face, under HIS hat, in HIS colour.
  final ManagerLook look;

  /// A pose to hold him in, for an axis that changes no part of the LOOK.
  ///
  /// **Celebrations had nothing to swap, so all sixteen chips drew the same
  /// man.** The axis has no field — an emote is not worn — so the look handed
  /// to each chip was identical and the grid was sixteen copies of one picture,
  /// which told the player nothing about which celebration they were about to
  /// pick. A gesture is a POSE, not a garment, so the thing to vary is the rig's
  /// angles rather than its wardrobe: [gesturePose] sampled at its peak, handed
  /// over as the walker's `idle` because that is the parameter for a held pose
  /// (`walking: false` freezes him, so the gesture's own clock would never run).
  final GesturePose? pose;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final region = _regionFor(axis.kind);
    return LayoutBuilder(
      builder: (context, box) {
        final k = box.maxWidth / region.width;
        // Its own layer: twenty rigs in a scrollable grid otherwise repaint
        // together on every scroll pixel, and a rig is a deep tree of clipped
        // SVG layers. **OUTSIDE the clip**, so the texture is the chip's size:
        // inside it the cached raster was the whole rig at scale k — a quarter
        // of a megapixel per chip at 3x, eighteen times over on Celebrations,
        // for a 40-unit crop of each.
        // **A PICTURE, not a live rig.** Impeller has no raster cache, so a
        // `RepaintBoundary` isolates repaints and stores nothing: while the
        // preview walked, every still chip — a full rig, skull clips, a dozen
        // blurred shadows — was re-rasterised on the GPU each frame, eighteen
        // of them on Celebrations. Reported as that tab slowing everything to
        // a crawl. Snapshotted once and drawn as an image until the look or
        // the pose changes; the key is what throws the old picture away.
        return _Still(
          key: ValueKey(Object.hash(axis.kind, look, pose)),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(-region.left * k, -region.top * k),
                child: SizedBox(
                  width: walkerWidth * k,
                  height: walkerHeight * k,
                  child: ManagerWalker(
                    kit: kit.accent,
                    skin: const Color(0xFFEEBB8C),
                    hair: const Color(0xFF3A2A1C),
                    look: look,
                    mood: Mood.neutral,
                    idle: pose,
                    // Still, and that is what keeps nineteen of these free: a
                    // walker that is not walking starts no clock at all.
                    walking: false,
                    // And unblurred: a dozen blur passes per rig was most of
                    // what the grid cost to rasterise, for softness below a
                    // pixel at this size.
                    soft: false,
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

/// A child rasterised once and drawn as an image from then on.
///
/// Recreate it (a new key) to take a new picture — `SnapshotWidget` never
/// notices its child repainting, by design.
class _Still extends StatefulWidget {
  const _Still({required this.child, super.key});

  final Widget child;

  @override
  State<_Still> createState() => _StillState();
}

class _StillState extends State<_Still> {
  final SnapshotController _controller = SnapshotController(
    allowSnapshotting: true,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Taken at 2x at most: the snapshot reads the device ratio, and a 3x
    // picture of an 80-point crop is 2.25 times the pixels for nothing the eye
    // gets — twenty of them during the frames the sheet is sliding.
    return MediaQuery(
      data: media.copyWith(
        devicePixelRatio: math.min(media.devicePixelRatio, 2),
      ),
      child: SnapshotWidget(
        controller: _controller,
        // Permissive: the rig is plain painting, and a chip that cannot be
        // snapshotted should still draw rather than throw.
        mode: SnapshotMode.permissive,
        child: widget.child,
      ),
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

  /// The pose this chip holds him in, for an axis that swaps no garment.
  ///
  /// Sampled a little past halfway, which is where every gesture's own peak
  /// falls — its tracks ease out to rest by the end, so a pose taken at 1.0 is
  /// the same standing figure for all sixteen of them. See [LookPreview.pose].
  GesturePose? get _pose {
    if (axis.kind != 'emote') return null;
    final gesture = gestures.where((g) => g.id == id).firstOrNull;
    if (gesture == null) return null;
    return gesturePose(id, 0.55, gestureMs: gesture.ms);
  }

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
      label: locked ? '$_label - $lockedReason' : _label,
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
                          pose: _pose,
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


/// **THE OFFER FOR A LOCKED ITEM, standing on the touchline with him.**
///
/// Asked for directly from the couch, and the placement is the whole idea: the
/// stage is the biggest and emptiest thing on the sheet, the item being sold is
/// on the figure in the middle of it, and two full-width CTAs have somewhere
/// obvious to go. A sheet rising over the bottom half — which is what this
/// replaced — covers the very thing the tap was for.
///
/// Both routes, in the shop's own colour language: yellow is a rewarded video
/// and blue is gems. The pack line is what makes the gem price an offer for ten
/// items rather than a bigger number than the free one beside it.
class _LockedOfferBar extends ConsumerWidget {
  const _LockedOfferBar({
    required this.kind,
    required this.id,
    required this.packId,
    required this.reason,
    required this.onWatch,
    required this.onBuy,
    required this.onClose,
  });

  final String kind;
  final String id;

  /// The pack this item is in, or null for a lock nothing can open on the spot
  /// — a Fan Zone tier, a cup. See [_ManagerCustomiserState._offer].
  final String? packId;

  /// Why it is locked, from [lockedReason]. The only line under the name when
  /// there is no pack, and the line the toast used to carry on its own.
  final String reason;
  final VoidCallback onWatch;
  final VoidCallback onBuy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveRevisionProvider);
    final save = ref.read(gameProvider).state;
    final pack = packId;
    final tile = pack == null ? null : lookTileState(save, pack);
    final waiting = !canWatchPackAd(save);
    return Container(
      key: const ValueKey('locked-look-offer'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        // A scrim rather than a panel: he is still walking behind it, and the
        // whole point of the bar being here is that you can see him.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lookItemLabel(kind, id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      // `reason` IS the pack line when there is a pack —
                      // `lockedReason` falls through to `customise.locked.pack`
                      // — so the two cases differ only in the progress after
                      // it, and a cup or a Fan Zone tier reads as itself.
                      tile == null
                          ? reason
                          : '$reason · '
                                '${t('customise.pack.progress', {'n': tile.owned, 'total': tile.total})}',
                      key: const ValueKey('locked-look-progress'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              // A way out that is not "tap something else": the bar sits over
              // the picture, and a player who only wanted a look needs it back.
              IconButton(
                key: const ValueKey('locked-look-close'),
                onPressed: onClose,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              ),
            ],
          ),
          // **NOTHING TO SELL IS NOT AN EMPTY ROW.** A cup or a Fan Zone tier
          // has no video and no price, so the bar is the item's name and the
          // line saying what it waits on — which is the whole of what the
          // player asked to be shown, with the item on the rig behind it.
          if (pack != null) ...[
            const SizedBox(height: 6),
            // **FULL-SIZE BUTTONS, not the row variant.** `small` is the list
            // line's — 11pt type in a 9pt radius — and these are the only two
            // controls on the stage: asked for as "the buttons need a little
            // more height to match others", which is the same call the shop's
            // pack pill got for the same reason.
            Row(
              children: [
                Expanded(
                  child: StoreButton(
                    key: const ValueKey('locked-look-watch'),
                    tone: StoreTone.ad,
                    label: waiting
                        ? t('customise.pack.wait', {
                            'time': formatAdWait(msUntilPackAd(save)),
                          })
                        : t('customise.pack.watch'),
                    onTap: waiting ? null : onWatch,
                  ),
                ),
                if (tile != null && tile.status != 'owned') ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: StoreButton(
                      key: const ValueKey('locked-look-buy'),
                      tone: StoreTone.gem,
                      label: '${t('customise.pack.unlock_all')} · ${tile.cost}',
                      leading: const GameIcon('gem', size: 14),
                      onTap: onBuy,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
