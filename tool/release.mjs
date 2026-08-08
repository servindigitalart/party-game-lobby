#!/usr/bin/env node
// tool/release.mjs
//
// Release pipeline for Bufón. Driven through npm scripts:
//
//   npm run verify      every check, nothing deployed
//   npm run release     checks, then deploy rules → indexes → functions
//
// Node rather than a shell script so it runs the same on macOS, Linux and
// Windows. Every external command is spawned through the platform shell so
// `flutter`/`firebase` resolve from PATH on all three.

import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { createInterface } from 'node:readline/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

const args = new Set(process.argv.slice(2));
const DEPLOY = args.has('--deploy');
const ASSUME_YES = args.has('--yes');
const projectArg = process.argv
  .slice(2)
  .find((a) => a.startsWith('--project='));

// ---------------------------------------------------------------------------
// Output
// ---------------------------------------------------------------------------

const color = process.stdout.isTTY && !process.env.NO_COLOR;
const paint = (code, text) => (color ? `[${code}m${text}[0m` : text);
const bold = (t) => paint('1', t);
const green = (t) => paint('32', t);
const red = (t) => paint('31', t);
const yellow = (t) => paint('33', t);
const dim = (t) => paint('2', t);

const results = [];

function heading(text) {
  console.log(`\n${bold(`── ${text} ${'─'.repeat(Math.max(0, 56 - text.length))}`)}`);
}

// ---------------------------------------------------------------------------
// Command runner
// ---------------------------------------------------------------------------

/**
 * Runs a command, streaming its output. Resolves with the exit code.
 *
 * `shell: true` is what makes this portable: `flutter` is `flutter.bat` on
 * Windows and a shim on POSIX, and neither resolves through a bare spawn.
 */
function run(command, { cwd = ROOT, capture = false } = {}) {
  return new Promise((resolve) => {
    const child = spawn(command, {
      cwd,
      shell: true,
      stdio: capture ? ['ignore', 'pipe', 'pipe'] : 'inherit',
    });

    let output = '';
    if (capture) {
      child.stdout.on('data', (d) => (output += d));
      child.stderr.on('data', (d) => (output += d));
    }

    child.on('close', (code) => resolve({ code: code ?? 1, output }));
    child.on('error', () => resolve({ code: 1, output }));
  });
}

/** Runs one pipeline step and records its outcome. */
async function step(name, command, options) {
  heading(name);
  console.log(dim(`$ ${command}`));
  const { code } = await run(command, options);
  const ok = code === 0;
  results.push({ name, ok });
  if (!ok) {
    console.log(red(`\n✗ ${name} failed (exit ${code})`));
    summarise();
    process.exit(code);
  }
  console.log(green(`✓ ${name}`));
}

// ---------------------------------------------------------------------------
// Preflight
// ---------------------------------------------------------------------------

async function requireTool(name, command, hint) {
  const { code, output } = await run(command, { capture: true });
  if (code !== 0) {
    console.log(red(`✗ ${name} is not available.`));
    console.log(`  ${hint}`);
    process.exit(1);
  }
  const version = output.trim().split('\n')[0];
  console.log(`${green('✓')} ${name} ${dim(version)}`);
}

/**
 * Resolves the Firebase project this release targets and refuses anything
 * unexpected.
 *
 * The default comes from `.firebaserc` rather than from whatever `firebase
 * use` happens to be set to, so a stale local alias cannot silently redirect
 * a deploy at another project.
 */
function resolveProject() {
  const rc = JSON.parse(readFileSync(path.join(ROOT, '.firebaserc'), 'utf8'));
  const configured = rc.projects?.default;

  if (!configured) {
    console.log(red('✗ .firebaserc has no default project.'));
    process.exit(1);
  }

  const target = projectArg ? projectArg.split('=')[1] : configured;

  if (target !== configured) {
    console.log(
      yellow(
        `! Target ${bold(target)} differs from .firebaserc default ${bold(configured)}.`
      )
    );
  }

  // A demo project only exists inside the emulator. Deploying to one is
  // always a mistake, and it fails late and confusingly.
  if (target.startsWith('demo-')) {
    console.log(red(`✗ ${target} is an emulator-only project. Refusing.`));
    process.exit(1);
  }

  return target;
}

async function verifyProjectAccess(project) {
  const { code, output } = await run(
    `firebase projects:list --json`,
    { capture: true }
  );

  if (code !== 0) {
    console.log(red('✗ Could not list Firebase projects.'));
    console.log('  Run `firebase login` and try again.');
    process.exit(1);
  }

  let ids = [];
  try {
    const parsed = JSON.parse(output.slice(output.indexOf('{')));
    ids = (parsed.result ?? []).map((p) => p.projectId);
  } catch {
    console.log(yellow('! Could not parse the project list; skipping check.'));
    return;
  }

  if (!ids.includes(project)) {
    console.log(red(`✗ ${project} is not a project this account can access.`));
    console.log(`  Available: ${ids.join(', ') || '(none)'}`);
    process.exit(1);
  }
  console.log(`${green('✓')} Firebase project ${bold(project)} is accessible`);
}

async function confirm(project) {
  if (ASSUME_YES) return;
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(
    `\n${yellow('About to deploy to')} ${bold(project)}. Type the project id to continue: `
  );
  rl.close();
  if (answer.trim() !== project) {
    console.log(red('✗ Aborted.'));
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

function summarise() {
  const width = Math.max(...results.map((r) => r.name.length), 20);
  console.log(`\n${bold('─'.repeat(width + 8))}`);
  for (const r of results) {
    console.log(
      `${r.name.padEnd(width)}  ${r.ok ? green('PASS') : red('FAIL')}`
    );
  }
  console.log(bold('─'.repeat(width + 8)));
}

// ---------------------------------------------------------------------------
// Pipeline
// ---------------------------------------------------------------------------

heading('Preflight');
await requireTool(
  'Firebase CLI',
  'firebase --version',
  'Install it with: npm install -g firebase-tools'
);
await requireTool(
  'Flutter',
  'flutter --version',
  'Install Flutter and make sure it is on PATH.'
);

const project = resolveProject();
await verifyProjectAccess(project);
results.push({ name: 'Preflight', ok: true });

// Checks. Every one of these must pass before anything is deployed.
await step('Flutter Analyze', 'flutter analyze', {
  cwd: path.join(ROOT, 'bufon_flutter'),
});
await step('Flutter Tests', 'flutter test', {
  cwd: path.join(ROOT, 'bufon_flutter'),
});
await step('Functions Build', 'npm --prefix functions run build');
await step('Functions Tests', 'npm --prefix functions test');
await step(
  'Firestore Rules Tests',
  // A demo project id keeps the emulator from touching a real one.
  'firebase emulators:exec --only firestore --project demo-bufon "npm --prefix firestore-tests test"'
);
await step(
  'Integration Tests',
  'firebase emulators:exec --only firestore,functions,auth --project demo-bufon "node --test functions/integration.test.mjs"'
);

if (!DEPLOY) {
  summarise();
  console.log(green(bold('\nAll checks passed. Nothing deployed.')));
  console.log(dim('Run `npm run release` to deploy.'));
  process.exit(0);
}

await confirm(project);

// Deploy order matters. The hardened rules are compatible with the client
// that is already in the field, so shipping them first is safe. The reverse
// is not: functions that write under new paths would be rejected by the old
// rules.
await step(
  'Deploy Rules',
  `firebase deploy --only firestore:rules --project ${project} --non-interactive`
);
await step(
  'Deploy Indexes',
  `firebase deploy --only firestore:indexes --project ${project} --non-interactive`
);
await step(
  'Deploy Functions',
  `firebase deploy --only functions --project ${project} --non-interactive`
);

summarise();
console.log(green(bold(`\nRelease complete → ${project}`)));
console.log(
  dim('The Flutter build is a separate step; see docs/releases/RELEASE_PIPELINE.md.')
);
