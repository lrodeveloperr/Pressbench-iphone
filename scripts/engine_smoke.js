'use strict';
const assert = require('assert');
const path = require('path');
const core = require(path.resolve(__dirname, '../PressBench/Resources/PressBenchLogic.js'));
const D = core.domain, E = core.entitlement, P = core.process;

const baseMs = Date.now() + 60_000;
const iso = (seconds) => new Date(baseMs + seconds * 1000).toISOString();
const civil = (milliseconds) => {
  const date = new Date(milliseconds);
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};
const now = iso(0);
let settings = D.defaultSettings();
settings = P.acceptLegal(settings, {termsAccepted:true, safetyAccepted:true, privacyPresented:true}, now);
settings = P.confirmTemperatureUnit(settings, 'F', now);
assert.equal(P.operationalReadiness(settings).ready, true);

let entitlement = E.normalizeEntitlement({});
let context = {machines:[], recipes:[], setups:[], batches:[], settings, session:null, entitlement, storageMode:'native'};

// A fabricated local boolean must never create paid access.
assert.equal(E.evaluateEntitlement({paidAccess:true, productId:'pressbench_unlimited_lifetime_ios'}, now).paidAccess, false);

// Verified StoreKit purchase must unlock only the exact product.
const purchasedEvent = {
  action:'purchase', platform:'ios', userInitiated:true, nativeAdapterVerified:true,
  verificationSource:'storekit2', productId:'pressbench_unlimited_lifetime_ios', purchaseState:'purchased',
  transactionId:'1000000000001', nativeVerificationId:'storekit2:1000000000001:1000000000001:pressbench_unlimited_lifetime_ios:1787155200',
  storeEventAt:now
};
let purchaseResult = E.applyStoreEvent(entitlement, purchasedEvent, now);
entitlement = purchaseResult.entitlement;
assert.equal(E.evaluateEntitlement(entitlement, now).paidAccess, true);
context.entitlement = entitlement;

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
assert.equal(D.validateRunnableSetup(savedSetup, now, 0).length, 0);

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
const authorization = P.authorizeRun(context, savedSetup, {now, utcOffsetMinutes:0, progressMode:'final_confirmation', firstPiecePolicy:'required_for_unproven'});
assert.equal(authorization.authorized, true);
let run = authorization.run;
run = P.transitionRun(run, {type:'CONFIRM_INSTRUCTIONS', confirmed:true, at:iso(1)});
assert.equal(run.phase, 'first_piece');
run = P.transitionRun(run, {type:'RECORD_FIRST_PIECE', outcome:'pass', note:'', at:iso(20)});
assert.equal(run.phase, 'result_pending');
run = P.transitionRun(run, {type:'CONFIRM_ALL_GOOD', confirmedPlannedQuantity:1, explicitConfirmation:true, notes:'', saveChoice:'update_recipe', variantTitle:'', at:iso(21)});
run = P.transitionRun(run, {type:'BEGIN_COMMIT', at:iso(22)});
const commit = P.planResultCommit({...context, session:authorization.session}, run);
assert.equal(commit.batches.length, 1);
assert.equal(D.validateBatch(commit.batches[0]).length, 0);
context.batches = commit.batches; context.recipes = commit.recipes; context.setups = commit.recipes; context.session = null;

// Report gating: core exports are available free; premium reports require trusted entitlement.
const freeContext = {...context, entitlement:E.normalizeEntitlement({})};
assert.equal(P.planReport(freeContext, 'json', context.batches, now).allowed, true);
assert.equal(P.planReport(freeContext, 'pdf', context.batches, now).allowed, false);
assert.equal(P.planReport(context, 'pdf', context.batches, now).allowed, true);
assert.equal(P.planReport(context, 'xlsx', context.batches, now).allowed, true);

// Revocation is terminal and removes premium access.
const revokedEvent = {...purchasedEvent, action:'automatic_refresh', userInitiated:false, purchaseState:'revoked', storeEventAt:iso(3600)};
const revoked = E.applyStoreEvent(entitlement, revokedEvent, iso(3600)).entitlement;
assert.equal(E.evaluateEntitlement(revoked, iso(3600)).paidAccess, false);

// Destructive local-data planning is explicit and never claims to erase the
// App Store entitlement, which remains wrapper-owned.
const deletion = P.planDeleteAll(context, 'DELETE');
assert.deepStrictEqual(deletion.machines, []);
assert.deepStrictEqual(deletion.recipes, []);
assert.deepStrictEqual(deletion.batches, []);
assert.equal(deletion.session, null);
assert.equal(deletion.purchaseEntitlementUnaffected, true);
assert.equal(Object.prototype.hasOwnProperty.call(deletion, 'entitlement'), false);

console.log('ENGINE SMOKE: PASS');
