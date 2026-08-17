// The whole quest bank, flattened, from the JS.
//
// A 75-entry table of ids, divisions, tags, rewards and target curves is the
// easiest thing in the port to get subtly wrong — one mistyped tag welds two
// families together and a whole slot on the track quietly disappears. So every
// field is dumped, and every target curve is evaluated at all seven division
// indices rather than described.
//
//   node tool/dump_quest_bank_reference.mjs > test/fixtures/quest_bank_reference.json

const {
  QUEST_BANK,
  QUEST_ACTIONS,
  QUEST_TAGS,
  questTags,
  isDerived,
  resolveTarget,
  isEligible,
  STREAK_STATE_KEY,
  PER_MATCH_ACTIONS,
  MATCH_PACED_ACTIONS,
  MAX_ACTIONS,
  MATCH_QUEST_COUNT,
  SEASON_QUEST_COUNT,
  NO_REPEAT_WINDOW,
} = await import('../../merge-empire-fc/src/data/quests.js');

const DIV_COUNT = 7;

const quests = QUEST_BANK.map((q) => ({
  id: q.id,
  scope: q.scope,
  action: q.action,
  minDiv: q.minDiv,
  maxDiv: q.maxDiv ?? null,
  tags: q.tags ?? [],
  familySlots: questTags(q),
  coins: q.reward?.coins ?? 0,
  icon: q.icon,
  strategy: q.strategy ?? null,
  baseline: !!q.baseline,
  lift: q.lift ?? null,
  derived: isDerived(q),
  hasFeasible: typeof q.feasible === 'function',
  // Evaluated, not described.
  targets: Array.from({ length: DIV_COUNT }, (_, d) => resolveTarget(q, d)),
  eligible: Array.from({ length: DIV_COUNT }, (_, d) => isEligible(q, d)),
}));

process.stdout.write(JSON.stringify({
  quests,
  actions: QUEST_ACTIONS,
  tags: QUEST_TAGS,
  streakStateKey: STREAK_STATE_KEY,
  perMatchActions: [...PER_MATCH_ACTIONS],
  matchPacedActions: [...MATCH_PACED_ACTIONS],
  maxActions: [...MAX_ACTIONS],
  matchQuestCount: MATCH_QUEST_COUNT,
  seasonQuestCount: SEASON_QUEST_COUNT,
  noRepeatWindow: NO_REPEAT_WINDOW,
}));
