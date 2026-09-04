import type { Meta, StoryObj } from '@storybook/react';
import { HudChip, HudCluster, HudPlus } from './HudChip';
import { CoinCounter } from './CoinCounter';

const meta: Meta<typeof HudChip> = { title: 'HUD/HudChip', component: HudChip };
export default meta;
type S = StoryObj<typeof HudChip>;

/** The three resources are colour-CODED and their hues are fixed on every kit:
 *  the coin gold, the bolt blue, the gem cyan. */
export const Cluster: S = {
  render: () => (
    <HudCluster>
      <HudChip icon="🪙" fill="#ffd700" ink="#3a2c00" trailing={<HudPlus label="Buy coins" />}>
        <CoinCounter value={128400} />
      </HudChip>
      <HudChip icon="⚡" fill="#4fa8ff" trailing={<HudPlus label="Buy energy" />}>18</HudChip>
      <HudChip icon="💎" fill="#00c8ff" ink="#00323d">42</HudChip>
      <HudChip icon="⚙" iconSize={18} />
    </HudCluster>
  ),
};

export const OnTheKitAccent: S = { args: { icon: '🏆', children: '3rd' } };
