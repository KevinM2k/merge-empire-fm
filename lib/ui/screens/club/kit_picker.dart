/// The club's colours, and the row that opens them. Ported from
/// `_renderKitRedesign` and `_openKitPicker` in `ui/screens/ClubScreen.js`.
///
/// **This was missing entirely.** `kitPrimaryColor` is the one value that themes
/// the WHOLE app — every surface, the tab bar, the manager's shirt, the crests,
/// the next-match card — and the port had no way to change it. Twenty-one kits,
/// six of them earned by upgrading the Stadium, and the player could reach none
/// of them.
///
/// **Picking one does NOT close the sheet.** A kit recolours the app behind the
/// picker, so the point of staying open is that the player can see what they just
/// chose and try the next one. Closing on the first tap makes comparing two kits
/// cost two journeys.
///
/// **A locked swatch stays on the grid**, desaturated and padlocked, and says
/// which Stadium tier would unlock it. Hidden, the reward for upgrading would be
/// a surprise nobody was working towards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/club_assets.dart';
import 'package:merge_empire_fc/data/kit_palette.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/util/event_bus.dart';

/// The nine every club starts with. `BASE_KIT_COLORS` in the JS.
const List<String> baseKitColours = [
  '#4caf50',
  '#e53935',
  '#1e88e5',
  '#ffb300',
  '#8e24aa',
  'turf',
  '#546e7a',
  'humbug',
  '#d4e157',
];

/// Every kit there is, in grid order: the base nine, then the Stadium unlocks in
/// tier order. Locked ones are SHOWN, not skipped.
List<String> get allKitColours => [
  ...baseKitColours,
  for (final entry in stadiumColourUnlocks.entries) ...entry.value,
];

/// Which Stadium tier a locked colour is waiting on.
int? kitUnlockTier(String colour) {
  for (final entry in stadiumColourUnlocks.entries) {
    if (entry.value.contains(colour)) return entry.key;
  }
  return null;
}

final kitColourProvider = savePick<String>((s) {
  final club = s['club'];
  final id = club is Map<String, dynamic> ? club['kitPrimaryColor'] : null;
  return id is String && id.isNotEmpty ? id : defaultKitColor;
});

/// Change the club's colours, and tell the app.
void setKitColour(WidgetRef ref, String colour) {
  ref.read(gameProvider).update((s) {
    final club = s.putIfAbsent(
      'club',
      () => <String, dynamic>{
        'kitPrimaryColor': defaultKitColor,
        'polishLevel': 0,
      },
    );
    if (club is Map<String, dynamic>) club['kitPrimaryColor'] = colour;
  });
  // The bus event the JS emits. Anything painting in club colours that is not
  // driven by the theme listens for it.
  emit('kit:changed', colour);
}

/// The row on the Club screen: the current colour, what it is, and the way in.
class KitRedesignRow extends ConsumerWidget {
  const KitRedesignRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final current = ref.watch(kitColourProvider);

    return Container(
      key: const ValueKey('kit-redesign-row'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kit.border),
      ),
      child: Row(
        children: [
          _Swatch(colour: current, size: 32, radius: 6, selected: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('club.kit_design'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  t('club.kit_design_hint'),
                  style: TextStyle(fontSize: 11, color: kit.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            key: const ValueKey('kit-redesign'),
            onPressed: () => showKitPicker(context, ref),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              t('club.redesign'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showKitPicker(BuildContext context, WidgetRef ref) {
  return showDialog<void>(context: context, builder: (_) => const _KitPicker());
}

class _KitPicker extends ConsumerWidget {
  const _KitPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final current = ref.watch(kitColourProvider);
    // The UNLOCK tier, not the scene one: `stadiumTierProvider` floors at one
    // for the stadium photo and the sky, and gating with that floor gave these
    // four away before the Stadium existed.
    final stadiumTier = ref.watch(stadiumUnlockTierProvider);
    final unlocked = {...baseKitColours, ...getUnlockedColours(stadiumTier)};

    return Dialog(
      backgroundColor: kit.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: kit.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            key: const ValueKey('kit-picker'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('kit.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  for (final colour in allKitColours)
                    _SwatchButton(
                      colour: colour,
                      selected: colour == current,
                      unlocked: unlocked.contains(colour),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('kit-picker-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t('common.close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwatchButton extends ConsumerWidget {
  const _SwatchButton({
    required this.colour,
    required this.selected,
    required this.unlocked,
  });

  final String colour;
  final bool selected;
  final bool unlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = kitUnlockTier(colour);
    return GestureDetector(
      key: ValueKey('kit-swatch-$colour'),
      onTap: () {
        if (unlocked) {
          setKitColour(ref, colour);
          return;
        }
        // Says which tier, rather than doing nothing. A dead swatch teaches the
        // player that the locked half of the grid is not worth tapping.
        emit('toast:info', t('club.swatch_locked_toast', {'tier': tier ?? 1}));
      },
      child: Tooltip(
        message: unlocked
            ? _swatchTitle(colour)
            : t('club.swatch_locked_title', {'tier': tier ?? 1}),
        child: _Swatch(
          colour: colour,
          size: null,
          radius: 10,
          selected: selected,
          locked: !unlocked,
        ),
      ),
    );
  }
}

/// The two PATTERN kits are the only ones a colour name cannot describe, so they
/// carry theirs.
String _swatchTitle(String colour) => switch (colour) {
  'turf' => t('kit.swatch.turf_title'),
  'humbug' => t('kit.swatch.humbug_title'),
  _ => colour,
};

/// One kit, painted. Patterned kits render their real bands rather than a flat
/// approximation — `fill: humbug` is not a colour, and every surface that took
/// the raw id and dropped it into a paint got black instead of the kit.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.colour,
    required this.size,
    required this.radius,
    required this.selected,
    this.locked = false,
  });

  final String colour;
  final double? size;
  final double radius;
  final bool selected;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final stripes = kitStripes(colour);

    Widget face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: stripes == null ? cssColour(kitSolidColor(colour)) : null,
        gradient: stripes == null
            ? null
            : LinearGradient(
                // Bands, not a blend — a striped kit read as a muddy average
                // when it was drawn as a two-stop gradient.
                colors: [
                  cssColour(stripes.$1),
                  cssColour(stripes.$1),
                  cssColour(stripes.$2),
                  cssColour(stripes.$2),
                ],
                stops: const [0, 0.25, 0.25, 0.5],
                tileMode: TileMode.repeated,
                begin: Alignment.topLeft,
                end: const Alignment(-0.4, 1),
              ),
        border: Border.all(
          color: selected ? Colors.white : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: locked
          ? Center(
              child: GameIcon(
                'lock',
                size: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            )
          // A pattern kit gets its name on a dark pill: the bands alternate
          // light and dark, so no single ink holds contrast across both.
          : stripes == null
          ? null
          : Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  t(colour == 'turf' ? 'kit.swatch.turf' : 'kit.swatch.humbug'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
    );

    if (locked) {
      face = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_lockedWash),
        child: face,
      );
    }

    final box = size == null
        ? AspectRatio(aspectRatio: 1, child: face)
        : SizedBox(width: size, height: size, child: face);

    return selected && size != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: kit.border),
            ),
            child: box,
          )
        : box;
  }
}

/// `saturate(0) brightness(0.45)` — the JS's own treatment for a locked swatch.
const List<double> _lockedWash = <double>[
  0.0954,
  0.3186,
  0.036,
  0,
  0,
  0.0954,
  0.3186,
  0.036,
  0,
  0,
  0.0954,
  0.3186,
  0.036,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

/// A `#rrggbb` string as a colour, defaulting to the base green rather than
/// throwing on a pattern id that reached the wrong call.
Color cssColour(String value) {
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null || hex.length != 6
      ? const Color(0xFF4CAF50)
      : Color(0xFF000000 | parsed);
}
