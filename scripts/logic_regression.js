'use strict';

const assert = require('assert');
const { domain: D, business: B, entitlement: E, process: P } = require('../PressBench/Resources/PressBenchLogic.js');

const origin = Date.parse('2040-01-01T12:00:00.000Z');
const at = seconds => new Date(origin + seconds * 1000).toISOString();

function readySettings() {
  let settings = D.defaultSettings();
  settings = P.acceptLegal(settings, { termsAccepted: true, safetyAccepted: true, privacyPresented: true }, at(0));
  return P.confirmTemperatureUnit(settings, 'F', at(0));
}

function paidEntitlement() {
  return E.applyStoreEvent(E.normalizeEntitlement({}), {
    action: 'purchase', platform: 'ios', userInitiated: true, nativeAdapterVerified: true,
    verificationSource: 'storekit2', productId: 'pressbench_unlimited_annual_ios',
    productType: 'auto_renewable_subscription', purchaseState: 'purchased', transactionId: 'regression-transaction',
    nativeVerificationId: 'storekit2:regression-transaction:original:pressbench_unlimited_annual_ios',
    storeEventAt: at(0), expiresAt: at(366 * 86400)
  }, at(0)).entitlement;
}

function fixture() {
  const context = { machines: [], recipes: [], setups: [], batches: [], settings: readySettings(), session: null,
    entitlement: paidEntitlement(), storageMode: 'native' };
  const machinePlan = P.planSaveMachine(context, {
    nickname: 'Press A', brand: 'Regression', model: 'P1', platenOrZone: 'Main', lastExternalCheckDate: '', archived: false
  }, at(0));
  context.machines = machinePlan.machines;
  const machine = context.machines[0];
  let setup = D.emptySetup('F');
  Object.assign(setup, {
    title: 'Regression setup', blankMaterial: 'Cotton', transferMedium: 'DTF', processStructure: 'other',
    machineProfileId: machine.id, machineProfile: D.machineProfileSnapshot(machine), machineNickname: machine.nickname,
    platenZone: machine.platenOrZone, temperature: 325, temperatureUnit: 'F', pressTimeSeconds: 1,
    pressure: 'Medium', pressCount: 1, defaultQuantity: 1,
    instructionSource: { type: 'supplier', name: 'Supplier', reference: 'S1', checkedDate: '2040-01-01', revision: '', priorBatchId: '' },
    steps: [{ id: D.uuid(), stageType: 'press', name: 'Press', instruction: '', machineNickname: machine.nickname,
      machineProfileId: machine.id, platenZone: machine.platenOrZone, temperature: 325, temperatureUnit: 'F',
      durationSeconds: 1, pressure: 'Medium', repeatCount: 1, placementAction: '', finishAction: '' }]
  });
  const setupPlan = P.planSaveSetup(context, setup, at(0));
  context.recipes = setupPlan.setups;
  context.setups = setupPlan.setups;
  return { context, setup: setupPlan.setup };
}

function finishTimer(run, clock) {
  if (!run.timer) run = P.transitionRun(run, { type: 'TIMER_INITIALIZE', index: 0, at: at(clock++) });
  while (!(run.timer.completed && run.timer.index === run.timer.stages.length - 1)) {
    if (run.timer.completed) run = P.transitionRun(run, { type: 'TIMER_NEXT', at: at(clock++) });
    else {
      run = P.transitionRun(run, { type: 'TIMER_START', at: at(clock++) });
      clock += Math.ceil(run.timer.totalMs / 1000) + 1;
      run = P.transitionRun(run, { type: 'TIMER_TICK', at: at(clock++) });
    }
  }
  return { run, clock };
}

function provenFixture() {
  const base = fixture();
  const auth = P.authorizeRun(base.context, base.setup, { now: at(1), utcOffsetMinutes: 0,
    progressMode: 'final_confirmation', runMode: 'test' });
  let run = P.transitionRun(auth.run, { type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: at(2) });
  let timed = finishTimer(run, 3); run = timed.run;
  run = P.transitionRun(run, { type: 'RECORD_FIRST_PIECE', outcome: 'pass', note: '', at: at(timed.clock++) });
  run = P.confirmAllGood(run, { confirmedPlannedQuantity: 1, explicitConfirmation: true, saveChoice: 'update_recipe' }, at(timed.clock++));
  run = P.transitionRun(run, { type: 'BEGIN_COMMIT', at: at(timed.clock++) });
  const commit = P.planResultCommit({ ...base.context, session: auth.session }, run);
  base.context.batches = commit.batches; base.context.recipes = commit.recipes; base.context.setups = commit.recipes;
  return { context: base.context, setup: commit.recipes[0], batch: commit.batch };
}

function startProduction(proven, quantity, clock) {
  const auth = P.authorizeRun(proven.context, proven.setup, { now: at(clock++), utcOffsetMinutes: 0,
    progressMode: 'live_cycles', runMode: 'production', quantity });
  let run = P.transitionRun(auth.run, { type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: at(clock++) });
  run = P.transitionRun(run, { type: 'START_PRODUCTION', at: at(clock++) });
  return { run, clock };
}

const proven = provenFixture();

// The expanded global starter catalogue must remain structural only: no
// temperature, time, pressure, machine, supplier, or proof is preloaded.
const safeStarters = B.starterTemplates('F');
assert.equal(B.STARTER_TEMPLATE_VERSION, 'APP-018-STRUCTURES-v6');
assert.equal(safeStarters.length, 15);
assert.equal(new Set(safeStarters.map(item => item.id)).size, safeStarters.length);
for (const starter of safeStarters) {
  assert.equal(D.isCanonicalStarterRecipe(starter), true, starter.id);
  assert.equal(starter.status, 'draft', starter.id);
  assert.equal(starter.verifiedAt, '', starter.id);
  assert.equal(starter.verifiedBatchId, '', starter.id);
  assert.equal(starter.machineProfileId, '', starter.id);
  assert.equal(starter.instructionSource.type, 'none', starter.id);
  assert.equal(starter.temperature, '', starter.id);
  assert.equal(starter.pressTimeSeconds, '', starter.id);
  assert.equal(starter.pressure, '', starter.id);
  assert.ok(starter.steps.length > 0, starter.id);
  for (const step of starter.steps) {
    assert.equal(step.temperature, '', starter.id);
    assert.equal(step.durationSeconds, '', starter.id);
    assert.equal(step.pressure, '', starter.id);
    assert.equal(step.machineProfileId, '', starter.id);
  }
}
assert.equal(P.processStructure('other', 'F').title, 'Other process setup');
assert.equal(P.processStructure('blank', 'F').title, '');

// A cycle may land on a QC checkpoint but cannot jump over one.
let started = startProduction(proven, 3000, 30);
let timed = finishTimer(started.run, started.clock); let run = timed.run; let clock = timed.clock;
assert.throws(() => P.transitionRun(run, { type: 'COMPLETE_CYCLE', cycleComplete: true, items: 3000, at: at(clock) }), /qc_checkpoint_crossed/);

// The largest authorized run remains completable with no more than 100 persisted checks.
started = startProduction(proven, 999999, 100);
run = started.run; clock = started.clock;
while (run.processedCount < run.quantity) {
  timed = finishTimer(run, clock); run = timed.run; clock = timed.clock;
  const policy = P.qcPolicy(run);
  const lastQc = run.qcChecks.length ? run.qcChecks[run.qcChecks.length - 1].processedCount : 0;
  const nextQc = lastQc === 0 ? policy.firstAt : lastQc + policy.every;
  const target = Math.min(run.quantity, nextQc);
  run = P.transitionRun(run, { type: 'COMPLETE_CYCLE', cycleComplete: true,
    items: target - run.processedCount, at: at(clock++) });
  if (run.processedCount >= nextQc) run = P.transitionRun(run, { type: 'RECORD_QC', result: 'pass', note: '', at: at(clock++) });
}
run = P.transitionRun(run, { type: 'END_RUN', reason: 'operator_finish', at: at(clock++) });
assert.equal(run.phase, 'result_pending');
assert.ok(run.qcChecks.length <= 100);

// Long interruption histories roll forward instead of blocking completion.
started = startProduction(proven, 1, 1000);
timed = finishTimer(started.run, started.clock); run = timed.run; clock = timed.clock;
run = P.transitionRun(run, { type: 'COMPLETE_CYCLE', cycleComplete: true, items: 1, at: at(clock++) });
for (let index = 0; index < 150; index += 1) {
  run = P.transitionRun(run, { type: 'PAUSE', reason: 'operator_pause', at: at(clock++) });
  run = P.transitionRun(run, { type: 'RESUME', at: at(clock++) });
}
run = P.transitionRun(run, { type: 'END_RUN', reason: 'operator_finish', at: at(clock++) });
assert.equal(run.phase, 'result_pending');
assert.equal(run.interruptions.length, 100);

// Invalid numeric values remain invalid through normalization and explicit APIs reject them.
assert.throws(() => P.markBackupCompleted(D.defaultSettings(), -1, at(0)), /batchCount/);
assert.notEqual(typeof D.normalizeIssue({ quantity: -1 }).quantity, 'number');
assert.notEqual(typeof D.normalizeIssue({ quantity: 1.5 }).quantity, 'number');

// Completion cannot be forged as a run event without the atomic storage commit proof.
const commitFixture = fixture();
const testAuth = P.authorizeRun(commitFixture.context, commitFixture.setup, { now: at(3000), utcOffsetMinutes: 0,
  progressMode: 'final_confirmation', runMode: 'test' });
assert.throws(() => P.transitionRun(testAuth.run, { type: 'COMMIT_SUCCEEDED', at: at(3001) }), /run_event/);

// Collection cloning no longer imposes an aggregate 1,000,000-node history ceiling.
const history = Array.from({ length: 6000 }, (_, index) => ({ ...proven.batch, id: `history-${index}` }));
const deletedSetup = P.planDeleteSetup({ ...proven.context, batches: history }, proven.setup.id);
assert.equal(deletedSetup.batches.length, 6000);

// Evidence lookup should scale linearly enough for a long local history.
const evidenceHistory = Array.from({ length: 8000 }, (_, index) => ({ ...proven.batch, id: `evidence-${index}` }));
const proofStarted = process.hrtime.bigint();
const proof = P.proofSummary(proven.setup, evidenceHistory);
const proofMilliseconds = Number(process.hrtime.bigint() - proofStarted) / 1e6;
assert.equal(proof.cleanMatchingBatches, 8000);
assert.ok(proofMilliseconds < 6000, `proofSummary took ${proofMilliseconds.toFixed(1)}ms`);

assert.equal(B.FREE_BATCH_LIMIT, 2); // Approved monetization remains unchanged.
console.log(`LOGIC REGRESSION: PASS — max run, 150 pauses, 6,000-record clone, 8,000-record proof (${proofMilliseconds.toFixed(1)}ms)`);
