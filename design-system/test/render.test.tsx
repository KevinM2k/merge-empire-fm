// Typechecking says nothing about whether a component mounts. Every export in
// the barrel gets rendered here, once, inside a provider.
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import {
  KitProvider, Button, GlassPanel, HudChip, HudCluster, HudPlus, CoinCounter,
  BarFill, SectionHeading, BottomSheet, SheetHeader, CoachCard, CoachBubbleTail,
  PlayerCard, PitchBoard, BadgeIcon, TierBadge, PlayerPortrait,
  CardGlyph, buildKitSurfaces, formatCoinsCompact,
} from '../src';

const wrap = (ui: React.ReactNode, kit = 'turf', light = false) =>
  render(<KitProvider kit={kit} light={light}>{ui}</KitProvider>);

describe('every component mounts', () => {
  it('Button, both variants and disabled', () => {
    wrap(<><Button>Play</Button><Button variant="outline">Maybe later</Button><Button disabled>Off</Button></>);
    expect(screen.getByText('Play')).toBeTruthy();
    expect(screen.getByText('Off')).toHaveProperty('disabled', true);
  });

  it('GlassPanel at each density', () => {
    const { container } = wrap(<>
      <GlassPanel density="chip">chip</GlassPanel>
      <GlassPanel density="panel">panel</GlassPanel>
      <GlassPanel density="deep" sheen={false} shadow={false}>deep</GlassPanel>
    </>);
    expect(container.querySelectorAll('.me-glass')).toHaveLength(3);
    expect(container.querySelector('.me-glass--chip')).toBeTruthy();
  });

  it('the HUD cluster', () => {
    wrap(<HudCluster>
      <HudChip icon="🪙" fill="#ffd700" trailing={<HudPlus label="Buy coins" />}>
        <CoinCounter value={1234} />
      </HudChip>
      <HudChip icon="⚡" fill="#4fa8ff">7</HudChip>
      <HudChip icon="⚙" />
    </HudCluster>);
    expect(screen.getByLabelText('Buy coins')).toBeTruthy();
    expect(screen.getByText('7')).toBeTruthy();
  });

  it('BarFill clamps past 1', () => {
    const { container } = wrap(<BarFill fraction={1.4} />);
    expect(container.querySelector('.me-bar__fill')).toHaveProperty('style.width', '100%');
  });

  it('SectionHeading upper-cases', () => {
    wrap(<SectionHeading title="Trophy room" icon="🏆" />);
    expect(screen.getByText('TROPHY ROOM')).toBeTruthy();
  });

  it('BottomSheet with a header', () => {
    wrap(<BottomSheet title="Energy" subtitle="Refills over time.">body</BottomSheet>);
    expect(screen.getByText('ENERGY')).toBeTruthy();
    expect(screen.getByText('Refills over time.')).toBeTruthy();
  });

  it('SheetHeader keeps trailing out of the centring', () => {
    const { container } = wrap(<SheetHeader title="Squad" trailing={<span>x</span>} />);
    expect(container.querySelector('.me-sheethead__trailing')).toBeTruthy();
  });

  it('CoachCard carries its own dismissal', () => {
    wrap(<CoachCard name="Coach Colin" actions={<Button variant="outline">No thanks</Button>}>
      A word about the back four.
    </CoachCard>);
    expect(screen.getByText('No thanks')).toBeTruthy();
    const { container } = wrap(<CoachBubbleTail />);
    expect(container.querySelector('svg')).toBeTruthy();
  });

  it('PlayerCard at every tier', () => {
    for (let tier = 1; tier <= 9; tier++) {
      const { container } = wrap(
        <PlayerCard name="Smith" tier={tier} rating={82} position="ST"
          traits={[{ icon: '⚽', level: 'III', title: 'Finisher III' }]} />,
      );
      const card = container.querySelector('.me-player') as HTMLElement;
      expect(card.style.background).toContain('linear-gradient');
      expect(container.querySelector('.me-trait')).toBeTruthy();
    }
  });

  it('PitchBoard centres every slot on its own percentage', () => {
    const slots = [{ id: 'gk', x: 50, y: 92 }, { id: 'st', x: 50, y: 12 }];
    const { container } = wrap(
      <PitchBoard slots={slots} tokenScale={0.9} renderSlot={(s) => <span>{s.id}</span>} />,
    );
    const first = container.querySelector('.me-pitch__slot') as HTMLElement;
    expect(first.style.transform).toBe('translate(-50%, -50%) scale(0.9)');
    expect(container.querySelectorAll('.me-pitch__slot')).toHaveLength(2);
  });

  it('BadgeIcon, TierBadge, PlayerPortrait, CardGlyph', () => {
    const { container } = wrap(<>
      <BadgeIcon glyph="🏆" label="Champion" />
      <BadgeIcon glyph="🔒" label="Locked" locked />
      <TierBadge tier={9} />
      <PlayerPortrait alt="Smith" />
      <CardGlyph card="yellow" />
      <CardGlyph card="second_yellow" />
      <CardGlyph card="red" />
    </>);
    expect(screen.getByLabelText('Champion')).toBeTruthy();
    expect(container.querySelector('.me-badge--locked')).toBeTruthy();
    expect(screen.getByText(/Icon/)).toBeTruthy();
    // A second yellow draws BOTH cards, fanned.
    expect(container.querySelectorAll('.me-cardglyph__card')).toHaveLength(4);
  });
});

describe('KitProvider', () => {
  it('writes the ramp as custom properties', () => {
    const { container } = render(<KitProvider kit="#ffeb3b" light={false}><span /></KitProvider>);
    const root = container.firstElementChild as HTMLElement;
    const expected = buildKitSurfaces('#ffeb3b', false);
    expect(root.style.getPropertyValue('--color-accent')).toBe(expected.accent);
    expect(root.style.getPropertyValue('--color-surface')).toBe(expected.surface);
    // Yellow is the case the ink test exists for: white on it is invisible.
    expect(root.style.getPropertyValue('--color-accent-ink')).toBe('#0d0d0d');
  });

  it('marks the theme so light-mode rules can bite', () => {
    const { container } = render(<KitProvider kit="turf" light><span /></KitProvider>);
    expect((container.firstElementChild as HTMLElement).dataset.meTheme).toBe('light');
  });
});

describe('formatCoinsCompact', () => {
  it.each([[999, '999'], [1000, '1K'], [1234, '1.2K'], [15000, '15K'], [3400000, '3.4M']])(
    '%i -> %s', (v, want) => expect(formatCoinsCompact(v)).toBe(want),
  );
});
