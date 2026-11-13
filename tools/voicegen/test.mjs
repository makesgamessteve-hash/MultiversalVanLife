// Tests for the voice line helpers (node --test). MIT License.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseLines, planJobs, pcmRate, pcmToWav, voiceFor } from './lib.mjs';

const config = JSON.parse(readFileSync(new URL('./voices.json', import.meta.url), 'utf8'));

test('parses the game dialogue file', () => {
  const text = readFileSync(new URL('../../game/voice/lines.txt', import.meta.url), 'utf8');
  const lines = parseLines(text);
  assert.ok(lines.length > 30);
  const intro = lines.find((l) => l.id === 'van_intro_3');
  assert.equal(intro.speaker, 'juniper');
  assert.match(intro.text, /Juniper/);
  assert.equal(new Set(lines.map((l) => l.id)).size, lines.length, 'ids are unique');
});

test('keeps pipes inside text and skips comments', () => {
  const lines = parseLines('# c\nfoo | bob | a | b\n\nnot a line\n | x | y\n');
  assert.deepEqual(lines, [{ id: 'foo', speaker: 'bob', text: 'a | b' }]);
});

test('plans only missing, voiced lines', () => {
  const lines = [
    { id: 'a', speaker: 'juniper', text: 'hi' },
    { id: 'b', speaker: 'narrator', text: 'skip me' },
    { id: 'c', speaker: 'mabel', text: 'hello' },
    { id: 'd', speaker: 'mabel', text: '' },
  ];
  assert.deepEqual(planJobs(lines, config).map((l) => l.id), ['a', 'c']);
  assert.deepEqual(planJobs(lines, config, { exists: (id) => id === 'a' }).map((l) => l.id), ['c']);
  assert.deepEqual(planJobs(lines, config, { exists: () => true, force: true }).map((l) => l.id), ['a', 'c']);
  assert.deepEqual(planJobs(lines, config, { only: ['c'] }).map((l) => l.id), ['c']);
});

test('picks speaker voices with defaults', () => {
  assert.equal(voiceFor(config, 'juniper').stability, 0.45);
  assert.equal(voiceFor(config, 'unknown').voice_id, config.default.voice_id);
});

test('wraps PCM into a WAV the engine can read', () => {
  const pcm = Buffer.from([1, 0, 2, 0, 3, 0]);
  const wav = pcmToWav(pcm, pcmRate('pcm_22050'));
  assert.equal(wav.length, 50);
  assert.equal(wav.toString('ascii', 0, 4), 'RIFF');
  assert.equal(wav.readUInt32LE(24), 22050);
  assert.equal(wav.readUInt32LE(40), 6);
  assert.throws(() => pcmRate('mp3_44100_128'), /pcm_/);
});
