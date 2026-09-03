'use strict';
const assert = require('assert');
const path = require('path');
const core = require(path.resolve(__dirname, '../PressBench/Resources/PressBenchLogic.js'));
const D = core.domain, B = core.business, E = core.entitlement, P = core.process;

const baseMs = Date.now() + 60_000;
const iso = (seconds) => new Date(baseMs + seconds * 1000).toISOString();
const civil = (milliseconds) => {
  const date = new Date(milliseconds);
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};
const now = iso(0);
const testUtcOffsetMinutes = -new Date(baseMs).getTimezoneOffset();
let settings = D.defaultSettings();
settings = P.acceptLegal(settings, {termsAccepted:true, safetyAccepted:true, privacyPresented:true}, now);
settings = P.confirmTemperatureUnit(settings, 'F', now);
assert.equal(P.operationalReadiness(settings).ready, true);

let entitlement = E.normalizeEntitlement({});
let context = {machines:[], recipes:[], setups:[], batches:[], settings, session:null, entitlement, storageMode:'native'};
assert.equal(P.ARCHITECTURE_REQUIREMENTS.trackingSdk, false);
assert.equal(P.ARCHITECTURE_REQUIREMENTS.advertisingSdk, 'none');
assert.equal(P.ARCHITECTURE_REQUIREMENTS.routineNetworkBoundary, 'store_entitlement_only');

// A fabricated local boolean must never create paid access.
assert.equal(E.evaluateEntitlement({paidAccess:true, productId:'pressbench_unlimited_monthly_ios'}, now).paidAccess, false);

// Verified StoreKit purchase must unlock only the exact product.
const purchasedEvent = {
  action:'purchase', platform:'ios', userInitiated:true, nativeAdapterVerified:true,
  verificationSource:'storekit2', productId:'pressbench_unlimited_monthly_ios',
  productType:'auto_renewable_subscription', purchaseState:'purchased',
  transactionId:'1000000000001', nativeVerificationId:'storekit2:1000000000001:1000000000001:pressbench_unlimited_monthly_ios:1787155200',
  storeEventAt:now, expiresAt:iso(31 * 24 * 60 * 60)
};
let purchaseResult = E.applyStoreEvent(entitlement, purchasedEvent, now);
entitlement = purchaseResult.entitlement;
assert.equal(E.evaluateEntitlement(entitlement, now).paidAccess, true);
assert.equal(E.evaluateEntitlement(entitlement, iso(32 * 24 * 60 * 60)).paidAccess, false);
context.entitlement = entitlement;

// Renewal and explicit restore extend/recover the same verified subscription.
const renewedEvent = {...purchasedEvent, action:'automatic_refresh', userInitiated:false,
  transactionId:'1000000000003', nativeVerificationId:'storekit2:1000000000003:1000000000001:pressbench_unlimited_monthly_ios:1789833600',
  storeEventAt:iso(30 * 24 * 60 * 60), expiresAt:iso(61 * 24 * 60 * 60)};
entitlement = E.applyStoreEvent(entitlement, renewedEvent, iso(30 * 24 * 60 * 60)).entitlement;
assert.equal(E.evaluateEntitlement(entitlement, iso(45 * 24 * 60 * 60)).paidAccess, true);
const restoredEvent = {...renewedEvent, action:'explicit_restore', userInitiated:true, storeEventAt:iso(40 * 24 * 60 * 60)};
entitlement = E.applyStoreEvent(entitlement, restoredEvent, iso(40 * 24 * 60 * 60)).entitlement;
assert.equal(E.evaluateEntitlement(entitlement, iso(45 * 24 * 60 * 60)).paidAccess, true);
context.entitlement = entitlement;

// Existing lifetime buyers stay grandfathered after the subscription migration.
const legacyEvent = {...purchasedEvent, productId:'pressbench_unlimited_lifetime_ios', productType:'non_consumable',
  transactionId:'1000000000002', nativeVerificationId:'storekit2:1000000000002:1000000000002:pressbench_unlimited_lifetime_ios:1787155200'};
delete legacyEvent.expiresAt;
const legacyEntitlement = E.applyStoreEvent(E.normalizeEntitlement({}), legacyEvent, now).entitlement;
assert.equal(E.evaluateEntitlement(legacyEntitlement, iso(400 * 24 * 60 * 60)).paidAccess, true);

assert.equal(B.FREE_BATCH_LIMIT, 5);
assert.equal(B.MONETIZATION_MODEL.ios.pricing.baseAmountMinor, 999);
assert.equal(E.capabilities(E.normalizeEntitlement({}), {setups:10, batches:0}, now).canCreateSetup, true);

let wrongFailed = false;
try { E.applyStoreEvent(E.normalizeEntitlement({}), {...purchasedEvent, productId:'wrong_product'}, now); } catch (_) { wrongFailed = true; }
assert.equal(wrongFailed, true);

// Machine and setup creation must go through planners and validate graph integrity.
const machinePlan = P.planSaveMachine(context, {
  nickname:'Press A', brand:'Sample', model:'P1', pressureMethod:'', pressureScale:'',
  platenOrZone:'Main platen', lastExternalCheckDate:'', notes:'', archived:false
}, now);
context.machines = machinePlan.machines;
assert.equal(context.machines.length, 1);
const machine = context.machines[0];

let setup = D.emptySetup('F');
setup.title = 'Cotton + DTF';
setup.blankMaterial = 'Cotton tee';
setup.transferMedium = 'DTF transfer';
setup.processStructure = 'other';
setup.machineProfileId = machine.id;
setup.machineProfile = D.machineProfileSnapshot(machine);
setup.machineNickname = machine.nickname;
setup.platenZone = machine.platenOrZone;
setup.temperature = 325;
setup.temperatureUnit = 'F';
setup.pressTimeSeconds = 15;
setup.pressure = 'Medium';
setup.pressCount = 1;
setup.defaultQuantity = 10;
// A checked date is a device civil date, not a UTC calendar date. Keeping the
// fixture in local civil time makes this gate deterministic around UTC midnight.
setup.instructionSource = {type:'supplier', name:'Supplier sheet', reference:'S-1', checkedDate:civil(baseMs), revision:'', priorBatchId:''};
setup.steps = [{stageType:'press', name:'Press', instruction:'', machineNickname:machine.nickname, machineProfileId:machine.id,
  platenZone:machine.platenOrZone, temperature:325, temperatureUnit:'F', durationSeconds:15, pressure:'Medium', repeatCount:1,
  placementAction:'', finishAction:''}];
const setupPlan = P.planSaveSetup(context, setup, now);
context.recipes = setupPlan.setups; context.setups = setupPlan.setups;
assert.equal(context.recipes.length, 1);
const savedSetup = context.recipes[0];
assert.equal(D.validateRunnableSetup(savedSetup, now, testUtcOffsetMinutes).length, 0);

// Same-product variant safety: a multi-stage clone may change only the three
// fields allowed by reuseSetup. The save planner must preserve source, machine,
// material, transfer and every operating field (stage UUIDs are intentionally new).
const multiSource = JSON.parse(JSON.stringify(savedSetup));
multiSource.id = D.uuid();
multiSource.title = 'Two-stage cotton + DTF';
multiSource.processStructure = 'multi_stage';
multiSource.steps = [
  {...multiSource.steps[0], id:D.uuid()},
  {...multiSource.steps[0], id:D.uuid(), stageType:'postpress', name:'Post-press', durationSeconds:8, pressTimeSeconds:8}
];
const multiPlan = P.planSaveSetup(context, multiSource, iso(0.2));
const multiSaved = multiPlan.setup;
const variantContext = {...context, recipes:multiPlan.setups, setups:multiPlan.setups};
const variantReuse = D.reuseSetup(multiSaved, 'same_product_variant', {
  title:'Two-stage navy variant', notes:'Variant note', defaultQuantity:12
}, iso(0.3));
const variantPlan = P.planSaveSetup(variantContext, variantReuse.setup, iso(0.4));
const savedVariant = variantPlan.setup;
const stableShape = (value) => ({
  processStructure:value.processStructure,
  blankMaterial:value.blankMaterial,
  transferMedium:value.transferMedium,
  instructionSource:value.instructionSource,
  machineProfileId:value.machineProfileId,
  machineProfile:value.machineProfile,
  machineNickname:value.machineNickname,
  platenZone:value.platenZone,
  temperature:value.temperature,
  temperatureUnit:value.temperatureUnit,
  pressTimeSeconds:value.pressTimeSeconds,
  pressure:value.pressure,
  steps:value.steps.map(({id, ...step}) => step)
});
assert.deepStrictEqual(stableShape(savedVariant), stableShape(multiSaved));
assert.equal(savedVariant.status, 'trial');
assert.equal(savedVariant.title, 'Two-stage navy variant');
assert.equal(savedVariant.defaultQuantity, 12);
assert.notEqual(savedVariant.id, multiSaved.id);

// Test/unproven run: confirm instructions -> first piece -> result -> atomic plan.
const authorization = P.authorizeRun(context, savedSetup, {now, utcOffsetMinutes:testUtcOffsetMinutes, progressMode:'final_confirmation', firstPiecePolicy:'required_for_unproven'});
assert.equal(authorization.authorized, true);
function sortedBridgeRoundTrip(value) {
  if (Array.isArray(value)) return value.map(sortedBridgeRoundTrip);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map(key => [key, sortedBridgeRoundTrip(value[key])]));
}
function legacyV2Fingerprint(value) {
  const permit = value.permit || {}, usage = permit.usageSnapshot || {};
  const legacyUsage = usage.migrated === true ? {migrated:true} : {
    setups:usage.setups, batches:usage.batches, freeSetupLimit:usage.freeSetupLimit,
    freeBatchLimit:usage.freeBatchLimit, physicalLimit:usage.physicalLimit
  };
  return `sha256:${D.sha256(JSON.stringify([
    value.id, value.resultId, value.sourceSetupId || value.sourceRecipeId, value.sourceBatchId || '', value.runMode,
    value.quantity, value.utcOffsetMinutes, value.progressMode || 'final_confirmation', value.jobReference || '',
    value.reservedAt, value.startedAt, D.exactSetupFingerprint(value.originalSetup), value.originalOperationalFingerprint,
    permit.reservedAt, permit.authorizationBasis, permit.setupSlotReserved === true, permit.variantSlotReserved === true,
    permit.variantSetupId || '', permit.reservedBytes, legacyUsage
  ]))}`;
}

const legacyV2Run = JSON.parse(JSON.stringify(authorization.run));
legacyV2Run.permit.schemaVersion = 2;
legacyV2Run.permit.intentFingerprint = legacyV2Fingerprint(legacyV2Run);
for (const sessionVersion of [3, 4]) {
  const restored = P.restoreSession(sortedBridgeRoundTrip({schemaVersion:sessionVersion, activeRun:legacyV2Run,
    setupDraft:null, savedAt:now}), [], 'F', iso(1));
  assert.equal(restored.activeRun.permit.schemaVersion, 3);
  assert.equal(P.permitValid(restored.activeRun), true);
}
const tamperedV2Run = JSON.parse(JSON.stringify(legacyV2Run));
tamperedV2Run.permit.intentFingerprint = 'sha256:attacker-controlled-invalid';
assert.equal(P.restoreSession({schemaVersion:4, activeRun:tamperedV2Run, setupDraft:null, savedAt:now}, [], 'F', iso(1)), null);
const unverifiableV1Run = JSON.parse(JSON.stringify(legacyV2Run));
unverifiableV1Run.permit.schemaVersion = 1;
assert.equal(P.restoreSession({schemaVersion:4, activeRun:unverifiableV1Run, setupDraft:null, savedAt:now}, [], 'F', iso(1)), null);

let run = sortedBridgeRoundTrip(authorization.run);
run = P.transitionRun(run, {type:'CONFIRM_INSTRUCTIONS', confirmed:true, at:iso(1)});
assert.equal(run.phase, 'first_piece');
let prematureFirstPieceBlocked = false;
try { P.transitionRun(run, {type:'RECORD_FIRST_PIECE', outcome:'pass', note:'', at:iso(2)}); }
catch (error) { prematureFirstPieceBlocked = error.message === 'timer_plan_incomplete'; }
assert.equal(prematureFirstPieceBlocked, true);
run = P.transitionRun(run, {type:'TIMER_INITIALIZE', index:0, at:iso(2)});
run = P.transitionRun(run, {type:'TIMER_START', at:iso(3)});
run = P.transitionRun(run, {type:'TIMER_TICK', at:iso(19)});
assert.equal(run.timer.completed, true);
run = P.transitionRun(run, {type:'RECORD_FIRST_PIECE', outcome:'pass', note:'', at:iso(20)});
assert.equal(run.phase, 'result_pending');
run = P.transitionRun(run, {type:'CONFIRM_ALL_GOOD', confirmedPlannedQuantity:1, explicitConfirmation:true, notes:'', saveChoice:'update_recipe', variantTitle:'', at:iso(21)});
run = P.transitionRun(run, {type:'BEGIN_COMMIT', at:iso(22)});
const commit = P.planResultCommit({...context, session:authorization.session}, run);
assert.equal(commit.batches.length, 1);
assert.equal(D.validateBatch(commit.batches[0]).length, 0);
context.batches = commit.batches; context.recipes = commit.recipes; context.setups = commit.recipes; context.session = null;

// Corrections synchronize the user-facing job reference and keep an audit trail.
const correction = P.planCorrection(context, commit.batch.id, {
  reason:'Correct operator entry', correctedAt:iso(25), changes:{
    jobReference:'Corrected Job', notes:'Corrected note'
  }
});
const correctedBatch = correction.batches.find((item) => item.id === commit.batch.id);
assert.equal(correctedBatch.jobReference, 'Corrected Job');
assert.equal(correctedBatch.jobName, 'Corrected Job');
assert.equal(correctedBatch.corrections.length, 1);
context.batches = correction.batches; context.recipes = correction.recipes; context.setups = correction.recipes;

// Production counts are coupled to completion of the entire timer plan and
// completing a cycle prepares stage one for the next item.
const productionSetup = context.recipes.find((item) => item.id === savedSetup.id);
const productionAuth = P.authorizeRun(context, productionSetup, {now:iso(30), utcOffsetMinutes:testUtcOffsetMinutes,
  progressMode:'live_cycles', firstPiecePolicy:'required_for_unproven', runMode:'production', quantity:10});
let productionRun = productionAuth.run;
productionRun = P.transitionRun(productionRun, {type:'CONFIRM_INSTRUCTIONS', confirmed:true, at:iso(31)});
assert.equal(productionRun.phase, 'production_ready');
productionRun = P.transitionRun(productionRun, {type:'START_PRODUCTION', at:iso(32)});
let prematureCountBlocked = false;
try { P.transitionRun(productionRun, {type:'COMPLETE_CYCLE', cycleComplete:true, items:1, at:iso(33)}); }
catch (error) { prematureCountBlocked = error.message === 'timer_plan_incomplete'; }
assert.equal(prematureCountBlocked, true);
productionRun = P.transitionRun(productionRun, {type:'TIMER_START', at:iso(34)});
productionRun = P.transitionRun(productionRun, {type:'TIMER_TICK', at:iso(50)});
productionRun = P.transitionRun(productionRun, {type:'COMPLETE_CYCLE', cycleComplete:true, items:1, at:iso(51)});
assert.equal(productionRun.processedCount, 1);
assert.equal(productionRun.timer.index, 0);
assert.equal(productionRun.timer.completed, false);
let dueQcBlockedFinish = false;
try { P.transitionRun(productionRun, {type:'END_RUN', reason:'operator_finish', at:iso(52)}); }
catch (error) { dueQcBlockedFinish = error.message === 'qc_required'; }
assert.equal(dueQcBlockedFinish, true);
productionRun = P.transitionRun(productionRun, {type:'RECORD_QC', result:'pass', note:'', at:iso(53)});
productionRun = P.transitionRun(productionRun, {type:'END_RUN', reason:'operator_end_early', at:iso(54)});
assert.equal(productionRun.phase, 'result_pending');
productionRun = P.transitionRun(productionRun, {type:'SAVE_RESULT_DRAFT', at:iso(55), result:{
  quantityProcessed:1, quantityWaste:0, quantityReworked:0, issues:[], notes:'Partial batch', saveChoice:'batch_only'
}});
productionRun = P.transitionRun(productionRun, {type:'BEGIN_COMMIT', at:iso(56)});
const productionCommit = P.planResultCommit({...context, session:productionAuth.session}, productionRun);
const productionCorrection = P.planCorrection({...context, recipes:productionCommit.recipes, setups:productionCommit.recipes,
  batches:productionCommit.batches}, productionCommit.batch.id, {
  reason:'Correct production quantities', correctedAt:iso(60), changes:{
    jobReference:'Production Job 12', quantityPlanned:12, quantityProcessed:1, quantityWaste:1, quantityReworked:0,
    issues:[{id:D.uuid(), quantity:1, symptom:'alignment', suspectedCause:'placement', disposition:'discarded', note:'Operator correction'}],
    notes:'Corrected production record'
  }
});
const correctedProduction = productionCorrection.batches.find((item) => item.id === productionCommit.batch.id);
assert.equal(correctedProduction.jobReference, 'Production Job 12');
assert.equal(correctedProduction.jobName, 'Production Job 12');
assert.equal(correctedProduction.quantityPlanned, 12);
assert.equal(correctedProduction.quantityProcessed, 1);
assert.equal(correctedProduction.quantityWaste, 1);
assert.equal(correctedProduction.issues.length, 1);
assert.equal(correctedProduction.corrections.length, 1);

// Raw interchange formats are unavailable; premium reports require trusted entitlement.
const freeContext = {...context, entitlement:E.normalizeEntitlement({})};
assert.equal(P.planReport(freeContext, 'json', context.batches, now).allowed, false);
assert.equal(P.planReport(freeContext, 'csv', context.batches, now).allowed, false);
assert.equal(P.planReport(freeContext, 'pdf', context.batches, now).allowed, false);
assert.equal(P.planReport(freeContext, 'xlsx', context.batches, now).allowed, false);
assert.equal(P.planReport(freeContext, 'pdf', context.batches, now).reason, 'paid_access_required');
assert.equal(P.planReport(freeContext, 'xlsx', context.batches, now).reason, 'paid_access_required');
assert.equal(P.planReport(context, 'pdf', context.batches, now).allowed, true);
assert.equal(P.planReport(context, 'xlsx', context.batches, now).allowed, true);

// Revocation is terminal and removes premium access.
const revokedAt = iso(50 * 24 * 60 * 60);
const revokedEvent = {...renewedEvent, action:'automatic_refresh', userInitiated:false, purchaseState:'revoked', storeEventAt:revokedAt};
const revoked = E.applyStoreEvent(entitlement, revokedEvent, revokedAt).entitlement;
assert.equal(E.evaluateEntitlement(revoked, revokedAt).paidAccess, false);

// Destructive local-data planning is explicit and never claims to erase the
// App Store entitlement, which remains wrapper-owned.
const deletion = P.planDeleteAll(context, 'DELETE');
assert.deepStrictEqual(deletion.machines, []);
assert.deepStrictEqual(deletion.recipes, []);
assert.deepStrictEqual(deletion.batches, []);
assert.equal(deletion.session, null);
assert.equal(deletion.purchaseEntitlementUnaffected, true);
assert.equal(Object.prototype.hasOwnProperty.call(deletion, 'entitlement'), false);

// User-owned backup files may carry only the monotonic free-run count as an
// extra schema-v4 field. Restore still rejects unknown fields and malformed
// counts before producing any mutation plan.
const portableBackup = D.makeBackup(context.recipes, context.batches, context.settings, context.machines);
portableBackup.freeRunsUsed = 3;
const portableRestore = P.planRestore({...context, session:null, storageMode:'native'}, JSON.stringify(portableBackup));
assert.equal(portableRestore.target.batches.length, context.batches.length);
assert.equal(portableRestore.entitlementUnaffected, true);
for (const invalidValue of [-1, 6, 1.5, '3']) {
  const invalidBackup = {...portableBackup, freeRunsUsed:invalidValue};
  assert.throws(() => P.planRestore({...context, session:null, storageMode:'native'}, JSON.stringify(invalidBackup)), /backup_shape/);
}
assert.throws(() => P.planRestore({...context, session:null, storageMode:'native'},
  JSON.stringify({...portableBackup, unexpectedField:true})), /backup_shape/);

console.log('ENGINE SMOKE: PASS');
