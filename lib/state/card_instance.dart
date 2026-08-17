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

  @override
  String toString() => 'CardInstance($instanceId, $definitionId)';
}
