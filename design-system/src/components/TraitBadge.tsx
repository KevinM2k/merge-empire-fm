import React from 'react';
import './TraitBadge.css';

export interface TraitBadgeProps {
  /** The trait's mark — the app's own glyph, or its emoji where the set has
   *  none rather than being forced into a wrong one. */
  icon: React.ReactNode;
  /** 'I', 'II' or 'III'. */
  level?: string;
  /** The localised '⚽ Finisher III', for anything that reads rather than looks. */
  title: string;
  size?: number;
}

/** The trait glyph the eleven's token and every player card both wear. */
export function TraitBadge({ icon, level = '', title, size = 9 }: TraitBadgeProps) {
  return (
    <span
      className="me-trait"
      aria-label={title}
      title={title}
      style={{
        padding: `1.5px ${size * 0.44}px`,
        borderRadius: size * 0.7,
        fontSize: size,
        gap: level ? size * 0.28 : 0,
      }}
    >
      <span className="me-trait__icon" style={{ fontSize: size * 1.15 }}>{icon}</span>
      {level && <span className="me-trait__level">{level}</span>}
    </span>
  );
}
