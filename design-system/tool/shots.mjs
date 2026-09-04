import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { extname, join } from 'node:path';

const types = { '.html':'text/html', '.js':'text/javascript', '.css':'text/css',
  '.json':'application/json', '.woff2':'font/woff2', '.ttf':'font/ttf', '.svg':'image/svg+xml' };
const root = 'storybook-static';
const server = createServer((req, res) => {
  const p = join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!existsSync(p) || p.endsWith('/')) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': types[extname(p)] ?? 'application/octet-stream' });
  res.end(readFileSync(p));
});
await new Promise((r) => server.listen(4499, r));

const shots = [
  ['controls-button--row', 'button-row'],
  ['squad-playercard--every-tier', 'player-tiers'],
  ['hud-hudchip--cluster', 'hud'],
  ['popups-coachcard--offer', 'coach'],
  ['surfaces-glasspanel--densities', 'glass'],
  ['squad-pitchboard--four-three-three', 'pitch'],
  ['bits-badges--tiers', 'tierbadges'],
];
const b = await chromium.launch();
for (const theme of ['dark', 'light']) {
  for (const [id, name] of shots) {
    const page = await b.newPage({ viewport: { width: 520, height: 400 }, deviceScaleFactor: 2 });
    await page.goto(`http://localhost:4499/iframe.html?id=${id}&globals=theme:${theme}`, { waitUntil: 'networkidle' });
    await page.waitForTimeout(500);
    await page.screenshot({ path: `.shots/${name}-${theme}.png` });
    await page.close();
  }
}
await b.close(); server.close();
console.log('shots done');
