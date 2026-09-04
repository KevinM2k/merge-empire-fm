import React from 'react';
import './CardGlyph.css';

export type BookingCard = 'yellow' | 'second_yellow' | 'red';

/**
 * The referee's card, drawn rather than fetched — a rounded rectangle is the
 * whole picture, at any size, in any theme.
 *
 * **A second yellow draws BOTH**, overlapped the way a referee holds them. It
 * is not a red; it is a caution too many, and this says so in the picture.
 */
export function CardGlyph({ card, height = 15 }: { card: BookingCard; height?: number }) {
  const w = height * 0.72;
  const one = (fill: string, style?: React.CSSProperties) => (
    <span
      className="me-cardglyph__card"
      style={{ width: w, height, borderRadius: height * 0.14, background: fill, ...style }}
    />
  );
  if (card !== 'second_yellow') {
    return <span className="me-cardglyph">{one(card === 'red' ? 'var(--card-red)' : 'var(--card-yellow)')}</span>;
  }
  // Fanned, so the two read as two rather than as a thick one.
  return (
    <span className="me-cardglyph" style={{ width: w * 1.5, height }}>
      {one('var(--card-yellow)', { position: 'absolute', left: 0, transform: 'rotate(-10.3deg)' })}
      {one('var(--card-red)', { position: 'absolute', left: w * 0.5, transform: 'rotate(10.3deg)' })}
    </span>
  );
}
