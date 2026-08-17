/// Sponsor companies, ported from
/// `../merge-empire-fc/src/data/sponsors.js`.
///
/// Each carries an income multiplier PLUS a concrete drawback stored on the
/// card itself, so the numbers actually bite:
///
///   ratingPenalty  percentage of the card's base rating subtracted from its
///                  effective rating (20 means -20% of def.rating)
///   injuryPenalty  added to the per-player injury chance each match, in
///                  absolute points (0.03 means +3%)
///   formPenalty    applied once at signing as a permanent form debuff
///
/// A mix of safe small deals and risky high-payout ones. IDs are stable —
/// existing saves reference `metatech`, `greenpower`, `fastfood`. Don't rename,
/// only add.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

class SponsorDrawback {
  const SponsorDrawback({
    required this.ratingPenalty,
    required this.injuryPenalty,
    required this.formPenalty,
    required this.msg,
  });

  final int ratingPenalty;
  final double injuryPenalty;
  final int formPenalty;

  /// The coach's read on the deal, shown on the offer card.
  final String msg;

  bool get isClean =>
      ratingPenalty == 0 && injuryPenalty == 0 && formPenalty == 0;
}

class Company {
  const Company({
    required this.id,
    required this.name,
    required this.icon,
    required this.mult,
    required this.drawback,
  });

  final String id;
  final String name;
  final String icon;

  /// Multiplier on the card's idle income while the deal runs.
  final double mult;

  final SponsorDrawback drawback;
}

const List<Company> companies = [
  // ── Safe: small boost, no drawback ────────────────────────────────────────
  Company(
    id: 'greenpower', name: 'GreenPower', icon: '🌱', mult: 1.25,
    drawback: SponsorDrawback(
      ratingPenalty: 0, injuryPenalty: 0, formPenalty: 0,
      msg: "Clean brand, clean deal — I'd take this one. Steady money, no catch.",
    ),
  ),
  Company(
    id: 'localbakery', name: 'Crusty Loaves', icon: '🥐', mult: 1.15,
    drawback: SponsorDrawback(
      ratingPenalty: 0, injuryPenalty: 0, formPenalty: 0,
      msg: 'Small cheque but zero strings attached — always worth saying yes.',
    ),
  ),
  Company(
    id: 'purawater', name: 'PuraWater', icon: '💧', mult: 1.20,
    drawback: SponsorDrawback(
      ratingPenalty: 0, injuryPenalty: 0, formPenalty: 0,
      msg: "Easy yes — no media circus, nothing that'll hurt them on the pitch.",
    ),
  ),
  Company(
    id: 'farmfresh', name: 'FarmFresh', icon: '🥕', mult: 1.30,
    drawback: SponsorDrawback(
      ratingPenalty: 3, injuryPenalty: 0, formPenalty: 4,
      msg:
          'Endless rural photoshoots and muddy field events — form tanks badly and they lose their edge on the pitch.',
    ),
  ),

  // ── Mild: mid boost, one small cost ───────────────────────────────────────
  Company(
    id: 'metatech', name: 'MetaTech', icon: '🔋', mult: 1.50,
    drawback: SponsorDrawback(
      ratingPenalty: 5, injuryPenalty: 0, formPenalty: 3,
      msg:
          'Big-tech contracts mean product launches, all-nighters testing kit — rating drops noticeably and form suffers. Think twice.',
    ),
  ),
  Company(
    id: 'sparkpad', name: 'SparkPad', icon: '📱', mult: 1.40,
    drawback: SponsorDrawback(
      ratingPenalty: 1, injuryPenalty: 0, formPenalty: 0,
      msg: 'Content shoots eat into training — rating drops a little. Manageable.',
    ),
  ),
  Company(
    id: 'stayfit', name: 'StayFit Gym', icon: '🏋️', mult: 1.45,
    drawback: SponsorDrawback(
      ratingPenalty: 0, injuryPenalty: 0.01, formPenalty: 0,
      msg:
          "Branded workouts look great, but they'll push too hard — watch for niggling injuries.",
    ),
  ),
  Company(
    id: 'speedywheels', name: 'Speedy Wheels', icon: '🏎️', mult: 1.55,
    drawback: SponsorDrawback(
      ratingPenalty: 4, injuryPenalty: 0.03, formPenalty: 1,
      msg:
          'Fast cars and late nights at launch events — rating drops, focus goes, and knocks pile up. The lifestyle shows on matchday.',
    ),
  ),
  Company(
    id: 'voltron', name: 'Voltron Energy', icon: '⚡', mult: 1.60,
    drawback: SponsorDrawback(
      ratingPenalty: 1, injuryPenalty: 0.01, formPenalty: 0,
      msg:
          'Energy drinks are double-edged — the buzz fades, rating drops and injuries creep in. Think twice.',
    ),
  ),
  Company(
    id: 'nightowl', name: 'NightOwl Games', icon: '🎮', mult: 1.55,
    drawback: SponsorDrawback(
      ratingPenalty: 5, injuryPenalty: 0.02, formPenalty: 2,
      msg:
          'Streaming deals keep them up till 3am — rating drops, fatigue creeps in, and form suffers fast.',
    ),
  ),

  // ── Spicy: big boost, noticeable drawback ─────────────────────────────────
  Company(
    id: 'fastfood', name: 'BurgerKing', icon: '🍔', mult: 2.00,
    drawback: SponsorDrawback(
      ratingPenalty: 8, injuryPenalty: 0.05, formPenalty: 0,
      msg:
          'Fast-food diet shows up fast — rating tanks, knocks pile up. Tempting cash though.',
    ),
  ),
  Company(
    id: 'pizzaprince', name: 'Pizza Prince', icon: '🍕', mult: 1.85,
    drawback: SponsorDrawback(
      ratingPenalty: 6, injuryPenalty: 0.06, formPenalty: 0,
      msg:
          'Pizza and late dinners at every event — injuries jump and sharpness dies. Careful.',
    ),
  ),
  Company(
    id: 'rockstar', name: 'Rockstar Energy', icon: '🥤', mult: 1.95,
    drawback: SponsorDrawback(
      ratingPenalty: 7, injuryPenalty: 0.04, formPenalty: 1,
      msg:
          'Rockstar lifestyle — rating drops off a cliff, niggles pile up. Full-package headache.',
    ),
  ),
  Company(
    id: 'casinoroyal', name: 'Casino Royale', icon: '🎰', mult: 2.10,
    drawback: SponsorDrawback(
      ratingPenalty: 10, injuryPenalty: 0.02, formPenalty: 2,
      msg:
          'Late nights at the tables wreck them — rating plummets, form collapses. Costly deal.',
    ),
  ),
  Company(
    id: 'vegasnights', name: 'Vegas Nights', icon: '🎲', mult: 2.20,
    drawback: SponsorDrawback(
      ratingPenalty: 12, injuryPenalty: 0.05, formPenalty: 2,
      msg:
          'Vegas will burn them out — rating dives hard, knocks pile up. Big payday, rough Saturdays.',
    ),
  ),

  // ── Reckless: top boost, hefty cost ───────────────────────────────────────
  Company(
    id: 'speedybets', name: 'Speedy Bets', icon: '🎯', mult: 2.30,
    drawback: SponsorDrawback(
      ratingPenalty: 15, injuryPenalty: 0.02, formPenalty: 0,
      msg:
          'Betting-shop money is huge but the scrutiny is brutal — rating takes a massive hit.',
    ),
  ),
  Company(
    id: 'megacarbs', name: 'MegaCarbs', icon: '🍩', mult: 2.50,
    drawback: SponsorDrawback(
      ratingPenalty: 17, injuryPenalty: 0.08, formPenalty: 0,
      msg:
          'Doughnuts and pastries at every event — rating collapses, injuries spike hard.',
    ),
  ),
  Company(
    id: 'dangerdrinks', name: 'Danger Drinks', icon: '☠️', mult: 3.00,
    drawback: SponsorDrawback(
      ratingPenalty: 20, injuryPenalty: 0.10, formPenalty: 1,
      msg:
          "I'd walk away. Triple money, but body, form and reputation ALL get hammered. This breaks careers.",
    ),
  ),
];

final Map<String, Company> _byId = {for (final c in companies) c.id: c};

Company? getCompany(String? id) => id == null ? null : _byId[id];
