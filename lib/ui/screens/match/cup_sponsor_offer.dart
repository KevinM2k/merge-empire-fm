/// The sponsor a cup win drops. Ported from `_showCupSponsorOffer` in
/// `ui/screens/LeagueScreen.js`.
///
/// The engine ROLLS the drop and applies nothing: the player is being asked, and
/// a deal that signed itself would be a reward the player never agreed to. It
/// lands on one named card and lasts the season.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/cup_engine.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';

/// Offer [drop], and take it up if the player says yes.
///
/// A Coach Colin card rather than a sheet: it is a question with two answers and
/// no scrollable content, which is exactly what that shape is for.
Future<bool> showCupSponsorOffer(
  BuildContext context,
  WidgetRef ref,
  CupSponsorDrop drop,
) async {
  final pct = ((drop.sponsorData.multiplier - 1) * 100).round();
  var accepted = false;
  await showCoachCard<void>(
    context,
    titleKey: 'cup.win_reward.title',
    bodyKey: 'cup.win_reward.body',
    bodyParams: {'sponsor': drop.sponsorData.name, 'player': drop.playerName},
    // The panel the JS puts under the body: what the deal pays, and how long it
    // lasts. The second line is the catch, so it is not folded into the first.
    extraLines: [
      (key: 'cup.win_reward.income_pct', params: {'pct': pct}, strong: true),
      (key: 'cup.win_reward.duration', params: const {}, strong: false),
    ],
    actions: [
      CoachAction(
        labelKey: 'common.decline',
        tone: CoachTone.decline,
        onTap: () {},
      ),
      CoachAction(
        labelKey: 'common.accept',
        tone: CoachTone.confirm,
        onTap: () {
          accepted = ref
              .read(gameProvider)
              .update((s) => acceptCupSponsorDrop(s, drop));
        },
      ),
    ],
  );
  return accepted;
}
