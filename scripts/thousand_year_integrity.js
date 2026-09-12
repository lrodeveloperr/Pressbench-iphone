'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { domain: D, business: B, entitlement: E, process: P } = require('../PressBench/Resources/PressBenchLogic.js');

const START_YEAR = 2026;
const END_YEAR = 3026;
const root = path.resolve(__dirname, '..');
const atYear = (year, second = 0) => new Date(Date.UTC(year, 8, 12, 12, 0, second)).toISOString();
const expiryFor = year => new Date(Date.UTC(year + 1, 8, 12, 12, 0, 0)).toISOString();

function readySettings(now) {
  let settings = D.defaultSettings();
  settings = P.acceptLegal(settings, {
    termsAccepted: true, safetyAccepted: true, privacyPresented: true
  }, now);
  return P.confirmTemperatureUnit(settings, 'F', now);
}

function iosStoreEvent(entitlement, year) {
  const now = atYear(year, 0);
  return E.applyStoreEvent(entitlement, {
    action: year === START_YEAR ? 'purchase' : 'automatic_refresh',
    platform: 'ios', userInitiated: year === START_YEAR, nativeAdapterVerified: true,
    verificationSource: 'storekit2', productId: 'pressbench_unlimited_annual_ios',
    productType: 'auto_renewable_subscription', purchaseState: 'purchased',
    transactionId: `millennium-ios-${year}`,
    nativeVerificationId: `storekit2:millennium-ios-${year}:pressbench_unlimited_annual_ios`,
    storeEventAt: now, expiresAt: expiryFor(year)
  }, now).entitlement;
}

function finishTimer(run, year, second) {
  if (!run.timer) run = P.transitionRun(run, { type: 'TIMER_INITIALIZE', index: 0, at: atYear(year, second++) });
  while (!(run.timer.completed && run.timer.index === run.timer.stages.length - 1)) {
    if (run.timer.completed) run = P.transitionRun(run, { type: 'TIMER_NEXT', at: atYear(year, second++) });
    else {
      run = P.transitionRun(run, { type: 'TIMER_START', at: atYear(year, second++) });
      second += Math.ceil(run.timer.totalMs / 1000) + 1;
      run = P.transitionRun(run, { type: 'TIMER_TICK', at: atYear(year, second++) });
    }
  }
  return { run, second };
}

function completeTestRun(context, setup, year) {
  let second = 10;
  const authorization = P.authorizeRun(context, setup, {
    now: atYear(year, second++), utcOffsetMinutes: 0,
    progressMode: 'final_confirmation', runMode: 'test'
  });
  let run = P.transitionRun(authorization.run, {
    type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: atYear(year, second++)
  });
  const timed = finishTimer(run, year, second); run = timed.run; second = timed.second;
  if (run.phase === 'first_piece') {
    run = P.transitionRun(run, {
      type: 'RECORD_FIRST_PIECE', outcome: 'pass', note: '', at: atYear(year, second++)
    });
  }
  run = P.confirmAllGood(run, {
    confirmedPlannedQuantity: 1, explicitConfirmation: true, saveChoice: 'update_recipe'
  }, atYear(year, second++));
  run = P.transitionRun(run, { type: 'BEGIN_COMMIT', at: atYear(year, second++) });
  const commit = P.planResultCommit({ ...context, session: authorization.session }, run);
  context.batches = commit.batches;
  context.recipes = commit.recipes;
  context.setups = commit.recipes;
  return commit;
}

function buildCustomerFixture() {
  const now = atYear(START_YEAR);
  const context = {
    machines: [], recipes: [], setups: [], batches: [], settings: readySettings(now),
    session: null, entitlement: iosStoreEvent(E.normalizeEntitlement({}), START_YEAR), storageMode: 'native'
  };
  const machinePlan = P.planSaveMachine(context, {
    nickname: 'Millennium press', brand: 'Other / custom', model: 'Manual clamshell press',
    platenOrZone: '16 × 20 in', lastExternalCheckDate: '2026-09-12', archived: false
  }, now);
  context.machines = machinePlan.machines;
  const machine = context.machines[0];

  let setup = D.emptySetup('F');
  Object.assign(setup, {
    title: 'Long-life setup', blankMaterial: 'Cotton/polyester blend',
    transferMedium: 'Heat transfer vinyl (HTV)', processStructure: 'htv',
    machineProfileId: machine.id, machineProfile: D.machineProfileSnapshot(machine),
    machineNickname: machine.nickname, platenZone: machine.platenOrZone,
    temperature: 300, temperatureUnit: 'F', pressTimeSeconds: 10, pressure: 'Medium',
    pressCount: 1, defaultQuantity: 1, createdAt: now, updatedAt: now,
    instructionSource: {
      type: 'supplier', name: 'Operator-checked instructions', reference: 'Local reference',
      checkedDate: '2026-09-12', revision: '1', priorBatchId: ''
    },
    steps: [{
      id: D.uuid(), stageType: 'press', name: 'Press', instruction: '',
      machineNickname: machine.nickname, machineProfileId: machine.id, platenZone: machine.platenOrZone,
      temperature: 300, temperatureUnit: 'F', durationSeconds: 10, pressure: 'Medium',
      repeatCount: 1, placementAction: '', finishAction: ''
    }]
  });
  const setupPlan = P.planSaveSetup(context, setup, now);
  context.recipes = setupPlan.setups;
  context.setups = setupPlan.setups;
  return { context, setup: setupPlan.setup };
}

function runMillenniumCustomerTest() {
  const fixture = buildCustomerFixture();
  let { context, setup } = fixture;
  const firstCommit = completeTestRun(context, setup, START_YEAR);
  setup = firstCommit.recipes[0];
  const seedBatch = firstCommit.batch;
  let priorCompletedAt = seedBatch.completedAt;

  // Preserve one normalized record for every intervening year. This avoids
  // revalidating the entire prior history 1,000 separate times while still
  // subjecting the complete millennium dataset to the final run, graph check,
  // proof calculation, and backup round-trip.
  for (let year = START_YEAR + 1; year < END_YEAR; year += 1) {
    context.entitlement = iosStoreEvent(context.entitlement, year);
    const access = E.evaluateEntitlement(context.entitlement, atYear(year, 1));
    assert.equal(access.paidAccess, true, `paid access ${year}`);
    const batch = D.normalizeBatch({
      ...seedBatch,
      id: `millennium-batch-${year}`,
      firstPiece: {
        outcome: 'pass', attemptedAt: atYear(year, 14), completedAt: atYear(year, 15), attempts: 1, note: ''
      },
      productionStartedAt: atYear(year, 13),
      instructionCheckedAt: atYear(year, 12),
      startedAt: atYear(year, 10),
      completedAt: atYear(year, 30),
      durationSeconds: 20,
      workDate: `${year}-09-12`,
      timeZone: '',
      corrections: []
    }, true);
    assert.equal(batch.workDate, `${year}-09-12`, `work date ${year}`);
    assert.equal(D.validateBatch(batch).length, 0, `batch validation ${year}`);
    assert.ok(new Date(batch.completedAt) > new Date(priorCompletedAt), `time order ${year}`);
    priorCompletedAt = batch.completedAt;
    context.batches.push(batch);
  }

  // A genuine end-to-end run in year 3026 must still authorize, transition,
  // commit, and remain proven with the preceding 1,000-year history attached.
  context.entitlement = iosStoreEvent(context.entitlement, END_YEAR);
  assert.equal(E.evaluateEntitlement(context.entitlement, atYear(END_YEAR, 1)).paidAccess, true);
  const finalCommit = completeTestRun(context, setup, END_YEAR);
  setup = finalCommit.recipes[0];
  assert.equal(finalCommit.batch.workDate, `${END_YEAR}-09-12`);
  assert.equal(D.validateBatch(finalCommit.batch).length, 0);

  assert.equal(context.batches.length, END_YEAR - START_YEAR + 1);
  assert.equal(new Set(context.batches.map(batch => batch.id)).size, context.batches.length);
  assert.equal(context.recipes.length, 1);
  assert.equal(P.proofSummary(setup, context.batches).publicStatus, 'proven');
  assert.equal(D.graphIntegrityErrors(context.machines, context.recipes, context.batches).length, 0);

  const backup = D.makeBackup(context.recipes, context.batches, context.settings, context.machines);
  const restored = D.parseBackup(JSON.stringify(backup));
  assert.equal(restored.machines.length, context.machines.length);
  assert.equal(restored.recipes.length, context.recipes.length);
  assert.equal(restored.batches.length, context.batches.length);
  assert.equal(restored.batches[0].id, context.batches[0].id);
  assert.equal(restored.batches.at(-1).id, context.batches.at(-1).id);
  return context.batches.length;
}

function runCalendarAndEntitlementBoundaryTest() {
  assert.equal(D.isCivilDate('2100-02-29'), false);
  assert.equal(D.isCivilDate('2400-02-29'), true);
  assert.equal(D.isCivilDate('3000-02-29'), false);
  assert.equal(D.workDateFor('3026-09-12T23:30:00.000Z', 120), '3026-09-13');
  assert.equal(D.workDateFor('3026-09-12T00:30:00.000Z', -120), '3026-09-11');

  const purchaseAt = atYear(START_YEAR);
  const android = E.applyStoreEvent(E.normalizeEntitlement({}), {
    action: 'purchase', platform: 'android', userInitiated: true, nativeAdapterVerified: true,
    verificationSource: 'play_billing', productId: 'pressbench_unlimited_lifetime_android',
    productType: 'non_consumable', purchaseState: 'purchased', acknowledged: true,
    transactionId: 'millennium-android-lifetime',
    nativeVerificationId: 'play:millennium-android-lifetime:pressbench_unlimited_lifetime_android',
    storeEventAt: purchaseAt
  }, purchaseAt).entitlement;
  assert.equal(E.evaluateEntitlement(android, atYear(END_YEAR)).paidAccess, true);
}

function runCrossFileIntegrityTest() {
  const logicSource = fs.readFileSync(path.join(root, 'PressBench/Resources/PressBenchLogic.js'), 'utf8');
  for (const forbidden of [/\beval\s*\(/, /new\s+Function\s*\(/, /\bXMLHttpRequest\b/, /\bWebSocket\b/, /\bfetch\s*\(/]) {
    assert.equal(forbidden.test(logicSource), false, `forbidden runtime capability ${forbidden}`);
  }
  assert.equal(B.FREE_BATCH_LIMIT, 2);
  assert.equal(B.MONETIZATION_MODEL.ios.pricing.monthlyBaseAmountMinor, 1299);
  assert.equal(B.MONETIZATION_MODEL.ios.pricing.annualBaseAmountMinor, 11999);
  assert.equal(B.MONETIZATION_MODEL.android.pricing.baseAmountMinor, 499);

  const starters = B.starterTemplates('F');
  assert.equal(starters.length, 15);
  for (const starter of starters) {
    assert.equal(D.isCanonicalStarterRecipe(starter), true, starter.id);
    assert.equal(starter.status, 'draft', starter.id);
    assert.equal(starter.temperature, '', starter.id);
    assert.equal(starter.pressTimeSeconds, '', starter.id);
    assert.equal(starter.pressure, '', starter.id);
    assert.equal(starter.instructionSource.type, 'none', starter.id);
  }

  const prefill = JSON.parse(fs.readFileSync(path.join(root, 'PressBench/Resources/PrefillLocalizations.json'), 'utf8'));
  const localeCodes = new Set([...prefill.languages, ...prefill.localeOverrideCodes]);
  let choiceCount = 0;
  for (const [group, locales] of Object.entries(prefill.groups)) {
    assert.deepEqual(new Set(Object.keys(locales)), localeCodes, `${group} locale coverage`);
    const count = locales.en.length; choiceCount += count;
    for (const [code, values] of Object.entries(locales)) {
      assert.equal(values.length, count, `${group}/${code} count`);
      assert.equal(values.every(value => typeof value === 'string' && value.trim()), true, `${group}/${code} empty`);
      assert.equal(new Set(values.map(value => value.trim().toLocaleLowerCase())).size, values.length, `${group}/${code} duplicate`);
    }
  }
  assert.equal(choiceCount, 98);

  const machines = fs.readFileSync(path.join(root, 'PressBench/Models/PBMachineCatalog.swift'), 'utf8');
  const machineRows = machines.match(/\("[^"]+",\s*"[^"]*",\s*"[^"]+"\)/g) || [];
  assert.equal(machineRows.length, 104);
  assert.equal((machines.match(/\("(?:Manual clamshell|Automatic clamshell|Swing-away|Pneumatic single-platen|Pneumatic dual-platen|Cap or headwear|Mug or tumbler|Portable hand|Large-format|Calender or roll|Multipurpose) press", "",/g) || []).length, 11);

  const presets = fs.readFileSync(path.join(root, 'PressBench/Models/PBSetupPresetCatalog.swift'), 'utf8');
  assert.equal((presets.match(/^\s+e\("/gm) || []).length, 56);
  for (const marker of [
    'requiresCurrentInstructionConfirmation: Bool { true }',
    'bundledStatus: String { "draft" }',
    'isOperatorProven: Bool { false }'
  ]) assert.ok(presets.includes(marker), marker);
}

const started = process.hrtime.bigint();
const yearlyRuns = runMillenniumCustomerTest();
runCalendarAndEntitlementBoundaryTest();
runCrossFileIntegrityTest();
const milliseconds = Number(process.hrtime.bigint() - started) / 1e6;

console.log(`1000-YEAR CUSTOMER + CODING INTEGRITY: PASS — ${yearlyRuns} annual records, end-to-end runs at 2026 and 3026, backup round-trip, calendar boundaries, catalog invariants (${milliseconds.toFixed(1)}ms)`);
