import React from 'react';
import './PlayerPortrait.css';

export interface PlayerPortraitProps {
  src?: string;
  alt?: string;
  size?: number;
  /** The ring takes the tier's accent where a card has one. */
  ring?: string;
  fallback?: React.ReactNode;
}

/** A player's face, at one size in one shape wherever it appears. */
export function PlayerPortrait({ src, alt = '', size = 44, ring, fallback }: PlayerPortraitProps) {
  return (
    <span
      className="me-portrait"
      style={{ width: size, height: size, borderColor: ring ?? 'var(--color-border)' }}
    >
      {src ? <img src={src} alt={alt} /> : <span className="me-portrait__fallback">{fallback ?? '👤'}</span>}
    </span>
  );
}
