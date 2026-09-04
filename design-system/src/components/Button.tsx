import React from 'react';
import './Button.css';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  /** The secondary form: same geometry, same edge bar, an empty face. A cancel
   *  carrying a solid face out-shouts the button beside it, which is the one
   *  thing the shape is for. */
  variant?: 'solid' | 'outline';
  size?: 'md' | 'sm';
}

/**
 * The moulded face every button in the game wears.
 *
 * A moulded button answers a press by DROPPING — the face sinks 2px and the
 * edge bar under it shrinks to match, so the bar's bottom never moves. That is
 * the whole gesture; there is no ripple, because a ripple over the top of it is
 * two different answers to one tap.
 */
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  function Button({ variant = 'solid', size = 'md', className, type = 'button', ...rest }, ref) {
    return (
      <button
        ref={ref}
        type={type}
        className={['me-btn', `me-btn--${variant}`, `me-btn--${size}`, className]
          .filter(Boolean)
          .join(' ')}
        {...rest}
      />
    );
  },
);
