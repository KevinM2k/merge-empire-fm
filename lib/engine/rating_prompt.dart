/// When to ask the player to rate the game. Ported from
/// `../merge-empire-fc/src/engine/ratingEngine.js`.
///
/// **THERE IS NO CUSTOM DIALOG ANY MORE, and that is the JS's own decision.**
/// It used to show a five-star pre-prompt and only fire the OS sheet on four or
/// five; its comment records the change — "all star ratings (1–5) trigger the
/// OS-native in-app review sheet — no gating", "the sheet now fires directly (no
/// custom pre-prompt), so WE are the only thing stopping it nagging". So this
/// file is the whole of the restraint: everything here exists to decide whether
/// the platform gets asked at all.
///
/// **Which is why the cap is a LIFETIME one.** Apple rate-limits the sheet to
/// about three a year and shows nothing when it declines, so a game that asks
/// too often does not get told it is being ignored — it just stops working. Five
/// prompts, ever, with a week between them.
///
/// Flutter-free: the sheet itself is `services/store_review.dart`.
library;

import 'package:merge_empire_fc/util/event_bus.dart';

/// Lifetime matches before the first ask. A player who has not finished eight
/// games has not seen enough of it to have a view.
const int ratingMatchThreshold = 8;

/// Goal difference that makes a win a GOOD one. Asking after a 1–0 scrape is
/// asking at the wrong moment.
const int ratingWinMargin = 2;

/// A week, which is both the "later" cooldown and the gap between any two asks.
const int ratingCooldownMs = 7 * 24 * 60 * 60 * 1000;

/// How many times the OS sheet may EVER be fired.
const int ratingMaxPrompts = 5;

Map<String, dynamic>? _rating(Map<String, dynamic> state) {
  final r = state['rating'];
  return r is Map<String, dynamic> ? r : null;
}

int _int(Object? v) => v is num ? v.toInt() : 0;

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// The three checks every trigger shares: not opted out, not inside the
/// cooldown, not over the lifetime cap.
bool _open(Map<String, dynamic> state, int at) {
  final r = _rating(state);
  if (r == null) return false;
  final status = r['status'];
  if (status == 'never' || status == 'done') return false;
  if (at < _int(r['nextPromptAt'])) return false;
  return _int(r['promptCount']) < ratingMaxPrompts;
}

/// Going up a division. **No win threshold** — a promotion is a high-emotion
/// moment on its own — but the cooldown and the cap still apply.
bool shouldPromptRatingOnPromotion(Map<String, dynamic> state, {int? now}) =>
    _open(state, now ?? DateTime.now().millisecondsSinceEpoch);

/// After a match. [won] and the goals are the result as the SIM reports it —
/// `homeGoals` is always OUR goals there, whichever ground the fixture was on.
bool shouldPromptRating(
  Map<String, dynamic> state, {
  required bool won,
  required int homeGoals,
  required int awayGoals,
  int? now,
}) {
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  if (!_open(state, at)) return false;
  final progression = state['progression'];
  final played = progression is Map<String, dynamic>
      ? _int(progression['matchesPlayed'])
      : 0;
  if (played < ratingMatchThreshold) return false;
  if (!won) return false;
  return homeGoals - awayGoals >= ratingWinMargin;
}

Map<String, dynamic> _ensure(Map<String, dynamic> state) {
  final r = _rating(state);
  if (r != null) return r;
  final made = <String, dynamic>{
    'status': 'pending',
    'promptCount': 0,
    'lastPromptAt': 0,
    'nextPromptAt': 0,
  };
  state['rating'] = made;
  return made;
}

/// Call when FIRING the sheet, not when the player answers it: the OS never
/// tells us what they chose, so the count and the cooldown have to be spent on
/// the asking.
void recordRatingShown(
  Map<String, dynamic> state, {
  int? now,
  String trigger = 'match',
}) {
  final r = _ensure(state);
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  final count = _int(r['promptCount']) + 1;
  r['promptCount'] = count;
  r['lastPromptAt'] = at;
  r['nextPromptAt'] = at + ratingCooldownMs;
  // **Reported from HERE because this is the one function both paths go
  // through.** The JS logs `rating_shown` at each of its two call sites, and
  // the port has the same two — a good win and a promotion. One event emitted
  // where the count is actually spent cannot drift from it, and `prompt_count`
  // is the field that says whether the lifetime cap is working.
  emit('rating:shown', {
    'promptCount': count,
    'trigger': trigger,
    'matchesPlayed':
        (_map(state['progression'])?['matchesPlayed'] as num?)?.toInt() ?? 0,
  });
}

/// `later` | `never` | `done`. Kept because the SETTINGS row still produces one
/// — a player who rates from there is finished being asked.
void recordRatingDecision(
  Map<String, dynamic> state,
  String decision, {
  int? now,
}) {
  final r = _ensure(state);
  final at = now ?? DateTime.now().millisecondsSinceEpoch;
  switch (decision) {
    case 'later':
      r['status'] = 'later';
      r['nextPromptAt'] = at + ratingCooldownMs;
    case 'never':
      r['status'] = 'never';
    case 'done':
      r['status'] = 'done';
  }
}
