import type { Meta, StoryObj } from '@storybook/react';
import { GlassPanel } from './GlassPanel';

const meta: Meta<typeof GlassPanel> = { title: 'Surfaces/GlassPanel', component: GlassPanel };
export default meta;
type S = StoryObj<typeof GlassPanel>;

// backdrop-filter needs something behind it to bite, so every pane sits on a scene.
const scene: React.CSSProperties = {
  background: 'linear-gradient(160deg, #2b6b2f, #123018 60%, #0b1d10)',
  padding: 24,
  borderRadius: 12,
};

export const Panel: S = {
  render: (a) => (
    <div style={scene}>
      <GlassPanel {...a} style={{ padding: 16, maxWidth: 320 }}>
        <div style={{ fontWeight: 900, marginBottom: 4 }}>Next match</div>
        <div style={{ opacity: 0.8, fontSize: 13 }}>Dulwich Hamlet — away, Saturday</div>
      </GlassPanel>
    </div>
  ),
};

export const Densities: S = {
  render: () => (
    <div style={{ ...scene, display: 'flex', gap: 12, alignItems: 'flex-start' }}>
      {(['chip', 'panel', 'deep'] as const).map((d) => (
        <GlassPanel key={d} density={d} style={{ padding: 14, minWidth: 92 }}>{d}</GlassPanel>
      ))}
    </div>
  ),
};

/** Sheen off, because it is a highlight on a small surface and not a wash for
 *  a big one — on a tall pane it reads as a band across the middle. */
export const TallNoSheen: S = {
  render: () => (
    <div style={scene}>
      <GlassPanel sheen={false} style={{ padding: 16, height: 260, maxWidth: 260 }}>
        Commentary
      </GlassPanel>
    </div>
  ),
};
