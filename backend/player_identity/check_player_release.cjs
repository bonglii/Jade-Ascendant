'use strict';
// Temporary runner for the draft QA branch. All runtime work is isolated from the checkout.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { qa, runProcess } = require('./check_event_touch.cjs');

const base = 'b9c64f2ebd0009375af4aa01578f8b1adf98321f';
const combatFiles = [
  'scripts/effects/actor_presentation.gd',
  'scripts/effects/combat_feedback.gd',
  'scripts/enemy/enemy_2.gd',
  'scripts/enemy/enemy_3.gd',
  'scripts/enemy/enemy_spawner.gd'
];
const suites = [
  ['home_connection_readiness_smoke', 'HOME_CONNECTION_READINESS', 'jade_connection_combat_qa'],
  ['home_connection_ui_smoke', 'HOME_CONNECTION_UI', 'jade_connection_combat_qa'],
  ['hero_popup_polish_smoke', 'HERO_POPUP_POLISH_CHECKS=', 'jade_hero_qa'],
  ['player_content_batch_smoke', 'PLAYER_CONTENT_BATCH_QA', 'jade_paid_v2_qa'],
  ['menu_experience_smoke', 'MENU_EXPERIENCE_QA', 'jade_paid_v2_qa'],
  ['run_entry_reliability_smoke', 'RUN_ENTRY_RELIABILITY checks=', 'jade_event_touch_qa'],
  ['stage_records_smoke', 'STAGE_RECORDS checks=', 'jade_event_touch_qa'],
  ['player_journey_layout_smoke', 'PLAYER_JOURNEY_LAYOUT checks=', 'jade_event_touch_qa', true],
  ['run_review_layout_smoke', 'RUN_REVIEW_LAYOUT checks=', 'jade_event_touch_qa', true],
  ['combat_fairness_smoke', 'COMBAT_FAIRNESS_QA', 'jade_combat_fairness_qa'],
  ['crowd_performance_smoke', 'CROWD_PERFORMANCE_CHECKS=', 'jade_crowd_qa'],
  ['pavilion_focus_smoke', 'PAVILION_FOCUS checks=', 'jade_pavilion_focus_qa', true],
  ['event_scroll_surface_smoke', 'EVENT_SCROLL_SURFACE checks=', 'jade_event_touch_qa', true],
  ['player_decisions_matrix', 'DECISION_MATRIX checks=', 'jade_decision_qa']
];

async function check(project, godot) {
  const root = fs.realpathSync(project);
  const receipt = fs.mkdtempSync(path.join(process.env.RUNNER_TEMP || os.tmpdir(), 'jade-decisions-qa-'));
  const logs = path.join(receipt, 'runtime');
  process.env.XDG_DATA_HOME = path.join(receipt, 'userdata');
  process.env.XDG_CONFIG_HOME = path.join(receipt, 'config');
  process.env.XDG_CACHE_HOME = path.join(receipt, 'cache');
  process.env.GODOT_SILENCE_ROOT_WARNING = '1';
  const images = path.join(receipt, 'images');
  fs.mkdirSync(images);
  process.env.JADE_JOURNEY_RENDER_DIR = images;
  process.env.JADE_COMBAT_RENDER_DIR = images;

  const engine = spawnSync(godot, ['--version'], { encoding: 'utf8' });
  if (engine.status !== 0 || !/^4\.7\.2\./.test(engine.stdout.trim())) throw Error('Pinned Godot 4.7.2 required');
  console.log('DECISION_ENGINE ' + engine.stdout.trim());
  await qa(root, godot, { only: [], logs: receipt });
  const fixture = path.join(receipt, 'fixture');
  const config = path.join(fixture, 'project.godot');
  const baseline = fs.readFileSync(config, 'utf8');
  const issues = [];

  async function run(script, marker, prefix, { native = false, extra = [], name = script, userArgs = [] } = {}) {
    fs.writeFileSync(config, baseline.replace(/config\/custom_user_dir_name="[^"\r\n]*"/,
      'config/custom_user_dir_name="' + prefix + '_jade_event_touch_qa_' + randomUUID() + '"'));
    const args = ['--audio-driver', 'Dummy', '--path', fixture, ...extra, '--script', 'res://tests/' + script + '.gd', '--', ...userArgs];
    const command = native ? 'xvfb-run' : godot;
    const commandArgs = native ? ['-a', '-s', '-screen 0 1280x1600x24 -nolisten tcp', godot, ...args] : ['--headless', ...args];
    try {
      await runProcess(command, commandArgs, { cwd: receipt, logs, name, marker, idleMs: 80000, totalMs: 145000 });
      return true;
    } catch (error) {
      const source = path.join(logs, name + '.log');
      if (fs.existsSync(source)) {
        const lines = fs.readFileSync(source, 'utf8').split(/\r?\n/);
        for (const line of lines.filter(line => /^(DECISION_CASE|DECISIONS_FAIL|DECISION_MATRIX|CROWD_PAIRED|SCRIPT ERROR|ERROR:|REAL_SCROLL)/.test(line)).slice(-120)) console.log(line);
      }
      console.log('DECISION_SUITE_FAIL ' + name + ' ' + error.message);
      issues.push(name);
      return false;
    }
  }

  for (const [script, marker, prefix, native] of suites) await run(script, marker, prefix, { native });

  const fetch = spawnSync('git', ['fetch', '--no-tags', '--depth=1', 'origin', base], { cwd: root, encoding: 'utf8' });
  if (fetch.status !== 0) throw Error('Baseline fetch failed: ' + fetch.stderr);
  const source = new Map(combatFiles.map(file => {
    const ref = spawnSync('git', ['show', base + ':' + file], { cwd: root });
    if (ref.status !== 0) throw Error('Cannot read baseline ' + file);
    return [file, { base: ref.stdout, candidate: fs.readFileSync(path.join(fixture, file)) }];
  }));
  for (const [chapter, enemies] of [[1, 96], [5, 110]]) {
    for (let round = 1; round <= 3; round++) {
      const order = round % 2 ? ['base', 'candidate'] : ['candidate', 'base'];
      for (const side of order) {
        for (const [file, versions] of source) fs.writeFileSync(path.join(fixture, file), versions[side]);
        const name = 'crowd-' + chapter + '-' + round + '-' + side;
        console.log('CROWD_CASE ' + name);
        await run('player_crowd_paired', 'CROWD_PAIRED ', 'jade_crowd_qa', {
          name, extra: ['--fixed-fps', '60', '--disable-render-loop'], userArgs: [String(chapter), String(enemies)]
        });
      }
    }
  }
  const evidence = fs.readdirSync(logs).filter(name => name.endsWith('.log')).map(name => path.join(logs, name));
  // The existing workflow uploads this path on its disposable runner.
  const upload = path.join(root, '.local/player_release_qa');
  fs.mkdirSync(upload, { recursive: true });
  for (const file of evidence) fs.copyFileSync(file, path.join(upload, path.basename(file)));
  fs.cpSync(images, path.join(upload, 'images'), { recursive: true });
  console.log('DECISION_BATCH issues=' + JSON.stringify(issues));
  if (issues.length) process.exitCode = 1;
}

check(process.argv[2], process.argv[3]).catch(error => {
  console.error('DECISION_RUNNER_STOP ' + error.message);
  process.exitCode = 1;
});
