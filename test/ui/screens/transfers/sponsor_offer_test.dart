/// Colin's read on a sponsor — see `sponsorRead`. The card had no read at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/data/sponsors.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/state/card_instance.dart';
import 'package:merge_empire_fc/state/state_schema.dart';
import 'package:merge_empire_fc/ui/screens/transfers/coach_verdict.dart';
import 'package:merge_empire_fc/ui/screens/transfers/sponsor_offer_card.dart';

const _id = 'c0';

({Map<String, dynamic> state, CardInstance player}) _club({
  int coins = 100000,
  bool starter = true,
  int seasons = 0,
  int form = 0,
}) {
  final s = createDefaultState();
  (s['resources'] as Map<String, dynamic>)['fanCoins'] = coins;
  final raw = <String, dynamic>{
    'instanceId': _id,
    'definitionId': 'player_t2_def',
    'variant': 0,
    'seasonsPlayed': seasons,
    'form': form,
  };
  ((s['grid'] as Map<String, dynamic>)['cells'] as List)[0] = raw;
  (s['squad'] as Map<String, dynamic>)['lineup'] = [
    {'slotId': 'cb', 'instanceId': starter ? _id : null},
  ];
  return (state: s, player: CardInstance.from(raw)!);
}

Company _clean() => companies.firstWhere((c) => c.drawback.isClean);
Company _injury() =>
    companies.firstWhere((c) => c.drawback.injuryPenalty > 0);
Company _form() => companies.firstWhere(
  (c) => c.drawback.formPenalty > 0 && c.drawback.injuryPenalty == 0,
);

void main() {
  setUp(() => setLocale('en'));
  tearDown(resetLocale);

  test('a clean deal is free money: sign it', () {
    final c = _club();
    final read = sponsorRead(c.state, c.player, _clean());
    expect(read.verdict, CoachVerdict.accept);
    expect(read.text, t('manager.sponsor.clean'));
  });

  test('an injury catch on a veteran is a no', () {
    final c = _club(seasons: 8);
    final read = sponsorRead(c.state, c.player, _injury());
    expect(read.verdict, CoachVerdict.decline);
    expect(read.text, contains('8'));
  });

  test('a form catch on a player already out of form is a no', () {
    final c = _club(form: -2);
    final read = sponsorRead(c.state, c.player, _form());
    expect(read.verdict, CoachVerdict.decline);
    expect(read.text, t('manager.sponsor.poor_form', {'player': c.player.name('')}));
  });

  test('a catch on somebody who does not play costs nothing: sign it', () {
    final c = _club(starter: false);
    final read = sponsorRead(c.state, c.player, _form());
    expect(read.verdict, CoachVerdict.accept);
    expect(read.text, t('manager.sponsor.bench', {'player': c.player.name('')}));
  });

  test('and a club that is skint takes the catch for the income', () {
    final c = _club(coins: 0);
    final read = sponsorRead(c.state, c.player, _form());
    expect(read.verdict, CoachVerdict.accept);
    expect(read.text, t('manager.sponsor.need_money'));
  });

  test('every read resolves its copy', () {
    for (final company in companies) {
      for (final starter in [true, false]) {
        final c = _club(starter: starter, seasons: 9, form: -1);
        final read = sponsorRead(c.state, c.player, company);
        expect(read.text, isNot(startsWith('manager.')), reason: company.id);
        expect(read.text, isNot(contains('{')), reason: company.id);
      }
    }
  });
}
