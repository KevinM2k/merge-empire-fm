/// Prestige — the New Adventure, and the only thing in the game that resets a
/// career on purpose.
///
/// **The engine, the copy and the achievements were all here; nothing could
/// reach any of them.** `canPrestige` and `performPrestige` (`engine/season_end.dart`)
/// had no caller in `lib/` at all, fourteen `prestige.*` strings sat translated
/// into ten catalogues with nothing able to print one, and
/// `prestige_level_1`, `prestige_level_3` and `reset_after_prestige` could
/// therefore never unlock. A green fixture test is not a caller — see
/// `CLAUDE.md`. This file is the caller.
///
/// **`home_dock.dart` already said where it goes**, which is why none of this
/// is reconstructed from memory: "the burger, bottom right, with Prestige above
/// it when it is available. Prestige leads the column: a gold star with a dot,
/// rather than the full-width call to action that used to sit under the match
/// card." That is `PrestigeDock`, and this is what it opens.
///
/// **Three cards, because it is three questions.** The offer says what a new
/// adventure BUYS (the stacking income multiplier, which is the only reason to
/// take it); the confirm says what it COSTS, which is a career; the name card
/// is the new club. They are Coach Colin's cards rather than `AlertDialog`s —
/// the port's standing rule, and this is the most consequential thing a player
/// is ever asked, so it is the last place to speak in the app's voice instead
/// of his.
///
/// **It opens on the tap and does NOT go through `enqueuePopup`**, which is the
/// same shape as the two orbs beside it: the coach opens his bubble and the
/// burger opens the menu, both directly. The queue is for popups that arrive at
/// the player — the welcome-back card, a rolled bid — and this is one the player
/// went and asked for. Nothing here auto-pops, and that is deliberate rather
/// than unfinished: the dock's own note calls prestige an orb "rather than the
/// full-width call to action that used to sit under the match card", and a card
/// that opened itself would be that banner again in a different shape.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/season_end.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/club_name_card.dart';
import 'package:merge_empire_fc/ui/popups/coach_card.dart';

/// What the next level's multiplier will be, for the offer's headline.
///
/// The engine's own arithmetic rather than a restatement of it: a card that
/// computed `1.1 ^ (level + 1)` for itself would sooner or later promise a
/// number the reset did not pay.
double nextPrestigeMultiplier(Map<String, dynamic>? state) =>
    prestigeMultiplierFor(prestigeLevel(state) + 1);

/// The multiplier as the copy wants it.
///
/// `1.1` reads as `1.1`, `1.21` as `1.21`, and a level deep enough to reach
/// `1.9487171000000004` reads as `1.95` rather than as a floating-point
/// accident — which is what a bare `$mult` in the placeholder would have put on
/// the card from level seven on.
String formatPrestigeMultiplier(double mult) {
  final text = ((mult * 100).round() / 100).toStringAsFixed(2);
  // Trailing zeroes off, but never the point's own digit: `1.10` is `1.1` and
  // `2.00` is `2`.
  if (text.endsWith('.00')) return text.substring(0, text.length - 3);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

/// The offer, the confirm, the reset and the new club's name — in that order,
/// and any of the three cards may be the last one.
///
/// Resolves to the new prestige level, or null if the player backed out at any
/// point. Nothing is written until [performPrestige] runs, so backing out of
/// the first two cards costs the save nothing.
Future<int?> showPrestigeOffer(BuildContext context, WidgetRef ref) async {
  final game = ref.read(gameProvider);
  if (!canPrestige(game.state)) return null;

  final mult = formatPrestigeMultiplier(nextPrestigeMultiplier(game.state));
  final pro = ref.read(hardModeProvider);
  final accepted = await showCoachCard<bool>(
    context,
    titleKey: 'prestige.title',
    bodyKey: 'prestige.body',
    bodyParams: {'mult': mult},
    // **The pro line changes with what the save already is.** `body_pro_hint`
    // invites a player into Pro mode; on a save that is ALREADY in it that
    // sentence is an invitation to somewhere they are standing. `pro_note` is
    // the same fact told the other way round — what the new career will be —
    // and both were translated ten times over with no caller.
    extraLines: [
      (
        key: pro ? 'prestige.pro_note' : 'prestige.body_pro_hint',
        params: const {},
        strong: false,
      ),
    ],
    actions: [
      CoachAction(labelKey: 'common.cancel', onTap: () {}, result: false),
      CoachAction(
        labelKey: 'prestige.button',
        tone: CoachTone.confirm,
        onTap: () {},
        result: true,
      ),
    ],
  );
  if (accepted != true || !context.mounted) return null;

  // **A SECOND CARD, and it is not a formality.** The offer is about what is
  // gained; this is the only place the player is told what goes — the squad,
  // the club, the division and the coins — and that it cannot be undone.
  final confirmed = await showCoachCard<bool>(
    context,
    titleKey: 'prestige.confirm_title',
    bodyKey: 'prestige.confirm_body',
    actions: [
      CoachAction(labelKey: 'common.cancel', onTap: () {}, result: false),
      CoachAction(
        labelKey: 'prestige.lets_go',
        tone: CoachTone.confirm,
        onTap: () {},
        result: true,
      ),
    ],
  );
  if (confirmed != true) return null;

  // The point of no return. Everything above this line is reversible by
  // pressing Cancel; nothing below it is.
  late PrestigeResult result;
  game.update((s) => result = performPrestige(s));
  if (!result.ok) return null;

  // **The toast is emitted HERE rather than by the engine**, and that is the
  // layering the whole port runs on: `performPrestige` emits `prestige:complete`
  // and knows nothing about a season line or a screen. `toast_host` turns that
  // event into the sentence.
  if (!context.mounted) return result.level;

  // The new club gets its name before the player sees the empty grid — the JS's
  // own three strings for this step, which the shared card takes as overrides so
  // there is one name card in the game rather than two.
  await showClubNameCard(
    context,
    titleKey: 'prestige.name_prompt',
    placeholderKey: 'prestige.name_placeholder',
    confirmKey: 'prestige.kick_off',
  );
  return result.level;
}

// **`prestige.season_income` STILL HAS NO CALLER, and that is recorded rather
// than papered over.** "Season {season} · Income ×{mult}" is a standing header
// line, not a beat in this flow — and where the JS puts it cannot be read from
// a cloud container. A helper for it lived here briefly with nothing calling
// it, which is precisely the fault this file exists to fix, so it has gone.
// Whoever places it will want `seasonNumberProvider` (`home/league_providers.dart`),
// which is sitting uncalled for the same reason, and
// `formatPrestigeMultiplier` above. See docs/REMAINING.md.
