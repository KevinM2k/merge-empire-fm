// Reference output from the JS event window helpers.
//
// The annual window resolves LOCAL wall-clock time, so these numbers are only
// comparable when both runtimes agree on the zone. Generated under TZ=UTC, and
// the Dart test skips itself unless it is running there too — the behavioural
// tests beside it hold in any zone, this one exists to pin the arithmetic.
//
//   TZ=UTC node tool/dump_event_window_reference.mjs > test/fixtures/event_window_reference.json

const {
  EVENTS,
  isInDateWindow,
  annualWindowOccurrences,
  currentAnnualWindow,
  nextAnnualWindow,
} = await import('../../merge-empire-fc/src/data/events.js');

const engine = await import('../../merge-empire-fc/src/engine/eventEngine.js');

const wc = EVENTS.find((e) => e.id === 'wc2026');
const ddl = EVENTS.find((e) => e.id === 'deadline_day');

const at = (iso) => Date.parse(iso);

// Instants chosen to land either side of every boundary the helpers have:
// before the preview window, inside it, inside the live window, after it, and
// across the December-to-January wrap that the ±1 year span exists for.
const PROBES = [
  '2026-01-01T12:00:00Z',
  '2026-01-01T18:30:00Z',
  '2026-01-01T19:30:00Z',
  '2026-01-31T18:00:00Z',
  '2026-02-01T18:30:00Z',
  '2026-05-01T00:00:00Z',
  '2026-05-13T00:00:00Z',
  '2026-06-11T00:00:00Z',
  '2026-07-01T00:00:00Z',
  '2026-07-19T23:59:59Z',
  '2026-07-20T00:00:01Z',
  '2026-08-15T18:30:00Z',
  '2026-12-20T00:00:00Z',
  '2026-12-27T00:00:00Z',
  '2027-01-05T18:30:00Z',
];

const out = { probes: PROBES, dateWindow: {}, annual: {}, phase: {} };

for (const iso of PROBES) {
  const nowMs = at(iso);
  out.dateWindow[iso] = isInDateWindow(wc.trigger, nowMs);
  const current = currentAnnualWindow(ddl.trigger, nowMs);
  const next = nextAnnualWindow(ddl.trigger, nowMs);
  out.annual[iso] = {
    occurrences: annualWindowOccurrences(ddl.trigger, nowMs).length,
    current: current ? { start: current.start, end: current.end } : null,
    next: next ? { start: next.start, end: next.end } : null,
  };
  out.phase[iso] = {
    wc: engine.eventPhase(wc, {}, nowMs),
    wcStartsIn: engine.eventStartsInMs(wc, nowMs),
    wcEndsAt: engine.eventEndsAtMs(wc, nowMs),
    ddl: engine.eventPhase(ddl, {}, nowMs),
    ddlStartsIn: engine.eventStartsInMs(ddl, nowMs),
    ddlEndsAt: engine.eventEndsAtMs(ddl, nowMs),
  };
}

// The full first-and-last of the occurrence list, so a drifting rollover shows
// up as a changed instant rather than merely a changed count.
const sample = annualWindowOccurrences(ddl.trigger, at('2026-06-01T00:00:00Z'));
out.occurrenceSample = {
  first: sample[0],
  last: sample[sample.length - 1],
  total: sample.length,
};

process.stdout.write(JSON.stringify(out));
