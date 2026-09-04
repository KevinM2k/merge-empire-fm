import React from 'react';
import './SheetHeader.css';

export interface SheetHeaderProps {
  /** As the catalogue writes it. Upper-cased here rather than in the string, so
   *  a language that has no case is untouched. */
  title: string;
  /** One sentence under it. Not a second heading. */
  subtitle?: string;
  /** A close button, a counter, a filter. Kept OUT of the centring. */
  trailing?: React.ReactNode;
  className?: string;
}

/**
 * The title at the top of anything that rises.
 *
 * One rule, everywhere, and that is the whole point: CAPS, the club's accent,
 * centred, 15px/w900/+0.8 tracking, and a muted sentence-case subtitle.
 */
export function SheetHeader({ title, subtitle, trailing, className }: SheetHeaderProps) {
  return (
    <div className={['me-sheethead', className].filter(Boolean).join(' ')}>
      <div className="me-sheethead__body">
        <div className="me-sheethead__title">{title.toUpperCase()}</div>
        {subtitle && <div className="me-sheethead__sub">{subtitle}</div>}
      </div>
      {trailing && <div className="me-sheethead__trailing">{trailing}</div>}
    </div>
  );
}
