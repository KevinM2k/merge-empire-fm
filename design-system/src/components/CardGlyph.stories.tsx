import type { Meta, StoryObj } from '@storybook/react';
import { CardGlyph } from './CardGlyph';

const meta: Meta<typeof CardGlyph> = { title: 'Bits/CardGlyph', component: CardGlyph };
export default meta;
type S = StoryObj<typeof CardGlyph>;

export const Yellow: S = { args: { card: 'yellow', height: 22 } };
export const Red: S = { args: { card: 'red', height: 22 } };
/** A second yellow draws BOTH, overlapped the way a referee holds them: it is
 *  not a red, it is a caution too many. */
export const SecondYellow: S = { args: { card: 'second_yellow', height: 22 } };
