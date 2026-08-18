// Reference output from the JS Boot Room board.
//
// Every function here takes its randomness as an argument, so the whole file is
// reproducible: the draws below come from a mulberry32 the Dart side drives an
// identical copy of. What that pins is the ORDER of the draws as much as the
// results — `collapse` refills column by column, top-up cells counted upward,
// and a port that refills row-wise produces a board with exactly the same tile
// counts and none of the same tiles.
//
// The hand-authored boards are the other half. Cascades are easy to get right
// and L and T shapes are not: a cell in both a row run and a column run turns up
// in two groups, and clearing it twice is how a cross ends up dropping the wrong
// column.
//
//   node tool/dump_boot_room_reference.mjs > test/fixtures/boot_room_reference.json

const br = await import('../../merge-empire-fc/src/engine/bootRoomEngine.js');

// mulberry32, the same stream `test/support/js_math_random.dart` drives.
const makeRng = (seed) => {
  let a = seed;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

const out = {};

// ── Hand-authored boards ────────────────────────────────────────────────────
// 5 wide, 5 tall unless a case says otherwise. `null` is a hole, which the
// scanner has to treat as a run-breaker rather than as a type.
const BOARDS = {
  // A plain row of three across the middle.
  rowOfThree: [
    0, 1, 2, 0, 1,
    2, 3, 3, 3, 0,
    1, 2, 0, 1, 2,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // A column of three down the left.
  columnOfThree: [
    3, 1, 2, 0, 1,
    3, 2, 0, 1, 2,
    3, 1, 2, 0, 1,
    0, 2, 1, 2, 0,
    1, 0, 2, 1, 2,
  ],
  // A cross: the centre cell is in both runs and must clear once.
  crossShape: [
    0, 1, 4, 0, 1,
    2, 3, 4, 3, 0,
    4, 4, 4, 4, 4,
    0, 1, 4, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // An L: the corner is shared.
  lShape: [
    5, 1, 2, 0, 1,
    5, 2, 0, 1, 2,
    5, 5, 5, 0, 1,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // A run of five, which is one group and not two overlapping threes.
  runOfFive: [
    6, 6, 6, 6, 6,
    2, 3, 1, 3, 0,
    1, 2, 0, 1, 2,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // Two separate runs in the same row, split by one different tile.
  twoRunsOneRow: [
    7, 7, 7, 1, 7,
    2, 3, 1, 3, 0,
    1, 2, 0, 1, 2,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // Nothing matching — and no legal swap either, which is what makes it the
  // reshuffle trigger rather than merely a quiet board.
  settledButDead: [
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
    1, 2, 0, 1, 2,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // Holes: three nulls in a row are not a run.
  withHoles: [
    null, null, null, 0, 1,
    2, 0, 1, 2, 0,
    1, 2, 0, 1, 2,
    0, 1, 2, 0, 1,
    2, 0, 1, 2, 0,
  ],
  // Nothing matching, but a swap away from plenty. Named for the pattern rather
  // than for a verdict: a checkerboard LOOKS dead and is not.
  checkerboard: [
    0, 1, 0, 1, 0,
    1, 0, 1, 0, 1,
    0, 1, 0, 1, 0,
    1, 0, 1, 0, 1,
    0, 1, 0, 1, 0,
  ],
};

const COLS = 5;
const ROWS = 5;

out.boards = BOARDS;
out.cols = COLS;
out.rows = ROWS;

out.findMatches = {};
out.clearedCells = {};
for (const [label, board] of Object.entries(BOARDS)) {
  const groups = br.findMatches(board, COLS, ROWS);
  out.findMatches[label] = groups;
  out.clearedCells[label] = br.clearedCells(groups);
}

// ── Index maths ─────────────────────────────────────────────────────────────
out.indexing = [];
for (const [x, y] of [[0, 0], [4, 0], [0, 4], [3, 2], [4, 4]]) {
  const idx = br.idxOf(COLS, x, y);
  out.indexing.push({ x, y, idx, backX: br.xOf(COLS, idx), backY: br.yOf(COLS, idx) });
}

out.adjacent = [];
for (const [a, b] of [[0, 1], [1, 0], [0, 5], [0, 6], [0, 2], [4, 5], [12, 13], [12, 7], [12, 17], [3, 3]]) {
  out.adjacent.push({ a, b, adjacent: br.areAdjacent(COLS, a, b) });
}

// ── Collapse ────────────────────────────────────────────────────────────────
out.collapse = [];
for (const [label, cleared, seed, typeCount] of [
  ['rowOfThree', [6, 7, 8], 1, 4],
  ['columnOfThree', [0, 5, 10], 2, 4],
  ['crossShape', [2, 7, 10, 11, 12, 13, 14, 17], 3, 5],
  ['wholeColumn', [0, 5, 10, 15, 20], 4, 4],
  ['wholeBoard', Array.from({ length: 25 }, (_, i) => i), 5, 4],
  ['nothing', [], 6, 4],
]) {
  const board = BOARDS[label] ?? BOARDS.rowOfThree;
  const rng = makeRng(seed);
  out.collapse.push({ label, cleared, seed, typeCount, ...br.collapse(board, COLS, ROWS, cleared, typeCount, rng) });
}

// ── Resolve ─────────────────────────────────────────────────────────────────
out.resolve = [];
for (const [label, seed, typeCount] of [
  ['rowOfThree', 11, 4],
  ['crossShape', 12, 5],
  ['runOfFive', 13, 4],
  ['settledButDead', 14, 4],
  // Two types cascade forever-ish, which is what the guard is for.
  ['rowOfThree_twoTypes', 15, 2],
]) {
  const board = BOARDS[label.split('_')[0]];
  const rng = makeRng(seed);
  const r = br.resolve(board, COLS, ROWS, typeCount, rng);
  out.resolve.push({ label, seed, typeCount, ...r });
}

// ── Swaps ───────────────────────────────────────────────────────────────────
out.trySwap = [];
for (const [label, a, b] of [
  ['makesAMatch', 1, 6],
  ['matchesNothing', 0, 1],
  ['diagonal', 0, 6],
  ['distant', 0, 24],
  ['itself', 7, 7],
]) {
  out.trySwap.push({ label, a, b, board: br.trySwap(BOARDS.checkerboard, COLS, ROWS, a, b) });
}
// The same swap on a board with no legal move at all.
out.trySwapOnDeadBoard = br.trySwap(BOARDS.settledButDead, COLS, ROWS, 1, 6);
out.findMove = {};
out.hasAnyMove = {};
for (const [label, board] of Object.entries(BOARDS)) {
  out.findMove[label] = br.findMove(board, COLS, ROWS);
  out.hasAnyMove[label] = br.hasAnyMove(board, COLS, ROWS);
}

// ── Making a board ──────────────────────────────────────────────────────────
out.createBoard = [];
for (const [seed, cols, rows, typeCount] of [
  [21, 6, 6, 5],
  [22, 6, 6, 6],
  [23, 5, 5, 4],
  [24, 3, 3, 3],
  // Two types cannot settle at all: this is the give-up path.
  [25, 5, 5, 2],
  // One type is the degenerate case of that.
  [26, 4, 4, 1],
]) {
  const rng = makeRng(seed);
  const board = br.createBoard(cols, rows, typeCount, rng);
  out.createBoard.push({
    seed, cols, rows, typeCount, board,
    settled: br.findMatches(board, cols, rows).length === 0,
    playable: br.hasAnyMove(board, cols, rows),
  });
}

out.reshuffle = [];
for (const [label, board, seed, typeCount, cols, rows] of [
  ['deadBoard', BOARDS.settledButDead, 31, 4, COLS, ROWS],
  ['alreadyPlayable', BOARDS.checkerboard, 32, 4, COLS, ROWS],
  // A bag of one type can never make a move, so it falls through to a fresh
  // board — which is the only way the tiles change identity.
  ['oneTypeOnly', Array.from({ length: 25 }, () => 3), 33, 4, COLS, ROWS],
]) {
  const rng = makeRng(seed);
  const next = br.reshuffle(board, cols, rows, typeCount, rng);
  out.reshuffle.push({
    label, seed, typeCount, board: next,
    settled: br.findMatches(next, cols, rows).length === 0,
    playable: br.hasAnyMove(next, cols, rows),
    sameBag: [...board].sort().join() === [...next].sort().join(),
  });
}

process.stdout.write(JSON.stringify(out));
