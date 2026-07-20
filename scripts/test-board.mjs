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

assert.equal(typeof logic.evaluateFreshness, 'function', 'BoardLogic exports evaluateFreshness');
assert.equal(logic.STALE_AFTER_MS, 60_000, 'freshness threshold is pinned at 60 seconds');

const FRESHNESS_NOW = Date.UTC(2026, 0, 1, 12, 0, 0);
const STALE_AFTER_MS = logic.STALE_AFTER_MS;

function freshness(lastSuccessMs, now = FRESHNESS_NOW) {
  return logic.evaluateFreshness({ lastSuccessMs, now, staleAfterMs: STALE_AFTER_MS });
}

const fresh = freshness(FRESHNESS_NOW - STALE_AFTER_MS + 1);
assert.equal(fresh.stale, false, 'freshness stays fresh below the stale threshold');
assert.equal(fresh.ageMs, STALE_AFTER_MS - 1, 'freshness reports the exact age below the threshold');

const boundary = freshness(FRESHNESS_NOW - STALE_AFTER_MS);
assert.equal(boundary.stale, true, 'freshness is stale at the exact threshold boundary');
assert.equal(boundary.ageMs, STALE_AFTER_MS, 'freshness reports the exact boundary age');

const stale = freshness(FRESHNESS_NOW - STALE_AFTER_MS - 1);
assert.equal(stale.stale, true, 'freshness remains stale above the threshold');

const noSuccess = freshness(null);
assert.equal(noSuccess.stale, false, 'no successful refresh yet is not treated as stale');
assert.equal(noSuccess.ageMs, null, 'no successful refresh yet reports no age');

const newer = freshness(FRESHNESS_NOW - STALE_AFTER_MS - 1);
const older = freshness(FRESHNESS_NOW - STALE_AFTER_MS - 60_000);
assert.equal(older.ageMs > newer.ageMs, true, 'an older successful refresh has a larger age');

console.log('PASS: freshness logic regression tests');

assert.equal(typeof logic.evaluateReminder, 'function', 'BoardLogic exports evaluateReminder');
assert.equal(logic.REARM_TOLERANCE_MS, 90_000, 'reminder re-arm tolerance is pinned');
assert.deepEqual(Array.from(logic.REMINDER_LEADS), [3, 5, 10], 'reminder leads are pinned in order');

let currentLead = null;
const leadCycle = [];
for (let i = 0; i < 4; i++) {
  const next = logic.nextReminderLead(currentLead);
  leadCycle.push({ remindMe: next.remindMe, remindLeadMin: next.remindLeadMin });
  currentLead = next.remindMe ? next.remindLeadMin : null;
}
assert.deepEqual(
  leadCycle,
  [
    { remindMe: true, remindLeadMin: 3 },
    { remindMe: true, remindLeadMin: 5 },
    { remindMe: true, remindLeadMin: 10 },
    { remindMe: false, remindLeadMin: null }
  ],
  'reminder lead cycle is exactly Off to 3 to 5 to 10 to Off'
);

console.log('PASS: reminder lead cycle regression tests');

const NOW = Date.UTC(2026, 0, 1, 12, 0, 0);
const LEAD_MS = 3 * 60 * 1000;

function reminder(overrides, now = NOW) {
  return logic.evaluateReminder({
    remindMe: true,
    nearestEta: NOW + LEAD_MS,
    leadMs: LEAD_MS,
    notifiedEta: null,
    ...overrides
  }, now);
}

const notYet = reminder({ nearestEta: NOW + LEAD_MS + 1_000 });
assert.equal(notYet.shouldNotify, false, 'reminder stays quiet above the lead threshold');

const firstEta = NOW + LEAD_MS - 30_000;
const first = reminder({ nearestEta: firstEta });
assert.equal(first.shouldNotify, true, 'armed reminder fires when ETA crosses within the lead time');
assert.equal(first.notifiedEta, firstEta, 'first notification latches the bus ETA');

const sameBus = reminder({
  nearestEta: firstEta - 30_000,
  notifiedEta: first.notifiedEta
}, NOW + 15_000);
assert.equal(sameBus.shouldNotify, false, 'same bus does not fire again on the next refresh');
assert.equal(sameBus.notifiedEta, first.notifiedEta, 'same-bus latch survives normal ETA drift');

const laterEta = firstEta + 8 * 60 * 1000;
const laterBeforeLead = reminder({
  nearestEta: laterEta,
  notifiedEta: first.notifiedEta
}, firstEta + 30_000);
assert.equal(laterBeforeLead.shouldNotify, false, 'distinct later bus does not fire before its lead threshold');
assert.equal(laterBeforeLead.notifiedEta, null, 'distinct later bus clears the previous latch');

const later = reminder({
  nearestEta: laterEta,
  notifiedEta: laterBeforeLead.notifiedEta
}, laterEta - LEAD_MS);
assert.equal(later.shouldNotify, true, 'distinctly later next bus re-arms and fires');
assert.equal(later.notifiedEta, laterEta, 'later bus becomes the new latched ETA');

const unarmed = logic.evaluateReminder({
  remindMe: false,
  nearestEta: NOW,
  leadMs: LEAD_MS,
  notifiedEta: firstEta
}, NOW);
assert.equal(unarmed.shouldNotify, false, 'unarmed card never fires');
assert.equal(unarmed.notifiedEta, null, 'unarmed card clears its latch');
assert.equal(unarmed.minutes, null, 'unarmed card has no ETA minutes');

const unavailable = logic.evaluateReminder({
  remindMe: true,
  nearestEta: null,
  leadMs: LEAD_MS,
  notifiedEta: firstEta
}, NOW);
assert.equal(unavailable.shouldNotify, false, 'missing ETA never fires');
assert.equal(unavailable.notifiedEta, null, 'missing ETA resets the unavailable bus latch');
assert.equal(unavailable.minutes, null, 'missing ETA has no ETA minutes');

const atBoundary = reminder({ nearestEta: NOW + LEAD_MS });
assert.equal(atBoundary.shouldNotify, true, 'ETA exactly at the lead threshold fires');

const aboveBoundary = reminder({ nearestEta: NOW + LEAD_MS + 1 });
assert.equal(aboveBoundary.shouldNotify, false, 'ETA clearly above the lead threshold does not fire');

const arrivingNow = reminder({ nearestEta: NOW - 1_000 });
assert.equal(arrivingNow.shouldNotify, true, 'arriving-now ETA still fires without a lower cutoff');

function reminderAtLead(minutesOut, leadMin) {
  return logic.evaluateReminder({
    remindMe: true,
    nearestEta: NOW + minutesOut * 60_000,
    leadMs: leadMin * 60_000,
    notifiedEta: null
  }, NOW);
}

for (const leadMin of [5, 10]) {
  assert.equal(
    reminderAtLead(5, leadMin).shouldNotify,
    true,
    `a 5-minute ETA fires at a ${leadMin}-minute lead`
  );
}
assert.equal(reminderAtLead(5, 3).shouldNotify, false, 'a 5-minute ETA stays quiet at a 3-minute lead');
for (const leadMin of [3, 5, 10]) {
  assert.equal(
    reminderAtLead(3, leadMin).shouldNotify,
    true,
    `a 3-minute ETA fires at a ${leadMin}-minute lead`
  );
}
assert.equal(reminderAtLead(8, 10).shouldNotify, true, 'an 8-minute ETA fires at a 10-minute lead');
assert.equal(reminderAtLead(8, 5).shouldNotify, false, 'an 8-minute ETA stays quiet at a 5-minute lead');
assert.equal(reminderAtLead(8, 3).shouldNotify, false, 'an 8-minute ETA stays quiet at a 3-minute lead');

console.log('PASS: lead-driven reminder threshold regression tests');

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
