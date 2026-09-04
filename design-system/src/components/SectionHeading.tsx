import React from 'react';
import './SectionHeading.css';

export interface SectionHeadingProps {
  /** Rendered in caps. Pass it in the caller's own words. */
  title: string;
  /** Line art, not emoji: a section heading is interface. */
  icon: React.ReactNode;
  /** The glyph's colour, and the rule's at a lower alpha. **Each section has
   *  its OWN colour** where the sections are things you navigate between —
   *  that is what makes a column of them scannable. */
  ink?: string;
  className?: string;
}

/** A glyph, the name in caps, and a rule out to the edge. No disc: a frame
 *  around a glyph adds a rectangle competing with the card's own edge. */
export function SectionHeading({ title, icon, ink, className }: SectionHeadingProps) {
  return (
    <div
      className={['me-heading', className].filter(Boolean).join(' ')}
      style={ink ? ({ '--heading-ink': ink } as React.CSSProperties) : undefined}
    >
      <span className="me-heading__icon">{icon}</span>
      <span className="me-heading__title">{title.toUpperCase()}</span>
      <span className="me-heading__rule" />
    </div>
  );
}
