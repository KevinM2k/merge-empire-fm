/// The Trophy Room. Ported from `ui/screens/TrophyRoomScreen.js`.
///
/// A shell sheet rather than a tab, because it is a destination rather than a
/// place you live — and the sheet's own grab-handle chrome is why the JS gives
/// this screen no title of its own.
///
/// `leagueTrophies` carries three kinds of entry and this room draws two of
/// them: division titles and cups.
///
/// **Event entries are deliberately not drawn.** `event_cup_engine` no longer
/// writes one — its comment says why, that an event win surfaces as an
/// achievement and a trophy card as well would double it up — so the only
/// entries left are in saves from before that change, and drawing those would
/// reintroduce exactly the double the engine removed. The JS groups them by
/// (event, nation), counts them, stashes them on the instance to "fold into the
/// Special Events section", and then never reads the variable: the same
/// conclusion, arrived at by abandoning the code halfway. Filtering them out
/// with a reason is the same screen and a legible one.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/data/art_paths.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/engine/badge_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/shell/shell_controller.dart';
import 'package:merge_empire_fc/ui/shell/shell_routes.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/art_image.dart';
import 'package:merge_empire_fc/ui/widgets/badge_icon.dart';
import 'package:merge_empire_fc/util/format.dart';

/// Gold. The one colour in the game that is NOT derived from the club's kit:
/// a trophy is gold whoever won it, and tinting it team colours would make an
/// achievement look like a kit item.
const Color trophyGold = Color(0xFFFFD700);

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// One trophy card.
typedef TrophyView = ({bool isCup, String division, int season, int position});

/// Everything the room draws, resolved in one pass over the save.
typedef TrophyRoomView = ({
  List<TrophyView> league,
  List<TrophyView> cups,
  Set<String> unlockedIds,
  Map<String, int> unlockCounts,
  Map<String, int> unlockedAt,
  String equippedBadgeId,
});

TrophyView _trophyFrom(Map<String, dynamic> raw) => (
  isCup: raw['cup'] == true,
  division: '${raw['division'] ?? ''}',
  season: _num(raw['season'])?.toInt() ?? 0,
  position: _num(raw['position'])?.toInt() ?? 0,
);

final trophyRoomProvider = savePick<TrophyRoomView>((s) {
  final prog = _map(s['progression']);
  final raw = prog?['leagueTrophies'];
  final league = <TrophyView>[];
  final cups = <TrophyView>[];

  for (final entry in raw is List ? raw : const []) {
    final trophy = _map(entry);
    if (trophy == null) continue;
    // See the header: an event entry is a legacy one, and its achievement tile
    // already says the player won it.
    if (trophy['event'] == true) continue;
    if (trophy['cup'] == true) {
      cups.add(_trophyFrom(trophy));
    } else {
      league.add(_trophyFrom(trophy));
    }
  }

  final counts = <String, int>{};
  final at = <String, int>{};
  for (final entry
      in (prog?['achievements'] is List
          ? prog!['achievements'] as List
          : const [])) {
    final a = _map(entry);
    final id = a?['id'];
    if (id is! String) continue;
    counts[id] = _num(a!['count'])?.toInt() ?? 1;
    final stamp = _num(a['unlockedAt'])?.toInt();
    if (stamp != null) at[id] = stamp;
  }

  return (
    league: league,
    cups: cups,
    unlockedIds: getUnlockedIds(s),
    unlockCounts: counts,
    unlockedAt: at,
    equippedBadgeId: getEquippedBadgeId(s),
  );
});

/// An achievement's title and description come from the catalogue when it has
/// them and from the data file when it does not — 61 of the 81 are translated,
/// and the rest would otherwise render their raw key across a tile.
String achievementTitle(Achievement a) {
  final key = 'ach.title.${a.id}';
  final hit = t(key);
  return hit == key ? a.title : hit;
}

String achievementDescription(Achievement a) {
  final key = 'ach.desc.${a.id}';
  final hit = t(key);
  return hit == key ? a.description : hit;
}

String _categoryLabel(String cat) {
  final key = 'ach.cat.$cat';
  final hit = t(key);
  return hit == key ? (categoryLabels[cat] ?? cat) : hit;
}

Future<void> showTrophyRoomSheet(BuildContext context) =>
    openShellSheet(context, ShellSheet.trophies, const _TrophyRoom());

class _TrophyRoom extends ConsumerWidget {
  const _TrophyRoom();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(trophyRoomProvider);
    final kit = Theme.of(context).extension<KitTheme>()!;
    final hasSessionTrophies = view.league.isNotEmpty || view.cups.isNotEmpty;

    return Padding(
      key: const ValueKey('trophy-room'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeRow(equipped: view.equippedBadgeId),
          if (hasSessionTrophies) ...[
            const SizedBox(height: 16),
            _SectionLabel(t('trophy.session_label'), muted: true),
          ],
          if (view.league.isNotEmpty) ...[
            _SectionLabel(t('trophy.league_count', {'n': view.league.length})),
            _TrophyGrid(trophies: view.league),
          ],
          if (view.cups.isNotEmpty) ...[
            _SectionLabel(t('trophy.cup_count', {'n': view.cups.length})),
            _TrophyGrid(trophies: view.cups),
          ],
          if (!hasSessionTrophies) ...[
            const SizedBox(height: 12),
            Text(
              t('trophy.empty_league'),
              key: const ValueKey('trophy-empty'),
              style: TextStyle(color: kit.textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          _SectionLabel(
            t('trophy.ach_count', {
              'done': view.unlockedIds.length,
              'total': achievements.length,
            }),
            muted: true,
          ),
          for (final category in achievementCategories)
            ..._categorySection(category, view),
        ],
      ),
    );
  }

  List<Widget> _categorySection(String category, TrophyRoomView view) {
    final items = [
      for (final a in achievements)
        if (a.category == category) a,
    ];
    if (items.isEmpty) return const [];
    // Special Events stays hidden until one is earned. Listing them would spoil
    // what is out there for someone who has never seen a live event.
    if (category == 'events' &&
        !items.any((a) => view.unlockedIds.contains(a.id))) {
      return const [];
    }
    return [
      _SectionLabel(_categoryLabel(category)),
      _AchievementGrid(items: items, view: view),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: muted ? 12 : 11,
          fontWeight: muted ? FontWeight.w700 : FontWeight.w800,
          letterSpacing: muted ? 0.5 : 1,
          color: muted ? kit.textMuted : kit.accentBright,
        ),
      ),
    );
  }
}

/// "Your Badge" — the one thing every player has set, so it sits above the
/// lists rather than under them. It is READ here and chosen from an
/// achievement's detail sheet, which is where the choice actually lives.
class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.equipped});

  final String equipped;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return Container(
      key: const ValueKey('trophy-badge-row'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.border),
      ),
      child: Row(
        children: [
          BadgeIcon(badgeId: equipped, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('trophy.badge_title').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kit.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('trophy.badge_hint'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: kit.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrophyGrid extends StatelessWidget {
  const _TrophyGrid({required this.trophies});

  final List<TrophyView> trophies;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: [for (final trophy in trophies) _TrophyCard(trophy: trophy)],
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.trophy});

  final TrophyView trophy;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final cupDef = trophy.isCup ? getCupById(trophy.division) : null;
    final divDef = trophy.isCup ? null : getDivision(trophy.division);
    final colour = cssColor(cupDef?.color ?? divDef?.color ?? '#ffd700');

    final name = cupDef != null
        ? tName('cup', cupDef.id)
        : divDef != null
        ? tName('division', divDef.id)
        : t('trophy.trophy');

    final path = trophy.isCup
        ? cupTrophyPath(trophy.division)
        : divisionTrophyPath(trophy.division);

    final subtitle = trophy.isCup
        ? t('trophy.cup_subtitle', {'season': trophy.season})
        : trophy.position > 0
        ? t('trophy.league_subtitle', {
            'season': trophy.season,
            'position': trophy.position,
          })
        : t('trophy.season_label', {'season': trophy.season});

    return Container(
      key: ValueKey('trophy-${trophy.division}-${trophy.season}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kit.surface,
        // The JS paints a wash of the trophy's own colour over the surface.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colour.withValues(alpha: 0.27), Colors.transparent],
          stops: const [0, 0.55],
        ),
        border: Border.all(color: colour, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Same as the achievement tiles: the trophy fills its box and the
          // caption sits over it. `contain` inside a padded column left a
          // letterboxed picture in two thirds of the tile.
          ArtImage(
            path: path,
            fallback: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 44)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(10),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kit.surface.withValues(alpha: 0),
                    kit.surface.withValues(alpha: 0.88),
                    kit.surface.withValues(alpha: 0.96),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                child: Column(
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: colour,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 3),
                        ],
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: kit.textMuted),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "×3" — an achievement earned in more than one prestige run. A league title
/// or a cup is one card each, so only the achievement tiles wear this.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: trophyGold,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      '×$count',
      style: const TextStyle(
        color: Colors.black,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _AchievementGrid extends StatelessWidget {
  const _AchievementGrid({required this.items, required this.view});

  final List<Achievement> items;
  final TrophyRoomView view;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        // `repeat(auto-fill, minmax(110px, 1fr))` — the same tile size, so the
        // column count follows the screen width rather than being fixed.
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, i) =>
          _AchievementTile(achievement: items[i], view: view),
    );
  }
}

class _AchievementTile extends ConsumerWidget {
  const _AchievementTile({required this.achievement, required this.view});

  final Achievement achievement;
  final TrophyRoomView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final unlocked = view.unlockedIds.contains(achievement.id);
    final count = view.unlockCounts[achievement.id] ?? 1;
    final border = unlocked ? trophyGold.withValues(alpha: 0.75) : kit.border;
    final progress = unlocked
        ? null
        : _progressOf(achievement, ref.read(gameProvider).state);

    return GestureDetector(
      key: ValueKey('achievement-${achievement.id}'),
      onTap: () => _showDetail(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? kit.surface : kit.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // **THE PICTURE FILLS THE TILE.** It used to take an `Expanded`
            // slice with the caption below it, so a 512×512 painting was
            // letterboxed into two thirds of a square box and the tile read as
            // an icon with a label rather than as a trophy.
            ArtImage(
              path: achievementArtPath(achievement.id),
              dimmed: !unlocked,
              fallback: Center(
                child: Text(
                  achievement.icon ?? '🏅',
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),
            // The caption OVER it, as a band. Its own bottom radius matters: the
            // tile clips to a 12px round and its border is 2px wide, so the
            // child's clip and the border's inner edge are two different curves
            // — and a square-cornered band between them is the sliver that made
            // the tile look loose at the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                  // A scrim rather than a solid slab: the art runs under it, so
                  // the band reads as part of the picture.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kit.surface2.withValues(alpha: 0),
                      kit.surface2.withValues(alpha: 0.86),
                      kit.surface2.withValues(alpha: 0.96),
                    ],
                    stops: const [0, 0.35, 1],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 5),
                  child: Column(
                    children: [
                      Text(
                        achievementTitle(achievement),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: unlocked ? trophyGold : kit.textMuted,
                          shadows: const [
                            // On artwork rather than on a surface now, so the
                            // title needs its own separation where the scrim is
                            // thinnest.
                            Shadow(color: Color(0x99000000), blurRadius: 3),
                          ],
                        ),
                      ),
                      if (progress != null) ...[
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress.$1,
                            minHeight: 3,
                            backgroundColor: kit.border,
                            valueColor: AlwaysStoppedAnimation(
                              trophyGold.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          progress.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 9, color: kit.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (count >= 2)
              Positioned(top: 6, right: 6, child: _CountPill(count: count)),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _AchievementDetail(achievement: achievement, view: view),
    );
  }
}

/// The bar under a locked tile, as (fraction, label) — or null where there is
/// nothing countable to show.
///
/// The JS wraps both calls in try/catch: these are eighty-odd predicates over a
/// save that may be from an older schema, and one that throws must dim a tile
/// rather than take the room down.
(double, String)? _progressOf(Achievement a, Map<String, dynamic>? state) {
  final read = a.progress;
  if (read == null) return null;
  try {
    final p = read(state);
    if (p.target <= 0 || p.current <= 0) return null;
    final label =
        a.progressText?.call(state) ??
        '${formatCoins(p.current)} / ${formatCoins(p.target)}';
    return ((p.current / p.target).clamp(0.0, 1.0).toDouble(), label);
  } catch (_) {
    return null;
  }
}

class _AchievementDetail extends ConsumerWidget {
  const _AchievementDetail({required this.achievement, required this.view});

  final Achievement achievement;
  final TrophyRoomView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final unlocked = view.unlockedIds.contains(achievement.id);
    final isEquipped = unlocked && view.equippedBadgeId == achievement.id;
    final count = view.unlockCounts[achievement.id] ?? 1;
    final game = ref.read(gameProvider);

    return AlertDialog(
      key: ValueKey('achievement-detail-${achievement.id}'),
      backgroundColor: kit.surface,
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 140,
              child: ArtImage(
                path: achievementArtPath(achievement.id),
                fit: BoxFit.contain,
                dimmed: !unlocked,
                dimBrightness: 0.5,
                fallback: Center(
                  child: Text(
                    achievement.icon ?? '🏅',
                    style: const TextStyle(fontSize: 88),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              achievementTitle(achievement),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: unlocked ? trophyGold : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _description(unlocked, game.state),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: kit.textMuted),
            ),
            if (achievement.availability != null) ...[
              const SizedBox(height: 8),
              _AvailabilityPill(achievement: achievement),
            ],
            const SizedBox(height: 14),
            _status(context, unlocked, count, game.state),
          ],
        ),
      ),
      actions: [
        if (unlocked)
          TextButton(
            key: ValueKey('achievement-badge-${achievement.id}'),
            onPressed: isEquipped
                ? null
                : () {
                    game.update((s) => setEquippedBadge(s, achievement.id));
                    Navigator.of(context).pop();
                  },
            child: Text(
              isEquipped
                  ? t('trophy.badge_equipped')
                  : t('trophy.badge_set_btn'),
            ),
          ),
        ElevatedButton(
          key: const ValueKey('achievement-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t('common.close')),
        ),
      ],
    );
  }

  /// An earned achievement can say something richer than its catalogue line —
  /// which nation you won the International Cup with, say.
  String _description(bool unlocked, Map<String, dynamic>? state) {
    if (unlocked && achievement.descriptionWhenUnlocked != null) {
      try {
        final dynamicDesc = achievement.descriptionWhenUnlocked!(state);
        if (dynamicDesc != null) {
          return t(dynamicDesc.i18nKey, dynamicDesc.params);
        }
      } catch (_) {
        // Falls through to the catalogue line.
      }
    }
    return achievementDescription(achievement);
  }

  Widget _status(
    BuildContext context,
    bool unlocked,
    int count,
    Map<String, dynamic>? state,
  ) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    if (unlocked) {
      final stamp = view.unlockedAt[achievement.id];
      return Column(
        children: [
          Text(
            t('trophy.unlocked_at', {
              'date': stamp == null
                  ? t('trophy.date_unknown')
                  : formatDate(stamp),
            }),
            style: TextStyle(fontSize: 11, color: kit.accentBright),
          ),
          if (count >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t('trophy.earned_across_resets', {'n': count}),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: trophyGold,
                ),
              ),
            ),
        ],
      );
    }

    final progress = _progressOf(achievement, state);
    if (progress == null) {
      return Text(
        t('trophy.locked'),
        style: TextStyle(fontSize: 11, color: kit.textMuted),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.$1,
            minHeight: 6,
            backgroundColor: kit.border,
            valueColor: AlwaysStoppedAnimation(
              trophyGold.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(progress.$2, style: TextStyle(fontSize: 11, color: kit.textMuted)),
      ],
    );
  }
}

/// When an achievement could be earned. Once an event closes it becomes
/// un-earnable for anyone who missed it, so the window is stated rather than
/// leaving a permanently locked tile unexplained.
class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final key = achievement.availabilityKey;
    final label = key != null && t(key) != key
        ? t(key)
        : achievement.availability!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: trophyGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: trophyGold.withValues(alpha: 0.4)),
      ),
      child: Text(
        '⏳ ${label.toUpperCase()}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: trophyGold,
        ),
      ),
    );
  }
}
