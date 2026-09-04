import type { Meta, StoryObj } from '@storybook/react';
import { PitchBoard } from './PitchBoard';

const meta: Meta<typeof PitchBoard> = { title: 'Squad/PitchBoard', component: PitchBoard };
export default meta;
type S = StoryObj<typeof PitchBoard>;

// A 4-3-3, in the percentages a formation is actually laid out in.
const slots = [
  { id: 'GK', x: 50, y: 92 },
  { id: 'LB', x: 16, y: 72 }, { id: 'CB', x: 38, y: 76 },
  { id: 'CB2', x: 62, y: 76 }, { id: 'RB', x: 84, y: 72 },
  { id: 'CM', x: 30, y: 50 }, { id: 'CDM', x: 50, y: 56 }, { id: 'CM2', x: 70, y: 50 },
  { id: 'LW', x: 20, y: 24 }, { id: 'ST', x: 50, y: 16 }, { id: 'RW', x: 80, y: 24 },
];

const token = (id: string) => (
  <div style={{
    width: 40, height: 40, borderRadius: '50%',
    background: 'var(--color-accent)', color: 'var(--color-accent-ink)',
    display: 'grid', placeItems: 'center', fontSize: 11, fontWeight: 900,
    border: '2px solid #ffffff2e',
  }}>{id}</div>
);

export const FourThreeThree: S = {
  render: () => (
    <div style={{ maxWidth: 320 }}>
      <PitchBoard slots={slots} renderSlot={(s) => token(s.id)} />
    </div>
  ),
};
