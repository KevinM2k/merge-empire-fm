import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { CoinCounter } from './CoinCounter';
import { Button } from './Button';

const meta: Meta<typeof CoinCounter> = { title: 'HUD/CoinCounter', component: CoinCounter };
export default meta;
type S = StoryObj<typeof CoinCounter>;

/** The swell is NOT driven by the value changing — idle income moves it every
 *  second, and a counter that pulses every second is furniture. */
export const CountsUpAndSwells: S = {
  render: () => {
    const [v, setV] = useState(1200);
    const [r, setR] = useState(0);
    return (
      <div style={{ display: 'grid', gap: 12, justifyItems: 'start', fontSize: 22, fontWeight: 900 }}>
        <CoinCounter value={v} reward={r} />
        <div style={{ display: 'flex', gap: 8 }}>
          <Button variant="outline" onClick={() => setV((x) => x + 850)}>Idle income</Button>
          <Button onClick={() => { setV((x) => x + 5000); setR((x) => x + 1); }}>Claim reward</Button>
        </div>
      </div>
    );
  },
};
