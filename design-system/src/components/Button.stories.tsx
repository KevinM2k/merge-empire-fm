import type { Meta, StoryObj } from '@storybook/react';
import { Button } from './Button';

const meta: Meta<typeof Button> = { title: 'Controls/Button', component: Button };
export default meta;
type S = StoryObj<typeof Button>;

export const Solid: S = { args: { children: 'Play match' } };
export const Outline: S = { args: { children: 'Maybe later', variant: 'outline' } };
export const Disabled: S = { args: { children: 'Not enough energy', disabled: true } };

/** The pair as a card's footer uses them: the action shouts, the cancel does not. */
export const Row: S = {
  render: () => (
    <div style={{ display: 'flex', gap: 8 }}>
      <Button variant="outline">Decline</Button>
      <Button>Accept £4.2M</Button>
    </div>
  ),
};
