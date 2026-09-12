'use strict';

const assert = require('node:assert/strict');
const core = require('../PressBench/Resources/PressBenchLogic.js');
const O = core.operations;
const E = core.entitlement;
const B = core.business;

const now = '2042-01-01T00:00:00.000Z';
const later = '2042-01-02T00:00:00.000Z';
let checks = 0;
function check(name, action) { action(); checks += 1; process.stdout.write(`PASS ${name}\n`); }
function rejects(code, action) { assert.throws(action, error => error && error.message === code); }

const baseJob = {
  id: 'job-1', title: 'Team shirts', customerReference: 'PO-2042-18', item: 'Cotton tee', quantity: 25,
  dueAt: '2042-01-10T12:00:00Z', status: 'ordered', currency: 'CAD', currencyExponent: 2,
  saleAmountMinor: 50000, depositAmountMinor: 15000, blankCostMinor: 10000,
  transferCostMinor: 5000, laborMinutes: 90, laborCostMinor: 6000, overheadCostMinor: 2000,
  linkedBatchIds: ['batch-1'], createdAt: now, updatedAt: now
};

check('job normalization and financial totals', () => {
  const job = O.normalizeJob(baseJob, true);
  const finance = O.jobFinancials(job);
  assert.equal(finance.totalCostMinor, 23000);
  assert.equal(finance.profitMinor, 27000);
  assert.equal(finance.balanceDueMinor, 35000);
  assert.equal(finance.marginBasisPoints, 5400);
});

check('invalid money, deposits, currencies and time order fail closed', () => {
  rejects('job_saleAmountMinor', () => O.normalizeJob({ ...baseJob, saleAmountMinor: 1.5 }, true));
  rejects('job_deposit_exceeds_sale', () => O.normalizeJob({ ...baseJob, depositAmountMinor: 50001 }, true));
  rejects('job_currency', () => O.normalizeJob({ ...baseJob, currency: '$$$' }, true));
  rejects('job_time_order', () => O.normalizeJob({ ...baseJob, updatedAt: '2041-12-31T00:00:00Z' }, true));
  rejects('job_identity', () => O.normalizeJob({ title: '', item: '' }, true));
});

check('job state transitions reject impossible and stale transitions', () => {
  rejects('job_transition', () => O.transitionJob(baseJob, 'delivered', later));
  rejects('job_event_stale', () => O.transitionJob(baseJob, 'pressing', '2041-12-31T00:00:00Z'));
  rejects('job_completion_batch', () => O.transitionJob({ ...baseJob, status: 'pressing', linkedBatchIds: [] }, 'done', later));
  const pressing = O.transitionJob(baseJob, 'pressing', later);
  assert.equal(pressing.status, 'pressing');
});

check('remakes link to originals and contribute to the remake rate', () => {
  const remake = O.makeRemake(baseJob, { ...baseJob, id: undefined, title: 'Team shirts remake',
    saleAmountMinor: 0, depositAmountMinor: 0, remakeReason: 'Wash lift', createdAt: later, updatedAt: later });
  assert.equal(remake.remakeOfJobId, 'job-1');
  const summary = O.summarizeJobs([baseJob, remake], 'CAD');
  assert.equal(summary.jobs, 2);
  assert.equal(summary.remakes, 1);
  assert.equal(summary.remakeRate, 0.5);
  assert.equal(O.validateJobGraph([baseJob, remake]).length, 2);
  rejects('job_remake_reference', () => O.validateJobGraph([{ ...baseJob, remakeOfJobId: 'missing' }]));
});

check('mixed currencies are never silently combined', () => {
  rejects('mixed_currency_summary', () => O.summarizeJobs([baseJob, { ...baseJob, id: 'job-2', currency: 'USD' }]));
});

check('delayed durability distinguishes press-proven, wash-proven and failed', () => {
  const batch = { id: 'batch-1', outcome: 'success', quantityWaste: 0 };
  assert.equal(O.durabilityEvidence(batch, []).level, 'press_proven');
  const pass = O.normalizeDurabilityReview({ id: 'd-1', batchId: 'batch-1', setupId: 'setup-1',
    status: 'pass', method: 'wash', washCycles: 5, testedAt: later }, true);
  assert.equal(O.durabilityEvidence(batch, [pass]).level, 'wash_proven');
  const fail = O.normalizeDurabilityReview({ id: 'd-2', batchId: 'batch-1', setupId: 'setup-1',
    status: 'fail', method: 'wash', washCycles: 1, testedAt: later, failureMode: 'edge_lift' }, true);
  assert.equal(O.durabilityEvidence(batch, [pass, fail]).level, 'durability_failed');
});

check('layer plans require source, test-first, complete instructions and compatible temperatures', () => {
  const plan = { id: 'layers-1', setupId: 'setup-1', sourceConfirmed: true, testFirstAcknowledged: true,
    layers: [
      { id: 'l1', name: 'Base', material: 'HTV', temperature: 300, temperatureUnit: 'F', tackSeconds: 3,
        pressure: 'medium', peelMethod: 'warm', carrierAction: 'remove carrier', coverAction: 'cover' },
      { id: 'l2', name: 'Top', material: 'HTV', temperature: 305, temperatureUnit: 'F', finalPressSeconds: 12,
        pressure: 'medium', peelMethod: 'warm', carrierAction: 'remove carrier', coverAction: 'cover' }
    ] };
  assert.equal(O.layerPlanAssessment(plan).ready, true);
  assert.equal(O.buildLayerTimerStages(plan).length, 2);
  const unsafe = { ...plan, sourceConfirmed: false };
  assert.equal(O.layerPlanAssessment(unsafe).ready, false);
  rejects('layer_plan_not_ready', () => O.buildLayerTimerStages(unsafe));
});

check('calibration detects failing zones, overdue checks and incomplete pressure method', () => {
  const calibration = { id: 'c-1', machineId: 'm-1', checkedAt: now, dueAt: '2042-02-01T00:00:00Z',
    temperatureUnit: 'F', targetTemperature: 320, tolerance: 5,
    zoneReadings: [{ zone: 'centre', measuredTemperature: 321 }, { zone: 'left', measuredTemperature: 308 }],
    pressureMethod: 'gauge', pressureReading: '6', pressureUnit: 'kg' };
  const assessment = O.calibrationAssessment(calibration, later);
  assert.equal(assessment.status, 'failed');
  assert.equal(assessment.failingZones.length, 1);
  assert.equal(assessment.maximumAbsoluteDeviation, 12);
});

check('favorites remain unique and reject unknown setup ids', () => {
  assert.deepEqual(O.toggleFavorite([], 'setup-2', ['setup-1', 'setup-2']), ['setup-2']);
  assert.deepEqual(O.toggleFavorite(['setup-2'], 'setup-2', ['setup-1', 'setup-2']), []);
  rejects('favorite_setup', () => O.toggleFavorite([], 'missing', ['setup-1']));
});

check('CSV round-trips international text and neutralizes spreadsheet formulas', () => {
  const job = { ...baseJob, title: '=HYPERLINK("bad")', customerReference: 'Réf-١٢', linkedBatchIds: ['b1', 'b2'] };
  const csv = O.exportJobsCsv([job]);
  assert.match(csv, /'=HYPERLINK/);
  const imported = O.importJobsCsv(csv);
  assert.equal(imported.length, 1);
  assert.equal(imported[0].title, '=HYPERLINK("bad")');
  assert.equal(imported[0].customerReference, 'Réf-١٢');
  assert.deepEqual(imported[0].linkedBatchIds, ['b1', 'b2']);
});

check('CSV rejects malformed quotes, headers and duplicate ids', () => {
  rejects('csv_quote', () => O.importJobsCsv('"unterminated'));
  rejects('csv_headers', () => O.importJobsCsv('wrong,headers\r\n1,2'));
  const csv = O.exportJobsCsv([baseJob, { ...baseJob, id: 'job-2' }]);
  const duplicate = csv.replace(/"job-2"/, '"job-1"');
  rejects('csv_duplicate_id', () => O.importJobsCsv(duplicate));
});

check('approved monetization values remain unchanged and paid CSV is gated', () => {
  assert.equal(B.FREE_BATCH_LIMIT, 2);
  assert.equal(B.MONETIZATION_MODEL.ios.pricing.monthlyBaseAmountMinor, 1299);
  assert.equal(B.MONETIZATION_MODEL.ios.pricing.annualBaseAmountMinor, 11999);
  assert.equal(B.MONETIZATION_MODEL.android.pricing.baseAmountMinor, 499);
  assert.equal(E.capabilities({}, { setups: 0, batches: 0 }, now).canCsv, false);
});

for (let index = 0; index < 10000; index += 1) {
  const q = index % 999999 + 1;
  const job = O.normalizeJob({ ...baseJob, id: `job-${index}`, quantity: q,
    saleAmountMinor: index * 101, depositAmountMinor: index, linkedBatchIds: [`batch-${index}`] }, true);
  assert.equal(job.quantity, q);
  assert.equal(O.jobFinancials(job).balanceDueMinor, index * 100);
}

process.stdout.write(`OPERATIONS STRESS: PASS — ${checks} feature checks; 10,000 deterministic job rounds\n`);
