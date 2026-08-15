#!/usr/bin/env node
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const fixtureText = await readFile(
  new URL('../shared/fixtures/board-logic.vectors.json', import.meta.url),
  'utf8'
);
const vectors = JSON.parse(fixtureText);
const { groups } = vectors;

const expectedCaseCounts = {
  compareBoardItems: 2,
  compareBoardManual: 4,
  reorderBoardOrder: 11,
  resolveEtaDisplay: 12,
  shouldRunBackground: 4,
  evaluateFreshness: 8,
  formatFreshnessAge: 6,
  nextReminderLead: 1,
  evaluateReminder: 37,
  constants: 3
};

assert.equal(vectors.schemaVersion, 1, 'board logic vector schema version is supported');
assert.deepEqual(
  Object.keys(groups).sort(),
  Object.keys(expectedCaseCounts).sort(),
  'fixture declares exactly the expected BoardLogic groups'
);

let totalCaseCount = 0;

function hasOwnPath(root, path) {
  let current = root;
  for (const segment of path.split('.')) {
    if (current === null || current === undefined ||
        !Object.prototype.hasOwnProperty.call(current, segment)) {
      return false;
    }
    current = current[segment];
  }
  return true;
}

function casesFor(groupName) {
  const group = groups[groupName];
  assert.ok(group, `fixture group ${groupName} is present`);
  assert.ok(Array.isArray(group.cases), `fixture group ${groupName} has cases`);
  assert.ok(group.cases.length > 0, `fixture group ${groupName} is not empty`);
  assert.equal(
    group.cases.length,
    expectedCaseCounts[groupName],
    `${groupName} fixture case count is unchanged`
  );
  for (const vectorCase of group.cases) {
    assert.equal(typeof vectorCase.name, 'string', `${groupName} case has a name`);
    for (const absentKey of vectorCase.absentKeys || []) {
      assert.equal(
        hasOwnPath(vectorCase, absentKey),
        false,
        `${groupName} ${vectorCase.name}: absent key is omitted`
      );
    }
  }
  totalCaseCount += group.cases.length;
  return group.cases;
}

function assertExpectedFields(actual, expected, name) {
  for (const [key, value] of Object.entries(expected)) {
    const actualValue = key === 'etaRows' && Array.isArray(actual[key])
      ? Array.from(actual[key])
      : actual[key];
    assert.deepEqual(actualValue, value, name);
  }
}

function pathValue(root, path) {
  return path.split('.').reduce((value, segment) => value[segment], root);
}

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

assert.equal(typeof logic.compareBoardManual, 'function', 'BoardLogic exports compareBoardManual');
assert.equal(typeof logic.reorderBoardOrder, 'function', 'BoardLogic exports reorderBoardOrder');

for (const vectorCase of casesFor('compareBoardItems')) {
  const { input, expected } = vectorCase;
  if (expected.orderedRoutes) {
    const ordered = input.items.slice().sort(logic.compareBoardItems);
    assert.deepEqual(ordered.map(item => item.route), expected.orderedRoutes, vectorCase.name);
  }
  if (expected.comparisonSign !== undefined) {
    assert.equal(
      Math.sign(logic.compareBoardItems(input.a, input.b)),
      expected.comparisonSign,
      vectorCase.name
    );
  }
}
console.log('PASS: board ordering regression tests');

for (const vectorCase of casesFor('compareBoardManual')) {
  const { input, expected } = vectorCase;
  if (expected.orderedRoutes) {
    const ordered = input.items.slice().sort(logic.compareBoardManual);
    assert.deepEqual(ordered.map(item => item.route), expected.orderedRoutes, vectorCase.name);
  }
  if (expected.comparisonSign !== undefined) {
    assert.equal(
      Math.sign(logic.compareBoardManual(input.a, input.b)),
      expected.comparisonSign,
      vectorCase.name
    );
  }
}
console.log('PASS: manual sort and reorder regression tests');

for (const vectorCase of casesFor('reorderBoardOrder')) {
  const { input, expected } = vectorCase;
  const snapshot = vectorCase.assertInputUnchanged ? structuredClone(input.items) : null;
  let reordered;
  if (vectorCase.assertNoThrow) {
    assert.doesNotThrow(() => {
      reordered = logic.reorderBoardOrder(input.items, input.fromIndex, input.toIndex);
    }, vectorCase.name);
  } else {
    reordered = logic.reorderBoardOrder(input.items, input.fromIndex, input.toIndex);
  }
  if (vectorCase.assertInputUnchanged) {
    assert.deepEqual(input.items, snapshot, vectorCase.name);
  }
  if (vectorCase.assertClonedItems) {
    assert.equal(reordered.every(item => !input.items.includes(item)), true, vectorCase.name);
  }
  if (expected.orderedIds) {
    assert.deepEqual(reordered.map(item => item.id), expected.orderedIds, vectorCase.name);
  }
  if (expected.boardOrders) {
    assert.deepEqual(reordered.map(item => item.boardOrder), expected.boardOrders, vectorCase.name);
  }
  if (expected.isArray !== undefined) {
    assert.equal(Array.isArray(reordered), expected.isArray, vectorCase.name);
  }
  if (expected.length !== undefined) {
    assert.equal(reordered.length, expected.length, vectorCase.name);
  }
}
console.log('PASS: reorderBoardOrder regression tests');

assert.equal(typeof logic.resolveEtaDisplay, 'function', 'BoardLogic exports resolveEtaDisplay');
for (const vectorCase of casesFor('resolveEtaDisplay')) {
  const { input, expected } = vectorCase;
  const resolved = logic.resolveEtaDisplay(input.previous, input.outcome);
  if (vectorCase.assertRowsIdentity) {
    assert.equal(
      resolved.etaRows,
      pathValue(input, vectorCase.assertRowsIdentity),
      vectorCase.name
    );
  }
  assertExpectedFields(resolved, expected, vectorCase.name);
}
console.log('PASS: ETA display resolver truth table');

assert.equal(typeof logic.shouldRunBackground, 'function', 'BoardLogic exports shouldRunBackground');
for (const vectorCase of casesFor('shouldRunBackground')) {
  const actual = logic.shouldRunBackground(
    vectorCase.input.hidden,
    vectorCase.input.boardActive
  );
  assert.equal(actual, vectorCase.expected, vectorCase.name);
}
console.log('PASS: visibility background predicate truth table');

assert.equal(typeof logic.evaluateFreshness, 'function', 'BoardLogic exports evaluateFreshness');
for (const vectorCase of casesFor('evaluateFreshness')) {
  const { input, expected } = vectorCase;
  if (expected.olderAgeGreater !== undefined) {
    const newer = logic.evaluateFreshness(input.newer);
    const older = logic.evaluateFreshness(input.older);
    assert.equal(older.ageMs > newer.ageMs, expected.olderAgeGreater, vectorCase.name);
  } else {
    assertExpectedFields(logic.evaluateFreshness(input), expected, vectorCase.name);
  }
}
console.log('PASS: freshness logic regression tests');

const freshnessAgeStart = html.indexOf('function formatFreshnessAge');
const freshnessAgeEnd = html.indexOf('function renderFreshnessStatus', freshnessAgeStart);
assert.notEqual(freshnessAgeStart, -1, 'production formatFreshnessAge function is present');
assert.notEqual(freshnessAgeEnd, -1, 'production formatFreshnessAge boundary is present');

const freshnessAgeContext = vm.createContext({});
const freshnessAgeSource = html.slice(freshnessAgeStart, freshnessAgeEnd) +
  '\nglobalThis.__formatFreshnessAge = formatFreshnessAge;';
new vm.Script(freshnessAgeSource, { filename: 'index.html#formatFreshnessAge' })
  .runInContext(freshnessAgeContext);
const formatFreshnessAge = freshnessAgeContext.__formatFreshnessAge;
for (const vectorCase of casesFor('formatFreshnessAge')) {
  const decodedExpected = JSON.parse(JSON.stringify(vectorCase.expected));
  assert.equal(
    formatFreshnessAge(vectorCase.input.ageMs),
    decodedExpected,
    vectorCase.name
  );
}
console.log('PASS: freshness age formatting boundary tests');

assert.equal(typeof logic.nextReminderLead, 'function', 'BoardLogic exports nextReminderLead');
for (const vectorCase of casesFor('nextReminderLead')) {
  let currentLead = vectorCase.input.startingLead;
  const cycle = [];
  for (let i = 0; i < vectorCase.input.steps; i++) {
    const next = logic.nextReminderLead(currentLead);
    cycle.push({ remindMe: next.remindMe, remindLeadMin: next.remindLeadMin });
    currentLead = next.remindMe ? next.remindLeadMin : null;
  }
  assert.deepEqual(cycle, vectorCase.expected.cycle, vectorCase.name);
}
console.log('PASS: reminder lead cycle regression tests');

assert.equal(typeof logic.evaluateReminder, 'function', 'BoardLogic exports evaluateReminder');
const chainResults = new Map();
for (const vectorCase of casesFor('evaluateReminder')) {
  if (vectorCase.chainAssertion) continue;
  const { input, expected } = vectorCase;
  const actual = logic.evaluateReminder({
    remindMe: input.remindMe,
    nearestEta: input.nearestEta,
    leadMs: input.leadMs,
    notifiedEta: input.notifiedEta
  }, input.now);
  assertExpectedFields(actual, expected, vectorCase.name);
  if (vectorCase.chain) {
    if (!chainResults.has(vectorCase.chain)) chainResults.set(vectorCase.chain, new Map());
    chainResults.get(vectorCase.chain).set(vectorCase.chainStep, actual);
  }
}
for (const vectorCase of groups.evaluateReminder.cases) {
  if (!vectorCase.chainAssertion) continue;
  const results = chainResults.get(vectorCase.chainAssertion.chain);
  assert.ok(results, vectorCase.name);
  const fireCount = [...results.values()].filter(result => result.shouldNotify === true).length;
  assert.equal(
    fireCount,
    vectorCase.chainAssertion.shouldNotifyCount,
    vectorCase.name
  );
}
console.log('PASS: evaluateReminder regression tests');
console.log('PASS: transient-null reminder latch regression tests');
console.log('PASS: lead-driven reminder threshold regression tests');

for (const vectorCase of casesFor('constants')) {
  const actual = vectorCase.input.key === 'REMINDER_LEADS'
    ? Array.from(logic[vectorCase.input.key])
    : logic[vectorCase.input.key];
  assert.deepEqual(actual, vectorCase.expected, vectorCase.name);
}
console.log('PASS: constants regression tests');

const NOW = Date.UTC(2026, 0, 1, 12, 0, 0);

const persistenceStart = html.indexOf('function loadBoard()');
const persistenceEnd = html.indexOf('function nextBoardOrder()', persistenceStart);
assert.notEqual(persistenceStart, -1, 'production loadBoard function is present');
assert.notEqual(persistenceEnd, -1, 'production saveBoard boundary is present');

const storage = {
  value: JSON.stringify([
    {
      route: 'armed', company: 'KMB', stopId: 'A', dir: 'outbound', boardOrder: 0,
      remindMe: true, remindLeadMin: 5, nearestEta: NOW, etaRows: [], remindNotifiedEta: NOW
    },
    {
      route: 'legacy-armed', company: 'KMB', stopId: 'LA', dir: 'outbound', boardOrder: 1,
      remindMe: true, nearestEta: NOW, etaRows: [], remindNotifiedEta: NOW
    },
    { route: 'legacy', company: 'KMB', stopId: 'L', dir: 'outbound', boardOrder: 2 }
  ]),
  getItem() { return this.value; },
  setItem(key, value) { this.value = value; }
};
const persistenceContext = vm.createContext({ __storage: storage });
const persistenceSource = html.slice(start, end + endMarker.length) +
  '\nconst REMIND_LEAD_MIN = 3;\n' +
  '\nlet board = [];\n' +
  'let sortMode = \'auto\';\n' +
  'const localStorage = globalThis.__storage;\n' +
  html.slice(persistenceStart, persistenceEnd) +
  '\nglobalThis.__persistence = { loadBoard, saveBoard, getBoard: () => board };';
new vm.Script(persistenceSource, { filename: 'index.html#BoardPersistence' }).runInContext(persistenceContext);

persistenceContext.__persistence.loadBoard();
const loadedBoard = persistenceContext.__persistence.getBoard();
const loadedArmed = loadedBoard.find(item => item.route === 'armed');
const loadedLegacyArmed = loadedBoard.find(item => item.route === 'legacy-armed');
const loadedLegacy = loadedBoard.find(item => item.route === 'legacy');
assert.equal(loadedArmed.remindMe, true, 'armed reminder state loads from localStorage');
assert.equal(loadedArmed.remindLeadMin, 5, 'armed reminder lead loads from localStorage');
assert.equal(loadedLegacyArmed.remindLeadMin, 3, 'armed legacy items backfill the default reminder lead');
assert.equal(loadedLegacy.remindMe, false, 'legacy board items backfill reminder state as off');
assert.equal(loadedLegacy.remindLeadMin, 3, 'legacy board items backfill the default reminder lead');
assert.equal('remindNotifiedEta' in loadedArmed, false, 'runtime latch is not loaded into board state');

loadedArmed.remindNotifiedEta = NOW;
persistenceContext.__persistence.saveBoard();
const persisted = JSON.parse(storage.value);
const persistedArmed = persisted.find(item => item.route === 'armed');
assert.equal(persistedArmed.remindMe, true, 'armed reminder state round-trips to localStorage');
assert.equal(persistedArmed.remindLeadMin, 5, 'armed reminder lead round-trips to localStorage');
assert.equal('remindNotifiedEta' in persistedArmed, false, 'runtime latch is never persisted');
assert.equal('nearestEta' in persistedArmed, false, 'runtime ETA remains excluded from persistence');

console.log('PASS: arrival reminder regression tests');
console.log(`PASS: total fixture cases asserted: ${totalCaseCount}`);
