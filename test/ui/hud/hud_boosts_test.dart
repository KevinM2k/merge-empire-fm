/// The active-boost pills in the middle of the HUD.
///
/// **They need no copy at all**, which is why they could be ported: the JS
/// writes "×2" and "🌟 VIP" with a unit letter after a number, and there is not
/// a `t()` in the whole function. A player with VIP running had nothing on the
/// bar saying so.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:merge_empire_fc/ui/hud/hud_boosts.dart';

const int _now = 1800000000000;
const int _minute = 60000;
const int _day = 86400000;

Map<String, dynamic> save(Map<String, dynamic> boosts) => <String, dynamic>{
  'boosts': boosts,
};

void main() {
  test('a save with nothing running has no pills', () {
    expect(hudBoostsFor(save(const {}), nowMs: _now), isEmpty);
    expect(hudBoostsFor(const <String, dynamic>{}, nowMs: _now), isEmpty);
    expect(hudBoostsFor(null, nowMs: _now), isEmpty);
  });

  test('the idle boost shows its multiplier and the minutes left', () {
    final pills = hudBoostsFor(
      save({
        'incomeBoostActive': true,
        'incomeBoostEndsAt': _now + 5 * _minute,
      }),
      nowMs: _now,
    );
    expect(pills.single.label, '×2');
    expect(pills.single.sub, '5m');
  });

  test('VIP shows its days', () {
    final pills = hudBoostsFor(
      save({'vipActive': true, 'vipExpiresAt': _now + 9 * _day}),
      nowMs: _now,
    );
    expect(pills.single.label, '🌟 VIP');
    expect(pills.single.sub, '9d');
  });

  /// **THE POLISH IS A PILL NOW, and it could not have been before.**
  ///
  /// It is a ×2 on idle income, which is this row's whole rule — but the sub is
  /// a countdown and a SEASON has no minutes on it. Half an hour from purchase
  /// gives eight gems something the player can watch running and watch go.
  test('the trophy polish shows its multiplier and the minutes left', () {
    final pills = hudBoostsFor(
      save({'trophyPolishUntil': _now + 22 * _minute}),
      nowMs: _now,
    );
    expect(pills.single.label, '🏆 ×2');
    expect(pills.single.sub, '22m');
  });

  test('and a spent one is not a pill', () {
    expect(
      hudBoostsFor(save({'trophyPolishUntil': _now}), nowMs: _now),
      isEmpty,
    );
    // An old save's SEASON stamp is not a deadline and must not be read as one.
    expect(
      hudBoostsFor(save({'trophyPolishSeason': 4}), nowMs: _now),
      isEmpty,
    );
  });

  test('BOTH ROUND UP AND FLOOR AT ONE', () {
    // Forty seconds left is not "0m" — that reads as expired.
    expect(
      hudBoostsFor(
        save({'incomeBoostActive': true, 'incomeBoostEndsAt': _now + 40000}),
        nowMs: _now,
      ).single.sub,
      '1m',
    );
    expect(
      hudBoostsFor(
        save({'vipActive': true, 'vipExpiresAt': _now + 3600000}),
        nowMs: _now,
      ).single.sub,
      '1d',
    );
  });

  test('AN EXPIRED BOOST IS NOT A BOOST, whatever the flag says', () {
    // The flag is written when it starts and nothing clears it on the tick, so
    // the time is the truth and the flag is a hint.
    expect(
      hudBoostsFor(
        save({'incomeBoostActive': true, 'incomeBoostEndsAt': _now - 1}),
        nowMs: _now,
      ),
      isEmpty,
    );
    expect(
      hudBoostsFor(
        save({'vipActive': true, 'vipExpiresAt': _now - 1}),
        nowMs: _now,
      ),
      isEmpty,
    );
  });

  test('and a flag that was never set shows nothing however long is left', () {
    expect(
      hudBoostsFor(
        save({'incomeBoostEndsAt': _now + _day}),
        nowMs: _now,
      ),
      isEmpty,
    );
  });

  test('THE TEMPORARY ONE COMES FIRST, which is the JS\'s order', () {
    // It is the one about to run out, so it is the one worth glancing at.
    final pills = hudBoostsFor(
      save({
        'incomeBoostActive': true,
        'incomeBoostEndsAt': _now + _minute,
        'vipActive': true,
        'vipExpiresAt': _now + _day,
      }),
      nowMs: _now,
    );
    expect(pills.map((p) => p.label), ['×2', '🌟 VIP']);
  });
}
