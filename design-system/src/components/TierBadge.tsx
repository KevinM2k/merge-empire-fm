
import { tierThemes } from '../tokens/tiers.gen';
import './TierBadge.css';

export interface TierBadgeProps {
  /** 1 through 9. Bronze to Icon. */
  tier: number;
  /** Overrides the catalogue's own label. */
  label?: string;
  showEmoji?: boolean;
}

/** The rarity chip. It stays DARK in both themes so its bright rarity text
 *  stays readable on top of a pale card body. */
export function TierBadge({ tier, label, showEmoji = true }: TierBadgeProps) {
  const t = tierThemes[tier];
  if (!t) return null;
  return (
    <span className="me-tier" style={{ background: t.labelBg, color: t.accentLight }}>
      {showEmoji && <span className="me-tier__emoji">{t.emoji}</span>}
      {label ?? t.label}
    </span>
  );
}
