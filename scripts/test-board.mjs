#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const startMarker = '/* BOARD_LOGIC_START */';
const endMarker = '/* BOARD_LOGIC_END */';
const start = html.indexOf(startMarker);
const end = html.indexOf(endMarker, start);

assert.notEqual(start, -1, 'production BoardLogic start marker is present');
assert.notEqual(end, -1, 'production BoardLogic end marker is present');

const context = vm.createContext({});
const source = html.slice(start, end + endMarker.length) +
  '\nglobalThis.__boardLogic = BoardLogic;';
new vm.Script(source, { filename: 'index.html#BoardLogic' }).runInContext(context);
const logic = context.__boardLogic;

const sampleBoard = [
  { route: 'late', company: 'KMB', stopId: 'L', dir: 'outbound', nearestEta: 300000, boardOrder: 0 },
  { route: 'tie-second', company: 'KMB', stopId: 'T2', dir: 'outbound', nearestEta: 120000, boardOrder: 2 },
  { route: 'no-eta-first', company: 'KMB', stopId: 'N1', dir: 'outbound', nearestEta: null, boardOrder: 3 },
  { route: 'early', company: 'KMB', stopId: 'E', dir: 'outbound', nearestEta: 60000, boardOrder: 4 },
  { route: 'tie-first', company: 'KMB', stopId: 'T1', dir: 'outbound', nearestEta: 120000, boardOrder: 1 },
  { route: 'no-eta-second', company: 'KMB', stopId: 'N2', dir: 'outbound', nearestEta: undefined, boardOrder: 5 }
];

const ordered = sampleBoard.slice().sort(logic.compareBoardItems);
assert.deepEqual(
  ordered.map(item => item.route),
  ['early', 'tie-first', 'tie-second', 'late', 'no-eta-first', 'no-eta-second'],
  'ETA ordering is ascending, stable for ties, and sinks unavailable cards'
);

const starredLater = { route: 'starred-later', company: 'KMB', stopId: 'S', dir: 'outbound', starred: true, nearestEta: 240000, boardOrder: 0 };
const unstarredSooner = { route: 'unstarred-sooner', company: 'KMB', stopId: 'U', dir: 'outbound', starred: false, nearestEta: 180000, boardOrder: 1 };
assert.equal(
  logic.compareBoardItems(unstarredSooner, starredLater) < 0,
  true,
  'starred cards are not pinned ahead of a sooner ETA'
);

console.log('PASS: board ordering regression tests');
