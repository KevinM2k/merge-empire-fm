import type { Meta, StoryObj } from '@storybook/react';
import { BadgeIcon } from './BadgeIcon';

const meta: Meta<typeof BadgeIcon> = { title: 'Bits/BadgeIcon', component: BadgeIcon };
export default meta;
type S = StoryObj<typeof BadgeIcon>;

export const Earned: S = { args: { glyph: '🏆', label: 'League champion', fill: 'var(--color-gold)', ink: '#3a2c00' } };
export const Podium: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 12 }}>
      <BadgeIcon glyph="🏆" label="Champion" fill="var(--color-gold)" ink="#3a2c00" />
      <BadgeIcon glyph="🥈" label="Runner up" fill="var(--color-silver)" ink="#2b2b2b" />
      <BadgeIcon glyph="🥉" label="Third" fill="var(--color-bronze)" />
    </div>
  ),
};
/** Not yet earned reads as a hole rather than a prize. */
export const Locked: S = { args: { glyph: '🔒', label: 'Not yet earned', locked: true } };
