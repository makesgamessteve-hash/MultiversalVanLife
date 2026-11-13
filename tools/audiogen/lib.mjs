// Multiversal Van Life - audio manifest helpers (MIT License).
// Pure functions shared by generate.mjs and the tests.

export const KINDS = ['sfx', 'loop', 'music'];

// Validates a manifest and returns a list of problems (empty when fine).
export function validateManifest(m) {
  const problems = [];
  const ids = new Set();
  for (const e of m.entries || []) {
    if (!e.id || ids.has(e.id)) problems.push(`duplicate or missing id: ${e.id}`);
    ids.add(e.id);
    if (!KINDS.includes(e.kind)) problems.push(`${e.id}: unknown kind ${e.kind}`);
    if (!e.prompt || e.prompt.length < 10) problems.push(`${e.id}: prompt too short`);
    if (!/^(sounds|music)\/[a-z0-9_]+\.(wav|mp3)$/.test(e.out || '')) problems.push(`${e.id}: bad output path ${e.out}`);
    if (e.kind === 'music' && !e.out.endsWith('.mp3')) problems.push(`${e.id}: music must be MP3`);
    if (e.kind !== 'music' && !e.out.endsWith('.wav')) problems.push(`${e.id}: sound effects and loops must be WAV`);
    const max = e.kind === 'music' ? 600 : 30;
    const min = e.kind === 'music' ? 3 : 0.5;
    if (!(e.duration >= min && e.duration <= max)) problems.push(`${e.id}: duration must be ${min}..${max} s`);
  }
  if (!(m.entries || []).length) problems.push('no entries');
  return problems;
}

// Entries to generate: all, or `only` ids, skipping existing files unless forced.
export function planJobs(m, { only = null, force = false, exists = () => false } = {}) {
  return m.entries.filter((e) => (!only || only.includes(e.id)) && (force || !exists(e.out)));
}

// The ElevenLabs request for an entry.
export function requestFor(m, e) {
  if (e.kind === 'music') {
    return {
      api: 'music',
      body: { prompt: e.prompt, musicLengthMs: Math.round(e.duration * 1000), modelId: m.music_model,
              forceInstrumental: true, outputFormat: 'mp3_44100_128' },
    };
  }
  return {
    api: 'sfx',
    body: { text: e.prompt, modelId: m.sfx_model, durationSeconds: e.duration, promptInfluence: e.influence ?? 0.5,
            loop: e.kind === 'loop', outputFormat: `pcm_${m.pcm_rate || 22050}` },
  };
}

// True for errors that mean "your plan cannot do this" (skip, keep old file).
export function isPlanError(err) {
  const status = err && (err.statusCode || err.status);
  const text = String((err && (err.message || err.body && JSON.stringify(err.body))) || err);
  return status === 402 || status === 403 || /paid_plan_required|subscription|plan|not available on your/i.test(text);
}

// ElevenLabs returns raw PCM as signed 16-bit little-endian interleaved
// stereo. The engine mixes in mono, so channels are averaged.
export function pcmToMono(pcm, channels = 2) {
  const frames = Math.floor(pcm.length / (2 * channels));
  const out = new Int16Array(frames);
  for (let i = 0; i < frames; i++) {
    let acc = 0;
    for (let c = 0; c < channels; c++) acc += pcm.readInt16LE((i * channels + c) * 2);
    out[i] = Math.round(acc / channels);
  }
  return out;
}

export const PEAK = Math.round(32767 * Math.pow(10, -3 / 20)); // -3 dBFS

// Makes a loop seamless at the sample level: its last `k` samples are
// crossfaded into the first `k` and dropped, so the end flows into the start.
export function crossfadeLoop(s, k) {
  k = Math.min(k, Math.floor(s.length / 2));
  const n = s.length - k;
  const out = Float32Array.from(s.subarray(0, n));
  for (let i = 0; i < k; i++) {
    const t = i / k;
    out[i] = s[i] * t + s[n + i] * (1 - t);
  }
  return out;
}

// Prepares generated audio for the game: one-shots lose leading and trailing
// silence and get short fades, loops get a 60 ms seam crossfade; everything
// is normalised to -3 dBFS. Throws on (near) silence.
export function processSamples(samples, rate, kind) {
  let peak = 0;
  for (const v of samples) peak = Math.max(peak, Math.abs(v));
  if (peak < 33) throw new Error('generated audio is silent; try another prompt');
  let s = samples;
  if (kind !== 'sfx') {
    s = crossfadeLoop(s, Math.round(rate * 0.06));
    peak = 0;
    for (const v of s) peak = Math.max(peak, Math.abs(v));
  } else {
    let a = 0;
    let b = s.length - 1;
    while (a < b && Math.abs(s[a]) < peak * 0.02) a++;
    while (b > a && Math.abs(s[b]) < peak * 0.01) b--;
    a = Math.max(0, a - Math.round(rate * 0.005));
    b = Math.min(s.length - 1, b + Math.round(rate * 0.02));
    s = s.slice(a, b + 1);
    const fadeIn = Math.min(Math.round(rate * 0.003), s.length);
    const fadeOut = Math.min(Math.round(rate * 0.02), s.length);
    s = Float32Array.from(s);
    for (let i = 0; i < fadeIn; i++) s[i] *= i / fadeIn;
    for (let i = 0; i < fadeOut; i++) s[s.length - 1 - i] *= i / fadeOut;
  }
  const gain = PEAK / peak;
  const out = new Int16Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = Math.max(-32768, Math.min(32767, Math.round(s[i] * gain)));
  return out;
}

// A 16-bit mono PCM WAV file.
export function wavFromSamples(samples, rate) {
  const header = Buffer.alloc(44);
  const bytes = samples.length * 2;
  header.write('RIFF', 0);
  header.writeUInt32LE(36 + bytes, 4);
  header.write('WAVE', 8);
  header.write('fmt ', 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36);
  header.writeUInt32LE(bytes, 40);
  const body = Buffer.alloc(bytes);
  for (let i = 0; i < samples.length; i++) body.writeInt16LE(samples[i], i * 2);
  return Buffer.concat([header, body]);
}

// Raw API output -> finished WAV file for an entry.
export function finishSound(m, e, pcm) {
  const rate = m.pcm_rate || 22050;
  return wavFromSamples(processSamples(pcmToMono(pcm, m.pcm_channels || 2), rate, e.kind), rate);
}
