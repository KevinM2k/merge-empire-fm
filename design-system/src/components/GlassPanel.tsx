import React from 'react';
import './GlassPanel.css';

export type GlassDensity = 'chip' | 'panel' | 'deep';

export interface GlassPanelProps extends React.HTMLAttributes<HTMLDivElement> {
  radius?: number;
  density?: GlassDensity;
  /** Off for anything small or numerous — the tint stands alone by design. */
  blur?: boolean;
  /** The vertical highlight down the pane. **Off for a TALL one**: it is a
   *  highlight on a small surface, not a wash for a big one. */
  sheen?: boolean;
  /** Off for a pane already floating on chrome of its own — the HUD's cluster
   *  sits in a bar, not on the scene. */
  shadow?: boolean;
  /** Force the dark stops whatever the theme is. A takeover page pins its own
   *  material in BOTH themes, because the ground is the sky. */
  darkGlass?: boolean;
}

/**
 * The app's pane. A tint, a sheen and a rim — the sheen is what separates glass
 * from a translucent rectangle, because it implies a light source and a
 * thickness.
 */
export function GlassPanel({
  radius = 16,
  density = 'panel',
  blur = true,
  sheen = true,
  shadow = true,
  darkGlass,
  className,
  style,
  children,
  ...rest
}: GlassPanelProps) {
  return (
    <div
      className={[
        'me-glass',
        `me-glass--${density}`,
        blur && 'me-glass--blur',
        sheen && 'me-glass--sheen',
        shadow && 'me-glass--shadow',
        darkGlass === true && 'me-glass--night',
        darkGlass === false && 'me-glass--day',
        className,
      ].filter(Boolean).join(' ')}
      style={{ borderRadius: radius, ...style }}
      {...rest}
    >
      {children}
    </div>
  );
}
