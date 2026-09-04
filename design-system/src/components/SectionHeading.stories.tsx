import type { Meta, StoryObj } from '@storybook/react';
import { SectionHeading } from './SectionHeading';

const meta: Meta<typeof SectionHeading> = { title: 'Layout/SectionHeading', component: SectionHeading };
export default meta;
type S = StoryObj<typeof SectionHeading>;

export const Default: S = { args: { title: 'Trophy room', icon: '🏆' } };

/** Each section has its OWN colour where the sections are things you navigate
 *  between — that is what makes a long sheet scannable. */
export const AColumnOfThem: S = {
  render: () => (
    <div style={{ display: 'grid', gap: 18, maxWidth: 360 }}>
      <SectionHeading title="Boosts" icon="⚡" ink="#4fa8ff" />
      <SectionHeading title="Gem packs" icon="💎" ink="#00c8ff" />
      <SectionHeading title="Manager looks" icon="🧢" ink="#b98bff" />
    </div>
  ),
};
