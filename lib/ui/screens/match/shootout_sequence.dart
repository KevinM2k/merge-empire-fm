/// **THE SHOOTOUT, PLAYED OUT ONE KICK AT A TIME.**
///
/// A level cup tie already rolled its penalties before the screen opened — the
/// whole list of them, sudden death and all, is on the result under
/// `penaltyShootout`. What it did NOT have was a moment: the whistle went on a
/// 0-0 and the summary announced the club through, with the thing that decided
/// it reported as a row of ticks somewhere further down the page.
///
/// Asked for from the couch in the shape a shootout actually has: a player
/// steps up, a pause, then it is a goal or it is not, and that repeats until
/// the kicks run out. This is that, driven off the list the engine already
/// wrote, so nothing here decides anything — it only reveals, in order, what
/// was already true.
///
/// **CUP TIES ONLY**, because only a cup tie can go to penalties. In the league
/// a draw is a result.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:merge_empire_fc/i18n/i18n.dart';
import 'package:merge_empire_fc/ui/theme/kit_theme_ext.dart';

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

/// One kick, in the order it was taken.
///
/// **In ORDER, which is the one thing `shootoutFrom` throws away.** That one
/// splits the kicks into two rows of marks because that is what a summary
/// needs; a sequence needs them interleaved the way they were taken, because
/// the alternation is the drama.
typedef ShootoutKick = ({bool ours, bool scored, bool suddenDeath});

/// Every kick of a tie's shootout, in order — or empty for a tie that never
/// went to one, which is nearly all of them.
List<ShootoutKick> shootoutKicksOf(Map<String, dynamic>? result) {
  final raw = _map(result?['penaltyShootout'])?['kicks'];
  if (raw is! List) return const [];
  return [
    for (final entry in raw)
      if (_map(entry) case final kick?)
        (
          // **`home` is always OURS in an engine result** — there is no venue
          // flip, which is the same rule the goals follow and the one thing
          // here that looks like it should be checked and must not be.
          ours: kick['team'] == 'home',
          scored: kick['scored'] == true,
          suddenDeath: kick['suddenDeath'] == true,
        ),
  ];
}

/// How long a taker stands over the ball before the ball is struck.
const Duration shootoutStepUp = Duration(milliseconds: 700);

/// How long the outcome of a kick stays up before the next taker walks.
const Duration shootoutHold = Duration(milliseconds: 750);

/// The beat between the last kick and handing the screen back.
const Duration shootoutSettle = Duration(milliseconds: 1200);

/// The shootout, revealed kick by kick.
class ShootoutSequence extends StatefulWidget {
  const ShootoutSequence({
    super.key,
    required this.kicks,
    required this.ourName,
    required this.theirName,
    required this.onDone,
    this.stepUp = shootoutStepUp,
    this.hold = shootoutHold,
    this.settle = shootoutSettle,
  });

  final List<ShootoutKick> kicks;
  final String ourName;
  final String theirName;

  /// Called once, after the last kick has been held and the result has had a
  /// beat to land. The screen behind this one waits for it before offering
  /// anything to press — a shootout the player can skip past is a shootout
  /// they did not watch.
  final VoidCallback onDone;

  /// Test seams. A suite that waited out the real thing would spend a minute
  /// of wall clock on a single tie.
  final Duration stepUp;
  final Duration hold;
  final Duration settle;

  @override
  State<ShootoutSequence> createState() => ShootoutSequenceState();
}

class ShootoutSequenceState extends State<ShootoutSequence> {
  /// How many kicks have been TAKEN — their outcome is on screen.
  int _taken = 0;

  /// Somebody is standing over the ball and the outcome is not out yet.
  bool _waiting = false;

  /// Every timer this has in flight, so `dispose` can take them with it. A
  /// shootout that outlives its route goes on calling `setState` on a dead
  /// element, and the route above it is one a player can leave.
  final List<Timer> _timers = [];

  bool get _done => _taken >= widget.kicks.length;

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _after(Duration d, VoidCallback run) {
    late Timer timer;
    timer = Timer(d, () {
      _timers.remove(timer);
      if (mounted) run();
    });
    _timers.add(timer);
  }

  void _next() {
    if (_done) {
      _after(widget.settle, widget.onDone);
      return;
    }
    setState(() => _waiting = true);
    _after(widget.stepUp, () {
      setState(() {
        _waiting = false;
        _taken++;
      });
      _after(widget.hold, _next);
    });
  }

  /// The running score, counted off the kicks already taken — not read off the
  /// result's totals, which are the FINAL pair and would give the ending away
  /// on the first kick.
  (int, int) get _score {
    var ours = 0;
    var theirs = 0;
    for (var i = 0; i < _taken; i++) {
      final kick = widget.kicks[i];
      if (!kick.scored) continue;
      if (kick.ours) {
        ours++;
      } else {
        theirs++;
      }
    }
    return (ours, theirs);
  }

  @override
  Widget build(BuildContext context) {
    final kit = Theme.of(context).extension<KitTheme>()!;
    final (ours, theirs) = _score;
    // Whose kick is being shown: the one standing over it, or the one whose
    // outcome is up.
    final idx = _waiting ? _taken : _taken - 1;
    final current = idx >= 0 && idx < widget.kicks.length
        ? widget.kicks[idx]
        : null;

    return Container(
      key: const ValueKey('shootout-sequence'),
      color: const Color(0xCC000000),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            t('cup.shootout.title'),
            key: const ValueKey('shootout-title'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: kit.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$ours - $theirs',
            key: const ValueKey('shootout-running-score'),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
            ),
          ),
          const SizedBox(height: 12),
          // **ONE LINE THAT SAYS WHAT IS HAPPENING RIGHT NOW**, and it is the
          // whole point of the sequence: who is on the ball, then whether it
          // went in. A row of marks can say the first of those and cannot say
          // the second.
          SizedBox(
            height: 34,
            child: Center(
              child: current == null
                  ? const SizedBox.shrink()
                  : _waiting
                  ? Text(
                      t('cup.shootout.steps_up', {
                        'club': current.ours ? widget.ourName : widget.theirName,
                      }),
                      key: const ValueKey('shootout-stepping-up'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kit.textMuted,
                      ),
                    )
                  : Text(
                      t(
                        current.scored
                            ? 'cup.shootout.scored'
                            : 'cup.shootout.missed',
                      ),
                      key: ValueKey(
                        current.scored ? 'shootout-scored' : 'shootout-missed',
                      ),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: current.scored
                            ? kit.accentBright
                            : const Color(0xFFF87171),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Sudden death says so, because it changes what a miss means.
          if (current?.suddenDeath == true)
            Text(
              t('cup.shootout.sudden_death'),
              key: const ValueKey('shootout-sudden-death'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: kit.accentBright,
              ),
            ),
        ],
      ),
    );
  }
}
