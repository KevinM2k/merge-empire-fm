/// Limited-time content — the International Cup, Deadline Day, and whatever
/// comes next. Ported from `../merge-empire-fc/src/data/events.js`.
///
/// Each event carries a `trigger` that says WHEN it runs, so the same engine
/// handles a real-world calendar event and an in-game one. The JS models the
/// trigger as a discriminated object; here it is a small sealed hierarchy,
/// which is the same idea with the compiler checking the dispatch.
///
/// Deliberately Flutter-free so it runs under plain `dart test`. The theme
/// palettes stay as the strings the JS wrote them in — the UI layer translates
/// them, and re-deriving the colours here would only invite drift.
library;

import 'dart:math' as math;

/// When an event runs.
sealed class EventTrigger {
  const EventTrigger({this.previewDays = 0});

  /// How many days before the window opens a countdown banner appears.
  final int previewDays;
}

/// One calendar slot, with the year pinned. Right for a one-off.
class DateWindowTrigger extends EventTrigger {
  const DateWindowTrigger({
    required this.start,
    required this.end,
    super.previewDays,
  });

  /// ISO 8601, as written in the catalogue.
  final String start;
  final String end;

  int? get startMs => DateTime.tryParse(start)?.millisecondsSinceEpoch;
  int? get endMs => DateTime.tryParse(end)?.millisecondsSinceEpoch;
}

/// A month and day the window opens on, repeated every year.
typedef AnnualSlot = ({int month, int day, int hour});

/// A recurring calendar slot — the same month and day every year.
///
/// A [DateWindowTrigger] pins one slot with a hardcoded year, which is fine for
/// a one-off but useless for anything that has to come back. This repeats
/// forever: it stores month/day/hour rather than a full date, so the same
/// definition fires in 2026, 2027, 2028 with no code change.
///
/// [slots] use a 1-based month (8 = August) because these are written by hand
/// and a 0-based month in data is a reliable source of off-by-one bugs.
class AnnualWindowTrigger extends EventTrigger {
  const AnnualWindowTrigger({
    required this.slots,
    this.days = 1,
    this.startHour,
    this.durationMinutes = 60,
    this.durationHours = 24,
    super.previewDays,
  });

  final List<AnnualSlot> slots;

  /// Consecutive days the event runs for.
  final int days;

  /// The hour it opens each of those days, LOCAL. Null selects the older
  /// whole-day form, which uses [durationHours] instead.
  final int? startHour;

  final int durationMinutes;
  final int durationHours;

  /// A daily appointment beats the whole-day form.
  bool get isDaily => startHour != null;

  int get durationMs => isDaily
      ? durationMinutes * 60 * 1000
      : durationHours * 60 * 60 * 1000;
}

/// One challenge inside an event.
class EventChallenge {
  const EventChallenge({
    required this.id,
    required this.type,
    required this.target,
    required this.rewardMult,
    required this.text,
    required this.icon,
    this.points = 0,
  });

  final String id;

  /// The action type this counts. Matches what the action funnel sends.
  final String type;
  final int target;

  /// The multiplier on the player's current division `matchRevenueBase`, so a
  /// headline payout scales with progression rather than going stale.
  final num rewardMult;
  final String text;
  final String icon;

  /// Score added to the event track when this completes.
  final int points;
}

/// What a reward tier hands over.
typedef EventReward = ({num coins, int trophies, int energy, bool freeScout});

const EventReward noReward = (coins: 0, trophies: 0, energy: 0, freeScout: false);

/// A milestone the player claims as their score accrues.
class RewardTier {
  const RewardTier({required this.score, required this.reward});

  final int score;
  final EventReward reward;
}

/// The decoration an event drops on the screen while it runs. Purely cosmetic.
class EventTheme {
  const EventTheme({
    this.palette = const {},
    this.bgGradient,
    this.buntingFlags = const [],
    this.accentBorder,
    this.headerEmoji,
  });

  /// A bag of colour tokens the UI layer reads. Left as the strings the JS
  /// wrote so the two versions can be compared token for token.
  final Map<String, String> palette;
  final String? bgGradient;
  final List<String> buntingFlags;
  final String? accentBorder;
  final String? headerEmoji;
}

/// The bracket configuration for an event cup.
class EventCupConfig {
  const EventCupConfig({
    required this.rounds,
    required this.opponentRatingBump,
    required this.winBountyMult,
    required this.opponentPool,
    required this.nationRatings,
    required this.flags,
    required this.nationColors,
    this.nationFactCount = 0,
  });

  final List<String> rounds;

  /// Legacy fallback for a player who skipped the nation picker; the live path
  /// uses [nationRatings].
  final List<int> opponentRatingBump;

  /// Applied to the player's current division `matchRevenueBase`. Only the
  /// winner is paid — there are no per-round payouts.
  final num winBountyMult;

  /// Every nation in the tournament. The player leads one; the rest are the
  /// opponent pool.
  final List<String> opponentPool;

  /// Used directly as the side's match rating, so your club squad does not
  /// carry over — you ARE the nation. Picking Argentina gives you an
  /// Argentina-strength side; picking Haiti gives you the underdog run.
  final Map<String, int> nationRatings;

  final Map<String, String> flags;

  /// The main colour for each nation's player dots on the cutaway — the flag's
  /// primary colour, brightened where the real shade would vanish against the
  /// dark pitch. Green is avoided (pitch camouflage), with Mexico the one
  /// exception; nations whose identity is green fall back to a white change kit.
  final Map<String, String> nationColors;

  /// Coach-card facts are fully translated, so only the count lives here.
  final int nationFactCount;
}

/// A permanent trophy an event win adds to the trophy room.
typedef EventTrophy = ({String name, bool cup, bool event, String eventId});

/// The cosmetics an event offers while it is live.
class EventCosmetic {
  const EventCosmetic({this.kitPreset, this.trophy});

  final String? kitPreset;
  final EventTrophy? trophy;
}

/// One event in the catalogue.
class EventDef {
  const EventDef({
    required this.id,
    required this.name,
    required this.nameKey,
    required this.shortName,
    required this.flavour,
    required this.flavourKey,
    required this.color,
    required this.trigger,
    this.mechanics = const [],
    this.cupConfig,
    this.challengeConfig = const [],
    this.rewardTrack = const [],
    this.theme = const EventTheme(),
    this.cosmetic,
  });

  final String id;

  /// English fallbacks — the UI prefers the translation keys beside them.
  final String name;
  final String nameKey;
  final String shortName;
  final String flavour;
  final String flavourKey;
  final String color;

  final EventTrigger trigger;

  /// Which sub-tabs the event screen shows: `cup`, `challenges`, `shop`,
  /// `cosmetic`, `deadlineDay`.
  final List<String> mechanics;

  final EventCupConfig? cupConfig;
  final List<EventChallenge> challengeConfig;
  final List<RewardTier> rewardTrack;
  final EventTheme theme;
  final EventCosmetic? cosmetic;
}

const List<EventDef> events = [
  // DORMANT. Its window closed on 19 July 2026, so this permanently reports
  // `ended` and nothing here runs any more. It is kept whole rather than
  // deleted because the slot is going to be reused for a different event —
  // when that happens the id, name, dates and nation tables all change
  // together, and what is worth keeping is the SHAPE: a bracket event with a
  // pickable side, per-side ratings and colours, and lifetime challenges. Its
  // tests still pass and should keep passing; they are the specification for
  // whatever takes its place.
  EventDef(
    id: 'wc2026',
    name: 'International Cup 2026',
    nameKey: 'event.wc.name',
    shortName: 'WC',
    flavour: "The world's biggest stage. 16 nations. One trophy.",
    flavourKey: 'event.wc.flavour',
    color: '#ffd700',
    trigger: DateWindowTrigger(
      start: '2026-06-11T00:00:00Z',
      end: '2026-07-19T23:59:59Z',
      previewDays: 30,
    ),
    mechanics: ['cup', 'challenges', 'cosmetic'],
    cupConfig: EventCupConfig(
      // Four rounds — one more than the regular cup pyramid, so the run feels
      // deeper. Tuned tough: the Final should want a Champions-level side.
      rounds: ['Round of 16', 'Quarter-Final', 'Semi-Final', 'Final'],
      opponentRatingBump: [6, 12, 20, 32],
      // 30× → about 3k coins at Sunday League, about 3.6M at Champions.
      winBountyMult: 30,
      opponentPool: [
        // CONCACAF hosts
        'USA', 'Canada', 'Mexico',
        // CONMEBOL
        'Argentina', 'Brazil', 'Uruguay', 'Colombia', 'Ecuador', 'Paraguay',
        // UEFA
        'France', 'England', 'Spain', 'Germany', 'Portugal', 'Netherlands',
        'Belgium', 'Croatia', 'Switzerland', 'Austria', 'Norway', 'Türkiye',
        'Czechia', 'Scotland', 'Bosnia and Herzegovina', 'Sweden',
        // CAF
        'Morocco', 'Senegal', 'Tunisia', 'Algeria', 'Egypt',
        "Côte d'Ivoire", 'Ghana', 'DR Congo', 'Cape Verde', 'South Africa',
        // AFC
        'Japan', 'South Korea', 'Iran', 'Australia', 'Saudi Arabia',
        'Uzbekistan', 'Jordan', 'Iraq', 'Qatar',
        // CONCACAF (non-host)
        'Panama', 'Curaçao', 'Haiti',
        // OFC
        'New Zealand',
      ],
      nationRatings: {
        // Perennial favourites
        'Argentina': 91, 'France': 90, 'Spain': 89, 'Brazil': 88, 'England': 88,
        // Strong contenders
        'Portugal': 86, 'Netherlands': 85, 'Belgium': 84, 'Germany': 84,
        'Croatia': 83, 'Uruguay': 83, 'Colombia': 82, 'Morocco': 82,
        'Switzerland': 81,
        // Mid-tier, dangerous
        'Sweden': 76, 'Mexico': 78, 'USA': 77, 'Senegal': 78, 'Japan': 78,
        'Austria': 77, 'Türkiye': 76, 'Iran': 76, 'South Korea': 76,
        'Australia': 75, 'Egypt': 75, 'Algeria': 74, 'Ecuador': 74,
        'Norway': 78,
        // Workmanlike
        'Bosnia and Herzegovina': 71, 'Czechia': 72, 'Tunisia': 72, 'Qatar': 68,
        "Côte d'Ivoire": 73, 'Paraguay': 71, 'Canada': 73, 'Saudi Arabia': 70,
        'Uzbekistan': 69, 'Iraq': 68, 'Panama': 69, 'Scotland': 73,
        // Underdogs — picking one of these is the hardest run in the game
        'Ghana': 68, 'Jordan': 67, 'South Africa': 66, 'Cape Verde': 65,
        'DR Congo': 67, 'New Zealand': 65, 'Curaçao': 63, 'Haiti': 62,
      },
      flags: {
        'USA': '🇺🇸', 'Canada': '🇨🇦', 'Mexico': '🇲🇽',
        'Argentina': '🇦🇷', 'Brazil': '🇧🇷', 'Uruguay': '🇺🇾',
        'Colombia': '🇨🇴', 'Ecuador': '🇪🇨', 'Paraguay': '🇵🇾',
        'France': '🇫🇷', 'England': '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 'Spain': '🇪🇸', 'Germany': '🇩🇪',
        'Portugal': '🇵🇹', 'Netherlands': '🇳🇱', 'Belgium': '🇧🇪',
        'Croatia': '🇭🇷', 'Switzerland': '🇨🇭', 'Austria': '🇦🇹',
        'Norway': '🇳🇴', 'Türkiye': '🇹🇷', 'Czechia': '🇨🇿',
        'Scotland': '🏴󠁧󠁢󠁳󠁣󠁴󠁿', 'Bosnia and Herzegovina': '🇧🇦', 'Sweden': '🇸🇪',
        'Morocco': '🇲🇦', 'Senegal': '🇸🇳', 'Tunisia': '🇹🇳', 'Algeria': '🇩🇿',
        'Egypt': '🇪🇬', "Côte d'Ivoire": '🇨🇮', 'Ghana': '🇬🇭',
        'DR Congo': '🇨🇩', 'Cape Verde': '🇨🇻', 'South Africa': '🇿🇦',
        'Japan': '🇯🇵', 'South Korea': '🇰🇷', 'Iran': '🇮🇷', 'Australia': '🇦🇺',
        'Saudi Arabia': '🇸🇦', 'Uzbekistan': '🇺🇿', 'Jordan': '🇯🇴',
        'Iraq': '🇮🇶', 'Qatar': '🇶🇦',
        'Panama': '🇵🇦', 'Curaçao': '🇨🇼', 'Haiti': '🇭🇹',
        'New Zealand': '🇳🇿',
      },
      nationColors: {
        'USA': '#4169b3', 'Canada': '#e4002b', 'Mexico': '#00b25b',
        'Argentina': '#75aadb', 'Brazil': '#ffdf00', 'Uruguay': '#5cb8e6',
        'Colombia': '#fcd116', 'Ecuador': '#ffd100', 'Paraguay': '#d52b1e',
        'France': '#3b6fd4', 'England': '#ffffff', 'Spain': '#c60b1e',
        'Germany': '#ffce00', 'Portugal': '#da291c', 'Netherlands': '#ff7f00',
        'Belgium': '#ed2939', 'Croatia': '#e34234', 'Switzerland': '#e60026',
        'Austria': '#ef3340', 'Norway': '#d81e3f', 'Türkiye': '#e30a17',
        'Czechia': '#3d7edb', 'Scotland': '#0065bd',
        'Bosnia and Herzegovina': '#ffcc00', 'Sweden': '#ffcd00',
        'Morocco': '#c1272d', 'Senegal': '#fdef42', 'Tunisia': '#e70013',
        'Algeria': '#ffffff', 'Egypt': '#ce1126', "Côte d'Ivoire": '#f77f00',
        'Ghana': '#fcd116', 'DR Congo': '#007fff', 'Cape Verde': '#3d6fd0',
        'South Africa': '#ffb612',
        'Japan': '#4169e1', 'South Korea': '#cd2e3a', 'Iran': '#ffffff',
        'Australia': '#ffcd00', 'Saudi Arabia': '#ffffff',
        'Uzbekistan': '#0099b5', 'Jordan': '#ce1126', 'Iraq': '#a91d2a',
        'Qatar': '#8a1538',
        'Panama': '#da121a', 'Curaçao': '#4f86e0', 'Haiti': '#2a48c4',
        'New Zealand': '#ffffff',
      },
      nationFactCount: 3,
    ),
    challengeConfig: [
      // Lifetime achievements — each fires once when its condition is met. The
      // event cup emits one of several win types depending on the nation's
      // rating and whether the run was a shutout.
      EventChallenge(
        id: 'wc_first_win',
        type: 'event_cup_won',
        target: 1,
        rewardMult: 5,
        text: 'Win the International Cup',
        icon: '🏆',
      ),
      EventChallenge(
        id: 'wc_won_5',
        type: 'event_cup_won',
        target: 5,
        rewardMult: 25,
        text: 'Win the International Cup 5 times',
        icon: '🏅',
      ),
      EventChallenge(
        id: 'wc_won_10',
        type: 'event_cup_won',
        target: 10,
        rewardMult: 80,
        text: 'Win the International Cup 10 times',
        icon: '👑',
      ),
      // 40 rather than 20: the win-probability exponent moved 2.5 → 4.0, which
      // made an underdog bracket run roughly twice as rare (about 1 in 110).
      EventChallenge(
        id: 'wc_won_underdog',
        type: 'event_cup_won_underdog',
        target: 1,
        rewardMult: 40,
        text: 'Win with the worst-rated nation (Haiti)',
        icon: '🐺',
      ),
      EventChallenge(
        id: 'wc_won_favourite',
        type: 'event_cup_won_favourite',
        target: 1,
        rewardMult: 8,
        text: 'Win with the top-rated nation (Argentina)',
        icon: '⭐',
      ),
      EventChallenge(
        id: 'wc_won_clean',
        type: 'event_cup_won_clean',
        target: 1,
        rewardMult: 15,
        text: 'Win without conceding a single goal',
        icon: '🧱',
      ),
    ],
    // No reward track — the only prize is the trophy and the coin bounty for
    // winning the bracket.
    theme: EventTheme(
      palette: {
        'bg': '#0c0820', 'surface': '#15103a', 'surface2': '#1d1750',
        'border': '#3a2c8a', 'text': '#fff7e1', 'textMuted': '#a89dd4',
        'accent': '#ffd700', 'accentBright': '#ffe14a', 'accentDark': '#d4af37',
        'accentInk': '#1a0d4a', 'accentRgb': '255,215,0',
        'chromeTop': '#14094a', 'chromeBottom': '#0a0420',
        'glowA': 'rgba(255,215,0,0.18)', 'glowB': 'rgba(220,40,80,0.22)',
      },
      bgGradient:
          'linear-gradient(180deg, rgba(255,215,0,0.10) 0%, rgba(123,47,190,0.06) 60%, transparent 100%)',
      buntingFlags: [
        '🇺🇸', '🇨🇦', '🇲🇽', '🇧🇷', '🇦🇷', '🇫🇷', '🇪🇸', '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
        '🇩🇪', '🇵🇹', '🇳🇱', '🇯🇵', '🇲🇦', '🇸🇳', '🇰🇷', '🇭🇷',
      ],
      accentBorder: '#ffd700',
      headerEmoji: '🏆',
    ),
    cosmetic: EventCosmetic(
      kitPreset: '#ffd700',
      // The player's nation is appended at render time — "International Cup
      // 2026 Winners — England".
      trophy: (
        name: 'International Cup 2026 Winners',
        cup: true,
        event: true,
        eventId: 'wc2026',
      ),
    ),
  ),

  EventDef(
    id: 'deadline_day',
    name: 'Transfer Deadline Day',
    nameKey: 'event.deadline.name',
    shortName: 'DDL',
    flavour: 'The window shuts at midnight. Get your business done.',
    flavourKey: 'event.deadline.flavour',
    // Ticker yellow — the one colour this event has to be.
    color: '#ffdd00',
    // Recurring, not a one-off: it fires every year with no code change. It
    // runs for the whole of both transfer months, but as a nightly APPOINTMENT
    // rather than an all-day window — 6pm local for an hour, every night. An
    // appointment you can miss is what makes a live event feel live, and 6pm is
    // when people are off the train rather than at work.
    //
    // Both windows are 31-day months on purpose: on a shorter one the date
    // arithmetic rolls the tail over into the next month rather than stopping.
    trigger: AnnualWindowTrigger(
      slots: [
        (month: 1, day: 1, hour: 0), // winter window — all of January
        (month: 8, day: 1, hour: 0), // summer window — all of August
      ],
      days: 31,
      startHour: 18,
      durationMinutes: 60,
      previewDays: 7,
    ),
    mechanics: ['deadlineDay'],
    // Session tuning lives in the deadline-day data, not here — the catalogue
    // entry only decides WHEN the event runs; the engine decides how it plays.
    //
    // NO palette, deliberately. The International Cup repaints the whole app
    // because it IS a different competition for a month; Deadline Day is a
    // transfer window in your own season, and dressing it up as a separate game
    // made it read as somewhere else. Without a palette the screen inherits the
    // main game's colours, and the per-listing colours still carry meaning.
    theme: EventTheme(headerEmoji: '📰'),
  ),
];

/// The catalogue as the rest of the app sees it.
///
/// Normally [events], but [debugSetEvents] can swap it. Neither shipped event
/// carries a reward track, so without an override the whole tier-claiming path
/// would be untestable — and the dormant slot above is going to be reused by
/// something that may well want one.
List<EventDef> _catalogue = events;
Map<String, EventDef> _byId = {for (final e in events) e.id: e};

/// Replace the catalogue, or pass null to restore it.
///
/// For tests only. Nothing in the app calls this; the catalogue is a constant
/// and the app has no reason to change it at runtime.
void debugSetEvents(List<EventDef>? replacement) {
  _catalogue = replacement ?? events;
  _byId = {for (final e in _catalogue) e.id: e};
  clearAnnualWindowCache();
}

/// Every event the app currently knows about.
List<EventDef> get eventCatalogue => _catalogue;

EventDef? getEventById(String? id) => id == null ? null : _byId[id];

/// Does [nowMs] fall inside this fixed window?
bool isInDateWindow(EventTrigger? trigger, int nowMs) {
  if (trigger is! DateWindowTrigger) return false;
  final start = trigger.startMs;
  final end = trigger.endMs;
  if (start == null || end == null) return false;
  return nowMs >= start && nowMs <= end;
}

/// One occurrence of a recurring window.
typedef AnnualOccurrence = ({int start, int end});

final Map<String, List<AnnualOccurrence>> _occurrenceCache = {};

/// Every occurrence of [trigger] in the years either side of [nowMs], sorted by
/// start.
///
/// The ±1 year span is what makes a December-to-February wrap work: on 20
/// December 2026 the next January occurrence lives in 2027, so it has to be in
/// the candidate set to be found at all.
///
/// Memoised, because this is not as small as it looks — Deadline Day is two
/// 31-day windows over three years, so a cold call builds 186 instants and
/// sorts them, and the phase check alone asks twice on every render and every
/// idle tick. The result depends only on the trigger and the year the span is
/// centred on; the timezone offset rides along in the key so a device that
/// changes zone mid-session recomputes rather than keeping its windows at the
/// old wall-clock time. The list is unmodifiable, since it is shared: a caller
/// that sorted or spliced it would poison every later reader.
List<AnnualOccurrence> annualWindowOccurrences(
  EventTrigger? trigger,
  int nowMs,
) {
  if (trigger is! AnnualWindowTrigger) return const [];

  final asOf = DateTime.fromMillisecondsSinceEpoch(nowMs);
  final key = '${_triggerKey(trigger)}|${asOf.year}|'
      '${asOf.timeZoneOffset.inMinutes}';
  final cached = _occurrenceCache[key];
  if (cached != null) return cached;

  final days = math.max(1, trigger.days);
  final durationMs = trigger.durationMs;
  final baseYear = asOf.year;
  final out = <AnnualOccurrence>[];

  for (final slot in trigger.slots) {
    for (final year in [baseYear - 1, baseYear, baseYear + 1]) {
      for (var d = 0; d < days; d++) {
        // LOCAL, not UTC. "6pm" has to mean 6pm where the player is — a UTC
        // window would open at breakfast for half the world. Building a local
        // DateTime also rolls the month and year over on a multi-day event, and
        // lands on the right instant across a daylight-saving change, because
        // it resolves wall-clock time rather than an offset from the epoch.
        final start = DateTime(
          year,
          slot.month,
          slot.day + d,
          trigger.isDaily ? trigger.startHour! : slot.hour,
        ).millisecondsSinceEpoch;
        out.add((start: start, end: start + durationMs));
      }
    }
  }

  out.sort((a, b) => a.start - b.start);
  final frozen = List<AnnualOccurrence>.unmodifiable(out);
  _occurrenceCache[key] = frozen;
  return frozen;
}

String _triggerKey(AnnualWindowTrigger t) =>
    '${t.slots.map((s) => '${s.month}.${s.day}.${s.hour}').join(',')}'
    '|${t.days}|${t.startHour}|${t.durationMinutes}|${t.durationHours}';

/// Drop the memoised occurrences. Tests use it when they move the clock across
/// a year boundary; the app never needs it.
void clearAnnualWindowCache() => _occurrenceCache.clear();

/// The occurrence containing [nowMs], or null when the event isn't live.
AnnualOccurrence? currentAnnualWindow(EventTrigger? trigger, int nowMs) {
  for (final o in annualWindowOccurrences(trigger, nowMs)) {
    if (nowMs >= o.start && nowMs <= o.end) return o;
  }
  return null;
}

/// The soonest occurrence that hasn't started yet, or null.
AnnualOccurrence? nextAnnualWindow(EventTrigger? trigger, int nowMs) {
  for (final o in annualWindowOccurrences(trigger, nowMs)) {
    if (o.start > nowMs) return o;
  }
  return null;
}

/// True while [nowMs] sits inside one of the recurring windows.
bool isInAnnualWindow(EventTrigger? trigger, int nowMs) =>
    currentAnnualWindow(trigger, nowMs) != null;
