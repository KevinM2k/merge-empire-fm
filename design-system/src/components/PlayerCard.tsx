import React from 'react';
import { tierThemes, tierGradientCss } from '../tokens/tiers.gen';
import { TraitBadge, type TraitBadgeProps } from './TraitBadge';
import './PlayerCard.css';

export interface PlayerCardProps {
  name: string;
  /** 1 through 9. Drives the whole card body. */
  tier: number;
  rating: number;
  position: string;
  art?: React.ReactNode;
  traits?: TraitBadgeProps[];
  /** **Null by default and resolves from the theme.** Pass it only for a card
   *  that is genuinely not in the page's theme — one lifted onto a drag
   *  overlay. It was a bool defaulting to false, so seven callers each had to
   *  remember and the squad, the bench and the pickers were all dark on a
   *  light page. */
  light?: boolean;
  onClick?: () => void;
  className?: string;
}

/** A player, as the merge grid and the Player Index both draw him. */
export function PlayerCard({
  name, tier, rating, position, art, traits = [], light, onClick, className,
}: PlayerCardProps) {
  const t = tierThemes[tier];
  const body = t && (light ? t.bgLight : t.bg);
  return (
    <div
      className={['me-player', onClick && 'me-player--tap', className].filter(Boolean).join(' ')}
      data-me-card-theme={light == null ? undefined : light ? 'light' : 'dark'}
      style={{
        background: body ? tierGradientCss(body) : 'var(--color-surface)',
        borderColor: t ? `${t.accent}80` : 'var(--color-border)',
      }}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
    >
      {/* The rating and tier chips stay dark whatever the body does, so their
          bright rarity text stays readable on top. */}
      <div className="me-player__rating" style={{ background: t?.labelBg, color: t?.accentLight }}>
        {rating}
      </div>
      <div className="me-player__art">{art}</div>
      {traits.length > 0 && (
        <div className="me-player__traits">
          {traits.map((tr, i) => <TraitBadge key={i} {...tr} />)}
        </div>
      )}
      <div className="me-player__plate" style={{ background: t?.labelBg }}>
        <span className="me-player__pos" style={{ color: t?.accentLight }}>{position}</span>
        <span className="me-player__name">{name}</span>
      </div>
    </div>
  );
}
