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

for f in $(ls lib/engine/*.dart lib/data/*.dart lib/state/*.dart | grep -v '\.g\.dart'); do
  grep -oP '^[A-Za-z_][A-Za-z0-9_<>,\s\?\.\(\)\[\]]*?\b\K[a-z][A-Za-z0-9_]*(?=\()' "$f" 2>/dev/null |
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
