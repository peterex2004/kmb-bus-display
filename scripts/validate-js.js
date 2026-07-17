#!/usr/bin/env node
// Lightweight validation gate for this no-build, single-file app.
// Extracts the inline <script> block from index.html and parse-checks it, then
// runs the pinned board logic regression test without a test framework/build.
const fs = require('fs');
const { spawnSync } = require('child_process');

const html = fs.readFileSync('index.html', 'utf8');
const match = html.match(/<script>([\s\S]*?)<\/script>/);

if (!match) {
  console.error('FAIL: no inline <script> block found in index.html');
  process.exit(1);
}

try {
  new Function(match[1]);
} catch (e) {
  console.error('FAIL: JS syntax error in index.html inline script');
  console.error(e.message);
  process.exit(1);
}

console.log('PASS: index.html inline script is syntactically valid');

const regression = spawnSync(process.execPath, ['scripts/test-board.mjs'], { stdio: 'inherit' });
if (regression.status !== 0) {
  console.error('FAIL: board regression tests failed');
  process.exit(regression.status || 1);
}
console.log('PASS: board regression tests ran');
