import type { Meta, StoryObj } from '@storybook/react';
import { CoachCard, CoachLine } from './CoachCard';
import { Button } from './Button';

const meta: Meta<typeof CoachCard> = { title: 'Popups/CoachCard', component: CoachCard };
export default meta;
type S = StoryObj<typeof CoachCard>;

/** **A Coach Colin card has no barrier**, so it always carries its own
 *  dismissal — the decline is the only way out. */
export const Offer: S = {
  args: {
    name: 'Coach Colin',
    avatar: <div style={{ fontSize: 46, lineHeight: 1 }}>🧑‍🏫</div>,
    children: (
      <>Nike want to sponsor <CoachLine>Okonkwo</CoachLine>. That is{' '}
      <CoachLine>£40k a week</CoachLine> for the rest of the season.</>
    ),
    actions: (
      <>
        <Button variant="outline">No thanks</Button>
        <Button>Take the deal</Button>
      </>
    ),
  },
};

export const JustAWord: S = {
  args: {
    name: 'Coach Colin',
    children: 'That back four has kept three clean sheets on the bounce.',
  },
};
