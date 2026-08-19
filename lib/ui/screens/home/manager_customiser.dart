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
        // The rig itself, standing still. `walking: false` is the whole
        // difference between this and the touchline: a figure mid-stride is a
        // worse look at the thing you are choosing.
        SizedBox(
          height: 170,
          child: Center(
            child: SizedBox(
              width: walkerWidth,
              height: walkerHeight,
              child: ManagerWalker(
                key: const ValueKey('customise-preview'),
                kit: kit.accent,
                skin: const Color(0xFFEEBB8C),
                hair: const Color(0xFF3A2A1C),
                look: look,
                mood: Mood.pleased,
                walking: false,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            key: const ValueKey('customise-axes'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            itemCount: lookAxes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) => _AxisTab(
              key: ValueKey('customise-axis-${lookAxes[i].kind}'),
              label: t(lookAxes[i].labelKey),
              selected: i == _axis,
              onTap: () => setState(() => _axis = i),
            ),
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

class _AxisTab extends StatelessWidget {
  const _AxisTab({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? kit.accent : kit.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? kit.accent : kit.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : kit.textMuted,
          ),
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

/// One choice.
///
/// Deliberately a SWATCH-OR-WORD rather than a miniature of the whole figure.
/// The JS renders a dozen full rigs in here; at four to a row on a phone a
/// whole manager is 60px tall, at which point the thing being chosen — a
/// moustache, a pair of specs — is a few pixels of it. The preview above is
/// where the choice is judged.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.axis,
    required this.id,
    required this.selected,
    required this.lockedReason,
    required this.onTap,
  });

  final LookAxis axis;
  final String id;
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

    return GestureDetector(
      key: ValueKey('customise-chip-${axis.kind}-$id'),
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.45 : 1,
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
          child: locked
              ? Icon(Icons.lock, size: 16, color: kit.textMuted)
              : swatch != null
              ? const SizedBox.shrink()
              : Text(
                  _label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? kit.accentBright : kit.textMuted,
                  ),
                ),
        ),
      ),
    );
  }
}
