/// What a cup tie says when it is over: through to the next round, or out.
///
/// **Twenty-odd `cup.round_win.*`, `cup.knocked_out.*` and `cup.banner.*`
/// strings shipped in ten languages with no caller** — the whole of the cup's
/// reaction. A round the player won and a run that just ended were the same
/// event from the screen's side: a scoreline, a toast, and back to the Play
/// tab.
///
/// **THEY ARE THE UNLOCK SPLASH, not a fourth shape.** `feature_unlock.dart`
/// already makes the argument and it applies here word for word: a tier-up and
/// a first build are the same kind of event, and giving them different shapes
/// would make the smaller one read as a lesser thing. A cup round won is that
/// same beat — something the club has now that it did not — so it takes the
/// same card with a different eyebrow, and the elimination takes it in red.
///
/// **The button is dropped, deliberately.** The JS's card ends in "Bring it
/// on!", which does nothing but dismiss; the splash dismisses itself and a tap
/// anywhere takes it early. Nothing on either card is a decision.
library;

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/data/cups.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/popups/feature_unlock.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

/// Green for a round won, red for a run ended, gold for the trophy.
const Color cupWonInk = Color(0xFF4ADE80);
const Color cupOutInk = dangerInk;
const Color cupTrophyInk = Color(0xFFFFD700);

/// Which of the three closing lines a round earns, by what comes NEXT.
///
/// **It reads the round AHEAD, not the one just won.** "One win away from
/// lifting the cup" is a thing to say to somebody about to play a final, not to
/// somebody who has just won a quarter-final — and the difference is one index.
String cupRoundWinBodyKey({required bool nextIsFinal, required bool nextIsSemi}) {
  if (nextIsFinal) return 'cup.round_win.final_next';
  if (nextIsSemi) return 'cup.round_win.semi_next';
  return 'cup.round_win.generic_next';
}

/// Which body an elimination earns, by how far they got.
///
/// **Three lines because losing a final is not losing a quarter-final.** The
/// JS writes each one separately, and the one that matters is the final's:
/// "so close to glory" is the only thing worth saying to somebody who lost
/// there, and the generic line would read as dismissive.
///
/// **Told by POSITION, not by the round's name**, which is the same signal the
/// win path takes and for a reason that bit once: "Quarter-Final" contains the
/// word "final", so sniffing the string calls a quarter-final exit a heartbreak
/// at the last hurdle. The round index cannot be wrong about this.
String cupKnockedOutBodyKey({required bool wasFinal, required bool wasSemi}) {
  if (wasFinal) return 'cup.knocked_out.body_final';
  if (wasSemi) return 'cup.knocked_out.body_semi';
  return 'cup.knocked_out.body';
}

/// Through to the next round.
Future<void> showCupRoundWin(
  BuildContext context, {
  required String nextRoundName,
  required bool nextIsFinal,
  required bool nextIsSemi,
  String? nextOpponent,
}) => showFeatureUnlock(
  context,
  title: t('cup.round_win.title'),
  subtitle: t('cup.round_win.through', {'round': nextRoundName}),
  // The next opponent rides the card's second slot rather than queueing a
  // second popup behind it — the same call the facility splash makes about a
  // build that unlocked two things.
  bonus: nextOpponent == null
      ? t(cupRoundWinBodyKey(nextIsFinal: nextIsFinal, nextIsSemi: nextIsSemi))
      : t('cup.round_win.next_up', {'opponent': nextOpponent}),
  icon: Text(
    // A trophy when the final is what comes next, and a tick before that: the
    // glyph is how far through the run they are.
    nextIsFinal ? '🏆' : '✅',
    style: const TextStyle(fontSize: 56),
  ),
  accent: nextIsFinal ? cupTrophyInk : cupWonInk,
  isTierUp: true,
);

/// The run ends here.
Future<void> showCupKnockedOut(
  BuildContext context, {
  required String cupName,
  required String roundName,
  required bool wasFinal,
  required bool wasSemi,
}) => showFeatureUnlock(
  context,
  title: t('cup.knocked_out.title'),
  subtitle: t('cup.knocked_out.round', {'round': roundName}),
  bonus: t(
    cupKnockedOutBodyKey(wasFinal: wasFinal, wasSemi: wasSemi),
    {'cup': cupName},
  ),
  icon: const Text('💔', style: TextStyle(fontSize: 56)),
  // **RED, and that is the whole reason this is not just the same call.** The
  // splash is a celebration by default and an elimination is not one; the same
  // card in green would read as congratulating somebody on going out.
  accent: cupOutInk,
  isTierUp: true,
  starCount: 0,
);

/// The trophy.
Future<void> showCupWon(BuildContext context, {required String cupName}) =>
    showFeatureUnlock(
      context,
      title: t('cup.banner.champions'),
      subtitle: t('cup.banner.you_won', {'cup': cupName}),
      icon: const Text('🏆', style: TextStyle(fontSize: 64)),
      accent: cupTrophyInk,
      starCount: 5,
    );

/// The round after [round] in [cup], or null when that was the last one.
String? cupNextRoundName(Cup cup, int round) =>
    round + 1 < cup.rounds.length ? cup.rounds[round + 1] : null;
