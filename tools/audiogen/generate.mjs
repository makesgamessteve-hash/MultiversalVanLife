// Multiversal Van Life - generates the game's sound effects, ambience loops
// and music with ElevenLabs (MIT License).
//
//   npm run generate                         # every missing file
//   npm run generate -- --only step,door     # selected entries
//   npm run generate -- --force              # regenerate everything
//   npm run plan                             # show what would be generated
//
// Reads manifest.json and writes into game/ (WAV for sounds and loops, MP3
// for music). The API key is read from ELEVENLABS_API_KEY by the SDK and is
// never stored. Music needs a paid ElevenLabs plan: entries the plan cannot
// generate are skipped and existing files are kept.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { finishSound, isPlanError, planJobs, requestFor, validateManifest } from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
};

if (flag('--help') || flag('-h')) {
  console.log(`usage: node generate.mjs [--plan] [--force] [--only id,id] [--out game-dir]

Generates the entries of manifest.json with ElevenLabs into the game folder.
  --plan    list the entries that would be generated and exit (no API calls)
  --force   regenerate entries whose files already exist
  --only    comma separated entry ids
  --out     game folder (default: ../../game)
Requires ELEVENLABS_API_KEY in the environment (except --plan and --help).
Behind an HTTPS proxy run Node with NODE_USE_ENV_PROXY=1.`);
  process.exit(0);
}

const gameDir = resolve(option('--out') || join(here, '..', '..', 'game'));
const manifest = JSON.parse(readFileSync(join(here, 'manifest.json'), 'utf8'));
const problems = validateManifest(manifest);
if (problems.length) {
  console.error('manifest problems:\n  ' + problems.join('\n  '));
  process.exit(1);
}
const jobs = planJobs(manifest, {
  only: option('--only') ? option('--only').split(',') : null,
  force: flag('--force'),
  exists: (out) => existsSync(join(gameDir, out)),
});

if (flag('--plan')) {
  for (const e of jobs) console.log(`${e.kind.padEnd(5)} ${e.id.padEnd(16)} ${e.duration}s -> ${e.out}`);
  console.log(`${jobs.length} entr${jobs.length === 1 ? 'y' : 'ies'} to generate`);
  process.exit(0);
}

if (!process.env.ELEVENLABS_API_KEY) {
  console.error('ELEVENLABS_API_KEY is not set. Create a key at https://elevenlabs.io/app/api/api-keys and export it.');
  process.exit(1);
}

async function toBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

const { ElevenLabsClient } = await import('@elevenlabs/elevenlabs-js');
const client = new ElevenLabsClient();
const skipped = [];
let failed = 0;
for (const e of jobs) {
  const req = requestFor(manifest, e);
  try {
    const stream = req.api === 'music' ? await client.music.compose(req.body) : await client.textToSoundEffects.convert(req.body);
    const audio = await toBuffer(stream);
    const data = req.api === 'music' ? audio : finishSound(manifest, e, audio);
    const target = join(gameDir, e.out);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, data);
    console.log(`  ${e.id.padEnd(16)} ${(data.length / 1024).toFixed(0)} KiB -> ${e.out}`);
  } catch (err) {
    if (isPlanError(err)) {
      skipped.push(e.id);
      console.warn(`  ${e.id.padEnd(16)} skipped: not available on this ElevenLabs plan (existing file kept)`);
    } else {
      failed++;
      console.error(`  ${e.id.padEnd(16)} failed: ${err.message || err}`);
    }
  }
}
if (skipped.length) console.log(`skipped (plan): ${skipped.join(', ')}`);
process.exit(failed ? 1 : 0);
