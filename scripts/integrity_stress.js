'use strict';

const assert = require('assert');
const path = require('path');

class MemoryStorage {
  constructor() { this.values = new Map(); }
  getItem(key) { return this.values.has(key) ? this.values.get(key) : null; }
  setItem(key, value) { this.values.set(String(key), String(value)); }
  removeItem(key) { this.values.delete(String(key)); }
  clear() { this.values.clear(); }
}

global.localStorage = new MemoryStorage();
global.sessionStorage = new MemoryStorage();
global.indexedDB = undefined;

const core = require(path.resolve(__dirname, '../PressBench/Resources/PressBenchLogic.js'));
const D = core.domain;
const B = core.business;
const E = core.entitlement;
const P = core.process;
const S = core.storage;

const now = '2040-01-01T12:00:00.000Z';
const later = (seconds) => new Date(new Date(now).getTime() + seconds * 1_000).toISOString();
const clone = (value) => JSON.parse(JSON.stringify(value));
const throws = (fn, message) => assert.throws(fn, (error) => !message || error.message === message);

function readySettings() {
  let value = D.defaultSettings();
  value = P.acceptLegal(value, { termsAccepted: true, safetyAccepted: true, privacyPresented: true }, now);
  return P.confirmTemperatureUnit(value, 'F', now);
}

function paidEntitlement() {
  return E.applyStoreEvent(E.normalizeEntitlement({}), {
    action: 'purchase', platform: 'ios', userInitiated: true, nativeAdapterVerified: true,
    verificationSource: 'storekit2', productId: 'pressbench_unlimited_monthly_ios',
    productType: 'auto_renewable_subscription', purchaseState: 'purchased',
    transactionId: 'stress-transaction-1',
    nativeVerificationId: 'storekit2:stress-transaction-1:stress-original:pressbench_unlimited_monthly_ios:2208988800',
    storeEventAt: now, expiresAt: '2040-02-01T12:00:00.000Z'
  }, now).entitlement;
}

function fixture() {
  const settings = readySettings();
  const entitlement = paidEntitlement();
  const context = { machines: [], recipes: [], setups: [], batches: [], settings, session: null, entitlement, storageMode: 'native' };
  const machinePlan = P.planSaveMachine(context, {
    nickname: 'Stress Press 🔥', brand: 'Good Use', model: 'M-∞', pressureMethod: 'Gauge', pressureScale: '0–10',
    platenOrZone: 'Main platen', lastExternalCheckDate: '2040-01-01', notes: 'Unicode: العربية 日本語', archived: false
  }, now);
  context.machines = machinePlan.machines;
  const machine = machinePlan.machine;
  const setup = D.emptySetup('F');
  Object.assign(setup, {
    title: 'Cotton + DTF', blankMaterial: 'Cotton tee', transferMedium: 'DTF', processStructure: 'other',
    machineProfileId: machine.id, machineProfile: D.machineProfileSnapshot(machine), machineNickname: machine.nickname,
    platenZone: machine.platenOrZone, temperature: 325, temperatureUnit: 'F', pressTimeSeconds: 15,
    pressure: 'Medium', pressCount: 1, defaultQuantity: 10, status: 'trial',
    instructionSource: { type: 'supplier', name: 'Supplier', reference: 'S-1', checkedDate: '2040-01-01', revision: 'A', priorBatchId: '' },
    steps: [{ id: D.uuid(), stageType: 'press', name: 'Press', instruction: 'Center transfer',
      machineNickname: machine.nickname, machineProfileId: machine.id, platenZone: machine.platenOrZone,
      temperature: 325, temperatureUnit: 'F', durationSeconds: 15, pressure: 'Medium', repeatCount: 1,
      placementAction: 'Place', finishAction: 'Peel' }]
  });
  const setupPlan = P.planSaveSetup(context, setup, now);
  context.recipes = setupPlan.setups;
  context.setups = setupPlan.setups;
  return { context, machine, setup: setupPlan.setup };
}

function completeTimerPlan(runValue, startSecond) {
  let run = runValue;
  let second = startSecond;
  if (!run.timer) run = P.transitionRun(run, { type: 'TIMER_INITIALIZE', index: 0, at: later(second++) });
  while (!(run.timer.completed && run.timer.index === run.timer.stages.length - 1)) {
    if (run.timer.completed) {
      run = P.transitionRun(run, { type: 'TIMER_NEXT', at: later(second++) });
    } else {
      run = P.transitionRun(run, { type: 'TIMER_START', at: later(second++) });
      second += Math.ceil(run.timer.totalMs / 1_000) + 1;
      run = P.transitionRun(run, { type: 'TIMER_TICK', at: later(second++) });
    }
  }
  return { run, second };
}

function completedBatch(context, setup) {
  const auth = P.authorizeRun(context, setup, {
    now, utcOffsetMinutes: 0, progressMode: 'final_confirmation', firstPiecePolicy: 'required_for_unproven', runMode: 'test'
  });
  let run = auth.run;
  run = P.transitionRun(run, { type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: later(1) });
  const timed = completeTimerPlan(run, 2);
  run = timed.run;
  run = P.transitionRun(run, { type: 'RECORD_FIRST_PIECE', outcome: 'pass', note: '', at: later(timed.second) });
  run = P.confirmAllGood(run, { confirmedPlannedQuantity: 1, explicitConfirmation: true, saveChoice: 'update_recipe' }, later(timed.second + 1));
  run = P.transitionRun(run, { type: 'BEGIN_COMMIT', at: later(timed.second + 2) });
  return { auth, run, commit: P.planResultCommit({ ...context, session: auth.session }, run) };
}

function primitivesAndLocales() {
  assert.equal(D.sha256('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  assert.equal(D.sha256('😀'), 'f0443a342c5ef54783a111b51ba56c938e474c32324d90c3a60c9c8e3a37e2d9');
  assert.equal(D.utf8ByteLength('A😀'), 5);
  assert.equal(D.utf8ByteLength('\uD800'), 3);
  assert.equal(D.text(' \u0000 hello 😀 ', 8), 'hello 😀');
  assert.equal(D.text('a😀b', 2), 'a');
  assert.match(D.nowIso(), /^\d{4}-\d{2}-\d{2}T/);
  assert.match(D.uuid(), /^[0-9a-f-]{36}$/i);

  const circular = {}; circular.self = circular;
  const getter = {}; Object.defineProperty(getter, 'x', { enumerable: true, get() { return 1; } });
  const sparse = []; sparse.length = 2;
  for (const invalid of [NaN, Infinity, undefined, () => 1, circular, getter, sparse, new Date()]) {
    assert.equal(D.isBoundedJsonValue(invalid), false);
  }
  assert.equal(D.isBoundedJsonValue({ a: [1, true, null, 'x'] }), true);
  assert.equal(D.isBoundedJsonValue({ a: { b: 1 } }, 1, 20), false);
  assert.equal(D.isBoundedJsonValue([1, 2, 3], 4, 2), false);

  assert.equal(D.isCivilDate('2024-02-29'), true);
  assert.equal(D.isCivilDate('2023-02-29'), false);
  assert.equal(D.isCivilDate('2000-02-29'), true);
  assert.equal(D.isCivilDate('1900-02-29'), false);
  assert.equal(D.isCivilDate('2400-02-29'), true);
  assert.equal(D.isCivilDate('2100-02-29'), false);
  assert.equal(D.isCivilDate('9999-12-31'), true);
  assert.equal(D.workDateFor('2040-01-01T00:30:00Z', -60), '2039-12-31');
  assert.equal(D.workDateFor('bad', 0), '');
  assert.equal(D.workDateFor(now, 841), '');
  assert.equal(D.timeZoneOffsetAt('2040-01-15T12:00:00Z', 'America/New_York'), -300);
  assert.equal(D.timeZoneOffsetAt('2040-07-15T12:00:00Z', 'America/New_York'), -240);
  assert.equal(D.timeZoneOffsetAt(now, 'Not/AZone'), null);
  assert.equal(D.canonicalLanguageId('pt_BR'), 'pt');
  assert.equal(D.resolvedLocale('zh-TW'), 'zh-Hant');
  assert.deepEqual(D.normalizeLanguageLocale('fr', 'en-US', 'CA'), { language: 'fr', locale: 'fr-CA' });
  assert.deepEqual(D.localeFallbackChain('fr-CA'), ['fr-CA', 'fr-FR', 'en-US']);
  assert.equal(D.localeFacts('ar-SA').isRtl, true);
  assert.equal(D.requireSupportedLocale('zh-Hant-TW'), 'zh-Hant');
  throws(() => D.requireSupportedLocale('../en'), 'unsupported_locale');
  throws(() => D.requireSupportedLocale('x'.repeat(36)), 'unsupported_locale');
  for (const locale of D.SUPPORTED_LOCALES) {
    const facts = D.localeFacts(locale);
    assert.equal(facts.locale, locale);
    assert(D.LANGUAGES.has(facts.language));
    assert.equal(typeof D.storeLocaleTags(locale).internal, 'string');
  }
}

function settingsMachinesAndSetups() {
  const defaults = D.defaultSettings();
  assert.equal(P.legalReady(defaults), false);
  assert.equal(P.operationalReadiness(defaults).ready, true);
  assert.equal(P.requireOperationalReadiness(defaults).ready, true);
  const ready = readySettings();
  assert.equal(P.requireOperationalReadiness(ready).ready, true);
  const reminder = P.recordReminderDecision(ready, 'deny');
  assert.equal(reminder.reminderPermission, 'denied');
  const backupMarked = P.markBackupCompleted(reminder, 4, now);
  assert.equal(D.normalizeSettings(backupMarked).lastBackupBatchCount, 4);
  assert.equal(D.migrateSettings({ language: 'es-es', temperatureUnit: 'C' }).settings.language, 'es');
  assert.equal(Object.hasOwn(D.portableSettings(ready), 'purchaseEntitlement'), false);
  assert.equal(D.validatePortableSettingsRaw(D.portableSettings(ready)), true);

  const { context, machine, setup } = fixture();
  assert.deepEqual(D.validateMachineProfile(machine, now, 0), []);
  assert.equal(D.validateV4MachineRaw(machine), true);
  assert.equal(D.machineProfileSnapshot(machine).id, machine.id);
  assert(D.validateMachineProfile({ id: '', nickname: '', lastExternalCheckDate: '2040-02-31' }).length >= 2);
  assert.equal(D.civilDateNotAfter('2040-01-01', now, 0), true);
  assert.equal(D.civilDateNotAfter('2040-01-02', now, 0), false);
  assert.equal(D.instructionSourceChecked(setup.instructionSource), true);
  assert.equal(D.instructionSourceCheckedAt(setup.instructionSource, now, 0), true);
  assert.equal(D.publicSetupStatus({ status: 'verified' }), 'proven');
  assert.equal(D.publicSetupStatus({ status: 'trial', archived: true }), 'archived');
  assert.equal(D.validateV4RecipeRaw(setup), true);
  assert.deepEqual(D.validateRecipe(setup), []);
  assert.deepEqual(D.validateVerifiableRecipe(setup), []);
  assert.deepEqual(D.validateRunnableSetup(setup, now, 0), []);
  assert.equal(D.deriveSetupTitle('Cotton', 'DTF'), 'Cotton + DTF');
  assert.equal(D.batchSetupId({ setupId: setup.id }), setup.id);
  assert.equal(P.checkedToday(setup.instructionSource, now, 0).checkedDate, '2040-01-01');
  assert.equal(P.processStructure('multi_stage', 'F').steps.length >= 1, true);
  assert.equal(P.prepareSetupForSave(setup, context, now).id, setup.id);
  assert.equal(P.reusableSetupFacts(context).soleActiveMachineCandidate.id, machine.id);

  const same = D.reuseSetup(setup, 'same_product_variant', { title: 'Variant', defaultQuantity: 2 }, later(1));
  assert.equal(same.setup.title, 'Variant');
  assert.equal(D.operationalFingerprintV4(same.setup), D.operationalFingerprintV4(setup));
  const different = D.reuseSetup(setup, 'materially_different', { title: 'Different' }, later(2));
  assert.notEqual(different.setup.id, setup.id);
  assert.equal(different.setup.status, 'draft');
  throws(() => D.reuseSetup(setup, 'invalid', {}, now), 'reuse_class');

  const archived = P.archiveSetup(setup, later(3));
  assert.equal(archived.archived, true);
  const restored = P.restoreArchivedSetup(archived, later(4));
  assert.equal(restored.archived, false);
  assert.equal(P.classifyMachineChange(machine, { ...machine, notes: 'new note' }, false).changeClass, 'metadata');
  assert.equal(P.classifyMachineChange(machine, { ...machine, platenOrZone: 'Small' }, false).changeClass, 'material');
  assert.equal(D.recipeSnapshot(setup).id, setup.id);
  assert.equal(D.setupSnapshot(setup).id, setup.id);
  assert.match(D.operationalFingerprint(setup), /^sha256:/);
  assert.match(D.provenanceFingerprint(setup), /^sha256:/);
  assert.match(D.exactSetupFingerprint(setup), /^sha256:/);
  assert.match(D.setupRevisionId(setup.id, setup), /^revision-v2:/);
  return { context, machine, setup };
}

function runsReportsAndBackups(base) {
  const { context, setup } = base;
  const completed = completedBatch(context, setup);
  const batch = completed.commit.batch;
  const live = { ...context, recipes: completed.commit.recipes, setups: completed.commit.recipes,
    batches: completed.commit.batches, session: null };
  assert.equal(D.validateV4BatchRaw(batch), true);
  assert.deepEqual(D.validateBatch(batch), []);
  assert.equal(D.batchSetup(batch).id, setup.id);
  assert.equal(D.batchJobReference({ jobName: 'J-1' }), 'J-1');
  assert.equal(D.deriveOutcome(10, 10, 0, 0), 'success');
  assert.equal(D.deriveOutcome(10, 10, 0, 1), 'rework');
  assert.equal(D.deriveOutcome(10, 9, 0, 0), 'partial');
  assert.equal(D.deriveOutcome(10, 10, 1, 0), 'failure');
  assert.equal(D.normalizeIssue({ quantity: 2, disposition: 'discarded', note: 'x' }).quantity, 2);
  assert.equal(D.normalizeStoredBatch(batch).id, batch.id);
  assert.equal(D.normalizeStoredRecipe(completed.commit.recipes[0], 'F').id, setup.id);
  assert.deepEqual(D.graphIntegrityErrors(live.machines, live.recipes, live.batches), []);
  assert.equal(D.invalidLineageBatchIds(live.batches).size, 0);
  assert.equal(D.hasValidVerificationEvidence(completed.commit.recipes[0], new Map(live.batches.map((item) => [item.id, item]))), true);
  assert.equal(P.isQualifyingEvidence(batch, completed.commit.recipes[0], live.batches), true);
  assert.equal(P.proofSummary(completed.commit.recipes[0], live.batches).publicStatus, 'proven');
  assert.equal(P.completionSummary(batch, completed.commit.recipes[0], live).processed, 1);

  assert(D.recipeMatches(setup, 'cotton', 'cotton'));
  assert(D.batchMatches(batch, 'cotton', 'cotton'));
  assert.equal(D.sortRecipes([setup, { ...setup, id: 'z', updatedAt: later(2) }])[0].id, 'z');
  assert.equal(D.sortBatches([batch, { ...batch, id: 'z', completedAt: later(100) }])[0].id, 'z');
  assert.equal(D.metrics(live.recipes, live.batches, now).batches, 1);
  assert.equal(P.setupLibrary(live.recipes, live.batches, { query: 'cotton' }).length, 1);
  assert.equal(P.insights(live, {}, now).sampleSize, 1);
  assert.equal(B.outcomeMix(live.batches).success, 1);
  assert.equal(B.sampleSeries([1, 2, 3, 4, 5], 3).length, 3);
  assert.equal(B.temperatureToC(212, 'F'), 100);
  assert.equal(B.formatTemperature(100, 'C'), '212°F / 100°C');
  assert.equal(B.formatPressure('2 bar'), '29 PSI / 2 bar');
  assert.equal(B.velocitySeries(live.batches, 30).length > 0, true);
  B.temperaturePoints(live.recipes, live.batches, 'all', 10);
  B.recordedSetpointChanges(live.recipes, live.batches, 'all', 10);

  assert.equal(P.reportCapability(live, 'pdf', live.batches, now).allowed, true);
  assert.equal(P.planReport(live, 'xlsx', live.batches, now).recordIds[0], batch.id);
  assert.equal(P.planReport(live, 'xlsx', live.batches, now).detailedRows, 2);
  assert.equal(P.reportCapability(live, 'csv', live.batches, now).reason, 'paid_report');
  assert.equal(P.reportCapability({ ...live, entitlement: E.normalizeEntitlement({}) }, 'pdf', live.batches, now).reason, 'paid_access_required');
  const oversizedReport = Array.from({ length: B.MAX_DETAILED_REPORT_ROWS + 1 }, () => batch);
  assert.equal(P.reportCapability(live, 'xlsx', oversizedReport, now).reason, 'detailed_row_limit');
  assert.equal(P.reportCapability(live, 'pdf', oversizedReport, now).reason, 'detailed_row_limit');
  assert.equal(P.capacityStatus(live, now).access.canPremiumReports, true);
  assert.equal(P.usageOf(live).batches, 0); // Paid-authorized history never consumes free capacity.
  const beyondLegacyCeiling = Array.from({ length: 2_500 }, (_, index) => ({ ...batch, id: `stress-${index}` }));
  const uncapped = P.capacityStatus({ ...live, batches: beyondLegacyCeiling }, now);
  assert.equal(uncapped.usage.batches, 0);
  assert.equal(uncapped.physicalBatchLimit, Number.MAX_SAFE_INTEGER);
  assert.equal(uncapped.access.canReserveBatch, true);

  const corrected = P.planCorrection(live, batch.id, {
    reason: 'Fix note', correctedAt: later(100), changes: { jobReference: 'J-2', notes: 'Corrected' }
  });
  assert.equal(corrected.correctedBatch.corrections.length, 1);
  const deletedBatch = P.planDeleteBatch({ ...live, batches: corrected.batches, recipes: corrected.recipes }, batch.id);
  assert.equal(deletedBatch.batches.length, 0);
  const deletedSetup = P.planDeleteSetup({ ...live, batches: [], recipes: live.recipes }, setup.id);
  assert.equal(deletedSetup.recipes.length, 0);

  const backup = D.makeBackup(live.recipes, live.batches, live.settings, live.machines);
  backup.freeRunLedger = { schemaVersion: 2, completedBatchIDs: ['free-1', 'free-2'] };
  const parsed = D.parseBackup(JSON.stringify(backup));
  assert.equal(parsed.batches.length, 1);
  assert.equal(P.inspectBackup(JSON.stringify(backup)).batches, 1);
  const recovery = P.preRestoreBackup(live);
  const restore = P.planRestore(live, JSON.stringify(backup));
  assert.equal(restore.target.batches.length, 1);
  const rollback = P.planRollback(restore.target, { ...restore.recoveryEnvelope, state: 'applied' });
  assert.equal(rollback.target.batches.length, 1);
  const migrated = P.migrateLoadedData({ ...live, recipes: undefined, setups: live.recipes }, later(200));
  assert.deepEqual(D.graphIntegrityErrors(migrated.machines, migrated.recipes, migrated.batches), []);
  assert.equal(P.operationalStateFingerprint(live), P.operationalStateFingerprint(clone(live)));
  assert.equal(P.planDeleteAll({ ...live, session: null }, 'DELETE').purchaseEntitlementUnaffected, true);
  return { live, completed };
}

function adversarialAndLongevity(base, runData) {
  const { context, setup } = base;
  assert.equal(E.evaluateEntitlement(context.entitlement, '2040-02-02T12:00:00Z').paidAccess, false);
  assert.equal(E.evaluateEntitlement(context.entitlement, '2039-01-01T00:00:00Z').clockRollbackDetected, true);
  assert.equal(E.advanceClock(context.entitlement, '2039-01-01T00:00:00Z').clockFloor, now);
  const pending = E.applyStoreEvent(E.normalizeEntitlement({}), {
    action: 'purchase', platform: 'ios', userInitiated: true, nativeAdapterVerified: true,
    verificationSource: 'storekit2', productId: 'pressbench_unlimited_monthly_ios',
    productType: 'auto_renewable_subscription', purchaseState: 'pending', storeEventAt: now,
    nativeVerificationId: 'storekit2:pending:stress'
  }, now);
  assert.equal(pending.paidAccess, false);
  assert.equal(E.capabilities(E.normalizeEntitlement({}), { setups: 0, batches: 10 }, now).canReserveBatch, false);

  const auth = P.authorizeRun(context, setup, { now, utcOffsetMinutes: 0, progressMode: 'final_confirmation', runMode: 'test' });
  assert.notEqual(auth.run.permit.authorizationBasis, 'free');
  assert.equal(P.inspectActiveRunConflict({ session: auth.session }).runId, auth.run.id);
  assert.equal(P.permitValid(auth.run), true);
  assert.equal(P.instructionCheckValid(auth.run), false);
  assert.equal(P.firstPieceRequired(setup, 'required_for_unproven'), true);
  assert.equal(P.buildProcessStages(setup).length > 0, true);
  const checkedRun = P.transitionRun(auth.run, { type: 'CONFIRM_INSTRUCTIONS', confirmed: true, at: later(1) });
  const timer = P.createTimer(checkedRun, 0);
  assert.equal(P.timerPlanFingerprint(setup), timer.planFingerprint);
  const nowMs = Date.parse(now);
  const started = P.startTimer(timer, nowMs);
  const paused = P.pauseTimer(started, nowMs + 2_000);
  assert.equal(paused.running, false);
  const timedTimer = P.moveTimer(paused, 1);
  assert.equal(timedTimer.index, 1);
  assert.equal(P.resetTimer(paused).index, paused.index);
  assert.equal(P.reconcileTimer(P.startTimer(timedTimer, nowMs), nowMs + 20_000).completed, true);

  const discard = P.planDiscardUnstarted(auth.run, later(1));
  assert.equal(discard.clearSession, true);
  let startedRun = checkedRun;
  startedRun = P.transitionRun(startedRun, { type: 'TIMER_INITIALIZE', at: later(2) });
  startedRun = P.transitionRun(startedRun, { type: 'TIMER_NEXT', at: later(3) });
  startedRun = P.transitionRun(startedRun, { type: 'TIMER_START', at: later(4) });
  startedRun = P.transitionRun(startedRun, { type: 'TIMER_PAUSE', at: later(5) });
  startedRun = P.transitionRun(startedRun, { type: 'TIMER_START', at: later(6) });
  assert.equal(startedRun.timer.running, true);
  const tampered = clone(startedRun); tampered.permit.intentFingerprint = 'sha256:bad';
  throws(() => P.transitionRun(tampered, { type: 'TIMER_TICK', at: later(7) }), 'run_permit_invalid');

  let draftSession = P.saveSetupDraft(null, D.emptySetup('F'), { now });
  assert.equal(P.validSetupDraft(draftSession.setupDraft), true);
  const snapshot = P.sessionSnapshot(null, null, draftSession.setupDraft);
  assert.equal(P.restoreSession(snapshot, [], 'F', later(1)).setupDraft.id, draftSession.setupDraft.id);
  const cleared = P.clearSetupDraft(draftSession, draftSession.setupDraft.revision, later(2));
  assert.equal(cleared.setupDraft, null);
  draftSession.setupDraft.revision = Number.MAX_SAFE_INTEGER;
  throws(() => P.saveSetupDraft(draftSession, D.emptySetup('F'), { now }), 'setup_draft_revision_exhausted');

  const completedRun = clone(runData.completed.run);
  completedRun.phase = 'result_pending';
  completedRun.resultDraft.revision = Number.MAX_SAFE_INTEGER;
  throws(() => P.saveResultDraft(completedRun, completedRun.resultDraft, later(100)), 'result_revision_exhausted');

  let migration = { machines: context.machines, recipes: context.recipes, batches: [], settings: context.settings, session: null };
  const fingerprint = P.operationalStateFingerprint(P.migrateLoadedData(migration, now));
  for (let index = 0; index < 1_000; index += 1) {
    migration = P.migrateLoadedData(migration, later(index));
    assert.equal(P.operationalStateFingerprint(migration), fingerprint);
  }

  let seed = 0xC0FFEE;
  const random = () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4_294_967_296; };
  const atoms = [null, true, false, '', ' '.repeat(5), '\u0000bad', '😀'.repeat(500), 0, -1, 1, 999999, 1000000, NaN, Infinity, {}, [], { __proto__: null }];
  for (let index = 0; index < 20_000; index += 1) {
    const value = atoms[Math.floor(random() * atoms.length)];
    const recipe = D.normalizeRecipe(value, random() > 0.5 ? 'F' : 'C', true);
    const machine = D.normalizeMachineProfile(value, true);
    const issue = D.normalizeIssue(value, true);
    const batch = D.normalizeBatch(value, true);
    assert(D.isBoundedJsonValue(recipe, 50, 20_000));
    assert(D.isBoundedJsonValue(machine, 20, 2_000));
    assert(D.isBoundedJsonValue(issue, 20, 2_000));
    assert(D.isBoundedJsonValue(batch, 60, 50_000));
    D.normalizeSearch(value);
  }
}

async function storageIntegrity() {
  assert.equal(S.hasData({ machines: [], recipes: [], batches: [] }), false);
  assert.equal(S.hasData({ machines: [{ id: 'x' }] }), true);
  assert.throws(() => S.selectRecoveryBackend('bad'), /storage_recovery_choice/);
  S.selectRecoveryBackend('compatible');
  const store = await S.create();
  assert.equal(store.mode, 'compatible');
  const initial = await store.loadAll();
  assert.deepEqual(initial.machines, []);
  await assert.rejects(store.saveMachine({}), /planner_required/);
  await assert.rejects(store.replaceAll(), /planner_required/);
  const plan = P.planDeleteAll({ machines: [], recipes: [], batches: [], settings: readySettings(), session: null }, 'DELETE');
  const result = await S.applyDeleteAll(store, plan);
  assert.equal(result.deleted, true);
  const recovery = await S.inspectRecovery();
  assert(Array.isArray(recovery.errors));
  assert.equal(await S.retireAlternateBackend('compatible'), true);
}

async function main() {
  primitivesAndLocales();
  const base = settingsMachinesAndSetups();
  const runData = runsReportsAndBackups(base);
  adversarialAndLongevity(base, runData);
  await storageIntegrity();
  console.log('INTEGRITY STRESS: PASS — 20,000 malformed-input rounds; 1,000 migration generations');
}

main().catch((error) => {
  console.error(error && error.stack || error, error && error.fields || '');
  process.exitCode = 1;
});
