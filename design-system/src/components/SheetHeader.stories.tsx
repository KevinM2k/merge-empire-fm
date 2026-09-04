import type { Meta, StoryObj } from '@storybook/react';
import { SheetHeader } from './SheetHeader';

const meta: Meta<typeof SheetHeader> = { title: 'Popups/SheetHeader', component: SheetHeader };
export default meta;
type S = StoryObj<typeof SheetHeader>;

export const Default: S = { args: { title: 'League table', subtitle: 'National League, matchday 21' } };
export const WithClose: S = {
  args: { title: 'Squad', trailing: <span style={{ opacity: 0.7, cursor: 'pointer' }}>✕</span> },
};
