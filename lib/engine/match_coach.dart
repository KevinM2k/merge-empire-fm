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

/// [coachShouldSpeak]'s `lastSpokeMinute` before he has said anything.
///
/// **NOT -1, and that was twenty-four minutes of silence.** The sticky check
/// runs BEFORE the first-word check — the JS's order, and the right one — so a
/// `lastSpokeMinute` of -1 makes `since` equal `minute + 1` and holds every
/// word until minute 24. `MatchPopup.js` initialises `_lastBubbleMin` to -999
/// for exactly this reason: it has to be a figure the sticky window cannot
/// reach, not the minute before kick-off. Reported from the couch as the coach
/// not advising a tactic change at all.
const int coachNeverSpoke = -999;

/// The earliest he will open his mouth.
///
/// A bubble in the first minutes lands on top of the pre-match tip and
/// contradicts it — the JS waits, and at 2× the first tick is 175ms in.
const int coachFirstWordMinute = 5;

/// How long he sits on a tactic the manager has ALREADY turned down.
///
/// **A first bubble that repeats the pre-match tip is nagging, not advice.**
/// The pre-match tip names a tactic; a manager who kicks off playing something
/// else has read it and declined it, and being told the same thing again at
/// minute five is the game arguing with a decision that was just made.
/// Reported from the couch in exactly those terms: starting a match having
/// ignored the coach must not be met with an instant "change tactic to X".
///
/// So that particular ask has to be earned again. By the half-hour the
/// scoreline and the clock are part of his case — `coachReadKey` is reading a
/// different game by then — rather than it being the same read the manager
/// already heard. Every OTHER suggestion is unaffected: this holds one tactic,
/// not his mouth.
const int coachDeclinedHoldMinutes = 30;

/// The margin below which a tactic switch is not worth asking for.
///
/// Without it he asks for a change every time two tactics land a thousandth of
/// a point apart.
///
/// **HALF the JS's `MIN_TACTIC_GAIN`, which is 0.04**, and the note here used
/// to claim it WAS the JS's. Nothing pins it — no fixture compares it — and
/// the port is the more forthcoming of the two on purpose: the couch has asked
/// twice for the coach to speak up about the tactics, and this is the dial that
/// decides how often he has an opinion at all. Said plainly rather than left
/// looking like parity, because the next person to read it against
/// `MatchPopup.js` will find the two differ.
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
/// [lastSpokeMinute] is negative before his first word, and it has to be
/// [coachNeverSpoke] rather than any old negative — see that constant. [force]
/// is the half-time whistle and full time, which are moments rather than
/// opinions.
bool coachShouldSpeak({
  required int minute,
  required int lastSpokeMinute,
  required String activeStrategy,
  required String? suggestion,
  required String? lastSuggestion,

  /// The tactic the PRE-MATCH tip asked for and the manager did not set, or
  /// null when they took it — or when there was nothing to take. See
  /// [coachDeclinedHoldMinutes].
  String? declinedAtKickoff,
  bool force = false,
}) {
  if (force) return true;
  if (suggestion != null &&
      suggestion == declinedAtKickoff &&
      minute < coachDeclinedHoldMinutes) {
    return false;
  }
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
