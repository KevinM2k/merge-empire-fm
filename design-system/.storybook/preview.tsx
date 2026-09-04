import React from 'react';
import type { Preview } from '@storybook/react';
import { KitProvider } from '../src/KitProvider';
import '../src/components/base.css';
import '../src/styles/fonts.css';

// **Nothing renders styled outside a KitProvider** — every component reads
// var(--color-*) and those properties are written by it. The toolbar drives the
// same two arguments the app does: which kit, and which theme.
const preview: Preview = {
  globalTypes: {
    kit: {
      description: 'Club kit',
      defaultValue: 'turf',
      toolbar: {
        title: 'Kit',
        items: ['turf', 'humbug', 'sunset', 'midnight', 'empire', 'void', '#4caf50', '#ffeb3b'],
      },
    },
    theme: {
      description: 'Theme',
      defaultValue: 'dark',
      toolbar: { title: 'Theme', items: ['dark', 'light'] },
    },
  },
  decorators: [
    (Story, ctx) => (
      <KitProvider
        kit={ctx.globals.kit}
        light={ctx.globals.theme === 'light'}
        style={{ padding: 24, minHeight: '100vh' }}
      >
        <Story />
      </KitProvider>
    ),
  ],
  parameters: { layout: 'fullscreen', controls: { expanded: true } },
};
export default preview;
