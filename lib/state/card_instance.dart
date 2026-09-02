/// A player card instance as it lives in the save.
///
/// This is a typed VIEW over the underlying JSON map, not a replacement for it.
/// Cloud saves store the whole state as a JSON string and the port must round-
/// trip it exactly, so a model that parsed known fields into typed properties
/// and discarded the rest would corrupt saves written by a newer build. Holding
/// the map and reading through it keeps every unknown field intact while still
/// giving callers type safety.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'package:merge_empire_fc/data/player_art.dart';
import 'package:merge_empire_fc/data/players.dart';

class CardInstance {
  CardInstance(this.raw);

  /// The backing map. Mutations go through here so serialization stays lossless.
  final Map<String, dynamic> raw;

  static CardInstance? from(Object? value) =>
      value is Map<String, dynamic> ? CardInstance(value) : null;

  T? _get<T>(String key) {
    final v = raw[key];
    return v is T ? v : null;
  }

  String get definitionId => _get<String>('definitionId') ?? '';
  String get instanceId => _get<String>('instanceId') ?? '';

  /// Which portrait this card wears. Absent on a card written before variants
  /// existed, which reads as 0 — the same default the migration backfills with.
  int get variant => (_get<num>('variant') ?? 0).toInt();

  /// How the Player Index names this card: `{definitionId}:{m|f}`.
  ///
  /// One definition is TWO index entries, because the same striker has male and
  /// female art and a name pool each. The key is written into the save, so it
  /// has one home rather than a copy per caller.
  String get discoveryKey =>
      '$definitionId:${isVariantFemale(variant) ? 'f' : 'm'}';

  int get seasonsPlayed => (_get<num>('seasonsPlayed') ?? 0).toInt();

  /// An injured player is OURS and here, just unfit.
  bool get injured => raw['injured'] == true;

  /// Advertised for sale — not ours to pick.
  bool get listed => raw['listed'] == true;

  /// Out on loan at another club — not ours to pick.
  Object? get loanedOut => raw['loanedOut'];

  /// Cosmetic rename. Never inherited by a merged card.
  String? get customName => _get<String>('customName');

  /// The name rolled when the instance was created.
  String? get displayName => _get<String>('displayName');

  num get ratingBonus => _get<num>('ratingBonus') ?? 0;

  num get form => _get<num>('form') ?? 0;

  /// **THE MATCH NUMBER HE IS FREE AGAIN FOR**, or null for a player who is
  /// not suspended.
  ///
  /// A sending-off costs the next match as well as the rest of this one —
  /// asked for from the couch — and a ban is a fact about a FIXTURE rather than
  /// a duration: `matchesPlayed` at the moment of the red, plus one. Storing
  /// the target rather than a countdown means nothing has to remember to tick
  /// it down, and a save restored from the cloud mid-ban is still mid-ban.
  int? get suspendedUntilMatch => _get<num>('suspendedUntilMatch')?.toInt();

  /// Per-instance override of the definition's attack ratio.
  double? get attackRatio => _get<num>('attackRatio')?.toDouble();

  Object? get sponsor => raw['sponsor'];

  /// Persistent fitness, in rating points. Pro mode only.
  num? get energy => _get<num>('energy');

  /// Cannot take the field at all: at another club, or advertised for sale.
  ///
  /// Distinct from [injured] — that player is ours and here, just unfit. Every
  /// lineup filter used to check `injured` alone, which let a loaned-out player
  /// be auto-selected into the XI where the match engine rated them zero: a
  /// hole in the side that nothing on the Squad screen explained.
  bool get isUnavailable => listed || loanedOut != null;

  /// Ours, here, and fit enough to be picked.
  bool get isSelectable => !injured && !isUnavailable;

  /// The single source of truth for what a card is CALLED.
  ///
  /// Precedence: a player-set custom name, then the instance's rolled display
  /// name, then the definition's name, then [fallback]. Every user-facing
  /// surface reads through this, so a rename lands everywhere at once.
  ///
  /// A custom name is purely cosmetic — nothing here feeds rating, income,
  /// merge eligibility or sell value — and merging produces a brand-new
  /// instance, so the name is deliberately NOT inherited by the merged card.
  String name([String fallback = '']) {
    final custom = customName;
    if (custom != null && custom.isNotEmpty) return custom;
    final rolled = displayName;
    if (rolled != null && rolled.isNotEmpty) return rolled;
    return getPlayerDef(definitionId)?.name ?? fallback;
  }

  @override
  String toString() => 'CardInstance($instanceId, $definitionId)';
}
