/// The free shelf — everything a rewarded video buys.
///
/// The GATE is live and the ad is not, which is the whole difficulty: two true
/// statements about the same tile can still contradict each other in front of a
/// player.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_free.dart';
import 'package:merge_empire_fc/ui/widgets/game_icon.dart';
import 'package:merge_empire_fc/ui/widgets/store_button.dart';

import 'shop_helpers.dart';

void main() {
  testWidgets('IT DOES NOT SAY "ALREADY READY" AND "COMING SOON" AT ONCE', (
    tester,
  ) async {
    // The first is the ad GATE reporting itself open, the second is there being
    // no ad SDK — both true, and together they are nonsense to a player. The
    // one that becomes a lie while there is nothing to watch is the badge.
    await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
    expect(find.text(t('shop.already_ready')), findsNothing);
    expect(find.text(t('settings.comingSoon')), findsWidgets);
  });

  testWidgets('AN AD BUTTON SAYS SO ON THE BUTTON', (tester) async {
    // The tone was already the ad yellow and the label is a VERB ("Claim"),
    // which on its own is a free thing rather than a thing you watch a video
    // for. The disclosure has to come from somewhere.
    await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
    final button = tester.widget<StoreButton>(
      find.byKey(const ValueKey('shop-buy-ad-lucky-boot')).first,
    );
    expect(button.tone, StoreTone.ad);
    expect(button.leading, isA<GameIcon>());
    expect((button.leading! as GameIcon).name, 'video');
  });

  testWidgets('and both rows of the shelf are there', (tester) async {
    await pumpShopWidget(tester, (_) {}, FreeShelfSection.new);
    expect(find.byKey(const ValueKey('shop-tile-ad-match-cooldown')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-tile-ad-lucky-boot')), findsOneWidget);
  });
}
