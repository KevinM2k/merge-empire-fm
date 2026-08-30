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
import 'package:merge_empire_fc/i18n/i18n.dart';
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

/// Why the Pro difficulty is dead, in the words the game already ships.
///
/// **Nothing in the app ever said "locked", which is the whole of the report.**
/// The difficulty row's note printed `prestige.body_pro_hint` — "Or prestige
/// into Pro Mode — fatigue, squad rotation and live subs make it a real test" —
/// a fragment lifted from this card's own OFFER. It describes what Pro is; it
/// never says the control is unavailable, and its leading "Or" belongs to the
/// sentence it was cut out of. A player reading it under a greyed segment
/// learns what they are missing and not one word about how to get it.
///
/// The condition already ships, exactly and in ten languages, as
/// `ach.desc.prestige_level_1`: "Prestige for the first time." The padlock in
/// front of it is what marks the sentence as the reason rather than a boast.
///
/// **No new key, and there could not be one** — the catalogues are generated
/// from the JS's `en.js`, so a glyph and an existing string is the whole of the
/// budget. See CLAUDE.md.
String proLockedAnswer() => '🔒 ${t('ach.desc.prestige_level_1')}';

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

/// Which way the offer was answered.
///
/// Three answers rather than a bool, because "yes" now has two meanings and a
/// captured variable beside a `bool` is exactly the plumbing `CoachAction.result`
/// exists to avoid.
enum _Route { standard, pro, cancel }

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
  final answer = await showCoachCard<_Route>(
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
    // **THE SECOND DOOR INTO PRO MODE, and the JS has had it all along.**
    // `_showPrestigeColin` offers ONE button on a save already in Pro and TWO
    // on one that is not — the standard reset and `champ.pro_cta` — which is
    // why `prestige.button_standard` exists at all and why it had no caller
    // here: a card with one button has no reason for a shorter label on it.
    //
    // Both are green because both are the same answer to the offer; what
    // differs is which game the next career is. Cancel goes last rather than
    // first once there are three, which is the order the JS's own celebration
    // stacks them in and the only order in which the two ways to say yes are
    // adjacent.
    actions: [
      if (pro)
        CoachAction(
          labelKey: 'prestige.button',
          tone: CoachTone.confirm,
          onTap: () {},
          result: _Route.standard,
        )
      else ...[
        CoachAction(
          labelKey: 'prestige.button_standard',
          tone: CoachTone.confirm,
          onTap: () {},
          result: _Route.standard,
        ),
        CoachAction(
          labelKey: 'champ.pro_cta',
          tone: CoachTone.confirm,
          onTap: () {},
          result: _Route.pro,
        ),
      ],
      CoachAction(
        labelKey: 'common.cancel',
        tone: CoachTone.decline,
        onTap: () {},
        result: _Route.cancel,
      ),
    ],
  );
  final toPro = answer == _Route.pro;
  if (answer == null || answer == _Route.cancel || !context.mounted) {
    return null;
  }
  return confirmAndPrestige(context, ref, toPro: toPro);
}

/// The confirm, the reset and the new club's name — everything after the answer.
///
/// **Split out because there are TWO offers and one flow.** The JS's
/// `_doPrestige(switchToPro)` is reached from the dock's card and from the
/// champions celebration, and both are the same three beats afterwards; a
/// second copy is how the celebration ends up resetting a career without
/// warning anybody or asking the new club its name.
Future<int?> confirmAndPrestige(
  BuildContext context,
  WidgetRef ref, {
  required bool toPro,
}) async {
  final game = ref.read(gameProvider);

  // **A SECOND CARD, and it is not a formality.** The offer is about what is
  // gained; this is the only place the player is told what goes — the squad,
  // the club, the division and the coins — and that it cannot be undone.
  final confirmed = await showCoachCard<bool>(
    context,
    titleKey: 'prestige.confirm_title',
    bodyKey: 'prestige.confirm_body',
    // **The Pro warning belongs HERE when Pro is what was chosen**, which is
    // where the JS puts it: `_doPrestige(true)` appends `prestige.pro_note` to
    // the confirm body. Choosing the harder game and being told what it costs
    // are two different beats, and the second one is the last card before the
    // career goes.
    extraLines: [
      if (toPro)
        (key: 'prestige.pro_note', params: const {}, strong: true),
    ],
    actions: [
      CoachAction(
        labelKey: 'common.cancel',
        tone: CoachTone.decline,
        onTap: () {},
        result: false,
      ),
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
  game.update((s) {
    // `toPro` is carried on the `prestige:complete` event for analytics; the
    // flag itself is still written below, for the ordering reason that follows.
    result = performPrestige(s, toPro: toPro);
    // **After the reset, not before**, and the two orders are not the same:
    // `performPrestige` mutates the save in place and never touches `settings`,
    // so the flag survives it either way — but `resetState`, which the New Team
    // flow uses, COPIES settings forward, and writing the flag after that one
    // would land it on a save that had already booted in the old mode. Same
    // sentence, opposite order, and the difference is which function is
    // downstream. This is the JS's order for this flow.
    if (result.ok && toPro) {
      final settings = s['settings'];
      if (settings is Map<String, dynamic>) settings['hardMode'] = true;
    }
  });
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
