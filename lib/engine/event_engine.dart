/// Event lifecycle — activation, progress tracking, reward claiming. Ported
/// from `../merge-empire-fc/src/engine/eventEngine.js`.
///
/// The trigger dispatch is extension-ready: a new kind adds one case here and
/// one subclass in the catalogue, with no engine rewrite.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/util/event_bus.dart';
import 'package:merge_empire_fc/util/format.dart';
import 'package:merge_empire_fc/util/time.dart';

const int oneDayMs = 24 * 60 * 60 * 1000;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

Map<String, dynamic> _branch(Map<String, dynamic> owner, String key) {
  final existing = _map(owner[key]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{};
  owner[key] = fresh;
  return fresh;
}

List<dynamic> _list(Map<String, dynamic> owner, String key) {
  final existing = owner[key];
  if (existing is List) return existing;
  final fresh = <dynamic>[];
  owner[key] = fresh;
  return fresh;
}

/// Where an event sits relative to now.
///
/// A recurring window never reports `ended`: it comes back, so once an
/// occurrence closes the event is only ever counting down to the next one.
enum EventPhase {
  /// Outside both the preview window and the live one.
  inactive,

  /// Within `previewDays` of the start, but not yet live.
  preview,

  /// The trigger says fire now — a live window, or a dev override.
  active,

  /// The window has passed and will not return.
  ended,
}

/// Where [def] sits relative to [nowMs].
EventPhase eventPhase(EventDef? def, Map<String, dynamic>? state, [int? nowMs]) {
  if (def == null) return EventPhase.inactive;
  final at = nowMs ?? now();
  if (_map(state?['events'])?['devOverride'] == def.id) return EventPhase.active;

  final trigger = def.trigger;

  switch (trigger) {
    case AnnualWindowTrigger():
      if (currentAnnualWindow(trigger, at) != null) return EventPhase.active;
      final next = nextAnnualWindow(trigger, at);
      if (next == null) return EventPhase.inactive;
      if (trigger.previewDays > 0 &&
          at >= next.start - trigger.previewDays * oneDayMs) {
        return EventPhase.preview;
      }
      return EventPhase.inactive;

    case DateWindowTrigger():
      final start = trigger.startMs;
      final end = trigger.endMs;
      if (start == null || end == null) return EventPhase.inactive;
      if (at >= start && at <= end) return EventPhase.active;
      if (at > end) return EventPhase.ended;
      if (trigger.previewDays > 0 &&
          at >= start - trigger.previewDays * oneDayMs) {
        return EventPhase.preview;
      }
      return EventPhase.inactive;
  }
}

/// Milliseconds until the window opens, or 0 when it is already open or past.
int eventStartsInMs(EventDef? def, [int? nowMs]) {
  final at = nowMs ?? now();
  final trigger = def?.trigger;
  switch (trigger) {
    case AnnualWindowTrigger():
      if (currentAnnualWindow(trigger, at) != null) return 0;
      final next = nextAnnualWindow(trigger, at);
      return next == null ? 0 : math.max(0, next.start - at);
    case DateWindowTrigger():
      final start = trigger.startMs;
      return start == null ? 0 : math.max(0, start - at);
    case null:
      return 0;
  }
}

/// When the live occurrence closes, or 0 when it isn't live. Both window kinds
/// answer this, so countdown UI doesn't have to branch.
int eventEndsAtMs(EventDef? def, [int? nowMs]) {
  final at = nowMs ?? now();
  final trigger = def?.trigger;
  switch (trigger) {
    case AnnualWindowTrigger():
      return currentAnnualWindow(trigger, at)?.end ?? 0;
    case DateWindowTrigger():
      return trigger.endMs ?? 0;
    case null:
      return 0;
  }
}

/// Events currently in their preview window, soonest first.
List<EventDef> previewEvents(Map<String, dynamic>? state, [int? nowMs]) {
  final at = nowMs ?? now();
  final out = [
    for (final def in eventCatalogue)
      if (eventPhase(def, state, at) == EventPhase.preview) def,
  ];
  out.sort((a, b) => eventStartsInMs(a, at) - eventStartsInMs(b, at));
  return out;
}

/// Should [def] be active given [state] and [nowMs]?
///
/// A dev override — the hidden Settings toggle — bypasses the trigger entirely,
/// so an event can be dogfooded without touching the device clock.
bool evaluateTrigger(EventDef? def, Map<String, dynamic>? state, [int? nowMs]) {
  if (def == null) return false;
  final at = nowMs ?? now();
  if (_map(state?['events'])?['devOverride'] == def.id) return true;

  return switch (def.trigger) {
    final DateWindowTrigger t => isInDateWindow(t, at),
    final AnnualWindowTrigger t => isInAnnualWindow(t, at),
  };
}

Map<String, dynamic> _ensureProgress(Map<String, dynamic> state, String eventId) {
  final progressMap = _branch(_branch(state, 'events'), 'progress');
  final existing = _map(progressMap[eventId]);
  if (existing != null) return existing;
  final fresh = <String, dynamic>{
    'score': 0,
    'claimedTiers': <dynamic>[],
    'challenges': <String, dynamic>{},
    'cup': null,
    'activatedAt': now(),
  };
  progressMap[eventId] = fresh;
  return fresh;
}

/// Activate every catalogue event whose trigger fires, and retire every one
/// whose window has closed. Returns the ids newly activated.
///
/// Idempotent, so it can run on boot and on every resume — an event then
/// activates the moment its window opens, even if the app was already running.
List<String> activateEligibleEvents(Map<String, dynamic> state, [int? nowMs]) {
  final eventsBranch = _map(state['events']);
  if (eventsBranch == null) return [];
  final at = nowMs ?? now();
  final active = _list(eventsBranch, 'active');
  final newlyActivated = <String>[];

  for (final def in eventCatalogue) {
    final wasActive = active.contains(def.id);
    final shouldBeActive = evaluateTrigger(def, state, at);

    if (shouldBeActive && !wasActive) {
      active.add(def.id);
      _ensureProgress(state, def.id);
      newlyActivated.add(def.id);
      emit('event:activated', {'eventId': def.id, 'name': def.name});
    } else if (!shouldBeActive && wasActive) {
      endEventCleanup(state, def.id);
    }
  }

  return newlyActivated;
}

/// Move an event from active to history, keeping its progress so the player can
/// still see what they earned. Idempotent.
void endEventCleanup(Map<String, dynamic> state, String eventId) {
  final eventsBranch = _map(state['events']);
  if (eventsBranch == null) return;
  final active = _list(eventsBranch, 'active');
  final idx = active.indexOf(eventId);
  if (idx < 0) return;

  active.removeAt(idx);
  final progress = _map(_map(eventsBranch['progress'])?[eventId]) ?? const {};
  final cup = progress['cup'];

  _list(eventsBranch, 'history').add(<String, dynamic>{
    'eventId': eventId,
    'finalScore': _num(progress['score'])?.toInt() ?? 0,
    'claimedTiers': progress['claimedTiers'] ?? <dynamic>[],
    'cup': cup,
    'won': _map(cup)?['won'] == true,
    'endedAt': now(),
  });

  emit('event:ended', {
    'eventId': eventId,
    'name': getEventById(eventId)?.name ?? eventId,
  });
}

/// The catalogue entries this save currently has running.
List<EventDef> activeEvents(Map<String, dynamic>? state) {
  final active = _map(state?['events'])?['active'];
  if (active is! List) return [];
  return [
    for (final id in active) ?getEventById('$id'),
  ];
}

/// This save's progress in one event, or null if it has none.
Map<String, dynamic>? eventProgress(Map<String, dynamic>? state, String eventId) =>
    _map(_map(_map(state?['events'])?['progress'])?[eventId]);

bool isEventActive(Map<String, dynamic>? state, String eventId) {
  final active = _map(state?['events'])?['active'];
  return active is List && active.contains(eventId);
}

/// Track a player action against every active event's challenges.
///
/// The other half of the action funnel — the quest track is the first. Score
/// accrues when a challenge completes.
///
/// [actionType] is a quest action, or an event-only type the cup flow emits.
/// Anything nothing is watching passes through harmlessly.
void trackEventAction(
  Map<String, dynamic> state,
  String actionType, [
  num amount = 1,
]) {
  final eventsBranch = _map(state['events']);
  if (eventsBranch == null) return;
  final active = eventsBranch['active'];
  if (active is! List) return;

  for (final rawId in List<dynamic>.of(active)) {
    final eventId = '$rawId';
    final def = getEventById(eventId);
    if (def == null || def.challengeConfig.isEmpty) continue;
    final progress = _ensureProgress(state, eventId);
    final challenges = _branch(progress, 'challenges');

    for (final challenge in def.challengeConfig) {
      if (challenge.type != actionType) continue;
      var cp = _map(challenges[challenge.id]);
      if (cp == null) {
        cp = <String, dynamic>{
          'progress': 0,
          'completed': false,
          'scoredAt': null,
        };
        challenges[challenge.id] = cp;
      }
      if (cp['completed'] == true) continue;

      cp['progress'] = math.min(
        (_num(cp['progress']) ?? 0) + amount,
        challenge.target,
      );
      if ((_num(cp['progress']) ?? 0) >= challenge.target) {
        cp['completed'] = true;
        cp['scoredAt'] = now();
        progress['score'] = (_num(progress['score']) ?? 0) + challenge.points;
        emit('event:challenge-completed', {
          'eventId': eventId,
          'challengeId': challenge.id,
          'points': challenge.points,
        });
        emit('event:score-updated', {
          'eventId': eventId,
          'score': progress['score'],
        });
      }
    }
  }
}

/// The outcome of a claim.
typedef ClaimResult = ({bool ok, num coins, String? reason});

/// Claim a completed event challenge.
///
/// Pays the current division's `matchRevenueBase` times the challenge's
/// multiplier, so the reward scales with whatever league the player is in.
/// Idempotent — a second claim fails with `already_claimed`.
ClaimResult claimEventChallenge(
  Map<String, dynamic> state,
  String eventId,
  String challengeId,
) {
  final def = getEventById(eventId);
  if (def == null || def.challengeConfig.isEmpty) {
    return (ok: false, coins: 0, reason: 'unknown_event');
  }
  EventChallenge? challenge;
  for (final c in def.challengeConfig) {
    if (c.id == challengeId) challenge = c;
  }
  if (challenge == null) {
    return (ok: false, coins: 0, reason: 'unknown_challenge');
  }

  final progress = eventProgress(state, eventId);
  final cp = _map(_map(progress?['challenges'])?[challengeId]);
  if (cp == null || cp['completed'] != true) {
    return (ok: false, coins: 0, reason: 'not_completed');
  }
  if (cp['claimed'] == true) {
    return (ok: false, coins: 0, reason: 'already_claimed');
  }

  final div = getDivision('${_map(state['progression'])?['currentDivision']}');
  final coins = roundCoins(div.matchRevenueBase * challenge.rewardMult);
  final resources = _branch(state, 'resources');
  if (coins > 0) {
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + coins;
  }
  cp['claimed'] = true;
  cp['claimedAt'] = now();
  emit('event:challenge-claimed', {
    'eventId': eventId,
    'challengeId': challengeId,
    'coins': coins,
  });
  if (coins > 0) emit('coins:updated', resources['fanCoins']);
  return (ok: true, coins: coins, reason: null);
}

/// The outcome of claiming a reward tier.
typedef TierClaimResult = ({bool ok, EventReward? reward, String? reason});

/// Claim a reward tier the player has earned. Idempotent — no double claims.
TierClaimResult claimRewardTier(
  Map<String, dynamic> state,
  String eventId,
  int tierIdx,
) {
  final def = getEventById(eventId);
  if (def == null) {
    return (ok: false, reward: null, reason: 'unknown_event');
  }
  if (tierIdx < 0 || tierIdx >= def.rewardTrack.length) {
    return (ok: false, reward: null, reason: 'unknown_tier');
  }
  final tier = def.rewardTrack[tierIdx];

  final progress = _ensureProgress(state, eventId);
  if ((_num(progress['score']) ?? 0) < tier.score) {
    return (ok: false, reward: null, reason: 'not_earned');
  }
  final claimed = _list(progress, 'claimedTiers');
  if (claimed.contains(tierIdx)) {
    return (ok: false, reward: null, reason: 'already_claimed');
  }

  final r = tier.reward;
  final resources = _branch(state, 'resources');
  if (r.coins > 0) {
    resources['fanCoins'] = (_num(resources['fanCoins']) ?? 0) + roundCoins(r.coins);
  }
  if (r.trophies > 0) {
    resources['trophies'] = (_num(resources['trophies']) ?? 0) + r.trophies;
  }
  if (r.energy > 0) {
    // Capped at the UPGRADED maximum, whether or not this save has the
    // upgrade — the same ceiling the challenge claim uses.
    final energy = _branch(state, 'energy');
    energy['current'] = math.min(
      (_num(energy['current']) ?? 0) + r.energy,
      Energy.maxUpgraded,
    );
  }
  if (r.freeScout) _branch(state, 'shop')['freeScoutReady'] = true;

  claimed.add(tierIdx);
  emit('event:reward-claimed', {
    'eventId': eventId,
    'tierIdx': tierIdx,
    'reward': r,
  });
  if (r.coins > 0) emit('coins:updated', resources['fanCoins']);
  return (ok: true, reward: r, reason: null);
}
