// Multiversal Van Life - voice line helpers (MIT License).
// Pure functions shared by generate.mjs and the tests.

// Parses game/voice/lines.txt ("id | speaker | text", '#' comments).
export function parseLines(text) {
  const lines = [];
  for (const raw of text.split(/\r?\n/)) {
    if (/^\s*#/.test(raw) || !raw.includes('|')) continue;
    // only the first two '|' separate fields; the text may contain more
    const a = raw.indexOf('|');
    const b = raw.indexOf('|', a + 1);
    const id = raw.slice(0, a).trim();
    if (!id || b < 0) continue;
    lines.push({ id, speaker: raw.slice(a + 1, b).trim(), text: raw.slice(b + 1).trim() });
  }
  return lines;
}

// Settings for a speaker from voices.json (falls back to the default voice).
export function voiceFor(config, speaker) {
  return { ...config.default, ...((config.speakers || {})[speaker] || {}) };
}

// Decides which lines need audio. `exists(id)` reports already generated files.
export function planJobs(lines, config, { only = null, force = false, exists = () => false } = {}) {
  const skip = new Set(config.skip_speakers || []);
  return lines.filter((l) => l.text && !skip.has(l.speaker) && (!only || only.includes(l.id)) && (force || !exists(l.id)));
}

// Sample rate encoded in an ElevenLabs "pcm_<rate>" output format.
export function pcmRate(format) {
  const m = /^pcm_(\d+)$/.exec(format || '');
  if (!m) throw new Error(`output_format must be pcm_<rate> so the game can load it as WAV, got ${format}`);
  return Number(m[1]);
}

// Wraps raw signed 16-bit little-endian mono PCM in a WAV header.
export function pcmToWav(pcm, rate) {
  const header = Buffer.alloc(44);
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}
