'use strict';

const fs = require('fs');
const path = require('path');
const core = require(path.resolve(__dirname, '../PressBench/Resources/PressBenchLogic.js'));
const D = core.domain;
const E = core.entitlement;
const P = core.process;

const output = process.argv[2] || path.resolve(__dirname, '../PressBench/Resources/PressBenchScreenshotFixture.json');
const baseMs = Date.now() - (14 * 24 * 60 * 60 * 1000);
const iso = (seconds) => new Date(baseMs + seconds * 1000).toISOString();
const civil = (milliseconds) => {
  const date = new Date(milliseconds);
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

let settings = D.defaultSettings();
settings = P.acceptLegal(settings, {termsAccepted: true, safetyAccepted: true, privacyPresented: true}, iso(0));
settings = P.confirmTemperatureUnit(settings, 'F', iso(1));

const paidEvent = {
  action: 'purchase', platform: 'ios', userInitiated: true, nativeAdapterVerified: true,
  verificationSource: 'storekit2', productId: 'pressbench_unlimited_monthly_ios',
  productType: 'auto_renewable_subscription', purchaseState: 'purchased',
  transactionId: '9000000000001',
  nativeVerificationId: 'storekit2:9000000000001:9000000000001:pressbench_unlimited_monthly_ios:9999999999',
  storeEventAt: iso(2), expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString()
};
const entitlement = E.applyStoreEvent(E.normalizeEntitlement({}), paidEvent, iso(2)).entitlement;
let context = {machines: [], recipes: [], setups: [], batches: [], settings, session: null, entitlement, storageMode: 'native'};

const machineSpecs = [
  {nickname: 'Fusion IQ 15', brand: 'Hotronix', model: 'Fusion IQ', platenOrZone: '15 × 15 in'},
  {nickname: 'Auto Clam 16', brand: 'Geo Knight', model: 'DK16A', platenOrZone: '16 × 20 in'}
];

for (const [index, spec] of machineSpecs.entries()) {
  const plan = P.planSaveMachine(context, {
    ...spec, pressureMethod: '', pressureScale: '', lastExternalCheckDate: '',
    notes: index === 0 ? 'Primary garment press' : 'Large-format production press', archived: false,
    createdAt: iso(10 + index), updatedAt: iso(10 + index)
  }, iso(10 + index));
  context.machines = plan.machines;
}

const setupSpecs = [
  {title: 'Cotton tees · White HTV', material: '100% cotton T-shirt', transfer: 'Heat transfer vinyl (HTV)', machine: 0, temperature: 325, duration: 15, pressure: 'Medium', quantity: 36},
  {title: 'Polyester jerseys · Sublimation', material: 'Polyester jersey', transfer: 'Sublimation transfer', machine: 1, temperature: 385, duration: 45, pressure: 'Light', quantity: 24},
  {title: 'Fleece hoodies · DTF', material: 'Cotton-blend hoodie', transfer: 'Direct-to-film (DTF)', machine: 1, temperature: 310, duration: 12, pressure: 'Medium', quantity: 18},
  {title: 'Canvas totes · Black HTV', material: 'Canvas tote bag', transfer: 'Heat transfer vinyl (HTV)', machine: 0, temperature: 330, duration: 18, pressure: 'Firm', quantity: 30}
];

const setupIDs = [];
for (const [index, spec] of setupSpecs.entries()) {
  const machine = context.machines[spec.machine];
  let setup = D.emptySetup('F');
  setup.createdAt = iso(30 + index);
  setup.updatedAt = iso(30 + index);
  setup.title = spec.title;
  setup.blankMaterial = spec.material;
  setup.transferMedium = spec.transfer;
  setup.processStructure = 'other';
  setup.machineProfileId = machine.id;
  setup.machineProfile = D.machineProfileSnapshot(machine);
  setup.machineNickname = machine.nickname;
  setup.platenZone = machine.platenOrZone;
  setup.temperature = spec.temperature;
  setup.temperatureUnit = 'F';
  setup.pressTimeSeconds = spec.duration;
  setup.pressure = spec.pressure;
  setup.pressCount = 1;
  setup.defaultQuantity = spec.quantity;
  setup.instructionSource = {
    type: 'supplier', name: 'Verified supplier specification', reference: `SPEC-${1040 + index}`,
    checkedDate: civil(baseMs), revision: '2026.3', priorBatchId: ''
  };
  setup.steps = [{
    stageType: 'press', name: 'Press', instruction: '', machineNickname: machine.nickname,
    machineProfileId: machine.id, platenZone: machine.platenOrZone, temperature: spec.temperature,
    temperatureUnit: 'F', durationSeconds: spec.duration, pressure: spec.pressure,
    repeatCount: 1, placementAction: 'Center on platen', finishAction: 'Peel and inspect'
  }];
  const plan = P.planSaveSetup(context, setup, iso(30 + index));
  setupIDs.push(plan.setup.id);
  context.recipes = plan.setups;
  context.setups = plan.setups;
}

const runs = [
  {setup: 0, job: 'PB-1042 · Staff shirts', planned: 36, processed: 36, waste: 0, rework: 0},
  {setup: 1, job: 'PB-1043 · Away jerseys', planned: 24, processed: 24, waste: 0, rework: 1},
  {setup: 2, job: 'PB-1044 · Launch hoodies', planned: 18, processed: 18, waste: 1, rework: 0},
  {setup: 3, job: 'PB-1045 · Market totes', planned: 30, processed: 30, waste: 0, rework: 0},
  {setup: 0, job: 'PB-1046 · Volunteer tees', planned: 42, processed: 42, waste: 0, rework: 1},
  {setup: 1, job: 'PB-1047 · Home jerseys', planned: 28, processed: 28, waste: 0, rework: 0},
  {setup: 2, job: 'PB-1048 · Crew hoodies', planned: 20, processed: 20, waste: 0, rework: 0},
  {setup: 3, job: 'PB-1049 · Event totes', planned: 32, processed: 32, waste: 1, rework: 0},
  {setup: 0, job: 'PB-1050 · Team tees', planned: 48, processed: 48, waste: 0, rework: 0},
  {setup: 1, job: 'PB-1051 · Training jerseys', planned: 22, processed: 22, waste: 0, rework: 1},
  {setup: 2, job: 'PB-1052 · Retail hoodies', planned: 16, processed: 16, waste: 0, rework: 0},
  {setup: 3, job: 'PB-1053 · Studio totes', planned: 26, processed: 26, waste: 0, rework: 0}
];

function completeTestRun(spec, index) {
  const now = 1200 + index * 72000;
  const setupID = setupIDs[spec.setup];
  const liveSetup = context.recipes.find((item) => item.id === setupID);
  const authorization = P.authorizeRun(context, liveSetup, {
    now: iso(now), utcOffsetMinutes: 0, runMode: 'production', progressMode: 'final_confirmation',
    firstPiecePolicy: 'required_for_unproven', confirmUnprovenProduction: true,
    quantity: spec.planned, jobReference: spec.job
  });
  let run = authorization.run;
  run = P.transitionRun(run, {type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: iso(now + 1)});
  let cursor = now + 2;
  const completeTimerPlan = () => {
    if (!run.timer) {
      run = P.transitionRun(run, {type: 'TIMER_INITIALIZE', index: 0, at: iso(cursor)});
    }
    for (let stageIndex = run.timer.index; stageIndex < run.timer.stages.length; stageIndex += 1) {
      if (run.timer.stages[stageIndex].timed) {
        cursor += 1;
        run = P.transitionRun(run, {type: 'TIMER_START', at: iso(cursor)});
        cursor += run.timer.stages[stageIndex].seconds + 1;
        run = P.transitionRun(run, {type: 'TIMER_TICK', at: iso(cursor)});
      }
      if (stageIndex < run.timer.stages.length - 1) {
        cursor += 1;
        run = P.transitionRun(run, {type: 'TIMER_NEXT', at: iso(cursor)});
      }
    }
  };
  if (run.phase === 'first_piece') {
    completeTimerPlan();
    cursor += 1;
    run = P.transitionRun(run, {type: 'RECORD_FIRST_PIECE', outcome: 'pass', note: '', at: iso(cursor)});
  }
  cursor += 1;
  run = P.transitionRun(run, {type: 'START_PRODUCTION', at: iso(cursor)});
  completeTimerPlan();
  cursor += 1;
  run = P.transitionRun(run, {type: 'RECORD_QC', result: 'pass', note: 'Final quality check passed', at: iso(cursor)});
  cursor += 1;
  run = P.transitionRun(run, {type: 'END_RUN', reason: 'operator_finish', at: iso(cursor)});

  const issues = [];
  if (spec.waste) issues.push({
    id: D.uuid(), quantity: spec.waste, symptom: 'alignment', suspectedCause: 'placement',
    disposition: 'discarded', note: 'Caught during operator quality check'
  });
  if (spec.rework) issues.push({
    id: D.uuid(), quantity: spec.rework, symptom: 'edge lift', suspectedCause: 'pressure',
    disposition: 'reworked', note: 'Repressed and passed inspection'
  });
  cursor += 1;
  if (issues.length) {
    run = P.transitionRun(run, {type: 'SAVE_RESULT_DRAFT', at: iso(cursor), result: {
      quantityProcessed: spec.processed, quantityWaste: spec.waste, quantityReworked: spec.rework,
      issues, notes: 'Quality check recorded; batch completed.', saveChoice: 'update_recipe'
    }});
  } else {
    run = P.transitionRun(run, {
      type: 'CONFIRM_ALL_GOOD', confirmedPlannedQuantity: spec.planned, explicitConfirmation: true,
      notes: 'Batch completed to specification.', saveChoice: 'update_recipe', variantTitle: '', at: iso(cursor)
    });
  }
  cursor += 1;
  run = P.transitionRun(run, {type: 'BEGIN_COMMIT', at: iso(cursor)});
  const committed = P.planResultCommit({...context, session: authorization.session}, run);
  context.recipes = committed.recipes;
  context.setups = committed.recipes;
  context.batches = committed.batches;
  context.session = null;
}

runs.forEach(completeTestRun);

const backup = D.makeBackup(context.recipes, context.batches, context.settings, context.machines);
backup.freeRunsUsed = 5;
P.planRestore({...context, session: null}, JSON.stringify(backup));
fs.writeFileSync(output, `${JSON.stringify(backup, null, 2)}\n`, 'utf8');
console.log(`Generated ${context.machines.length} machines, ${context.recipes.length} setups, and ${context.batches.length} runs.`);
