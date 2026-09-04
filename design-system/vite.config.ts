/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';

export default defineConfig({
  test: { environment: 'jsdom', globals: true },
  plugins: [react()],
  build: {
    // Library mode inlines every asset by default, which turned four .ttf files
    // into 485kB of base64 in one stylesheet. Emit them as files instead.
    assetsInlineLimit: 0,
    lib: {
      entry: resolve(__dirname, 'src/index.ts'),
      name: 'MergeEmpireDS',
      formats: ['es', 'cjs'],
      fileName: (f) => (f === 'es' ? 'index.js' : 'index.cjs'),
    },
    rollupOptions: {
      external: ['react', 'react-dom', 'react/jsx-runtime'],
      output: { assetFileNames: (a) => (a.name?.endsWith('.ttf') ? 'fonts/[name][extname]' : '[name][extname]') },
    },
    cssCodeSplit: false,
  },
});
