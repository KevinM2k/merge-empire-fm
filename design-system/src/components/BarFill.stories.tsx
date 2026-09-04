import type { Meta, StoryObj } from '@storybook/react';
import { BarFill } from './BarFill';

const meta: Meta<typeof BarFill> = { title: 'Bits/BarFill', component: BarFill };
export default meta;
type S = StoryObj<typeof BarFill>;

export const Tracks: S = {
  render: () => (
    <div style={{ display: 'grid', gap: 10, maxWidth: 280 }}>
      <BarFill fraction={0.82} />
      <BarFill fraction={0.44} fill="var(--tactic-attack)" />
      <BarFill fraction={0.18} fill="var(--color-danger)" height={10} />
      {/* A countdown sweeping away wants the other end. */}
      <BarFill fraction={0.3} fill="var(--color-warning)" from="right" />
    </div>
  ),
};
