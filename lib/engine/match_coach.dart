/// Coach Colin on the touchline, for the ninety minutes he is standing on it.
/// Ported from `_buildCoachOpinion`, `_maybeShowCoachBubble` and
/// `_rawCoachSuggestion` in `ui/components/MatchPopup.js`.
///
/// **Twenty-four pooled strings, translated ten times over, with nothing able
/// to reach one of them.** Every `coach.match.*` key in the catalogues — his
/// read of the game at every scoreline, his per-tactic ask, his half-time word,
/// the fatigue warning and the no-subs shout — was ported as COPY and never as
/// a voice. The one screen a player watches for ninety minutes was the one
/// screen he had nothing to say on.
///
/// **He is a CASUAL-mode coach.** Pro mode buys the numbers and gives up the
/// advice, and that bargain is the JS's `_coachHelpOn`: hard mode, no tips.
///
/// Deliberately Flutter-free — this is which sentence, not how it is drawn.
library;

import 'package:merge_empire_fc/engine/tactic_coach.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';

/// How long he holds the floor after speaking, in GAME minutes.
///
/// The JS's `STICKY_MINS`, and its reason: a coach who revises his read every
/// other minute is noise the manager stops reading.
const int coachStickyMinutes = 25;

/// ...and how long before he will speak again regardless, even to repeat
/// himself. The JS's `PERIODIC_MINS`.
const int coachPeriodicMinutes = 40;

/// The earliest he will open his mouth.
///
/// A bubble in the first minutes lands on top of the pre-match tip and
/// contradicts it — the JS waits, and at 2× the first tick is 175ms in.
const int coachFirstWordMinute = 5;

/// The margin below which a tactic switch is not worth asking for.
///
/// The JS's `MIN_TACTIC_GAIN`. Without it he asks for a change every time two
/// tactics land a thousandth of a point apart.
const double coachMinTacticGain = 0.02;

/// Which read of the game he gives, as a catalogue key.
///
/// Half time has its own five, because "still level" at the whistle is a team
/// talk and at 70 minutes it is a warning.
String coachReadKey({
  required bool halftime,
  required int margin,
  required int minute,
}) {
  if (halftime) {
    if (margin == 0) return 'coach.match.ht.level';
    if (margin >= 2) return 'coach.match.ht.lead_big';
    if (margin == 1) return 'coach.match.ht.lead_one';
    if (margin <= -2) return 'coach.match.ht.behind_big';
    return 'coach.match.ht.behind_one';
  }
  if (minute < 15 && margin == 0) return 'coach.match.early_level';
  if (margin <= -2) return 'coach.match.battered';
  final late = minute >= 60;
  if (margin == -1) {
    return late
        ? 'coach.match.behind_one_late'
        : 'coach.match.behind_one_early';
  }
  if (margin == 0) {
    return late ? 'coach.match.level_late' : 'coach.match.level_early';
  }
  if (margin == 1) {
    return late ? 'coach.match.lead_one_late' : 'coach.match.lead_one_early';
  }
  return late ? 'coach.match.lead_big_late' : 'coach.match.lead_big_early';
}

/// His word at the FINAL whistle, as a catalogue key — or null when the
/// afternoon was not worth a remark.
///
/// **Nine more shipped strings with nothing able to reach one of them, and this
/// file's own header is about the last twenty-four.** `commentary.thriller_*`,
/// `demolition`, `drubbing`, `high_scoring_*`, `nervy_one_nil` and `nil_nil`
/// are his read of a RESULT rather than of a scoreline in progress —
/// "the players will be buzzing for days", "dust yourselves off" — and
/// [coachReadKey] stops at the 89th minute, so the one moment they were written
/// for was the one moment he had nothing to say.
///
/// **They are keyed `commentary.*` and they are NOT the commentary**, which is
/// the one thing about them worth spelling out. The key prefix is where they
/// sit in a generated catalogue, not who says them: every one is written in the
/// first person — "we took {opp} apart", "we came away with a point", "dust
/// yourselves off" — and the feed on the match screen is an independent
/// commentator describing two clubs, so it cannot say "we". A round spent
/// printing them there was reported from the couch in exactly those words.
///
/// **So they go in Colin's bubble** — `MatchScreenState._sayFullTimeWord`,
/// bottom-left, the shape the rest of his match talk already takes. This is the
/// manager talking to you about your own team, and the third-party write-up of
/// the same result is `match_report.dart` at the head of the feed. Two voices on
/// one afternoon, each saying the thing only it can say.
///
/// **Null for most matches, deliberately.** These nine describe results worth
/// a sentence; a 1-1 is not one, and a line on every full time is a line
/// nobody reads — the same rule `squadStateHint` follows when it stays quiet.
///
/// [ours] and [theirs] are goals in OUR order whatever the venue, which is what
/// the engine's `homeGoals`/`awayGoals` already mean.
String? fullTimeReactionKey({required int ours, required int theirs}) {
  // The two exact scorelines the copy names outright. They come first because
  // both are also "not many goals", and a general rule would swallow them.
  if (ours == 0 && theirs == 0) return 'commentary.nil_nil';
  if (ours == 1 && theirs == 0) return 'commentary.nervy_one_nil';

  final margin = ours - theirs;
  // Three clear is a hiding in either direction, however many were scored.
  if (margin >= 3) return 'commentary.demolition';
  if (margin <= -3) return 'commentary.drubbing';

  final total = ours + theirs;
  // **A THRILLER IS CLOSE FIRST AND HIGH-SCORING SECOND**, which is why it is
  // tested before the high-scoring pair: 3-3 has six goals in it and "goals
  // everywhere but we got the result" is not a thing to say about a draw.
  if (total >= 3 && margin.abs() <= 1) {
    return margin > 0
        ? 'commentary.thriller_win'
        : margin < 0
        ? 'commentary.thriller_loss'
        : 'commentary.thriller_draw';
  }
  // Only a two-goal margin can reach here — three was caught above — so this is
  // the 4-2 shape rather than anything one-sided.
  if (total >= 5) {
    return margin > 0
        ? 'commentary.high_scoring_win'
        : 'commentary.high_scoring_loss';
  }
  return null;
}

/// What he would play, or null when there is nothing left to play for.
///
/// **The base ratings, not the ones on the dial.** `suggestTactic` applies the
/// multipliers itself, so handing it already-modified numbers prices every
/// tactic on top of the one currently set.
///
/// Returns [activeStrategy] unchanged when the best switch is not worth
/// [coachMinTacticGain] — that is him agreeing with you, which the caller reads
/// as "nothing actionable".
String? matchCoachSuggestion({
  required double ourAttack,
  required double ourDefence,
  required double theirAttack,
  required double theirDefence,
  required String activeStrategy,
  required int minute,
  required int duration,
  required int margin,
  double benchCover = 0,
  double injuryRisk = 0,
  double injuryCost = 0,
  double? oppAttackRatio,
}) {
  final remaining = (duration - minute).clamp(0, duration) / duration;
  if (remaining <= 0) return null;
  final picked = suggestTactic(
    ourAttack,
    ourDefence,
    theirAttack,
    theirDefence,
    benchCover: benchCover,
    fraction: remaining,
    margin: margin,
    injuryRisk: injuryRisk,
    injuryCost: injuryCost,
    oppAttackRatio: oppAttackRatio,
  );
  for (final row in picked.ranked) {
    if (row.id != activeStrategy) continue;
    if (picked.expectedPoints - row.expectedPoints < coachMinTacticGain) {
      return activeStrategy;
    }
    break;
  }
  return picked.id;
}

/// Whether he speaks at all this minute.
///
/// [lastSpokeMinute] is negative before his first word. [force] is the half-time
/// whistle and full time, which are moments rather than opinions.
bool coachShouldSpeak({
  required int minute,
  required int lastSpokeMinute,
  required String activeStrategy,
  required String? suggestion,
  required String? lastSuggestion,
  bool force = false,
}) {
  if (force) return true;
  final since = minute - lastSpokeMinute;
  if (since < coachStickyMinutes) return false;
  final nothingToAskFor = suggestion == null || suggestion == activeStrategy;
  // His first word has to be worth interrupting for.
  if (lastSpokeMinute < 0 &&
      (nothingToAskFor || minute < coachFirstWordMinute)) {
    return false;
  }
  final periodic = since >= coachPeriodicMinutes;
  if (suggestion == lastSuggestion && !periodic) return false;
  if (nothingToAskFor && !periodic) return false;
  return true;
}

/// The whole line: his greeting, his read, and the switch he is asking for.
///
/// [seed] holds the pooled picks still while the bubble is on screen — the
/// screen rebuilds on every simulated minute and an unseeded pick would rewrite
/// his sentence under the reader.
String matchCoachOpinion({
  required bool halftime,
  required int margin,
  required int minute,
  required String activeStrategy,
  required String seed,
  String? suggestion,
}) {
  final head = halftime
      ? tPoolStable('coach.match.head.halftime', seed)
      : tPoolStable('coach.match.head.live', seed, {'mins': minute});
  final read = tPoolStable(
    coachReadKey(halftime: halftime, margin: margin, minute: minute),
    seed,
  );
  if (suggestion == null || suggestion == activeStrategy) {
    return '$head $read';
  }
  final name = t('strategy.$suggestion.name');
  // Per-tactic ask, so the words match what he is actually calling for. The
  // generic pool covers a tactic that ships without its own lines.
  const generic = 'coach.match.try_strategy';
  final perTactic = 'coach.match.try.$suggestion';
  final ask = t(perTactic) == perTactic
      ? tPoolStable(generic, seed, {'name': name})
      : tPoolStable(perTactic, seed, {'name': name});
  return '$head $read $ask';
}
