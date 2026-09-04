import type { Meta, StoryObj } from '@storybook/react';
import { PlayerPortrait } from './PlayerPortrait';

const meta: Meta<typeof PlayerPortrait> = { title: 'Bits/PlayerPortrait', component: PlayerPortrait };
export default meta;
type S = StoryObj<typeof PlayerPortrait>;

export const Empty: S = { args: { alt: 'Smith', size: 48 } };
export const Sizes: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
      {[28, 40, 56].map((s) => <PlayerPortrait key={s} alt="Smith" size={s} />)}
      {/* The ring takes the tier's accent where a card has one. */}
      <PlayerPortrait alt="Okonkwo" size={56} ring="#ffaa00" />
    </div>
  ),
};
