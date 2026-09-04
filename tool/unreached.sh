#!/usr/bin/env bash
#
# Every public top-level function in the pure-Dart half that NOTHING IN `lib/`
# names apart from its own declaration.
#
# `CLAUDE.md` says to check reachability rather than assume it, and this is that
# check mechanised. It has now caught six engines that were ported, tested and
# never once called — `recordDiscovery`, `maybeGenerateOffer`, `trackEvent`,
# `club_asset_tiers`, `grantLookPack` and the whole of prestige. A green fixture
# test is not a caller.
#
#   bash tool/unreached.sh              # the list
#   bash tool/unreached.sh | wc -l      # the count
#
# Output is `file :: function :: test-files=N`. A high test-file count is the
# INTERESTING case, not the safe one: it means the thing is ported, proven and
# unreachable.
#
# **Read the result, do not act on it blind.** Four kinds of hit are expected
# and are not bugs:
#
#   - `setXRandom` / `resetXRandom` are test seams and are supposed to look
#     like this.
#   - Some functions are a dead end in `../merge-empire-fc` TOO — the transfer
#     list is the known one. Grep the JS for a caller before building a UI for
#     one, or you are adding a feature rather than porting it.
#   - A function whose every reader already guards the same condition is
#     housekeeping, not a live bug (see `expireBoosts`).
#   - A convenience reader for a control the port renders differently
#     (`getDailyStreak` names a HUD chip this port does not have).
#
# The sweep is deliberately dumb about HOW something is called: `grep -w` on the
# bare name catches a tear-off and a prefixed call alike, and the cost of that
# is the false positives above rather than a missed engine.
set -u

# **A CHECKER THAT PRINTS NOTHING MUST NOT BE READ AS A PASS.**
#
# The function-name extraction below needs `grep -oP`, and macOS ships BSD grep,
# which has no `-P` at all. Run under `bash` on a Mac, every `grep -oP` failed,
# the loop had nothing to iterate, and the script printed nothing and exited 0 —
# which reads exactly like "no unreachable functions" and was believed. It was
# not: `canWatchMatchCooldownAd` was orphaned by the shop's Match Day shelf
# dropping its ad route, and the sweep said the tree was clean.
#
# Same trap as the half-extracted SDK in `CLAUDE.md`, and the same answer: find
# a grep that can do the job, and DIE if there is none rather than looking green.
# **ONE TOOL FOR THE PATTERN, THE PLAIN `grep` FOR THE SEARCHES.** Only the
# declaration parse needs PCRE; `-rlw --include` is ordinary and BSD grep does
# it, while `rg` — the fallback most likely to be installed — does not take
# `--include` at all. Mixing them up made every search print a usage error.
EXTRACT=grep
if ! echo x | "$EXTRACT" -qP 'x' 2>/dev/null; then
  for candidate in ggrep rg ugrep; do
    if command -v "$candidate" >/dev/null 2>&1 &&
      echo x | "$candidate" -qP 'x' 2>/dev/null; then
      EXTRACT=$candidate
      break
    fi
  done
fi
if ! echo x | "$EXTRACT" -qP 'x' 2>/dev/null; then
  echo "unreached.sh: no grep with -P (PCRE) found." >&2
  echo "  macOS ships BSD grep, which cannot run this sweep." >&2
  echo "  brew install grep    # provides ggrep" >&2
  echo "  brew install ripgrep # or rg, which this script also accepts" >&2
  exit 2
fi

for f in $(ls lib/engine/*.dart lib/data/*.dart lib/state/*.dart | grep -v '\.g\.dart'); do
  "$EXTRACT" -oP '^[A-Za-z_][A-Za-z0-9_<>,\s\?\.\(\)\[\]]*?\b\K[a-z][A-Za-z0-9_]*(?=\()' "$f" 2>/dev/null |
    sort -u |
    while read -r fn; do
      case "$fn" in if|for|while|switch|return|assert|print|throw|catch|else|""|main) continue ;; esac
      # Its own file included: a helper used only where it is declared reads as
      # one occurrence, and that is the case worth surfacing.
      own=$(grep -cw "$fn" "$f")
      out=$(grep -rlw --include='*.dart' "$fn" lib/ | grep -vx "$f" | wc -l)
      if [ "$out" -eq 0 ] && [ "$own" -le 1 ]; then
        echo "$f :: $fn :: test-files=$(grep -rlw --include='*.dart' "$fn" test/ | wc -l)"
      fi
    done
done
