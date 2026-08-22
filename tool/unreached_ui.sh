#!/usr/bin/env bash
#
# Every file in `lib/ui/` that NOTHING LIVE IMPORTS — the reachability check
# `tool/unreached.sh` structurally cannot make.
#
# That one sweeps `lib/engine`, `lib/data` and `lib/state` for public functions
# with no caller, so a dead SCREEN is invisible to it: a widget file's functions
# are called from inside the file itself, by its own `build`, and the whole
# island reads as busy. This asks the only question that catches an island —
# does any live Dart file import it.
#
#   bash tool/unreached_ui.sh           # the list
#   bash tool/unreached_ui.sh | wc -l   # the count
#
# Output is `file :: lines=N :: test-files=N :: round=N`.
#
# **`round=` is the whole point of the loop, and round 2 is where the bodies
# are.** A single pass finds a dead screen; it does NOT find what that screen
# was the last importer of. On the pass this was written for, one pass found
# `penalty_scene.dart` (313 lines) and stopped — while `keeper_figure.dart`, 768
# lines and FOURTEEN passing tests, looked alive because the dead scene imported
# it. So the sweep drops what it found and asks again, until a round finds
# nothing. Both went in the end, and only the loop gets the second one.
#
# **A high test-file count is the INTERESTING case, not the safe one**, same as
# the other sweep — a superseded screen that still passes its tests is the
# hardest kind to notice, and it is why `keeper_figure.dart` survived a rebuild
# that had already replaced it.
#
# **Read the result, do not act on it blind.** Three kinds of hit are expected
# and are not bugs:
#
#   - An entry point nothing imports BY DESIGN. `lib/main.dart` is outside this
#     sweep, but anything reached through a generated route table or a deferred
#     import would look the same.
#   - A file imported only by `test/` — ported and proven, waiting on the screen
#     that will show it. That is the queue's business, not a deletion.
#   - A widget kept deliberately as the one place a shape is defined, ahead of
#     the caller that will use it. `CLAUDE.md` is against shipping those, so
#     check the queue before assuming this one is deliberate.
#
# `test-files=` is what separates the last two from a genuine orphan: no live
# importer AND no test is a file nothing in the repo has an opinion about.
set -u

dead=$(mktemp)
round_out=$(mktemp)
trap 'rm -f "$dead" "$round_out"' EXIT

files=$(find lib/ui -name '*.dart' ! -name '*.g.dart' | sort)

round=0
while :; do
  round=$((round + 1))
  : >"$round_out"

  for f in $files; do
    grep -qxF "$f" "$dead" && continue
    base=$(basename "$f")
    # Package URIs are how every file in this repo imports; the basename pattern
    # keeps it honest if a relative import ever appears.
    # `lib/` only. A test importing a file is not reachability — the sibling
    # sweep's header says it in one line, "a green fixture test is not a caller",
    # and counting one here would have kept `keeper_figure.dart` alive on its own
    # fourteen tests after the only screen that drew it had gone.
    importers=$(grep -rl --include='*.dart' \
      -e "package:merge_empire_fc/${f#lib/}" \
      -e "'\(\.\./\)*[A-Za-z0-9_/]*$base'" \
      lib/ 2>/dev/null | grep -vx "$f" || true)
    # A file kept alive only by files already known dead is dead too. That is the
    # case a single pass misses, and it was the bigger half of the last one.
    live=$(echo "$importers" | grep -v '^$' | grep -vxF -f "$dead" 2>/dev/null || true)
    [ -n "$live" ] && continue

    tests=$(grep -rl --include='*.dart' "package:merge_empire_fc/${f#lib/}" test/ 2>/dev/null | wc -l)
    echo "$f :: lines=$(grep -c '' "$f") :: test-files=$tests :: round=$round"
    echo "$f" >>"$round_out"
  done

  [ -s "$round_out" ] || break
  cat "$round_out" >>"$dead"
done
