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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/manager_looks.dart';
import 'package:merge_empire_fc/data/manager_mood.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/screens/home/league_providers.dart';
import 'package:merge_empire_fc/ui/screens/home/manager_walker.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/theme/sky.dart';

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
  _ => const [],
};

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

class ManagerCustomiser extends ConsumerStatefulWidget {
  const ManagerCustomiser({super.key});

  @override
  ConsumerState<ManagerCustomiser> createState() => _ManagerCustomiserState();
}

class _ManagerCustomiserState extends ConsumerState<ManagerCustomiser> {
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: _AxisPicker(
            axes: lookAxes,
            index: _axis,
            onPick: (i) => setState(() => _axis = i),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _Grid(
            axis: axis,
            look: look,
            state: _save,
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
/// The diorama's own sky and turf rather than a colour picked to look like
/// them — one source for the two means a look chosen in here is judged against
/// the light it will actually be seen in.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ClipRRect(
      key: const ValueKey('customise-stage'),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 190,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: skyGradient(brightness: brightness, tier: 1),
              ),
            ),
            // A strip of grass under him rather than a whole pitch: the sheet is
            // about the man, and a mown fan in a 190px box is a texture nobody
            // asked for.
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: 0.34,
                child: DecoratedBox(
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
    required this.state,
    required this.onPick,
  });

  final LookAxis axis;
  final ManagerLook? look;
  final Map<String, dynamic>? state;
  final void Function(String id) onPick;

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
        final id = ids[i];
        final locked = lockedReason(state, axis.kind, id);
        return _Chip(
          axis: axis,
          id: id,
          look: look,
          selected: id == current,
          lockedReason: locked,
          onTap: () {
            if (locked != null) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(locked),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
class _LookPreview extends StatelessWidget {
  const _LookPreview({required this.axis, required this.look});

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
    required this.onTap,
  });

  final LookAxis axis;
  final String id;

  /// The player's current look, for the preview to swap this choice into.
  final ManagerLook? look;
  final bool selected;
  final String? lockedReason;
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
  /// accessible name at all unless one is said out loud.
  String get _label {
    final named = t('customise.${axis.kind}.$id');
    // The wardrobe is ids-first and only the axes with real names carry
    // strings; the rest are the id, tidied, which is what the JS falls back to
    // as well.
    if (!named.startsWith('customise.')) return named;
    return id[0].toUpperCase() + id.substring(1);
  }

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
                        _LookPreview(
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
                      if (locked)
                        Align(
                          alignment: Alignment.topRight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: kit.bg.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Icon(
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
