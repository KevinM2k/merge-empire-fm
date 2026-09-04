import type { Meta, StoryObj } from '@storybook/react';
import { TierBadge } from './TierBadge';

const meta: Meta<typeof TierBadge> = { title: 'Bits/TierBadge', component: TierBadge };
export default meta;
type S = StoryObj<typeof TierBadge>;

export const Gold: S = { args: { tier: 5 } };
/** Bronze to Icon. The chip stays DARK in both themes so its bright rarity
 *  text stays readable on a pale card body. */
export const EveryTier: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', maxWidth: 420 }}>
      {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((t) => <TierBadge key={t} tier={t} />)}
    </div>
  ),
};
