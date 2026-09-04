import React from 'react';
import './BadgeIcon.css';

export interface BadgeIconProps {
  glyph: React.ReactNode;
  size?: number;
  /** The disc's fill. Gold, silver and bronze are in the token sheet. */
  fill?: string;
  ink?: string;
  label?: string;
  /** A badge not yet earned reads as a hole rather than a prize. */
  locked?: boolean;
}

/** The circular badge. One component rather than three, because a badge that
 *  rendered differently per screen would read as a different badge. */
export function BadgeIcon({ glyph, size = 44, fill, ink, label, locked }: BadgeIconProps) {
  return (
    <span
      className={['me-badge', locked && 'me-badge--locked'].filter(Boolean).join(' ')}
      style={{ width: size, height: size, background: fill ?? 'var(--color-accent)', color: ink ?? '#fff' }}
      aria-label={label}
      title={label}
    >
      <span className="me-badge__glyph" style={{ fontSize: size * 0.46 }}>{glyph}</span>
    </span>
  );
}
