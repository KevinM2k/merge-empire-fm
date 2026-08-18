/// The badge on the manager's shirt. Ported from
/// `../merge-empire-fc/src/engine/badgeEngine.js`.
///
/// A badge is an achievement the player has unlocked, worn as an emblem. It
/// tracks the newest one automatically until the player picks one themselves —
/// after that it stays where they put it, because a badge that keeps changing
/// under them is not a choice.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/achievements.dart';
import 'package:merge_empire_fc/engine/achievement_engine.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/sorting.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

/// Every player starts with this badge equipped. It is not an achievement, so it
/// never appears in the unlocked list and is always valid.
const String defaultBadgeId = 'default';

String getEquippedBadgeId(Map<String, dynamic>? state) {
  final id = _map(state?['progression'])?['equippedBadgeId'];
  return id is String && id.isNotEmpty ? id : defaultBadgeId;
}

bool isValidBadgeId(Map<String, dynamic>? state, String? badgeId) {
  if (badgeId == defaultBadgeId) return true;
  return getUnlockedIds(state).contains(badgeId);
}

/// Equip a badge — the default, or an achievement the player has unlocked.
///
/// Returns false and changes nothing for anything else. Flags the badge as
/// manually chosen, which is what stops [autoEquipLatestBadge] tracking.
bool setEquippedBadge(Map<String, dynamic>? state, String? badgeId) {
  if (state == null || !isValidBadgeId(state, badgeId)) return false;
  final prog = _branch(state, 'progression');
  prog['equippedBadgeId'] = badgeId;
  prog['badgeManuallySet'] = true;
  emit('badge:equipped', badgeId);
  return true;
}

List<Map<String, dynamic>> _unlocked(Map<String, dynamic>? state) {
  final raw = _map(state?['progression'])?['achievements'];
  if (raw is! List) return const [];
  return [for (final e in raw) ?_map(e)];
}

/// The most recently unlocked achievement, or null if there are none.
Achievement? getLatestUnlockedAchievement(Map<String, dynamic>? state) {
  final unlocked = _unlocked(state);
  if (unlocked.isEmpty) return null;
  // Stable, so entries stamped at the same instant keep the order they were
  // unlocked in rather than an arbitrary one.
  final newest = stableSorted(
    unlocked,
    (a, b) => ((_num(b['unlockedAt']) ?? 0) - (_num(a['unlockedAt']) ?? 0)).sign
        .toInt(),
  ).first;
  return getAchievementDef(newest['id'] as String?);
}

/// Keep the badge synced to the newest achievement while the player still has
/// the default one — that is, while they have never picked a badge themselves.
///
/// Once they equip one through [setEquippedBadge] this becomes a no-op. Returns
/// true when the equipped badge changed.
bool autoEquipLatestBadge(Map<String, dynamic>? state) {
  if (state == null) return false;
  if (_map(state['progression'])?['badgeManuallySet'] == true) return false;
  final latest = getLatestUnlockedAchievement(state);
  if (latest == null) return false;
  // A non-null `latest` means the branch is already there — the JS guards
  // anyway, and so does this.
  final prog = _branch(state, 'progression');
  if (prog['equippedBadgeId'] == latest.id) return false;
  prog['equippedBadgeId'] = latest.id;
  emit('badge:equipped', latest.id);
  return true;
}

/// Unlocked achievements eligible as a badge, oldest first.
List<Achievement> getBadgeChoices(Map<String, dynamic>? state) => [
  for (final entry in stableSorted(
    _unlocked(state),
    (a, b) => ((_num(a['unlockedAt']) ?? 0) - (_num(b['unlockedAt']) ?? 0)).sign
        .toInt(),
  ))
    ?getAchievementDef(entry['id'] as String?),
];
