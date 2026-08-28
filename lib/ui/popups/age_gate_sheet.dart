/// The parent-or-guardian notice, ported from
/// `../merge-empire-fc/src/ui/components/AgeGateModal.js`.
///
/// **GAMEPLAY IS NEVER BLOCKED BY IT** — that is the JS's own opening line, and
/// it is the whole shape of the feature. Play has told the app this account
/// belongs to a minor; the law (Texas SB 2420) asks for a parent's consent
/// before REAL MONEY can be spent, and nothing else. So the second button is
/// "Play Without Purchases" rather than a way out of a wall.
///
/// **Ten `agegate.*` strings ship in ten languages and none of them had a
/// caller.** The port's note said this sheet was blocked on new copy; it was
/// not — the copy has been in the catalogue the whole time, which is the
/// loudest tell there is that a feature was dropped rather than deferred.
///
/// `t()` strips the `<strong>` the intro and the body were written with, which
/// is why they read as plain sentences here: the emphasis was a DOM affordance
/// and the card gets its weight from its own typography instead.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/engine/age_verification.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/popups/bottom_sheet_popup.dart';
import 'package:merge_empire_fc/ui/popups/sheet_header.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

/// Open it. Resolves true when a parent tapped Allow.
Future<bool> showAgeGateSheet(BuildContext context) async {
  final consented = await showBottomSheetPopup<bool>(
    context,
    heightFraction: 0.82,
    child: const _AgeGateBody(),
  );
  return consented ?? false;
}

class _AgeGateBody extends ConsumerWidget {
  const _AgeGateBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final save = ref.watch(gameProvider).state;
    // Under 13 or under 18 — the sentence names which, because a parent
    // reading it should be told what Play actually said.
    final child = save != null && ageGroupOf(save) == AgeGroup.child;
    final muted = TextStyle(color: kit.textMuted, fontSize: 12, height: 1.7);

    return ListView(
      key: const ValueKey('age-gate-sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        SheetHeader(title: t('agegate.title'), padding: EdgeInsets.zero),
        const SizedBox(height: 12),
        Text(
          t('agegate.intro', {
            'age': child ? t('agegate.under_13') : t('agegate.under_18'),
          }),
          style: TextStyle(color: kit.textMuted, fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 14),
        // The JS's inset panel: what is collected, and what can be bought.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kit.surface2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('agegate.collect_heading'), style: _heading),
              Text(t('agegate.collect_progress'), style: muted),
              Text(t('agegate.collect_analytics'), style: muted),
              Text(t('agegate.collect_ads'), style: muted),
              const SizedBox(height: 12),
              Text(t('agegate.purchases_heading'), style: _heading),
              Text(t('agegate.purchases_body'), style: muted),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t('agegate.safe_note'),
          style: TextStyle(color: kit.textMuted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 18),
        StoreButton(
          key: const ValueKey('age-gate-allow'),
          // Not a price, so not a currency's colour — the club's accent, which
          // is what [StoreTone.neutral] is for.
          tone: StoreTone.neutral,
          label: t('agegate.allow_purchases'),
          onTap: () {
            ref.read(gameProvider).update(grantParentalConsent);
            Navigator.of(context).pop(true);
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('age-gate-dismiss'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('agegate.play_without')),
        ),
      ],
    );
  }
}

const TextStyle _heading = TextStyle(fontSize: 12, fontWeight: FontWeight.w900);
