// Tests for the audio manifest helpers (node --test). MIT License.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { crossfadeLoop, finishSound, isPlanError, PEAK, pcmToMono, planJobs, processSamples, requestFor, validateManifest, wavFromSamples } from './lib.mjs';

const manifest = JSON.parse(readFileSync(new URL('./manifest.json', import.meta.url), 'utf8'));

test('the shipped manifest is valid', () => {
  assert.deepEqual(validateManifest(manifest), []);
  for (const kind of ['sfx', 'loop', 'music']) assert.ok(manifest.entries.some((e) => e.kind === kind), kind);
});

test('validation catches mistakes', () => {
  const bad = { entries: [
    { id: 'a', kind: 'sfx', prompt: 'a short sound here', duration: 1, out: 'sounds/a.mp3' },
    { id: 'a', kind: 'beep', prompt: 'x', duration: 99, out: '../evil.wav' },
    { id: 'm', kind: 'music', prompt: 'a long enough prompt', duration: 1, out: 'music/m.wav' },
  ] };
  const p = validateManifest(bad).join('\n');
  assert.match(p, /must be WAV/);
  assert.match(p, /duplicate/);
  assert.match(p, /unknown kind/);
  assert.match(p, /prompt too short/);
  assert.match(p, /bad output path/);
  assert.match(p, /music must be MP3/);
  assert.match(p, /duration/);
  assert.deepEqual(validateManifest({ entries: [] }), ['no entries']);
});

test('plans missing or selected entries', () => {
  const all = planJobs(manifest);
  assert.equal(all.length, manifest.entries.length);
  assert.equal(planJobs(manifest, { exists: () => true }).length, 0);
  assert.equal(planJobs(manifest, { exists: () => true, force: true }).length, manifest.entries.length);
  assert.deepEqual(planJobs(manifest, { only: ['door'] }).map((e) => e.id), ['door']);
});

test('builds ElevenLabs requests', () => {
  const loop = requestFor(manifest, manifest.entries.find((e) => e.kind === 'loop'));
  assert.equal(loop.api, 'sfx');
  assert.equal(loop.body.loop, true);
  assert.equal(loop.body.outputFormat, 'pcm_22050');
  assert.equal(loop.body.modelId, 'eleven_text_to_sound_v3');
  const music = requestFor(manifest, manifest.entries.find((e) => e.kind === 'music'));
  assert.equal(music.api, 'music');
  assert.equal(music.body.forceInstrumental, true);
  assert.equal(music.body.musicLengthMs, 60000);
  const sfx = requestFor(manifest, { kind: 'sfx', prompt: 'p', duration: 1, out: 'sounds/x.wav' });
  assert.equal(sfx.body.promptInfluence, 0.5);
  assert.equal(sfx.body.loop, false);
});

test('recognises plan errors', () => {
  assert.ok(isPlanError({ statusCode: 402 }));
  assert.ok(isPlanError({ message: 'paid_plan_required' }));
  assert.ok(isPlanError({ status: 403, message: 'forbidden' }));
  assert.ok(!isPlanError({ statusCode: 500, message: 'server error' }));
  assert.ok(!isPlanError(new Error('socket hang up')));
});

test('downmixes interleaved stereo PCM', () => {
  const pcm = Buffer.alloc(8);
  pcm.writeInt16LE(100, 0); pcm.writeInt16LE(300, 2); pcm.writeInt16LE(-50, 4); pcm.writeInt16LE(-150, 6);
  assert.deepEqual(Array.from(pcmToMono(pcm, 2)), [200, -100]);
  assert.deepEqual(Array.from(pcmToMono(pcm, 1)), [100, 300, -50, -150]);
});

test('trims, fades and normalises one-shots', () => {
  const rate = 1000;
  const s = new Int16Array(1000);
  for (let i = 300; i < 600; i++) s[i] = i % 2 ? 1000 : -1000;
  const out = processSamples(s, rate, 'sfx');
  assert.ok(out.length < 400 && out.length > 300, `length ${out.length}`);
  assert.equal(out[0], 0);
  assert.equal(out[out.length - 1], 0);
  assert.equal(Math.max(...out.map(Math.abs)), PEAK);
});

test('loops get a seamless crossfade instead of trimming', () => {
  const s = Int16Array.from({ length: 1000 }, (_, i) => (i < 500 ? 0 : 2000));
  const out = processSamples(s, 1000, 'loop');
  assert.equal(out.length, 940);
  assert.equal(out[939], PEAK);
  assert.equal(out[0], PEAK); // the start continues where the end left off
  assert.ok(Math.abs(out[30] - PEAK / 2) < 2);
  assert.equal(crossfadeLoop(Int16Array.from([1, 2, 3, 4]), 10).length, 2);
});

test('silence is rejected', () => {
  assert.throws(() => processSamples(new Int16Array(100), 1000, 'sfx'), /silent/);
});

test('writes mono WAV files', () => {
  const wav = wavFromSamples(Int16Array.from([1, -2]), 22050);
  assert.equal(wav.length, 48);
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.readUInt16LE(22), 1);
  assert.equal(wav.readUInt32LE(24), 22050);
  assert.equal(wav.readInt16LE(46), -2);
  const pcm = Buffer.alloc(400);
  for (let i = 0; i < 100; i++) { pcm.writeInt16LE(5000, i * 4); pcm.writeInt16LE(5000, i * 4 + 2); }
  const done = finishSound({ pcm_rate: 100 }, { kind: 'loop' }, pcm);
  assert.equal(done.readUInt32LE(40), 2 * (100 - 6));
});
