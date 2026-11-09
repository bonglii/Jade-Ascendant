'use strict';
// Temporary runner for the draft QA branch. All runtime work is isolated from the checkout.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawnSync } = require('node:child_process');
const { qa, runProcess } = require('./check_event_touch.cjs');

const suites = [
  ['run_review_layout_smoke', 'RUN_REVIEW_LAYOUT checks=', 'jade_event_touch_qa', true]
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
        for (const line of lines.filter(line => /^(DECISION_CASE|DECISIONS_FAIL|DECISION_MATRIX|CROWD_PAIRED|RUN_REVIEW_SWIPE|SCRIPT ERROR|ERROR:|REAL_SCROLL)/.test(line)).slice(-120)) console.log(line);
      }
      console.log('DECISION_SUITE_FAIL ' + name + ' ' + error.message);
      issues.push(name);
      return false;
    }
  }

  for (const [script, marker, prefix, native] of suites) {
    const name = script + (native ? '-native' : '');
    await run(script, marker, prefix, { native, name });
  }

  const evidence = fs.readdirSync(logs).filter(name => name.endsWith('.log')).map(name => path.join(logs, name));
  // The existing workflow uploads this path on its disposable runner.
  const upload = path.join(root, '.local/player_release_qa');
  fs.mkdirSync(upload, { recursive: true });
  for (const file of evidence) fs.copyFileSync(file, path.join(upload, path.basename(file)));
  const review = fs.readFileSync(path.join(logs,"run_review_layout_smoke-native.log"), "utf8");
  for (const line of review.split(/\r?\n/).filter(line => line.startsWith("RUN_REVIEW_SWIPE"))) console.log(line);
  fs.cpSync(images, path.join(upload, 'images'), { recursive: true });
  console.log('DECISION_BATCH issues=' + JSON.stringify(issues));
  if (issues.length) process.exitCode = 1;
}

check(process.argv[2], process.argv[3]).catch(error => {
  console.error('DECISION_RUNNER_STOP ' + error.message);
  process.exitCode = 1;
});
