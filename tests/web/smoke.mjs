// Multiversal Van Life - automated web smoke test (MIT License).
// Serves the Emscripten build, loads it in headless Chromium (desktop and a
// touch phone), checks that the game boots without errors, renders
// something other than a blank canvas, keeps its save folder in IndexedDB
// across a reload, enables touch controls on mobile, opens the codex by
// tapping on a phone and keeps drawing frames while the van travels.
//   node tests/web/smoke.mjs <build-web-dir> [screenshot-dir]
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, resolve } from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium, devices } = require('playwright');

const root = resolve(process.argv[2] || 'build-web');
const shots = process.argv[3];
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.data': 'application/octet-stream' };

const server = createServer(async (req, res) => {
  const path = join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  try {
    const body = await readFile(path.endsWith('/') ? join(path, 'multiversal_van_life.html') : path);
    res.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${server.address().port}/multiversal_van_life.html`;

// Travel budget in headless Chromium with software WebGL (SwiftShader, about
// 15 fps at 640x360 on a desktop; a generator that stops yielding during the
// trip shows as frames of several seconds).
const MIN_TRAVEL_FPS = 6;
const MAX_TRAVEL_FRAME_MS = 1000;

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
let failures = 0;

async function waitReady(page) {
  await page.waitForFunction(() => document.getElementById('status').style.display === 'none', null, { timeout: 60000 });
  await page.waitForTimeout(1500);
}

async function run(name, contextOptions, checks) {
  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); if (process.env.MVL_WEB_VERBOSE) console.log('  [' + name + '] ' + m.text()); });
  await page.goto(url);
  await waitReady(page);
  const result = await checks(page);
  if (shots) await page.screenshot({ path: join(shots, `web-${name}.png`) });
  // WebGL canvases cannot be read back without preserveDrawingBuffer, so
  // judge the real screenshot: a blank frame compresses to almost nothing.
  const png = await page.screenshot();
  const blank = png.length < 15000;
  const problems = [...errors];
  if (blank) problems.push('canvas is blank');
  if (result !== true) problems.push(String(result));
  console.log(`${problems.length ? 'FAIL' : 'ok  '} ${name}${problems.length ? ': ' + problems.join(' | ') : ''}`);
  failures += problems.length ? 1 : 0;
  await context.close();
}

await run('desktop', { viewport: { width: 1280, height: 720 } }, async (page) => {
  // "New journey" is preselected without a save; hold the key like a person
  // (a press and release within one frame is not seen by the game)
  await page.keyboard.down('Enter');
  await page.waitForTimeout(120);
  await page.keyboard.up('Enter');
  await page.waitForTimeout(1500);
  // the new journey was saved to /save (IndexedDB): it must survive a reload
  await page.reload();
  await waitReady(page);
  const index = await page.evaluate(() => {
    try {
      return new TextDecoder().decode((Module.FS || FS).readFile('/save/index.ini'));
    } catch (e) {
      return 'unreadable: ' + e;
    }
  });
  if (!/story\.started = 1/.test(index)) return 'save did not survive a reload: ' + index;
  return true;
});

await run('mobile', { ...devices['Pixel 7'] }, async (page) => {
  const touch = await page.evaluate(() => Module.ccall ? true : false);
  if (!touch) return 'module not ready';
  // tap the USE button: layout units scale by k = min(1, aspect) on portrait
  // screens (x = aspect - 0.17k, y = 1 - 0.22k, in screen heights)
  const box = await page.locator('canvas').boundingBox();
  const k = Math.min(1, box.width / box.height);
  await page.touchscreen.tap(box.x + box.width - 0.17 * k * box.height, box.y + box.height * (1 - 0.22 * k));
  await page.waitForTimeout(1500);
  // the codex on a phone: pause (the II button), tap "Codex", tap a tab,
  // close it with X. The UI canvas is 240 units high, at least 400 wide.
  const aspect = box.width / box.height;
  const uh = Math.round(240 * aspect < 400 ? 400 / aspect : 240);
  const uw = Math.round(uh * aspect);
  const at = async (ux, uy) => {
    await page.touchscreen.tap(box.x + ux / uw * box.width, box.y + uy / uh * box.height);
    await page.waitForTimeout(400);
  };
  await page.touchscreen.tap(box.x + box.width - 0.08 * k * box.height, box.y + 0.1 * k * box.height);
  await page.waitForTimeout(600);
  const menuTop = Math.floor((uh - (34 + 4 * 14)) / 2);
  await at(uw / 2, menuTop + 46);     // "Codex", the pause menu's second item
  await at(63, 32);                   // the "Places" tab
  if (shots) await page.screenshot({ path: join(shots, 'web-mobile-codex.png') });
  await at(uw - 85, 15);              // X (left of the pause button) closes it
  const codex = await page.evaluate(() => {
    try {
      return new TextDecoder().decode((Module.FS || FS).readFile('/save/records/codex.rec'));
    } catch (e) {
      return 'unreadable: ' + e;
    }
  });
  if (!/opened/.test(codex)) return 'the codex did not open by tapping: ' + codex.slice(0, 200);
  return true;
});

// Travel frame rate: a scripted trip (?benchmark=travel, fresh profile)
// generates the destination while the van is in the vortex; the page must
// keep drawing frames all the way (no long stalls, a playable rate).
await run('travel', { viewport: { width: 640, height: 360 } }, async (page) => {
  const started = page.waitForEvent('console', { predicate: (m) => m.text().includes('benchmark: travel start'), timeout: 30000 });
  await page.goto(url + '?benchmark=travel');
  await started;
  const arrived = page.waitForEvent('console', { predicate: (m) => m.text().includes('benchmark: arrived'), timeout: 60000 })
    .then(() => true, () => false);
  const frames = await page.evaluate(() => new Promise((done) => {
    const times = [];
    const t0 = performance.now();
    const tick = (t) => {
      times.push(t);
      if (t - t0 < 4000) requestAnimationFrame(tick); else done(times);
    };
    requestAnimationFrame(tick);
  }));
  if (!(await arrived)) return 'the van never arrived';
  let worst = 0;
  for (let i = 1; i < frames.length; ++i) worst = Math.max(worst, frames[i] - frames[i - 1]);
  const fps = (frames.length - 1) / ((frames[frames.length - 1] - frames[0]) / 1000);
  console.log(`     travel: ${fps.toFixed(1)} fps, longest frame ${worst.toFixed(0)} ms`);
  if (fps < MIN_TRAVEL_FPS) return `travel ran at ${fps.toFixed(1)} fps (at least ${MIN_TRAVEL_FPS} wanted)`;
  if (worst > MAX_TRAVEL_FRAME_MS) return `a frame took ${worst.toFixed(0)} ms during travel (at most ${MAX_TRAVEL_FRAME_MS})`;
  return true;
});

await browser.close();
server.close();
process.exit(failures ? 1 : 0);
