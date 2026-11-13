// Multiversal Van Life - generates the game's voice lines with ElevenLabs
// text to speech (MIT License).
//
//   npm run generate                 # every missing line
//   npm run generate -- --only van_intro_1,van_call_1
//   npm run generate -- --force      # regenerate everything
//   npm run voices                   # list pre-made voices
//
// Reads game/voice/lines.txt, uses the voices in voices.json and writes
// game/voice/<id>.wav, which the game plays automatically when a line is
// shown. The API key is read from the ELEVENLABS_API_KEY environment
// variable by the SDK; it is never stored in the repository.
import { ElevenLabsClient } from '@elevenlabs/elevenlabs-js';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseLines, planJobs, pcmRate, pcmToWav, voiceFor } from './lib.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : null;
};

const voiceDir = resolve(option('--out') || join(here, '..', '..', 'game', 'voice'));
const config = JSON.parse(readFileSync(join(here, 'voices.json'), 'utf8'));

async function toBuffer(stream) {
  const chunks = [];
  for await (const chunk of stream) chunks.push(Buffer.from(chunk));
  return Buffer.concat(chunks);
}

async function main() {
  if (!process.env.ELEVENLABS_API_KEY) {
    console.error('ELEVENLABS_API_KEY is not set. Create a key at https://elevenlabs.io/app/api/api-keys and export it.');
    process.exit(1);
  }
  const client = new ElevenLabsClient();

  if (flag('--list-voices')) {
    const res = await client.voices.getAll();
    for (const v of res.voices) if (v.category === 'premade') console.log(`${v.voiceId}  ${v.name}`);
    return;
  }

  const lines = parseLines(readFileSync(join(voiceDir, 'lines.txt'), 'utf8'));
  const only = option('--only') ? option('--only').split(',') : null;
  const jobs = planJobs(lines, config, {
    only,
    force: flag('--force'),
    exists: (id) => existsSync(join(voiceDir, `${id}.wav`)),
  });
  const rate = pcmRate(config.output_format);
  console.log(`${jobs.length} line(s) to generate into ${voiceDir}`);
  let chars = 0;
  for (const line of jobs) {
    const voice = voiceFor(config, line.speaker);
    const audio = await client.textToSpeech.convert(voice.voice_id, {
      text: line.text,
      modelId: config.model_id,
      outputFormat: config.output_format,
      voiceSettings: { stability: voice.stability, similarityBoost: voice.similarity_boost },
    });
    const wav = pcmToWav(await toBuffer(audio), rate);
    writeFileSync(join(voiceDir, `${line.id}.wav`), wav);
    chars += line.text.length;
    console.log(`  ${line.id} (${line.speaker}) ${(wav.length / 1024).toFixed(0)} KiB`);
  }
  console.log(`done, ${chars} characters sent`);
}

main().catch((err) => {
  console.error(`voice generation failed: ${err.message || err}`);
  process.exit(1);
});
