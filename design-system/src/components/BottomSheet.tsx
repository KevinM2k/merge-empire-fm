import React from 'react';
import { SheetHeader } from './SheetHeader';
import './BottomSheet.css';

export interface BottomSheetProps extends React.HTMLAttributes<HTMLDivElement> {
  title?: string;
  subtitle?: string;
  trailing?: React.ReactNode;
  /** The grabber. Off for a sheet that cannot be dragged away. */
  handle?: boolean;
}

/** One of the three popup shapes. A fourth shape is a spec change first. */
export function BottomSheet({
  title, subtitle, trailing, handle = true, className, children, ...rest
}: BottomSheetProps) {
  return (
    <div className={['me-sheet', className].filter(Boolean).join(' ')} role="dialog" {...rest}>
      {handle && <div className="me-sheet__handle" />}
      {title && <SheetHeader title={title} subtitle={subtitle} trailing={trailing} />}
      <div className="me-sheet__body">{children}</div>
    </div>
  );
}
