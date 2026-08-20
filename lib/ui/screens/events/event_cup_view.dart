/// An event's knockout bracket. Ported from `_renderCup` in
/// `ui/screens/EventScreen.js`.
///
/// The player leads a NATION through the bracket rather than their club, which
/// is why the first thing this screen shows is a picker: their pick is excluded
/// from the opponent pool for the whole run.
///
/// Four states — pick a nation, the next round, knocked out, champions — and
/// the last two both offer the same two doors, because the answer to a cup that
/// has finished is either "again with these" or "again with someone else".
///
/// **Nothing reaches this today.** The only event with a `cupConfig` is
/// `wc2026`, whose window closed in July 2026, so it permanently reports
/// `ended`. It is built anyway because `event_cup_engine` and its tests are the
/// specification for whatever reuses that slot, and a bracket engine with no
/// screen is exactly the half-built pairing `docs/REMAINING.md` warns about.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merge_empire_fc/data/config.dart';
import 'package:merge_empire_fc/data/events.dart';
import 'package:merge_empire_fc/engine/event_cup_engine.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/providers/game_providers.dart';
import 'package:merge_empire_fc/ui/theme/app_theme.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num _num(Object? v) => v is num ? v : 0;

/// The gold a rating wears, by band. A number with no colour is a number the
/// player has to read; a colour is one they can scan.
Color ratingInk(num rating) => switch (rating) {
  >= 85 => const Color(0xFFFFD700),
  >= 78 => const Color(0xFFC0C0C0),
  >= 72 => const Color(0xFFCD7F32),
  _ => const Color(0xFF9E9E9E),
};

class EventCupView extends ConsumerWidget {
  const EventCupView({required this.event, super.key});

  final EventDef event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(saveRevisionProvider);
    final game = ref.read(gameProvider);
    final state = game.state;
    final cfg = event.cupConfig;
    if (state == null || cfg == null) return const SizedBox.shrink();

    final cup = activeEventCup(state, event.id);
    if (cup == null) {
      return _NationPicker(event: event, cfg: cfg);
    }
    if (cup['won'] == true) {
      return _CupOver(event: event, cfg: cfg, cup: cup, won: true);
    }
    if (cup['eliminated'] == true) {
      return _CupOver(event: event, cfg: cfg, cup: cup, won: false);
    }
    return _CupRound(event: event, cfg: cfg, cup: cup);
  }
}

/// Who the player is leading.
///
/// Sorted by rating, favourites first, so power tier is visible at a glance
/// rather than something to be learnt by losing.
class _NationPicker extends ConsumerWidget {
  const _NationPicker({required this.event, required this.cfg});

  final EventDef event;
  final EventCupConfig cfg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final remembered = lastPickedNation(game.state, event.id);
    final pool = [...cfg.opponentPool]
      ..sort(
        (a, b) =>
            (cfg.nationRatings[b] ?? 70).compareTo(cfg.nationRatings[a] ?? 70),
      );

    return Column(
      key: const ValueKey('event-cup-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              Text(
                t('event.picker.title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kit.accent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('event.picker.body', {'n': cfg.rounds.length}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: kit.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (remembered != null) ...[
          const SizedBox(height: 14),
          Container(
            key: const ValueKey('event-cup-remembered'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kit.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kit.border),
            ),
            child: Row(
              children: [
                Text(
                  cfg.flags[remembered] ?? '🏳️',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('event.picker.last_picked').toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.5,
                          color: kit.textMuted,
                        ),
                      ),
                      Text(
                        remembered,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  key: const ValueKey('event-cup-lead-again'),
                  onPressed: () => game.update(
                    (s) => startEventCup(s, event.id, remembered),
                  ),
                  child: Text(t('event.picker.lead_again')),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  key: const ValueKey('event-cup-forget'),
                  onPressed: () =>
                      game.update((s) => forgetLastPickedNation(s, event.id)),
                  child: const Text('✕'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7,
          crossAxisSpacing: 7,
          childAspectRatio: 1.1,
          children: [
            for (final nation in pool)
              _NationTile(
                nation: nation,
                flag: cfg.flags[nation] ?? '🏳️',
                rating: cfg.nationRatings[nation] ?? 70,
                lastPicked: remembered == nation,
                onTap: () =>
                    game.update((s) => startEventCup(s, event.id, nation)),
              ),
          ],
        ),
      ],
    );
  }
}

class _NationTile extends StatelessWidget {
  const _NationTile({
    required this.nation,
    required this.flag,
    required this.rating,
    required this.lastPicked,
    required this.onTap,
  });

  final String nation;
  final String flag;
  final num rating;
  final bool lastPicked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    return GestureDetector(
      key: ValueKey('event-cup-nation-$nation'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 11),
        decoration: BoxDecoration(
          color: lastPicked
              ? const Color(0xFFFFD700).withValues(alpha: 0.08)
              : kit.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kit.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 26, height: 1)),
            const SizedBox(height: 4),
            Text(
              nation,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '⭐ $rating',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: ratingInk(rating),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The next round: who, how they compare, what the coach makes of them, and the
/// button that plays it.
class _CupRound extends ConsumerWidget {
  const _CupRound({required this.event, required this.cfg, required this.cup});

  final EventDef event;
  final EventCupConfig cfg;
  final Map<String, dynamic> cup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final state = game.state;
    if (state == null) return const SizedBox.shrink();

    final round = _num(cup['round']).toInt();
    final opponents = cup['opponents'];
    final opponent = opponents is List && round < opponents.length
        ? '${opponents[round]}'
        : '';
    final ourNation = cup['playerNation'] as String?;
    final ourName = ourNation ?? t('common.your_club');
    final ourRating = ourNation == null ? null : cfg.nationRatings[ourNation];
    final theirRating = cfg.nationRatings[opponent];
    final roundName = round < cfg.rounds.length ? cfg.rounds[round] : '';

    final energy = _num(_map(state['energy'])?['current']);
    final enoughEnergy = energy >= Energy.matchCost;

    return Column(
      key: const ValueKey('event-cup-round'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoachRead(event: event, cfg: cfg, opponent: opponent, round: round),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      roundName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: kit.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    _favouredLabel(ourName, ourRating, opponent, theirRating),
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 0.5,
                      color: kit.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _SideBlock(
                      flag: cfg.flags[ourNation] ?? '🏳️',
                      name: ourName,
                      rating: ourRating,
                    ),
                  ),
                  Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: cssColor(event.color),
                    ),
                  ),
                  Expanded(
                    child: _SideBlock(
                      flag: cfg.flags[opponent] ?? '🏳️',
                      name: opponent,
                      rating: theirRating,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          key: const ValueKey('event-cup-play'),
          onPressed: enoughEnergy
              ? () => game.update((s) => playEventCupRound(s, event.id))
              : null,
          child: Text(
            enoughEnergy
                ? t('event.cup.play_round', {'round': roundName})
                : t('play.out_of_energy'),
          ),
        ),
        _CupResults(cfg: cfg, cup: cup),
      ],
    );
  }

  /// Whoever has the higher rating is named. Both sides read the same way, so
  /// the sentence is about the match rather than about the player.
  String _favouredLabel(
    String ourName,
    num? ourRating,
    String opponent,
    num? theirRating,
  ) {
    if (ourRating == null || theirRating == null) return '';
    if (ourRating > theirRating) {
      return t('event.cup.team_favoured', {'team': ourName});
    }
    if (theirRating > ourRating) {
      return t('event.cup.team_favoured', {'team': opponent});
    }
    return t('event.cup.even');
  }
}

class _SideBlock extends StatelessWidget {
  const _SideBlock({
    required this.flag,
    required this.name,
    required this.rating,
  });

  final String flag;
  final String name;
  final num? rating;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(flag, style: const TextStyle(fontSize: 28, height: 1)),
      const SizedBox(height: 2),
      Text(
        name,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      Text(
        '⭐ ${rating ?? '?'}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Color(0xFFFFD700),
        ),
      ),
    ],
  );
}

/// What the coach makes of the opponent.
///
/// The fact is picked deterministically from the round and the nation's name
/// length, so it does not shuffle every time the screen repaints — a line that
/// changes under you reads as noise rather than as a read.
class _CoachRead extends StatelessWidget {
  const _CoachRead({
    required this.event,
    required this.cfg,
    required this.opponent,
    required this.round,
  });

  final EventDef event;
  final EventCupConfig cfg;
  final String opponent;
  final int round;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final count = cfg.nationFactCount > 0 ? cfg.nationFactCount : 3;
    final index = (round * 7 + (opponent.length % count)) % count;
    final key = 'event.${event.id}.fact.$opponent.$index';
    final hit = t(key);
    final line = hit == key
        ? t('event.cup.opponent_default', {'opp': opponent})
        : hit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kit.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kit.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: kit.bg,
            child: const Text('🧑‍🏫', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('event.cup.coach_on', {'team': opponent}).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: kit.accentBright,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  line,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Knocked out, or champions.
///
/// Both offer the same two doors, because the answer to a cup that has finished
/// is either "again with these" or "again with someone else".
class _CupOver extends ConsumerWidget {
  const _CupOver({
    required this.event,
    required this.cfg,
    required this.cup,
    required this.won,
  });

  final EventDef event;
  final EventCupConfig cfg;
  final Map<String, dynamic> cup;
  final bool won;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final game = ref.read(gameProvider);
    final nation = cup['playerNation'] as String?;
    final flag = cfg.flags[nation] ?? '';
    final round = _num(cup['round']).toInt();

    return Column(
      key: ValueKey('event-cup-${won ? 'won' : 'out'}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          decoration: BoxDecoration(
            color: kit.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kit.border),
          ),
          child: Column(
            children: [
              Text(won ? '🏆' : '💔', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 10),
              Text(
                won ? t('event.cup.champions') : t('event.cup.eliminated'),
                style: TextStyle(
                  fontSize: won ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: won ? kit.accent : const Color(0xFFE57373),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                won
                    ? t('event.cup.champions_body', {
                        'flag': flag,
                        'nation': nation ?? '',
                        'event': eventName(event),
                      })
                    : t('event.cup.eliminated_body', {
                        'flag': flag,
                        'nation': nation ?? '',
                        'round': round < cfg.rounds.length
                            ? cfg.rounds[round]
                            : '?',
                      }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: won ? null : kit.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    key: const ValueKey('event-cup-restart'),
                    onPressed: () =>
                        game.update((s) => restartEventCup(s, event.id)),
                    child: Text(
                      '${won ? t('event.cup.run_it_back') : t('event.cup.try_again')} $flag',
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('event-cup-change-nation'),
                    onPressed: () => game.update(
                      (s) => restartEventCup(
                        s,
                        event.id,
                        const ShowNationPicker(),
                      ),
                    ),
                    child: Text(t('event.nation.change')),
                  ),
                ],
              ),
            ],
          ),
        ),
        _CupResults(cfg: cfg, cup: cup),
      ],
    );
  }
}

/// The rounds already played.
class _CupResults extends StatelessWidget {
  const _CupResults({required this.cfg, required this.cup});

  final EventCupConfig cfg;
  final Map<String, dynamic> cup;

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final raw = cup['results'];
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    return Padding(
      key: const ValueKey('event-cup-results'),
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t('event.cup.results').toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: kit.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < raw.length; i++)
            if (_map(raw[i]) case final result?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i < cfg.rounds.length ? cfg.rounds[i] : '',
                        style: TextStyle(fontSize: 12, color: kit.textMuted),
                      ),
                    ),
                    Text(
                      '${result['opponent'] ?? ''}  '
                      '${_num(result['playerGoals']).toInt()}'
                      '–${_num(result['opponentGoals']).toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: result['won'] == true
                            ? kit.accentBright
                            : const Color(0xFFE57373),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
