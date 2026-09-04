import React from 'react';
import './HudChip.css';

export interface HudChipProps extends React.HTMLAttributes<HTMLDivElement> {
  icon: React.ReactNode;
  /** The chip's own fill. The three resources are colour-CODED and their hues
   *  are fixed on every kit: the coin gold, the bolt blue, the gem cyan.
   *  Omit it and the chip takes the club accent — right for the cog. */
  fill?: string;
  ink?: string;
  trailing?: React.ReactNode;
  onPress?: () => void;
  /** Bigger for the cog, which has no figure beside it. At the resources' 16 it
   *  was the one item in the cluster that read as smaller than the rest. */
  iconSize?: number;
}

/**
 * One reading in the HUD.
 *
 * **Each reading is its own badge, filled with its own colour.** A badge
 * controls its ground, so gold is gold because the CHIP is gold — it says the
 * same thing on a night sky as it does on a daylit one.
 */
export function HudChip({
  icon, fill, ink, trailing, onPress, iconSize = 16, className, children, style, ...rest
}: HudChipProps) {
  const bare = children == null;
  return (
    <div
      className={['me-hudchip', bare && 'me-hudchip--bare', onPress && 'me-hudchip--tap', className]
        .filter(Boolean).join(' ')}
      style={{
        background: fill ?? 'var(--color-accent)',
        color: ink ?? (fill ? '#ffffff' : 'var(--color-accent-ink)'),
        ...style,
      }}
      onClick={onPress}
      role={onPress ? 'button' : undefined}
      tabIndex={onPress ? 0 : undefined}
      {...rest}
    >
      <span className="me-hudchip__icon" style={{ fontSize: iconSize }}>{icon}</span>
      {!bare && <span className="me-hudchip__value">{children}</span>}
      {trailing && <span className="me-hudchip__trailing">{trailing}</span>}
    </div>
  );
}

/** Four badges in a row, and no box — a badge carries its own ground, so there
 *  is nothing left for a box to do. Separated rather than divided. */
export function HudCluster({ children, className, ...rest }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={['me-hudcluster', className].filter(Boolean).join(' ')} {...rest}>
      {children}
    </div>
  );
}

/** The small `+` that deep-links out of a resource chip. White on the badge,
 *  not the club's colour: a hole punched in the badge reads as part of it. */
export function HudPlus({ label, onPress }: { label: string; onPress?: () => void }) {
  return (
    <button type="button" className="me-hudplus" aria-label={label} onClick={onPress}>
      +
    </button>
  );
}
