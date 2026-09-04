import React, { createContext, useContext, useMemo } from 'react';
import { buildKitSurfaces, hexToHsl, hslToHex, type KitSurfaces } from './tokens/kit';
import './tokens/tokens.css';

export type KitId =
  | 'turf' | 'humbug' | 'sunset' | 'midnight' | 'empire' | 'void'
  | (string & {}); // or any '#rrggbb'

export interface KitProviderProps {
  /** One of the six pattern names, or a '#rrggbb' club colour. Anything
   *  unrecognised lands on the default green rather than throwing. */
  kit?: KitId;
  /** Light theme takes the kit too — the inverse of what dark does, not a
   *  neutral card stack with the accent moved. */
  light?: boolean;
  /** Renders a <div> by default. 'body-less' pages can pass a fragment host. */
  as?: keyof JSX.IntrinsicElements;
  className?: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

const KitContext = createContext<{ surfaces: KitSurfaces; light: boolean } | null>(null);

/** The derived palette for the surrounding <KitProvider>. */
export function useKit() {
  const ctx = useContext(KitContext);
  if (!ctx) throw new Error('useKit must be used inside a <KitProvider>');
  return ctx;
}

// The moulded button's edge is the face under 45% black — the one derived value
// the Dart computes at the theme rather than in buildKitSurfaces.
function edgeFor(accentHex: string): string {
  if (!accentHex.startsWith('#') || accentHex.length !== 7) return accentHex;
  const hsl = hexToHsl(accentHex);
  return hslToHex(hsl.h, hsl.s, Math.round(hsl.l * 0.55));
}

/**
 * Wraps the tree in a kit. **Nothing below is styled without one** — every
 * component reads `var(--color-*)`, and those properties are written here.
 */
export function KitProvider({
  kit = 'turf',
  light = false,
  as: Tag = 'div',
  className,
  style,
  children,
}: KitProviderProps) {
  const surfaces = useMemo(() => buildKitSurfaces(kit, light), [kit, light]);

  const vars = {
    '--color-bg': surfaces.bg,
    '--color-surface': surfaces.surface,
    '--color-surface-2': surfaces.surface2,
    '--color-border': surfaces.border,
    '--color-text-muted': surfaces.textMuted,
    '--color-accent': surfaces.accent,
    '--color-accent-bright': surfaces.accentBright,
    '--color-accent-bright-ink': surfaces.accentBrightInk,
    '--color-accent-ink': surfaces.accentInk,
    '--color-accent-edge': edgeFor(surfaces.accent),
    // Material derives body ink from a seeded scheme on the Flutter side; these
    // are the port's own high-contrast neutrals. See NOTES.md.
    '--color-text': light ? '#14171c' : '#eef2ee',
    '--kit-hue-rotate': `${surfaces.hueRotate}deg`,
    ...style,
  } as React.CSSProperties;

  return (
    <KitContext.Provider value={{ surfaces, light }}>
      <Tag
        data-me-kit={kit}
        data-me-theme={light ? 'light' : 'dark'}
        className={['me-root', className].filter(Boolean).join(' ')}
        style={vars}
      >
        {children}
      </Tag>
    </KitContext.Provider>
  );
}
