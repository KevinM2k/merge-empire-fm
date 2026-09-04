// Vite's library mode force-inlines assets, so the faces cannot live in the
// bundled CSS. They ship as files beside it and styles.css is the entry that
// pulls both — which is also the shape the design-sync upload wants.
import { cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';

mkdirSync('dist/fonts', { recursive: true });
for (const f of ['Barlow-SemiBold', 'Barlow-Bold', 'Barlow-Black', 'LilitaOne-Regular']) {
  cpSync(`src/fonts/${f}.woff2`, `dist/fonts/${f}.woff2`);
}
for (const f of ['OFL-Barlow.txt', 'OFL-LilitaOne.txt']) cpSync(`src/fonts/${f}`, `dist/fonts/${f}`);
// In src the faces sit at ../fonts (beside styles/); in dist they sit at
// ./fonts (beside fonts.css). Rewrite on the way out so both resolve.
writeFileSync('dist/fonts.css',
  readFileSync('src/styles/fonts.css', 'utf8').replaceAll("url('../fonts/", "url('./fonts/"));
writeFileSync('dist/styles.css', `@import './fonts.css';\n@import './style.css';\n`);
console.log('wrote dist/styles.css, dist/fonts.css, dist/fonts/');
