#!/usr/bin/env node
// Lightweight validation gate for this no-build, single-file app.
// Extracts the inline <script> block from index.html and parse-checks it.
// Catches real JS syntax errors without needing a test framework or build step.
const fs = require('fs');

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
