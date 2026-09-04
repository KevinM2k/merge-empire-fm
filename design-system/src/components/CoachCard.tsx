import React from 'react';
import './CoachCard.css';

export interface CoachCardProps {
  /** His name over the line. */
  name?: string;
  /** The portrait — his figure, or any avatar node. */
  avatar?: React.ReactNode;
  /** The actions. **A Coach Colin card has no barrier**, so it must always
   *  carry its own dismissal — a decline as well as an accept. */
  actions?: React.ReactNode;
  children?: React.ReactNode;
  className?: string;
}

/** One of the three popup shapes: Coach Colin, speaking. The tail is a wedge
 *  dropping down and to the LEFT, because the head is below and behind the
 *  bubble's corner. */
export function CoachCard({ name, avatar, actions, children, className }: CoachCardProps) {
  return (
    <div className={['me-coach', className].filter(Boolean).join(' ')}>
      <div className="me-coach__bubble">
        {name && <div className="me-coach__name">{name}</div>}
        <div className="me-coach__body">{children}</div>
        {actions && <div className="me-coach__actions">{actions}</div>}
        <CoachBubbleTail />
      </div>
      {avatar && <div className="me-coach__avatar">{avatar}</div>}
    </div>
  );
}

/** The speech tail: 18x12, apex down-left. Only the two slopes are stroked —
 *  an open path has no top edge to hide, and hiding one leaves a seam. */
export function CoachBubbleTail() {
  return (
    <svg className="me-coach__tail" width={18} height={12} viewBox="0 0 18 12" aria-hidden="true">
      <path d="M0 0 L18 0 L1.5 12 Z" className="me-coach__tail-fill" />
      <path d="M18 0 L1.5 12 L0 0" className="me-coach__tail-edge" fill="none" strokeLinejoin="round" />
    </svg>
  );
}

/** Emphasis inside a run of text. A Dart String cannot carry it, so the port's
 *  cards get it from their own typography instead of a <strong> in the copy. */
export function CoachLine({ children }: { children: React.ReactNode }) {
  return <strong className="me-coach__strong">{children}</strong>;
}
