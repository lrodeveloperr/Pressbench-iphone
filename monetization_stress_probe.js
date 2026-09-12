'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
require('./PressBench/Resources/PressBenchLogic.js');

const E = globalThis.PressBenchEntitlement;
const B = globalThis.PressBenchBusiness;
const DAY = 24 * 60 * 60 * 1000;
const base = Date.parse('2042-01-01T00:00:00.000Z');
const at = days => new Date(base + days * DAY).toISOString();

function event(overrides = {}) {
  return {
    action: 'purchase',
    platform: 'ios',
    userInitiated: true,
    nativeAdapterVerified: true,
    verificationSource: 'storekit2',
    productId: B.MONETIZATION_MODEL.ios.productId,
    productType: 'auto_renewable_subscription',
    purchaseState: 'purchased',
    transactionId: 'txn-1',
    nativeVerificationId: 'storekit2:txn-1:original-1:product:2042',
    storeEventAt: at(0),
    expiresAt: at(31),
    ...overrides
  };
}

function rejects(code, action) {
  assert.throws(action, error => error && error.message === code);
}

let passed = 0;
function check(name, action) {
  action();
  passed += 1;
  process.stdout.write(`PASS ${name}\n`);
}

check('caller paidAccess flag is ignored', () => {
  assert.equal(E.evaluateEntitlement({ paidAccess: true }, at(0)).paidAccess, false);
});

check('native verification marker is mandatory', () => {
  rejects('native_store_verification_required', () => E.applyStoreEvent({}, event({ nativeAdapterVerified: false }), at(0)));
});

check('wrong product and product type are rejected', () => {
  rejects('store_product_mismatch', () => E.applyStoreEvent({}, event({ productId: 'forged' }), at(0)));
  rejects('store_product_type', () => E.applyStoreEvent({}, event({ productType: 'non_consumable' }), at(0)));
});

check('future store events and invalid expiration are rejected', () => {
  rejects('store_event_time', () => E.applyStoreEvent({}, event({ storeEventAt: at(1) }), at(0)));
  rejects('subscription_expiration', () => E.applyStoreEvent({}, event({ expiresAt: at(0) }), at(0)));
});

check('restore requires an explicit user action', () => {
  rejects('restore_requires_user_action', () => E.applyStoreEvent({}, event({ action: 'explicit_restore', userInitiated: false }), at(0)));
});

const bought = E.applyStoreEvent({}, event(), at(0)).entitlement;

check('valid purchase activates, then expires exactly at boundary', () => {
  assert.equal(E.evaluateEntitlement(bought, at(30)).paidAccess, true);
  assert.equal(E.evaluateEntitlement(bought, at(31)).paidAccess, false);
});

check('clock rollback does not extend access', () => {
  const advanced = E.advanceClock(bought, at(40));
  const rolledBack = E.evaluateEntitlement(advanced, at(2));
  assert.equal(rolledBack.clockRollbackDetected, true);
  assert.equal(rolledBack.paidAccess, false);
});

check('pending and unacknowledged Android purchases do not unlock', () => {
  const pending = E.applyStoreEvent({}, event({ purchaseState: 'pending', transactionId: '' }), at(0));
  assert.equal(pending.paidAccess, false);
  const android = E.applyStoreEvent({}, event({
    platform: 'android', verificationSource: 'play_billing',
    productId: B.MONETIZATION_MODEL.android.productId,
    productType: 'non_consumable', purchaseToken: 'android-token', transactionId: '',
    acknowledged: false, expiresAt: ''
  }), at(0));
  assert.equal(android.paidAccess, false);
  assert.equal(android.requiresAcknowledgement, true);
});

check('refund/revocation is terminal for the same transaction', () => {
  const revoked = E.applyStoreEvent(bought, event({
    action: 'automatic_refresh', userInitiated: false,
    purchaseState: 'revoked', storeEventAt: at(2), expiresAt: at(31)
  }), at(2)).entitlement;
  assert.equal(E.evaluateEntitlement(revoked, at(2)).paidAccess, false);
  rejects('terminal_transaction_replay', () => E.applyStoreEvent(revoked, event({ storeEventAt: at(3) }), at(3)));
});

check('stale store events and mismatched terminal transactions are rejected', () => {
  rejects('store_event_stale', () => E.applyStoreEvent(bought, event({ storeEventAt: at(-1) }), at(0)));
  rejects('store_transaction_mismatch', () => E.applyStoreEvent(bought, event({
    purchaseState: 'refunded', transactionId: 'other-txn', storeEventAt: at(2)
  }), at(2)));
});

check('free usage boundary is exact', () => {
  assert.equal(E.capabilities({}, { setups: 1000, batches: 1 }, at(0)).canReserveBatch, true);
  assert.equal(E.capabilities({}, { setups: 1000, batches: 2 }, at(0)).canReserveBatch, false);
});

check('a fully fabricated persisted entitlement is rejected', () => {
  const forged = {
    schemaVersion: 2,
    platform: 'ios',
    productType: 'auto_renewable_subscription',
    status: 'active',
    purchaseState: 'purchased',
    sourceStore: 'app_store',
    productId: B.MONETIZATION_MODEL.ios.productId,
    verificationSource: 'storekit2',
    storeVerified: true,
    verifiedAt: at(0),
    acknowledged: true,
    storeTransactionIdHash: 'sha256:made-up',
    nativeVerificationIdHash: 'sha256:made-up',
    storeEventAt: at(0),
    expiresAt: at(31),
    continuityUntil: at(30),
    clockFloor: at(0)
  };
  const evaluation = E.evaluateEntitlement(forged, at(1));
  assert.equal(evaluation.paidAccess, false);
  assert.equal(evaluation.runtimeSealValid, false);
  assert.equal(E.evaluateEntitlement(evaluation.entitlement, at(1)).paidAccess, false);
});

check('a legitimate cache from a previous engine launch cannot authorize', () => {
  const source = fs.readFileSync(require.resolve('./PressBench/Resources/PressBenchLogic.js'), 'utf8');
  function isolatedEngine() {
    const context = vm.createContext({ console, Date, Math, Set, Map, JSON, Object, Array, Number, String,
      Boolean, RegExp, Error, Uint8Array, TextEncoder });
    vm.runInContext(source, context);
    return context.PressBenchEntitlement;
  }
  const first = isolatedEngine();
  const cached = first.applyStoreEvent({}, event(), at(0)).entitlement;
  const relaunched = isolatedEngine();
  assert.equal(relaunched.evaluateEntitlement(JSON.parse(JSON.stringify(cached)), at(1)).paidAccess, false);
});

process.stdout.write(`monetization stress probe passed (${passed} checks)\n`);
