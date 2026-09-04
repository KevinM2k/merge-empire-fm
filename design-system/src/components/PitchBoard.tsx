import React from 'react';
import './PitchBoard.css';

export interface PitchSlot {
  id: string;
  /** The formation's own percentages. Every slot is CENTRED on them. */
  x: number;
  y: number;
}

export interface PitchBoardProps {
  slots: PitchSlot[];
  renderSlot: (slot: PitchSlot) => React.ReactNode;
  /** The eleven scale to the shape they are in — a formation is laid out in
   *  percentages and the token in pixels, so whether a shape crowds depends on
   *  the screen. Pass what the caller has measured. */
  tokenScale?: number;
  className?: string;
}

/** Lays the eleven out for the squad tab AND the subs panel. */
export function PitchBoard({ slots, renderSlot, tokenScale = 1, className }: PitchBoardProps) {
  return (
    <div className={['me-pitch', className].filter(Boolean).join(' ')}>
      <div className="me-pitch__markings" aria-hidden="true">
        <span className="me-pitch__circle" />
        <span className="me-pitch__halfway" />
        <span className="me-pitch__box me-pitch__box--top" />
        <span className="me-pitch__box me-pitch__box--bottom" />
      </div>
      {slots.map((slot) => (
        <div
          key={slot.id}
          className="me-pitch__slot"
          style={{
            left: `${slot.x}%`,
            top: `${slot.y}%`,
            transform: `translate(-50%, -50%) scale(${tokenScale})`,
          }}
        >
          {renderSlot(slot)}
        </div>
      ))}
    </div>
  );
}
