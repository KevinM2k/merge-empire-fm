/// The six manager boosts — consumables spent during a live match.
///
/// **Proactive on the pitch, retrospective on the bench.** Two change how the
/// side plays for a window and are tapped from the match screen while
/// watching; two undo something the referee or the physio has already done and
/// are taken at the bench, in front of the consequence, with the clock stopped.
/// The kind is what decides where a boost is offered, and the window is what
/// decides whether the progress bar has a band to burn for it.
///
/// **One gem buys one**, against the gem catalogue's own anchors — scout
/// voucher 1, energy refill 5, trophy polish 5. The cheapest thing on the
/// shelf for the shortest effect, so a boost is SPENT rather than hoarded,
/// which is how a consumable teaches its own value. Asked for from the couch.
///
/// The catalogue's second law — "NEVER RAW RATING" — is why Crowd Roar is a
/// window and not a permanent, and why Park the Bus is not a rating change at
/// all: a transient lift is closer in kind to trophy polish's half hour than to
/// an unlock, and the division bands are tuned against what a squad is worth
/// normally.
///
/// The port's own, not the JS's. Deliberately Flutter-free.
library;

enum BoostKind {
  /// Tapped from the match screen at any minute. Carries a window.
  proactive,

  /// Offered at the bench when the panel opens for the thing it undoes. The
  /// match is paused while it is offered, so it has no window.
  retrospective,
}

class Boost {
  const Boost({
    required this.id,
    required this.icon,
    required this.kind,
    required this.gemCost,
    required this.packSize,
    this.windowMinutes = 0,
  });

  final String id;

  /// A name from `game_icon.dart` — the app's own line art, not an emoji, so
  /// a boost draws the way the shop and the HUD do. Asked for from the couch.
  final String icon;
  final BoostKind kind;

  /// The price of one PACK, in gems.
  final int gemCost;

  /// How many a pack delivers.
  final int packSize;

  /// How long the effect runs, in IN-GAME minutes. Zero for a retrospective
  /// boost. In-game rather than wall-clock because the unit has to survive the
  /// speed toggle and the auto-slow.
  final int windowMinutes;
}

/// Twenty-five: about nine real seconds at the normal pace, and twenty-eight
/// per cent of a match. Long enough to be seen as a window on the bar rather
/// than a flash, short enough that WHEN to tap it is still a decision.
const int _window = 25;

const Map<String, Boost> boosts = {
  'crowd_roar': Boost(
    id: 'crowd_roar', icon: 'megaphone',
    kind: BoostKind.proactive, gemCost: 1, packSize: 1,
    windowMinutes: _window,
  ),
  'park_the_bus': Boost(
    id: 'park_the_bus', icon: 'shield',
    kind: BoostKind.proactive, gemCost: 1, packSize: 1,
    windowMinutes: _window,
  ),
  // OUR attack lifted for a window, defence and the other side untouched —
  // on the board's ATK figure, so it can be seen doing it.
  'sharp_shooting': Boost(
    id: 'sharp_shooting', icon: 'target',
    kind: BoostKind.proactive, gemCost: 1, packSize: 1,
    windowMinutes: _window,
  ),
  'var_review': Boost(
    id: 'var_review', icon: 'tv',
    kind: BoostKind.retrospective, gemCost: 1, packSize: 1,
  ),
  'physio_sponge': Boost(
    id: 'physio_sponge', icon: 'bandage',
    kind: BoostKind.retrospective, gemCost: 1, packSize: 1,
  ),
  // The bench's third undo: a yellow card wiped, so the man plays at full
  // rating again and carries no ban towards the next one.
  'quiet_word': Boost(
    id: 'quiet_word', icon: 'handshake',
    kind: BoostKind.retrospective, gemCost: 1, packSize: 1,
  ),
};

final List<Boost> boostList = List.unmodifiable(boosts.values);

Boost? getBoost(String? id) => id == null ? null : boosts[id];
