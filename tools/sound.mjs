// Export music/raster-rumble.json to src/sound/ with the exporters of WebSidTracker (make sound).
// Usage: node tools/sound.mjs <folder of WebSidTracker>
//
// The tracker saves the project as raster_rumble.json: if that file is in music/, it becomes the new raster-rumble.json.
// Nothing is written until every check has passed.
import { existsSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';

const stop = (text) => { console.error('sound: ' + text); process.exit(1); };
const root = resolve(process.argv[2] ?? '../WebSidTracker');
if (!existsSync(root + '/web/model/export.js')) stop(`no WebSidTracker in ${root} (make sound WST=folder)`);
const load = (file) => import(`${root}/web/${file}`);
const { exportInstrumentsAsm, exportSfxAsm, exportSongAsm, projectFromJson } = await load('model/export.js');
const { lint, validate } = await load('model/project.js');
const { FORMAT, RELEASE } = await load('version.js');

const target = 'music/raster-rumble.json';
const saved = 'music/raster_rumble.json';
const source = existsSync(saved) ? saved : target;
if (source === saved && execFileSync('git', ['status', '--porcelain', '--', target]).length)
  stop(`${target} has changes that are not committed, ${saved} would overwrite them`);

const project = projectFromJson(readFileSync(source, 'utf8'));
const errors = validate(project);
if (errors.length) stop(`${source} is not valid: ${JSON.stringify(errors)}`);
const warnings = lint(project);
if (warnings.length) console.warn('sound: warnings: ' + JSON.stringify(warnings));

// the exported data must fit the player that is in the game
const player = /websidtracker format (\d+)/.exec(readFileSync('src/sound/music.asm', 'utf8'))?.[1];
if (Number(player) !== FORMAT) stop(`the tracker writes format ${FORMAT}, the player in src/sound is format ${player}`);

// the game knows the kick by its number (the raster bars pump on it)
const kick = Number(/^SND_KICK\s*=\s*(\d+)/m.exec(readFileSync('src/config.asm', 'utf8'))?.[1]);
if (!/kick/i.test(project.instruments[kick]?.name ?? '')) stop(`instrument ${kick} (SND_KICK) is not called a kick`);

const files = {
  'instruments.asm': exportInstrumentsAsm(project.instruments),
  'sfx.asm': exportSfxAsm(project.effects),
  'song_raster_rumble.asm': exportSongAsm(project.song, 'raster_rumble'),
};
for (const name of ['SFX_DODGE', 'SFX_CHAPTER', 'SFX_HIT', 'SFX_HIT_BODY'])
  if (!new RegExp(`^${name}\\s*=`, 'm').test(files['sfx.asm'])) stop(`the effect ${name} is missing`);

if (source === saved) renameSync(saved, target);
for (const [name, text] of Object.entries(files)) writeFileSync('src/sound/' + name, text);
console.log(`sound: exported ${source} with WebSidTracker ${RELEASE} (format ${FORMAT})`);
