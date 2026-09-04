import type { Meta, StoryObj } from '@storybook/react';
import { BottomSheet } from './BottomSheet';
import { Button } from './Button';
import { BarFill } from './BarFill';

const meta: Meta<typeof BottomSheet> = { title: 'Popups/BottomSheet', component: BottomSheet };
export default meta;
type S = StoryObj<typeof BottomSheet>;

export const Energy: S = {
  args: {
    title: 'Energy',
    subtitle: 'One pip refills every four minutes.',
    children: (
      <div style={{ display: 'grid', gap: 12 }}>
        <BarFill fraction={0.62} fill="#4fa8ff" height={10} />
        <Button>Refill for 40 💎</Button>
      </div>
    ),
  },
};
