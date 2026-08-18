/// Boot Room — the match-3 board, as pure logic. Ported from
/// `../merge-empire-fc/src/engine/bootRoomEngine.js`.
///
/// No timers and no state of its own: the caller hands it a board and gets a new
/// one back.
///
/// Ported in spirit from the sister game's board model, cut down to what a
/// thirty-second mini-game needs — runs of three or more, gravity, refill,
/// cascades and a deadlock reshuffle. Deliberately LEFT OUT: 2x2 square matches,
/// caged blockers and the run-length power-ups. Those are what make the sister
/// game a full match; here they would be five extra rules on a board the player
/// looks at for half a minute.
///
/// Index convention: `idx = y * cols + x`, row 0 at the TOP, gravity pulling
/// toward increasing y. That is DOM order, so the UI can map cells to grid
/// children one for one without flipping anything.
///
/// Deliberately Flutter-free so it runs under plain `dart test`.
library;

import 'dart:math' as math;

final math.Random _rng = math.Random();

/// Mirrors JS `Math.random()` rather than the seeded gameplay stream: a
/// mini-game board is not part of anybody's match.
double _defaultRand() => _rng.nextDouble();

int idxOf(int cols, int x, int y) => y * cols + x;

int xOf(int cols, int idx) => idx % cols;

int yOf(int cols, int idx) => idx ~/ cols;

int _randType(int typeCount, double Function() rand) =>
    (rand() * typeCount).floor();

/// One run of three or more of a kind.
typedef MatchGroup = ({int type, bool horizontal, List<int> cells});

/// A tile that fell from one cell to another.
typedef TileMove = ({int from, int to});

/// A tile that arrived from off the top of the board. [height] counts upward, so
/// the renderer can stagger the drop.
typedef TileSpawn = ({int cell, int height});

/// Every run of three or more of one type, horizontal and vertical.
///
/// A cell in both a row run and a column run — an L or a T — turns up in two
/// groups. Callers dedupe through [clearedCells], which is what makes the cross
/// clear as one blob.
List<MatchGroup> findMatches(List<int?> board, int cols, int rows) {
  final groups = <MatchGroup>[];

  void scan(bool horizontal) {
    final outer = horizontal ? rows : cols;
    final inner = horizontal ? cols : rows;
    for (var o = 0; o < outer; o++) {
      var run = 1;
      for (var i = 1; i <= inner; i++) {
        int at(int k) => horizontal ? idxOf(cols, k, o) : idxOf(cols, o, k);
        final prevType = board[at(i - 1)];
        final same = i < inner && prevType != null && board[at(i)] == prevType;
        if (same) {
          run++;
          continue;
        }
        if (run >= 3 && prevType != null) {
          groups.add((
            type: prevType,
            horizontal: horizontal,
            cells: [for (var k = i - run; k < i; k++) at(k)],
          ));
        }
        run = 1;
      }
    }
  }

  scan(true);
  scan(false);
  return groups;
}

/// Every distinct cell covered by the given match groups.
List<int> clearedCells(List<MatchGroup> groups) {
  final seen = <int>{};
  final out = <int>[];
  for (final g in groups) {
    for (final cell in g.cells) {
      if (seen.add(cell)) out.add(cell);
    }
  }
  return out;
}

/// The result of one clear: a new board and the moves that animate it.
typedef Collapse = ({
  List<int?> board,
  List<TileMove> moves,
  List<TileSpawn> spawned,
});

/// Remove [cleared], drop every surviving tile in each column into the gaps, and
/// top the column back up from above.
///
/// `spawned` lists the cells filled from off the top of the board, so the UI can
/// drop them in rather than popping them into existence.
Collapse collapse(
  List<int?> board,
  int cols,
  int rows,
  List<int> cleared,
  int typeCount, [
  double Function()? rand,
]) {
  final draw = rand ?? _defaultRand;
  final next = [...board];
  final gone = cleared.toSet();
  final moves = <TileMove>[];
  final spawned = <TileSpawn>[];

  for (var x = 0; x < cols; x++) {
    // Walk the column bottom-up, packing survivors into the lowest free row.
    var write = rows - 1;
    for (var y = rows - 1; y >= 0; y--) {
      final from = idxOf(cols, x, y);
      if (gone.contains(from)) continue;
      final to = idxOf(cols, x, write);
      next[to] = board[from];
      if (to != from) moves.add((from: from, to: to));
      write--;
    }
    // Anything still unwritten is a fresh tile falling in from above.
    for (var y = write; y >= 0; y--) {
      final to = idxOf(cols, x, y);
      next[to] = _randType(typeCount, draw);
      spawned.add((cell: to, height: write - y + 1));
    }
  }

  return (board: next, moves: moves, spawned: spawned);
}

/// One cascade of a settle.
typedef ResolveStep = ({
  int cascade,
  List<MatchGroup> groups,
  List<int> cleared,
  List<TileMove> moves,
  List<TileSpawn> spawned,
  List<int?> board,
});

typedef Resolution = ({
  List<int?> board,
  List<ResolveStep> steps,
  int tilesCleared,
  int cascades,
});

/// Settle a board: clear, collapse, refill, repeat until nothing matches.
///
/// Each cascade comes back as its own step so the UI can play them in sequence —
/// watching the second and third clear land is the whole point of a match-3.
Resolution resolve(
  List<int?> board,
  int cols,
  int rows,
  int typeCount, [
  double Function()? rand,
]) {
  final draw = rand ?? _defaultRand;
  final steps = <ResolveStep>[];
  var current = [...board];

  // A settled board cannot cascade forever, but a bad draw should not be able to
  // hang the game loop either.
  for (var guard = 0; guard < 200; guard++) {
    final groups = findMatches(current, cols, rows);
    if (groups.isEmpty) break;
    final cleared = clearedCells(groups);
    final after = collapse(current, cols, rows, cleared, typeCount, draw);
    steps.add((
      cascade: steps.length + 1,
      groups: groups,
      cleared: cleared,
      moves: after.moves,
      spawned: after.spawned,
      board: after.board,
    ));
    current = after.board;
  }

  return (
    board: current,
    steps: steps,
    tilesCleared: steps.fold<int>(0, (n, s) => n + s.cleared.length),
    cascades: steps.length,
  );
}

/// True when the two cells share an edge. Diagonals are not swaps.
bool areAdjacent(int cols, int a, int b) {
  final dx = (xOf(cols, a) - xOf(cols, b)).abs();
  final dy = (yOf(cols, a) - yOf(cols, b)).abs();
  return dx + dy == 1;
}

/// The swap the player just made, if it is legal AND matches something.
///
/// Returns the swapped board, or null: a swap that matches nothing is reverted
/// and costs no move, the same as the sister game and the genre.
List<int?>? trySwap(List<int?> board, int cols, int rows, int a, int b) {
  if (!areAdjacent(cols, a, b)) return null;
  final next = [...board];
  next[a] = board[b];
  next[b] = board[a];
  return findMatches(next, cols, rows).isNotEmpty ? next : null;
}

/// The first swap that would match something — deadlock detection and the idle
/// hint in one function. Null when the board is dead.
({int a, int b})? findMove(List<int?> board, int cols, int rows) {
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final a = idxOf(cols, x, y);
      // Right and down only, so every edge is tested exactly once.
      if (x + 1 < cols) {
        final b = idxOf(cols, x + 1, y);
        if (trySwap(board, cols, rows, a, b) != null) return (a: a, b: b);
      }
      if (y + 1 < rows) {
        final b = idxOf(cols, x, y + 1);
        if (trySwap(board, cols, rows, a, b) != null) return (a: a, b: b);
      }
    }
  }
  return null;
}

bool hasAnyMove(List<int?> board, int cols, int rows) =>
    findMove(board, cols, rows) != null;

/// A board that is settled — nothing already matching — and playable.
List<int?> createBoard(
  int cols,
  int rows,
  int typeCount, [
  double Function()? rand,
]) {
  final draw = rand ?? _defaultRand;
  for (var attempt = 0; attempt < 60; attempt++) {
    final board = <int?>[
      for (var i = 0; i < cols * rows; i++) _randType(typeCount, draw),
    ];
    // Re-roll only the cells that match rather than the whole board — it settles
    // in a couple of passes instead of rejecting good boards wholesale.
    for (var pass = 0; pass < 40; pass++) {
      final groups = findMatches(board, cols, rows);
      if (groups.isEmpty) break;
      for (final cell in clearedCells(groups)) {
        board[cell] = _randType(typeCount, draw);
      }
    }
    if (findMatches(board, cols, rows).isEmpty &&
        hasAnyMove(board, cols, rows)) {
      return board;
    }
  }
  // Fewer than three types cannot produce a settled board at all. The caller's
  // difficulty curve never goes there, but do not spin forever if it does.
  return [for (var i = 0; i < cols * rows; i++) _randType(typeCount, draw)];
}

/// Deadlock recovery: keep the same tiles, rearrange them into a playable board.
///
/// Falls back to a fresh board when the bag itself cannot make a move — one type
/// left standing, say.
List<int?> reshuffle(
  List<int?> board,
  int cols,
  int rows,
  int typeCount, [
  double Function()? rand,
]) {
  final draw = rand ?? _defaultRand;
  for (var attempt = 0; attempt < 60; attempt++) {
    final next = [...board];
    for (var i = next.length - 1; i > 0; i--) {
      final j = (draw() * (i + 1)).floor();
      final tmp = next[i];
      next[i] = next[j];
      next[j] = tmp;
    }
    if (findMatches(next, cols, rows).isEmpty && hasAnyMove(next, cols, rows)) {
      return next;
    }
  }
  return createBoard(cols, rows, typeCount, draw);
}
