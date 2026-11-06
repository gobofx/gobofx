#!/usr/bin/env node
// Render fixture.html to fixtures/preview-a.png and preview-b.png (512×288, 1×).
// Playwright's bundled Chromium; run from the repo root: node tools/preview-fixture/render.mjs
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const here = dirname(fileURLToPath(import.meta.url));
// Playwright is not a dependency of this repo: resolve it from the current
// directory, so run this from any folder that has it installed (or set
// NODE_PATH-style resolution by running inside such a folder).
const { chromium } = createRequire(resolve(process.cwd(), 'package.json'))('playwright');
// CHROMIUM_PATH points at a Chrome binary when the installed Playwright does not own one.
const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
const page = await browser.newPage({ viewport: { width: 512, height: 288 }, deviceScaleFactor: 1 });
for (const v of ['a', 'b']) {
  await page.goto(`file://${resolve(here, 'fixture.html')}?v=${v}`);
  await page.waitForTimeout(200);
  await page.locator('#c').screenshot({ path: resolve(here, `../../fixtures/preview-${v}.png`), omitBackground: false });
  console.log(`wrote fixtures/preview-${v}.png`);
}
await browser.close();
