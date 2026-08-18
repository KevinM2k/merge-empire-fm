// The card's per-tier palette and labels, straight from Card.js.
//
// Nine tiers x four colours plus two label tables — all literals, so this
// fixture is a transcription guard rather than a derivation check. Said plainly
// because a wrong hex here is a silent rarity change nothing else would notice.
//
//   node tool/dump_card_theme_reference.mjs > test/fixtures/card_theme_reference.json

const card = await import('../../merge-empire-fc/src/ui/components/Card.js');

process.stdout.write(
  JSON.stringify(
    {
      label: card.TIER_LABEL,
      emoji: card.TIER_EMOJI,
      theme: card.TIER_THEME,
      bgLight: card.TIER_BG_LIGHT,
    },
    null,
    2,
  ),
);
