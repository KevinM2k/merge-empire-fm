import type { Meta, StoryObj } from '@storybook/react';
import { TraitBadge } from './TraitBadge';

const meta: Meta<typeof TraitBadge> = { title: 'Bits/TraitBadge', component: TraitBadge };
export default meta;
type S = StoryObj<typeof TraitBadge>;

export const Levelled: S = { args: { icon: '⚽', level: 'III', title: 'Finisher III', size: 12 } };
export const Row: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 6 }}>
      <TraitBadge icon="⚽" level="III" title="Finisher III" size={12} />
      <TraitBadge icon="🛡" level="II" title="Rock II" size={12} />
      {/* A trait with no level shows the mark alone. */}
      <TraitBadge icon="🎯" title="Leader" size={12} />
    </div>
  ),
};
