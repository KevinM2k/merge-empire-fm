/// **THE SEAM RENDERED ART DROPS INTO.**
///
/// Generating it is blocked in a cloud session — every image host is refused at
/// the proxy, see the artwork row in `docs/REMAINING.md` — so the decision was
/// "art later, fallbacks now". What this file holds is the two properties that
/// make "later" a three-step drop rather than a hunt: the shop can always draw
/// something, and the manifest can never name a file that is not bundled.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/engine/iap_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/screens/shop/coin_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/gem_pack_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_art.dart';
import 'package:merge_empire_fc/ui/screens/shop/shop_paid.dart';

import 'shop_helpers.dart';

void main() {
  tearDown(resetLocale);

  testWidgets('EVERY PRODUCT DRAWS SOMETHING, art or no art', (tester) async {
    // The fallback is not nullable for exactly this reason: a shop tile with no
    // picture at all is worse than either answer, and it is the state a
    // half-finished art drop would otherwise leave the shelf in.
    //
    // **One product at a time**, or the assertion passes on the first tile's
    // picture and says nothing about the other eleven.
    for (final product in getShopProducts()) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: shopProductGlyph(product)),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CoinPackPicture ||
              w is GemPackPicture ||
              w is Image ||
              (w is CustomPaint && w.painter != null),
        ),
        findsWidgets,
        reason: '${product.id} draws nothing',
      );
    }
  });

  test('the manifest names only files that are actually bundled', () {
    // **A half-landed drop fails the build rather than shipping a broken image
    // box.** Three things have to happen for shop art to arrive — the file, the
    // `pubspec.yaml` line, the manifest row — and the one that gets forgotten is
    // never the file.
    //
    // Empty today, which is the point: this passes vacuously now and starts
    // earning its keep the moment somebody adds a row.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final entry in shopArtManifest.entries) {
      expect(
        File(entry.value).existsSync(),
        isTrue,
        reason: '${entry.key} names ${entry.value}, which is not in the repo',
      );
      // Listed either outright or by the directory it sits in — `flutter` takes
      // both, so the check has to as well.
      final dir = '${entry.value.substring(0, entry.value.lastIndexOf('/'))}/';
      expect(
        pubspec.contains(entry.value) || pubspec.contains(dir),
        isTrue,
        reason: '${entry.value} is in the repo but not bundled by pubspec.yaml',
      );
    }
  });

  testWidgets('and the shelf uses whichever of the two exists', (tester) async {
    // **The promise of the seam is that it changed nothing on the day it
    // landed, and changes everything on the day the art does.** So this asks
    // the manifest rather than assuming it is empty: with no art the coin shelf
    // is its painters, and with art it is `Image`s — and the assertion is the
    // same sentence either way, so an art drop does not turn it red.
    await pumpShopWidget(tester, (_) {}, CoinPacksSection.new);
    final rendered = getShopProducts()
        .where((p) => p.category == 'coins' && shopArtAsset(p.id) != null)
        .length;
    final drawn = getShopProducts()
            .where((p) => p.category == 'coins')
            .length -
        rendered;
    expect(find.byType(CoinPackPicture), findsNWidgets(drawn));
    expect(find.byType(Image), findsNWidgets(rendered));
  });
}
