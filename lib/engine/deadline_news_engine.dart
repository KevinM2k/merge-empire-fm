/// The Deadline Day news ticker — the rolling strip under the event banner.
/// Ported from `../merge-empire-fc/src/engine/deadlineNewsEngine.js`.
///
/// Three phases, three different KINDS of truth, and the difference is the whole
/// point of the feature:
///
/// - `buildup` — before the doors open. Every line is a rumour and none of them
///   are real: nobody has been spotted anywhere, no agent was in any car park.
///   That is what deadline day actually sounds like, and inventing it here is
///   honest because nothing downstream reads it.
/// - `live` — the window is open, so it reports REAL listings off the live
///   session. Made-up lines survive only as a fallback for the minutes before
///   the first deal lands.
/// - `aftermath` — the window has shut and tonight's ledger exists. It reports
///   what was actually done, the same numbers the Deadline Day screen's tonight
///   block shows.
///
/// Lines come back as a key and its params rather than as sentences, the way the
/// club-asset tiers hand back ids: the engine stays i18n-free and the words live
/// with every other word.
///
/// Deterministic by design. The strip is rebuilt on every League re-render, and
/// a fresh draw each time would reshuffle the rumours under the player's eyes
/// mid-read. Everything comes off a stream of its own whose seed moves only when
/// the news should: the window it belongs to, plus an hour bucket through the
/// long build-up so a whole afternoon is not three sentences.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

import 'package:merge_empire_fc/data/divisions.dart';
import 'package:merge_empire_fc/data/players.dart';
import 'package:merge_empire_fc/engine/deadline_day_engine.dart';
import 'package:merge_empire_fc/util/random.dart' show Mulberry32;
import 'package:merge_empire_fc/util/time.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
num? _num(Object? v) => v is num ? v : null;

/// One line of the strip: a translation key and the params it wants.
typedef NewsLine = ({String key, Map<String, dynamic> params});

/// How many lines the strip rotates through.
const int newsLines = 3;

const int _hourMs = 60 * 60 * 1000;

/// Which of the three phases the strip is in.
enum NewsPhase { buildup, live, aftermath }

double Function() _rng(int seed) {
  final stream = Mulberry32(seed.toUnsigned(32).toSigned(32));
  return stream.next;
}

/// The modulo is not decoration: a draw of exactly 1 would index past the end.
T _pick<T>(double Function() rand, List<T> arr) =>
    arr[(rand() * arr.length).floor() % arr.length];

/// Draw [n] distinct members, in a stable shuffled order.
List<T> _sample<T>(double Function() rand, List<T> arr, int n) {
  final pool = [...arr];
  final out = <T>[];
  while (pool.isNotEmpty && out.length < n) {
    out.add(pool.removeAt((rand() * pool.length).floor()));
  }
  return out;
}

/// Club names to gossip about.
///
/// The whole pyramid, not just this season's seven — a rumour linking your
/// striker with a Champions League side is the fun one, and the seven teams you
/// play every week are the least interesting names available.
List<String> _rivalNames(Map<String, dynamic>? state) {
  final prog = _map(state?['progression']);
  final pyramid = _map(prog?['leaguePyramid']);
  final names = <String>[];
  if (pyramid != null) {
    for (final d in divisions) {
      final teams = pyramid[d.id];
      if (teams is! List) continue;
      for (final t in teams) {
        final name = _map(t)?['name'];
        if (name is String && name.isNotEmpty) names.add(name);
      }
    }
  }
  if (names.isEmpty) {
    final opponents = prog?['seasonOpponents'];
    if (opponents is List) {
      for (final n in opponents) {
        if (n != null && '$n'.isNotEmpty) names.add('$n');
      }
    }
  }
  return names;
}

/// Our own players, by name. Some rumours are about YOUR squad — that is the
/// hook.
List<String> _squadNames(Map<String, dynamic>? state) {
  final cells = _map(state?['grid'])?['cells'];
  if (cells is! List) return const [];
  final names = <String>[];
  for (final c in cells) {
    final card = _map(c);
    if (card == null) continue;
    final name = getCardName(card);
    if (name.isNotEmpty) names.add(name);
  }
  return names;
}

/// Names for the rumours that have nothing to do with us.
///
/// Deadline day is mostly other people's business, and a strip where every line
/// is about your own eleven reads as a squad screen rather than a newsroom.
/// Drawn from the game's own name pools rather than invented here, so a rival's
/// phantom target sounds like every other player in the game.
List<String> _outsiderNames(double Function() rand) {
  final out = <String>[];
  for (final pos in ['FWD', 'MID', 'DEF', 'GK']) {
    for (var i = 0; i < 6; i++) {
      final n = pickDisplayName(
        pos,
        (rand() * 64).floor() + i,
        female: rand() < 0.5,
      );
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
  }
  return out;
}

/// Which phase the strip is in.
///
/// [live] is the caller's answer — the League screen already knows whether the
/// event is running and there is no sense asking twice. Aftermath is keyed on
/// tonight's banked window being TODAY, exactly as the Deadline Day screen's
/// tonight block is, so both expire at the same midnight.
NewsPhase deadlineNewsPhase(
  Map<String, dynamic> state,
  bool live, [
  int? nowMs,
]) {
  if (live) return NewsPhase.live;
  final at = nowMs ?? now();
  final history = ensureDeadlineDay(state)['history'];
  final h = history is List && history.isNotEmpty ? _map(history.first) : null;
  if (h == null) return NewsPhase.buildup;
  final stamp = _num(h['windowStart']);
  final d = DateTime.fromMillisecondsSinceEpoch(
    ((stamp != null && stamp != 0 ? stamp : _num(h['endedAt']) ?? 0)).toInt(),
  );
  final n = DateTime.fromMillisecondsSinceEpoch(at);
  final sameDay = d.year == n.year && d.month == n.month && d.day == n.day;
  return sameDay ? NewsPhase.aftermath : NewsPhase.buildup;
}

// ── Rumours ─────────────────────────────────────────────────────────────────
//
// Every one of these is a lie, and they are written to be transparently one:
// house-hunting, car parks, unfollowing people on social media, a jet nobody can
// identify. That is what the hours before a deadline actually sound like, and
// writing them as plausible transfer news would be worse than useless — the
// strip would read as a preview of the listings, and then the window would open
// with none of them in it.
//
// `scope` decides whose gossip it is. `ours` puts one of the player's own squad
// in the headline; `theirs` is two rival clubs and a name from the wider game;
// `any` is atmosphere with nobody in it. The mix is deliberate: all-ours reads
// as a squad screen, all-theirs reads as somebody else's app.

typedef _Rumour = ({String key, String scope, List<String> needs});

const List<_Rumour> _rumours = [
  (key: 'event.news.rumour.spotted', scope: 'ours', needs: ['player', 'team']),
  (key: 'event.news.rumour.houses', scope: 'ours', needs: ['player', 'team']),
  (key: 'event.news.rumour.agent', scope: 'ours', needs: ['player', 'team']),
  (key: 'event.news.rumour.record', scope: 'ours', needs: ['player', 'team']),
  (key: 'event.news.rumour.unfollow', scope: 'ours', needs: ['player', 'club']),
  (
    key: 'event.news.rumour.link',
    scope: 'theirs',
    needs: ['player', 'team', 'team2'],
  ),
  (
    key: 'event.news.rumour.bidwar',
    scope: 'theirs',
    needs: ['player', 'team', 'team2'],
  ),
  (
    key: 'event.news.rumour.medical',
    scope: 'theirs',
    needs: ['player', 'team'],
  ),
  (
    key: 'event.news.rumour.training',
    scope: 'theirs',
    needs: ['player', 'team'],
  ),
  (key: 'event.news.rumour.jet', scope: 'theirs', needs: ['team']),
  (key: 'event.news.rumour.phones', scope: 'any', needs: <String>[]),
];

/// [n] rumours, at most one of each, with AT LEAST ONE about the player's own
/// squad whenever there is a squad to gossip about.
///
/// Left to a plain sample, a three-line set lands all-outsiders often enough to
/// matter, and a rumour mill that never mentions your own players is somebody
/// else's newspaper.
///
/// A template whose names we have not got is simply not drawn — an empty grid
/// has no squad to talk about, and "has been spotted at" with a blank in front
/// of it is worse than one fewer line. `team2` is drawn distinct from `team`,
/// because a bidding war a club is having with itself is a typo, not a joke.
List<NewsLine> _rumourLines(
  double Function() rand,
  int n, {
  required List<String> players,
  required List<String> outsiders,
  required List<String> teams,
  required String club,
}) {
  bool has(String scope) =>
      scope == 'ours' ? players.isNotEmpty : outsiders.isNotEmpty;
  final usable = [
    for (final r in _rumours)
      if ((!r.needs.contains('player') || has(r.scope)) &&
          (!r.needs.contains('team') || teams.isNotEmpty) &&
          (!r.needs.contains('team2') || teams.length > 1))
        r,
  ];
  final ours = [
    for (final r in usable)
      if (r.scope == 'ours') r,
  ];
  final lead = n > 0 && ours.isNotEmpty ? _sample(rand, ours, 1) : <_Rumour>[];
  final rest = _sample(rand, [
    for (final r in usable)
      if (!lead.contains(r)) r,
  ], math.max(0, n - lead.length));
  return [
    for (final r in [...lead, ...rest])
      () {
        final params = <String, dynamic>{};
        if (r.needs.contains('player')) {
          params['player'] = _pick(
            rand,
            r.scope == 'ours' ? players : outsiders,
          );
        }
        if (r.needs.contains('team')) params['team'] = _pick(rand, teams);
        if (r.needs.contains('team2')) {
          final others = [
            for (final x in teams)
              if (x != params['team']) x,
          ];
          params['team2'] = _pick(rand, others.isNotEmpty ? others : teams);
        }
        if (r.needs.contains('club')) params['club'] = club;
        return (key: r.key, params: params);
      }(),
  ];
}

// ── Real deals, read as a broadcast ─────────────────────────────────────────
//
// Third person, club named, verb in the perfect: "Northern Legion FC have signed
// X from Y". Not "you signed X" — the ticker is a newsroom reporting on the
// player's club from outside, which is the only register in which a transfer
// line sounds like a transfer line.
//
// `fee` is the one param the engine does NOT resolve: a number for the caller's
// coin formatter, or null meaning the broadcast is declining to say (the
// `_undisclosed` variant of the key). Every other param is final.

/// FNV-1a, so a listing's coin flip is stable and a fee does not turn
/// undisclosed mid-read.
int _hash(Object? s) {
  final str = '$s';
  var h = 2166136261;
  for (var i = 0; i < str.length; i++) {
    h = (h ^ str.codeUnitAt(i)).toSigned(32);
    h = (h * 16777619).toSigned(32);
  }
  return h.toUnsigned(32);
}

bool _undisclosed(Listing l) =>
    l['marquee'] != true && _hash(l['listingId'] ?? '') % 3 == 0;

/// An ACCEPTED listing — a deal that actually happened tonight.
NewsLine? _dealLine(Listing l, String club) {
  final hidden = _undisclosed(l);
  final p = <String, dynamic>{
    'player': l['playerName'],
    'team': l['fromTeam'],
    'club': club,
    'fee': hidden ? null : (l['price'] ?? 0),
  };
  final sfx = hidden ? '_undisclosed' : '';
  return switch (l['kind']) {
    'signing' => (
      key: 'event.news.deal.${l['marquee'] == true ? 'marquee' : 'signed'}$sfx',
      params: p,
    ),
    'bid' => (key: 'event.news.deal.sold$sfx', params: p),
    'loan' => (
      key: 'event.news.deal.loaned_in',
      params: {...p, 'n': l['matches'] ?? 0},
    ),
    'loanOut' => (
      key: 'event.news.deal.loaned_out',
      params: {...p, 'n': l['matches'] ?? 0},
    ),
    _ => null,
  };
}

/// A listing still on the table — talks, not a deal. Same broadcast register.
NewsLine? _talksLine(Listing l, String club) {
  final p = <String, dynamic>{
    'player': l['playerName'],
    'team': l['fromTeam'],
    'club': club,
  };
  return switch (l['kind']) {
    'signing' => (
      key: l['marquee'] == true
          ? 'event.news.talks.marquee'
          : 'event.news.talks.available',
      params: p,
    ),
    'bid' => (key: 'event.news.talks.bid', params: p),
    'loan' => (key: 'event.news.talks.loan', params: p),
    'loanOut' => (key: 'event.news.talks.loanout', params: p),
    _ => null,
  };
}

/// Tonight's accepted deals, newest first — or empty when the session on file
/// belongs to an earlier window.
///
/// Ending a session leaves its listings in place, so without the window check
/// the aftermath strip would happily rebroadcast last Tuesday's business as if
/// it had just landed.
List<Listing> _dealsFor(Map<String, dynamic> state, num? windowStart) {
  final s = _map(ensureDeadlineDay(state)['session']);
  if (s == null || _num(s['startedAt']) == null) return const [];
  if (windowStart != null && _num(s['windowStart']) != windowStart) {
    return const [];
  }
  final listings = s['listings'];
  if (listings is! List) return const [];
  return [
    for (final l in listings)
      if (_map(l)?['status'] == 'accepted') _map(l)!,
  ].reversed.toList();
}

/// The strip's lines, in rotation order.
///
/// [opener] is the build-up's first line, handed in whole. The caller owns it
/// because WHICH sentence is right depends on the clock — "at 6:00 pm" today,
/// "tomorrow at 6:00 pm" this evening, "in 4 days" a week out — and that is the
/// same judgement the Deadline Day screen already makes about its own closed
/// line. Two copies of it in two files is how the two end up disagreeing.
List<NewsLine> deadlineHeadlines(
  Map<String, dynamic> state, {
  bool live = false,
  int? nowMs,
  String clubName = '',
  NewsLine? opener,
}) {
  final at = nowMs ?? now();
  final phase = deadlineNewsPhase(state, live, at);
  final teams = _rivalNames(state);

  if (phase == NewsPhase.aftermath) {
    final h = _map((ensureDeadlineDay(state)['history'] as List).first)!;
    final rand = _rng((_num(h['endedAt']) ?? at).floor());
    // What was DONE leads, one deal per line, because that is the news. The
    // counts are the wrap-up underneath — and the only thing on offer at all
    // when the evening's business was nothing.
    final lines = <NewsLine>[
      for (final l in _dealsFor(state, _num(h['windowStart'])))
        ?_dealLine(l, clubName),
    ];
    final inDeals = (_num(h['signings']) ?? 0) + (_num(h['loans']) ?? 0);
    final outDeals = (_num(h['sales']) ?? 0) + (_num(h['loanOuts']) ?? 0);
    final total = inDeals + outDeals;
    if (total > 0) {
      lines.add((
        key: 'event.news.after.done',
        params: {'club': clubName, 'n': total, 's': total == 1 ? '' : 's'},
      ));
    } else {
      lines.add((key: 'event.news.after.quiet', params: {'club': clubName}));
      final missed = _num(h['missed']) ?? 0;
      if (missed > 0) {
        lines.add((
          key: 'event.news.after.missed',
          params: {'n': missed, 's': missed == 1 ? '' : 's'},
        ));
      }
    }
    // League-wide business is flavour, not a ledger — nothing else in the save
    // knows or cares what the other clubs did. Seeded off the window so it holds
    // the same number all evening rather than re-rolling every rotation.
    lines.add((
      key: 'event.news.after.league',
      params: {'n': 40 + (rand() * 60).floor()},
    ));
    lines.add((key: 'event.news.after.tomorrow', params: <String, dynamic>{}));
    return lines.take(newsLines).toList();
  }

  if (phase == NewsPhase.live) {
    // Done deals first — a signing that has actually gone through outranks an
    // offer sitting on the desk, however shiny the offer is.
    //
    // Only THIS session's, though. A session only starts by walking into the
    // Deadline Day screen, so during a live window the save can still be holding
    // last night's finished session, and passing no window here rebroadcast
    // those deals as if they had just landed — on a night the player had not yet
    // done any business at all. `liveListings` is already session-scoped by the
    // fuse; this is the half that was not.
    final s = _map(ensureDeadlineDay(state)['session']);
    final thisWindow = s?['done'] == true ? null : _num(s?['windowStart']);
    final done = <NewsLine>[
      for (final l
          in thisWindow == null
              ? const <Listing>[]
              : _dealsFor(state, thisWindow))
        ?_dealLine(l, clubName),
    ];
    final talks = <NewsLine>[
      for (final l in liveListings(state, at)) ?_talksLine(l, clubName),
    ];
    final real = [...done, ...talks].take(newsLines).toList();
    if (real.length >= newsLines) return real;
    // Nothing has landed yet — the first listing arrives a beat after the doors
    // open, and a blank strip in that gap reads as broken rather than as early.
    final rand = _rng((at / _hourMs).floor());
    const filler = ['open', 'rivals', 'hurry'];
    final chosen = _sample(rand, filler, newsLines - real.length);
    return [
      ...real,
      for (final f in chosen)
        (
          key: 'event.news.live.$f',
          params: f == 'open'
              ? <String, dynamic>{'club': clubName}
              : <String, dynamic>{},
        ),
    ];
  }

  // Buildup. The opener leads — it is the one true thing on the strip — and the
  // rest is the rumour mill.
  final rand = _rng((at / _hourMs).floor());
  final lines = <NewsLine>[?opener];
  lines.addAll(
    _rumourLines(
      rand,
      newsLines - lines.length,
      players: _squadNames(state),
      outsiders: _outsiderNames(rand),
      teams: teams,
      club: clubName,
    ),
  );
  while (lines.length < newsLines) {
    lines.add((key: 'event.news.buildup.ready', params: <String, dynamic>{}));
  }
  return lines.take(newsLines).toList();
}
