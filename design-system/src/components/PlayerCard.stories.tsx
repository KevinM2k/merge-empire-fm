import type { Meta, StoryObj } from '@storybook/react';
import { PlayerCard } from './PlayerCard';

const meta: Meta<typeof PlayerCard> = { title: 'Squad/PlayerCard', component: PlayerCard };
export default meta;
type S = StoryObj<typeof PlayerCard>;

const art = <div style={{ fontSize: 54, lineHeight: 1 }}>🧍</div>;

export const Gold: S = {
  args: {
    name: 'Okonkwo', tier: 5, rating: 78, position: 'ST', art,
    traits: [{ icon: '⚽', level: 'III', title: 'Finisher III' }],
  },
};

/** Every rarity, which is the thing the tier gradients exist to make scannable. */
export const EveryTier: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
      {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((tier) => (
        <PlayerCard key={tier} name="Smith" tier={tier} rating={60 + tier * 4}
          position="CM" art={art} />
      ))}
    </div>
  ),
};

export const WithTraits: S = {
  args: {
    name: 'Van Dijk', tier: 8, rating: 91, position: 'CB', art,
    traits: [
      { icon: '🛡', level: 'III', title: 'Rock III' },
      { icon: '🎯', level: 'II', title: 'Leader II' },
    ],
  },
};
