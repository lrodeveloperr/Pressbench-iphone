/*
 * PressBench application logic core
 * Version: 0.21.4
 * Logic baseline: PressBench v0.20.0 (2026-08-12)
 *
 * This artifact intentionally excludes the presentation and device wrappers:
 * HTML, CSS, DOM rendering, event wiring, translated interface copy, artwork,
 * embedded fonts, PDF/XLSX presentation engines, and native billing/alert code.
 *
 * Preserved here: domain records, normalization, validation, setup and batch
 * lifecycles, evidence, lineage, corrections, analytics, entitlement-aware
 * capacity reservations, first-piece and production states, timers, exports,
 * restore validation, local persistence, and recovery selection.
 */

(function (root) {
  "use strict";
  root.PressBenchLogicMeta = Object.freeze({
    name: "PressBench",
    version: "0.21.4",
    appId: "APP-018",
    dataSchema: "press-bench-log",
    dataSchemaVersion: 4,
    sourceVersion: "0.20.0",
    sourceDate: "2026-08-12",
    logicOnly: true
  });
})(typeof globalThis !== "undefined" ? globalThis : this);

(function (root) {
  "use strict";

  // Logic-only internationalization contract. Customer-facing translations
  // remain presentation assets owned by the native wrappers. These profiles
  // define exactly 31 distinct languages and the supported BCP 47 locale
  // variants needed for deterministic storage, fallback and layout direction.
  const LOCALE_PROFILE_DATA = [
    ["en-US", "en"], ["en-CA", "en"], ["en-GB", "en"],
    ["es-MX", "es"], ["es-ES", "es"], ["pt-BR", "pt"], ["pt-PT", "pt"],
    ["fr-FR", "fr"], ["fr-CA", "fr"], ["de-DE", "de"], ["it-IT", "it"],
    ["nl-NL", "nl"], ["pl-PL", "pl"], ["tr-TR", "tr"], ["ro-RO", "ro"],
    ["cs-CZ", "cs"], ["uk-UA", "uk"], ["ru-RU", "ru"], ["ar-SA", "ar"],
    ["zh-Hans", "zh"], ["zh-Hant", "zh"], ["ja-JP", "ja"], ["ko-KR", "ko"],
    ["hi-IN", "hi"], ["ur-PK", "ur"], ["bn-BD", "bn"], ["vi-VN", "vi"],
    ["id-ID", "id"], ["th-TH", "th"], ["fil-PH", "fil"], ["ms-MY", "ms"],
    ["fi-FI", "fi"], ["sv-SE", "sv"], ["da-DK", "da"], ["nb-NO", "nb"],
    ["el-GR", "el"], ["he-IL", "he"]
  ];
  const RTL_LANGUAGE_IDS = new Set(["ar", "he", "ur"]);
  const DEFAULT_LOCALE_BY_LANGUAGE = Object.freeze({
    en: "en-US", es: "es-MX", pt: "pt-PT", fr: "fr-FR", de: "de-DE", it: "it-IT", nl: "nl-NL",
    pl: "pl-PL", tr: "tr-TR", ro: "ro-RO", cs: "cs-CZ", uk: "uk-UA", ru: "ru-RU", ar: "ar-SA",
    zh: "zh-Hans", ja: "ja-JP", ko: "ko-KR", hi: "hi-IN", ur: "ur-PK", bn: "bn-BD", vi: "vi-VN",
    id: "id-ID", th: "th-TH", fil: "fil-PH", ms: "ms-MY", fi: "fi-FI", sv: "sv-SE", da: "da-DK",
    nb: "nb-NO", el: "el-GR", he: "he-IL"
  });
  const LOCALE_PROFILES = Object.freeze(LOCALE_PROFILE_DATA.reduce(function (profiles, item) {
    profiles[item[0]] = Object.freeze({ locale: item[0], language: item[1], direction: RTL_LANGUAGE_IDS.has(item[1]) ? "rtl" : "ltr" });
    return profiles;
  }, {}));
  const LANGUAGES = new Set(Object.keys(DEFAULT_LOCALE_BY_LANGUAGE));
  const SUPPORTED_LOCALES = new Set(Object.keys(LOCALE_PROFILES));
  // Accepted only at migration/import boundaries. Newly normalized settings
  // always store one of the 31 canonical language identifiers above.
  const LEGACY_LANGUAGE_ALIASES = Object.freeze({ "es-es": "es", "pt-br": "pt", "zh-hans": "zh", "zh-hant": "zh",
    tl: "fil", no: "nb", iw: "he", in: "id" });
  const ACCEPTED_LANGUAGE_CODES = new Set(Array.from(LANGUAGES).concat(Object.keys(LEGACY_LANGUAGE_ALIASES)));
  const STORE_LOCALE_TAGS = Object.freeze(Object.keys(LOCALE_PROFILES).reduce(function (result, locale) {
    let googlePlay = locale;
    if (locale === "he-IL") googlePlay = "iw-IL";
    else if (locale === "nb-NO") googlePlay = "no-NO";
    else if (locale === "zh-Hans") googlePlay = "zh-CN";
    else if (locale === "zh-Hant") googlePlay = "zh-TW";
    else if (locale === "es-MX") googlePlay = "es-419";
    else if (locale === "id-ID") googlePlay = "id";
    else if (locale === "fil-PH") googlePlay = "fil";
    else if (["ar-SA", "ro-RO", "th-TH", "uk-UA", "ur-PK", "vi-VN"].includes(locale)) {
      googlePlay = LOCALE_PROFILES[locale].language;
    }
    const appStoreConnectMetadata = ({
      "he-IL": "he", "id-ID": "id", "nb-NO": "no", "el-GR": "el", "fi-FI": "fi", "sv-SE": "sv",
      "da-DK": "da", "cs-CZ": "cs", "th-TH": "th", "uk-UA": "uk", "vi-VN": "vi", "fil-PH": null,
      "hi-IN": "hi", "it-IT": "it", "ja-JP": "ja", "ko-KR": "ko", "ms-MY": "ms", "pl-PL": "pl",
      "ro-RO": "ro", "ru-RU": "ru", "tr-TR": "tr"
    })[locale];
    result[locale] = Object.freeze({ internal: locale, language: LOCALE_PROFILES[locale].language,
      nativeApple: locale, appStoreConnectMetadata: appStoreConnectMetadata === undefined ? locale : appStoreConnectMetadata,
      googlePlay: googlePlay });
    return result;
  }, {}));
  const UNITS = new Set(["F", "C"]);
  const THEMES = new Set(["system", "dark", "light"]);
  const PAPER_SIZES = new Set(["letter", "a4"]);
  const DIMENSION_UNITS = new Set(["in", "cm"]);
  const REMINDER_PERMISSIONS = new Set(["not_asked", "dismissed", "granted", "denied"]);
  const OUTCOMES = new Set(["success", "rework", "failure", "partial"]);
  // `verified` is retained only as a backward-compatible storage code. Every
  // public/process-facing status maps it to "proven"; it never denotes
  // manufacturer approval or certification.
  const RECIPE_STATUSES = new Set(["draft", "trial", "verified", "archived"]);
  const VALIDATION_STATUSES = new Set(["draft", "trial", "verified"]);
  const PUBLIC_SETUP_STATUSES = Object.freeze({ draft: "draft", trial: "trial", verified: "proven", archived: "archived" });
  const PROCESS_STRUCTURES = new Set(["htv", "dtf", "sublimation", "screen_printed_transfer", "multi_stage", "other", "blank"]);
  const STAGE_TYPES = new Set(["placement", "prepress", "press", "peel", "cool", "postpress"]);
  const INSTRUCTION_SOURCE_TYPES = new Set(["none", "manufacturer", "supplier", "user_test", "prior_successful_batch"]);
  const RUN_MODES = new Set(["test", "production"]);
  const PROGRESS_MODES = new Set(["final_confirmation", "live_cycles"]);
  const SETUP_REUSE_CLASSES = Object.freeze({
    EXACT_REPEAT: "exact_repeat",
    SAME_PRODUCT_VARIANT: "same_product_variant",
    MATERIALLY_DIFFERENT: "materially_different"
  });
  const AUTHORIZATION_BASES = new Set(["free", "ios_paid", "ios_cached_paid", "android_paid", "android_cached_paid",
    "legacy_migration"]);
  const FIRST_PIECE_OUTCOMES = new Set(["not_required", "pending", "pass", "adjust_retry", "stop"]);
  const RUN_PHASES = new Set(["preflight", "first_piece", "production_ready", "running", "paused", "result_pending", "committing", "completed", "aborted_before_start"]);
  const ISSUE_SYMPTOMS = new Set([
    "color_shift", "ghosting", "edge_lift", "adhesion", "scorch", "alignment", "incomplete_transfer",
    "uneven_heat_pressure", "moisture", "transfer_shift", "contamination", "substrate_defect",
    "design_setup", "print_supply", "equipment_power", "interrupted", "other", "unknown"
  ]);
  const ISSUE_CAUSES = new Set([
    "unknown", "heat", "pressure", "time", "moisture", "placement", "transfer", "substrate",
    "design", "printer_ink_paper", "equipment_power", "operator_interruption", "other"
  ]);
  const ISSUE_DISPOSITIONS = new Set(["reworked", "discarded"]);
  const REVIEW_STATUSES = new Set(["complete", "legacy_needs_review"]);
  const MAX_RECORDS = 1000;
  const MAX_STAGES = 20;
  const MAX_ISSUES = 100;
  const MAX_CORRECTIONS = 100;
  const MAX_BACKUP_BYTES = 10_000_000;
  const MAX_DATA_BYTES = 8_000_000;
  const MAX_RECORD_BYTES = 1_000_000;
  const TERMS_VERSION = "APP-018-TERMS-v2";
  const SAFETY_ACK_VERSION = "APP-018-SAFETY-v2";
  const PRIVACY_NOTICE_VERSION = "APP-018-PRIVACY-v2";
  const SYSTEM_STARTER_IDS = new Set([
    "starter-template-standard-htv", "starter-template-polyester-dtf", "starter-template-sublimation",
    "starter-template-multi-stage", "starter-template-puff-vinyl", "starter-template-screen-printed-transfer",
    "starter-template-other", "starter-template-blank"
  ]);
  const STARTER_TEMPLATE_NOTE = "Structural starter only. It contains no operating values. Enter and check every value against the current equipment, transfer, substrate, and safety instructions before use.";
  const STARTER_SIGNATURES = Object.freeze({
    "starter-template-standard-htv": ["HTV setup", "htv", "Heat transfer vinyl (HTV)", "Press"],
    "starter-template-polyester-dtf": ["DTF setup", "dtf", "Direct-to-film transfer (DTF)", "Press"],
    "starter-template-sublimation": ["Sublimation setup", "sublimation", "Sublimation transfer", "Press"],
    "starter-template-multi-stage": ["Multi-stage setup", "multi_stage", "", "Stage 1"],
    "starter-template-puff-vinyl": ["Puff vinyl setup", "htv", "Puff heat transfer vinyl", "Press"],
    "starter-template-screen-printed-transfer": ["Screen-printed transfer setup", "screen_printed_transfer", "Screen-printed transfer", "Press"],
    "starter-template-other": ["Other process setup", "other", "", "Press"],
    "starter-template-blank": ["Blank setup", "blank", "", "Press"]
  });
  // Frozen fingerprints identify only the five exact v0.19 publisher records.
  // They let migration remove unsafe legacy presets without retaining their
  // operating values or mistaking an edited user record for a system record.
  const LEGACY_CANONICAL_STARTER_FINGERPRINTS = new Set([
    "sha256:081d17bcea514ebe00135a0dda515724ad4b2563b36d07259093f515c53616f2",
    "sha256:d2b72b3d51754a0ff5b8fd4eead47d768f6dbd4ab47da596d55dd5a1ffeeea8d",
    "sha256:af51d3c391813e59657c477d1bf358634325446de0e5509c67dffd390f132b08",
    "sha256:c73926c7d7d2ad53717ee93b6291a35ed0ba27648d99688b86909ed8f77e993e",
    "sha256:3495e47705b500550a2c23a2b6bf35dcd36c428dc448b24b70ab502aac87919d"
  ]);
  const LEGACY_CANONICAL_STARTER_METADATA = Object.freeze({
    "starter-template-standard-htv": "bd5dda130a36fae457fa877c0976fe1e37d76a62714f1f32190b9b3c85d4f200",
    "starter-template-polyester-dtf": "1ba322e40764126ffc95db069e9cf48d450b684d982bc458d5cf4f1d071c1c9d",
    "starter-template-sublimation": "aff740daa55fd7ed17d62e93dd6ca69440f170d6994f2e231caa554630b1b64c",
    "starter-template-multi-stage": "aad988a3b519d30e503140103c4730da56fc91040e1640212c4b732da09b2618",
    "starter-template-puff-vinyl": "6f7fb01bc1a3039d1063b370beb472db9752861776b47ebbd2b6c6e716f1d6df"
  });

  function nowIso() {
    return new Date().toISOString();
  }

  function uuid() {
    if (root.crypto && typeof root.crypto.randomUUID === "function") return root.crypto.randomUUID();
    if (root.crypto && typeof root.crypto.getRandomValues === "function") {
      const bytes = new Uint8Array(16); root.crypto.getRandomValues(bytes);
      bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
      const hex = Array.from(bytes, function (value) { return value.toString(16).padStart(2, "0"); }).join("");
      return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
    }
    const seed = `${Date.now()}-${Math.random()}-${Math.random()}`;
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (char) {
      const value = Math.abs(hashCode(seed + char + Math.random())) % 16;
      return (char === "x" ? value : (value & 3) | 8).toString(16);
    });
  }

  function hashCode(value) {
    let hash = 0;
    for (let index = 0; index < value.length; index += 1) hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0;
    return hash;
  }

  function sha256(value) {
    const bytes = [];
    for (let index = 0; index < value.length; index += 1) {
      let code = value.charCodeAt(index);
      if (code < 0x80) bytes.push(code);
      else if (code < 0x800) bytes.push(0xC0 | (code >>> 6), 0x80 | (code & 0x3F));
      else if (code >= 0xD800 && code <= 0xDBFF && index + 1 < value.length) {
        const low = value.charCodeAt(index + 1);
        if (low >= 0xDC00 && low <= 0xDFFF) {
          code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00); index += 1;
          bytes.push(0xF0 | (code >>> 18), 0x80 | ((code >>> 12) & 0x3F), 0x80 | ((code >>> 6) & 0x3F), 0x80 | (code & 0x3F));
        } else bytes.push(0xEF, 0xBF, 0xBD);
      } else if (code >= 0xDC00 && code <= 0xDFFF) bytes.push(0xEF, 0xBF, 0xBD);
      else bytes.push(0xE0 | (code >>> 12), 0x80 | ((code >>> 6) & 0x3F), 0x80 | (code & 0x3F));
    }
    const bitLength = bytes.length * 8;
    bytes.push(0x80);
    while (bytes.length % 64 !== 56) bytes.push(0);
    const highLength = Math.floor(bitLength / 0x100000000);
    const lowLength = bitLength >>> 0;
    for (let shift = 24; shift >= 0; shift -= 8) bytes.push((highLength >>> shift) & 0xFF);
    for (let shift = 24; shift >= 0; shift -= 8) bytes.push((lowLength >>> shift) & 0xFF);
    const constants = [
      0x428A2F98,0x71374491,0xB5C0FBCF,0xE9B5DBA5,0x3956C25B,0x59F111F1,0x923F82A4,0xAB1C5ED5,
      0xD807AA98,0x12835B01,0x243185BE,0x550C7DC3,0x72BE5D74,0x80DEB1FE,0x9BDC06A7,0xC19BF174,
      0xE49B69C1,0xEFBE4786,0x0FC19DC6,0x240CA1CC,0x2DE92C6F,0x4A7484AA,0x5CB0A9DC,0x76F988DA,
      0x983E5152,0xA831C66D,0xB00327C8,0xBF597FC7,0xC6E00BF3,0xD5A79147,0x06CA6351,0x14292967,
      0x27B70A85,0x2E1B2138,0x4D2C6DFC,0x53380D13,0x650A7354,0x766A0ABB,0x81C2C92E,0x92722C85,
      0xA2BFE8A1,0xA81A664B,0xC24B8B70,0xC76C51A3,0xD192E819,0xD6990624,0xF40E3585,0x106AA070,
      0x19A4C116,0x1E376C08,0x2748774C,0x34B0BCB5,0x391C0CB3,0x4ED8AA4A,0x5B9CCA4F,0x682E6FF3,
      0x748F82EE,0x78A5636F,0x84C87814,0x8CC70208,0x90BEFFFA,0xA4506CEB,0xBEF9A3F7,0xC67178F2
    ];
    const state = [0x6A09E667,0xBB67AE85,0x3C6EF372,0xA54FF53A,0x510E527F,0x9B05688C,0x1F83D9AB,0x5BE0CD19];
    const words = new Uint32Array(64);
    const rotate = function (number, bits) { return (number >>> bits) | (number << (32 - bits)); };
    for (let offset = 0; offset < bytes.length; offset += 64) {
      for (let index = 0; index < 16; index += 1) {
        const cursor = offset + index * 4;
        words[index] = ((bytes[cursor] << 24) | (bytes[cursor + 1] << 16) | (bytes[cursor + 2] << 8) | bytes[cursor + 3]) >>> 0;
      }
      for (let index = 16; index < 64; index += 1) {
        const s0 = rotate(words[index - 15], 7) ^ rotate(words[index - 15], 18) ^ (words[index - 15] >>> 3);
        const s1 = rotate(words[index - 2], 17) ^ rotate(words[index - 2], 19) ^ (words[index - 2] >>> 10);
        words[index] = (words[index - 16] + s0 + words[index - 7] + s1) >>> 0;
      }
      let a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7];
      for (let index = 0; index < 64; index += 1) {
        const sum1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25);
        const choice = (e & f) ^ (~e & g);
        const temp1 = (h + sum1 + choice + constants[index] + words[index]) >>> 0;
        const sum0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22);
        const majority = (a & b) ^ (a & c) ^ (b & c);
        const temp2 = (sum0 + majority) >>> 0;
        h = g; g = f; f = e; e = (d + temp1) >>> 0; d = c; c = b; b = a; a = (temp1 + temp2) >>> 0;
      }
      state[0] = (state[0] + a) >>> 0; state[1] = (state[1] + b) >>> 0;
      state[2] = (state[2] + c) >>> 0; state[3] = (state[3] + d) >>> 0;
      state[4] = (state[4] + e) >>> 0; state[5] = (state[5] + f) >>> 0;
      state[6] = (state[6] + g) >>> 0; state[7] = (state[7] + h) >>> 0;
    }
    return state.map(function (part) { return part.toString(16).padStart(8, "0"); }).join("");
  }

  function text(value, maxLength) {
    if (value === null || value === undefined) return "";
    const cleaned = String(value).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim();
    const limit = Number.isInteger(maxLength) && maxLength >= 0 ? maxLength : 5000;
    if (cleaned.length <= limit) return cleaned;
    let end = limit;
    if (end > 0 && /[\uD800-\uDBFF]/.test(cleaned.charAt(end - 1)) && /[\uDC00-\uDFFF]/.test(cleaned.charAt(end))) end -= 1;
    return cleaned.slice(0, end);
  }

  function isBoundedJsonValue(value, maxDepth, maxNodes) {
    const depthLimit = Number.isInteger(maxDepth) ? maxDepth : 40;
    const nodeLimit = Number.isInteger(maxNodes) ? maxNodes : 20000;
    const active = new WeakSet();
    const stack = [{ value: value, depth: 0, exit: false }];
    let nodes = 0;
    try {
      while (stack.length) {
        const entry = stack.pop(); const current = entry.value;
        if (entry.exit) { active.delete(current); continue; }
        nodes += 1;
        if (nodes > nodeLimit || entry.depth > depthLimit) return false;
        if (current === null || typeof current === "string" || typeof current === "boolean") continue;
        if (typeof current === "number") { if (!Number.isFinite(current)) return false; continue; }
        if (typeof current !== "object" || active.has(current)) return false;
        const prototype = Object.getPrototypeOf(current);
        if (prototype !== null) {
          const constructor = Object.prototype.hasOwnProperty.call(prototype, "constructor") ? prototype.constructor : null;
          const expectedName = Array.isArray(current) ? "Array" : "Object";
          if (typeof constructor !== "function" || constructor.name !== expectedName) return false;
        } else if (Array.isArray(current)) return false;
        active.add(current); stack.push({ value: current, depth: entry.depth, exit: true });
        if (Array.isArray(current)) {
          const ownKeys = Reflect.ownKeys(current);
          if (ownKeys.some(function (key) { return key !== "length" && (typeof key !== "string" || !/^(0|[1-9]\d*)$/.test(key)); })) return false;
          for (let index = current.length - 1; index >= 0; index -= 1) {
            if (!Object.prototype.hasOwnProperty.call(current, index)) return false;
            stack.push({ value: current[index], depth: entry.depth + 1, exit: false });
          }
        } else {
          if (Object.getOwnPropertySymbols(current).length) return false;
          const names = Object.getOwnPropertyNames(current); const keys = Object.keys(current);
          if (names.length !== keys.length) return false;
          if (keys.some(function (key) { return key === "__proto__" || key === "prototype" || key === "constructor"; })) return false;
          for (let index = keys.length - 1; index >= 0; index -= 1) {
            const descriptor = Object.getOwnPropertyDescriptor(current, keys[index]);
            if (!descriptor || !("value" in descriptor)) return false;
            stack.push({ value: descriptor.value, depth: entry.depth + 1, exit: false });
          }
        }
      }
      return true;
    } catch (_) { return false; }
  }

  function boundedJsonSnapshot(value) {
    if (!isBoundedJsonValue(value)) throw new Error("storage_corrupt");
    return JSON.parse(JSON.stringify(value));
  }

  function number(value, fallback, min, max) {
    if (value === "" || value === null || value === undefined) return fallback;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : text(value, 40);
  }

  function integer(value, fallback, min, max) {
    return number(value, fallback, min, max);
  }

  function invalidNumber(value, min, max, requireInteger) {
    if (value === "" || value === null || value === undefined) return false;
    if (typeof value !== "number" && typeof value !== "string") return true;
    const parsed = Number(value);
    return !Number.isFinite(parsed) || parsed < min || parsed > max || (requireInteger && !Number.isInteger(parsed));
  }

  function validDate(value, fallback) {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? fallback : parsed.toISOString();
  }

  function recipeMutationTime(recipe) {
    const supplied = Array.prototype.slice.call(arguments, 1).filter(function (value) {
      const timestamp = typeof value === "number" ? value : new Date(value).getTime(); return Number.isFinite(timestamp);
    });
    const values = [recipe && recipe.createdAt, recipe && recipe.updatedAt, recipe && recipe.verifiedAt]
      .concat(supplied.length ? supplied : [Date.now()]);
    const latest = values.reduce(function (result, value) {
      const timestamp = typeof value === "number" ? value : new Date(value).getTime();
      return Number.isFinite(timestamp) ? Math.max(result, timestamp) : result;
    }, -Infinity);
    if (!Number.isFinite(latest)) return nowIso();
    return new Date(latest).toISOString();
  }

  function isCivilDate(value) {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
    const parts = value.split("-").map(Number);
    const parsed = new Date(Date.UTC(parts[0], parts[1] - 1, parts[2]));
    return parsed.getUTCFullYear() === parts[0] && parsed.getUTCMonth() === parts[1] - 1 && parsed.getUTCDate() === parts[2];
  }

  function workDateFor(completedAt, utcOffsetMinutes) {
    const timestamp = new Date(completedAt).getTime();
    const offset = Number(utcOffsetMinutes);
    if (!Number.isFinite(timestamp) || !Number.isInteger(offset) || offset < -840 || offset > 840) return "";
    const local = new Date(timestamp + offset * 60000);
    return [local.getUTCFullYear(), String(local.getUTCMonth() + 1).padStart(2, "0"), String(local.getUTCDate()).padStart(2, "0")].join("-");
  }

  function timeZoneOffsetAt(value, timeZone) {
    if (typeof timeZone !== "string" || !timeZone) return null;
    const instant = new Date(value);
    if (Number.isNaN(instant.getTime()) || !root.Intl || typeof root.Intl.DateTimeFormat !== "function") return null;
    try {
      const parts = new root.Intl.DateTimeFormat("en-US-u-ca-gregory-nu-latn", {
        timeZone: timeZone, year: "numeric", month: "2-digit", day: "2-digit",
        hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23"
      }).formatToParts(instant).reduce(function (result, part) {
        if (part.type !== "literal") result[part.type] = Number(part.value);
        return result;
      }, {});
      if (![parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second].every(Number.isFinite)) return null;
      const representedAsUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute, parts.second);
      return Math.round((representedAsUtc - instant.getTime()) / 60000);
    } catch (_) { return null; }
  }

  function canonicalLanguageId(value) {
    const code = text(value, 35).replace(/_/g, "-").toLowerCase();
    if (!code) return "";
    if (LEGACY_LANGUAGE_ALIASES[code]) return LEGACY_LANGUAGE_ALIASES[code];
    const base = code.split("-")[0];
    return LEGACY_LANGUAGE_ALIASES[base] || (LANGUAGES.has(base) ? base : "");
  }

  function acceptedLanguageCode(value) {
    const code = text(value, 35).replace(/_/g, "-").toLowerCase();
    return ACCEPTED_LANGUAGE_CODES.has(code) ? code : "";
  }

  function localeRegion(value) {
    const code = text(value, 35).replace(/_/g, "-");
    const match = code.match(/-([A-Za-z]{2}|\d{3})(?:-|$)/);
    return match && /^[A-Za-z]{2}$/.test(match[1]) ? match[1].toUpperCase() : "";
  }

  function resolvedLocale(languageOrLocale, region, fallback) {
    const code = text(languageOrLocale, 35).replace(/_/g, "-");
    const lower = code.toLowerCase();
    const exact = Object.keys(LOCALE_PROFILES).find(function (locale) { return locale.toLowerCase() === lower; });
    if (exact) return exact;
    const base = canonicalLanguageId(code); const area = (/^[A-Za-z]{2}$/.test(text(region, 3))
      ? text(region, 3).toUpperCase() : localeRegion(code));
    if (base === "en") return area === "CA" ? "en-CA" : area === "GB" ? "en-GB" : "en-US";
    if (base === "es") return area === "ES" ? "es-ES" : "es-MX";
    if (base === "pt") return area === "BR" ? "pt-BR" : "pt-PT";
    if (base === "fr") return area === "CA" ? "fr-CA" : "fr-FR";
    if (base === "zh") return /hant|tw|hk|mo/i.test(code) || ["TW", "HK", "MO"].includes(area) ? "zh-Hant" : "zh-Hans";
    if (base && DEFAULT_LOCALE_BY_LANGUAGE[base]) return DEFAULT_LOCALE_BY_LANGUAGE[base];
    const fallbackCode = text(fallback, 35).replace(/_/g, "-");
    const exactFallback = Object.keys(LOCALE_PROFILES).find(function (locale) { return locale.toLowerCase() === fallbackCode.toLowerCase(); });
    return exactFallback || "en-US";
  }

  function normalizeLanguageLocale(language, locale, region, fallback) {
    const languageId = canonicalLanguageId(language) || canonicalLanguageId(locale) || "en";
    let canonicalLocale = resolvedLocale(locale || languageId, region, fallback || "en-US");
    if (!LOCALE_PROFILES[canonicalLocale] || LOCALE_PROFILES[canonicalLocale].language !== languageId) {
      canonicalLocale = resolvedLocale(languageId, region, fallback || "en-US");
    }
    return Object.freeze({ language: languageId, locale: canonicalLocale });
  }

  function localeFallbackChain(locale, fallback) {
    const canonical = resolvedLocale(locale, localeRegion(locale), fallback || "en-US");
    const language = LOCALE_PROFILES[canonical].language;
    const result = [canonical]; const languageDefault = DEFAULT_LOCALE_BY_LANGUAGE[language];
    // Traditional and Simplified Chinese are different translation assets;
    // never silently cross script when a locale-specific key is unavailable.
    if (language !== "zh" && languageDefault && !result.includes(languageDefault)) result.push(languageDefault);
    if (!result.includes("en-US")) result.push("en-US");
    return Object.freeze(result);
  }

  function localeFacts(value, fallback) {
    const canonical = resolvedLocale(value, localeRegion(value), fallback || "en-US");
    const profile = LOCALE_PROFILES[canonical];
    return Object.freeze({ locale: canonical, language: profile.language, direction: profile.direction,
      isRtl: profile.direction === "rtl", fallbackChain: localeFallbackChain(canonical, fallback) });
  }

  function requireSupportedLocale(value) {
    if (typeof value !== "string" || !value || value.length > 35 || value !== value.trim() ||
      /[\u0000-\u001F\u007F-\u009F\/\\]/.test(value)) throw new Error("unsupported_locale");
    const code = text(value, 35).replace(/_/g, "-");
    if (!code || !/^[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-[A-Za-z]{2}|-\d{3})?$/.test(code)) throw new Error("unsupported_locale");
    if (/^zh-(?:Hans-CN|Hant-(?:TW|HK))$/i.test(code)) return /hant/i.test(code) ? "zh-Hant" : "zh-Hans";
    const exact = Object.keys(LOCALE_PROFILES).find(function (locale) { return locale.toLowerCase() === code.toLowerCase(); });
    const acceptedAliases = { "iw-il": "he-IL", "in-id": "id-ID", "no-no": "nb-NO", "tl-ph": "fil-PH",
      "zh-cn": "zh-Hans", "zh-tw": "zh-Hant", "zh-hk": "zh-Hant", "es-419": "es-MX" };
    if (exact) return exact;
    if (acceptedAliases[code.toLowerCase()]) return acceptedAliases[code.toLowerCase()];
    const language = canonicalLanguageId(code);
    if (language && code.toLowerCase() === language) return DEFAULT_LOCALE_BY_LANGUAGE[language];
    throw new Error("unsupported_locale");
  }

  function storeLocaleTags(value) {
    return STORE_LOCALE_TAGS[requireSupportedLocale(value)];
  }

  function defaultSettings() {
    const browserLocale = text(root.navigator && root.navigator.language, 35).replace(/_/g, "-");
    const languagePart = canonicalLanguageId(browserLocale);
    const rawRegion = ((browserLocale.match(/-([A-Za-z]{2}|\d{3})(?:-|$)/) || [])[1] || "US").toUpperCase();
    const region = /^\d{3}$/.test(rawRegion) ? ({ es: "MX", pt: "BR", fr: "FR", zh: "CN" }[languagePart] || "US") : rawRegion;
    const defaultUnit = region === "US" ? "F" : "C";
    const languageLocale = normalizeLanguageLocale(languagePart, browserLocale, region, "en-US");
    return {
      settingsSchemaVersion: 5,
      language: languageLocale.language,
      locale: languageLocale.locale,
      region: region,
      defaultUnit: defaultUnit,
      confirmedTemperatureUnit: "",
      temperatureUnitConfirmedAt: "",
      dimensionUnit: region === "US" ? "in" : "cm",
      paperSize: region === "US" ? "letter" : "a4",
      termsAcceptedVersion: "",
      termsAcceptedAt: "",
      safetyAcceptedVersion: "",
      safetyAcceptedAt: "",
      privacyNoticeVersionViewed: "",
      privacyNoticeViewedAt: "",
      starterTemplatesVersion: "",
      reminderPermission: "not_asked",
      lastBackupAt: "",
      lastBackupBatchCount: 0
    };
  }

  function normalizeSettings(value) {
    const defaults = defaultSettings();
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const requestedRegion = text(source.region, 3).toUpperCase();
    const storedLocaleRegion = localeRegion(source.locale);
    const region = /^[A-Z]{2}$/.test(requestedRegion) ? requestedRegion : storedLocaleRegion || defaults.region;
    const languageLocale = normalizeLanguageLocale(source.language, source.locale, region, defaults.locale);
    const metricRegion = region !== "US";
    return {
      settingsSchemaVersion: 5,
      language: languageLocale.language,
      locale: languageLocale.locale,
      region: region,
      defaultUnit: UNITS.has(source.defaultUnit) ? source.defaultUnit : metricRegion ? "C" : "F",
      confirmedTemperatureUnit: UNITS.has(source.confirmedTemperatureUnit) ? source.confirmedTemperatureUnit : "",
      temperatureUnitConfirmedAt: source.temperatureUnitConfirmedAt ? validDate(source.temperatureUnitConfirmedAt, "") : "",
      dimensionUnit: DIMENSION_UNITS.has(source.dimensionUnit) ? source.dimensionUnit : metricRegion ? "cm" : "in",
      paperSize: PAPER_SIZES.has(source.paperSize) ? source.paperSize : metricRegion ? "a4" : "letter",
      // A prior bundled acknowledgement is deliberately not promoted to the
      // separate current Terms and safety acknowledgements.
      termsAcceptedVersion: text(source.termsAcceptedVersion, 80),
      termsAcceptedAt: source.termsAcceptedAt ? validDate(source.termsAcceptedAt, "") : "",
      safetyAcceptedVersion: text(source.safetyAcceptedVersion, 80),
      safetyAcceptedAt: source.safetyAcceptedAt ? validDate(source.safetyAcceptedAt, "") : "",
      privacyNoticeVersionViewed: text(source.privacyNoticeVersionViewed, 80),
      privacyNoticeViewedAt: source.privacyNoticeViewedAt ? validDate(source.privacyNoticeViewedAt, "") : "",
      starterTemplatesVersion: text(source.starterTemplatesVersion, 80),
      reminderPermission: REMINDER_PERMISSIONS.has(source.reminderPermission) ? source.reminderPermission : "not_asked",
      lastBackupAt: source.lastBackupAt ? validDate(source.lastBackupAt, "") : "",
      lastBackupBatchCount: integer(source.lastBackupBatchCount, 0, 0, MAX_RECORDS)
    };
  }

  function migrateSettings(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const sourceSchemaVersion = Number.isInteger(source.settingsSchemaVersion) ? source.settingsSchemaVersion : 0;
    const settings = normalizeSettings(source);
    return Object.freeze({ sourceSchemaVersion: sourceSchemaVersion, targetSchemaVersion: 5,
      migrated: sourceSchemaVersion !== 5 || JSON.stringify(source) !== JSON.stringify(settings), settings: settings });
  }

  function portableSettings(value) {
    const normalized = normalizeSettings(value);
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    return {
      settingsSchemaVersion: 2,
      language: normalized.language,
      locale: normalized.locale,
      region: normalized.region,
      defaultUnit: normalized.defaultUnit,
      dimensionUnit: normalized.dimensionUnit,
      paperSize: normalized.paperSize,
      // These v2 fields remain only to read and write the established portable
      // backup format. Presentation/device wrappers own the live preferences.
      hapticsEnabled: source.hapticsEnabled !== false,
      soundEnabled: source.soundEnabled === true,
      theme: THEMES.has(source.theme) ? source.theme : "light"
    };
  }

  function normalizeMachineProfile(value, preserveId) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const timestamp = nowIso();
    const createdAt = validDate(source.createdAt, timestamp);
    const updatedAt = validDate(source.updatedAt, createdAt);
    return {
      recordSchemaVersion: 1,
      id: preserveId ? text(source.id, 100) : uuid(),
      nickname: text(source.nickname || source.machineNickname, 120),
      brand: text(source.brand, 120),
      model: text(source.model, 120),
      pressureMethod: text(source.pressureMethod, 120),
      pressureScale: text(source.pressureScale, 120),
      platenOrZone: text(source.platenOrZone || source.platenZone, 120),
      lastExternalCheckDate: isCivilDate(source.lastExternalCheckDate) ? source.lastExternalCheckDate : "",
      notes: text(source.notes, 1000),
      archived: source.archived === true,
      createdAt: createdAt,
      updatedAt: new Date(Math.max(new Date(createdAt).getTime(), new Date(updatedAt).getTime())).toISOString()
    };
  }

  function civilDateNotAfter(value, boundary, utcOffsetMinutes) {
    if (!value) return true;
    if (!isCivilDate(value)) return false;
    const limit = new Date(boundary === undefined ? Date.now() : boundary);
    if (Number.isNaN(limit.getTime())) return false;
    const offset = Number.isInteger(utcOffsetMinutes) && utcOffsetMinutes >= -840 && utcOffsetMinutes <= 840
      ? utcOffsetMinutes : -limit.getTimezoneOffset();
    const limitDate = workDateFor(limit.toISOString(), offset);
    return value <= limitDate;
  }

  function machineProfileSnapshot(value) {
    const profile = normalizeMachineProfile(value, true);
    return {
      id: profile.id,
      nickname: profile.nickname,
      brand: profile.brand,
      model: profile.model,
      pressureMethod: profile.pressureMethod,
      pressureScale: profile.pressureScale,
      platenOrZone: profile.platenOrZone,
      lastExternalCheckDate: profile.lastExternalCheckDate
    };
  }

  function validateMachineProfile(value) {
    const profile = normalizeMachineProfile(value, true);
    const errors = [];
    if (!text(value && value.id, 100)) errors.push("id");
    if (!profile.nickname) errors.push("nickname");
    if (value && value.lastExternalCheckDate && !isCivilDate(value.lastExternalCheckDate)) errors.push("lastExternalCheckDate");
    if (value && value.lastExternalCheckDate && !civilDateNotAfter(value.lastExternalCheckDate)) errors.push("lastExternalCheckDate");
    return errors;
  }

  function normalizeInstructionSource(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const type = INSTRUCTION_SOURCE_TYPES.has(source.type) ? source.type : "none";
    return {
      type: type,
      name: text(source.name || source.supplierName, 180),
      reference: text(source.reference || source.document || source.url || source.note, 1000),
      checkedDate: isCivilDate(source.checkedDate) ? source.checkedDate : "",
      revision: text(source.revision, 180),
      priorBatchId: type === "prior_successful_batch" ? text(source.priorBatchId, 100) : ""
    };
  }

  function instructionSourceChecked(value) {
    const source = normalizeInstructionSource(value);
    if (source.type === "none" || !source.checkedDate) return false;
    if (source.type === "prior_successful_batch") return Boolean(source.priorBatchId);
    if (source.type === "user_test") return Boolean(source.reference);
    return Boolean(source.name && source.reference);
  }

  function instructionSourceCheckedAt(value, boundary, utcOffsetMinutes) {
    const source = normalizeInstructionSource(value);
    return instructionSourceChecked(source) && civilDateNotAfter(source.checkedDate, boundary, utcOffsetMinutes);
  }

  function publicSetupStatus(value) {
    const recipe = value && typeof value === "object" ? value : { status: value };
    if (recipe.archived === true || recipe.status === "archived") return "archived";
    return PUBLIC_SETUP_STATUSES[recipe.status] || "draft";
  }

  function emptyRecipe(defaultUnit) {
    const timestamp = nowIso();
    return {
      setupSchemaVersion: 4,
      id: uuid(),
      title: "",
      customerJob: "",
      jobReference: "",
      processStructure: "blank",
      blankMaterial: "",
      transferMedium: "",
      machineProfileId: "",
      machineProfile: machineProfileSnapshot({}),
      instructionSource: normalizeInstructionSource(null),
      machineNickname: "",
      platenZone: "",
      temperature: "",
      temperatureUnit: UNITS.has(defaultUnit) ? defaultUnit : "F",
      pressTimeSeconds: "",
      pressure: "",
      prePressSeconds: "",
      peelMethod: "",
      pressCount: 1,
      defaultQuantity: 1,
      notes: "",
      status: "draft",
      archived: false,
      verifiedAt: "",
      verifiedBatchId: "",
      provenEvidenceCount: 0,
      persistedOperationalFingerprintV4: "",
      // Evidence completed at or before this boundary is historical only. This
      // is set when an archived setup is restored or its exact process/source
      // definition changes, so an old result cannot silently re-prove it.
      proofResetAt: "",
      blankSupplier: "",
      blankSku: "",
      blankLot: "",
      blankColourSize: "",
      transferSupplier: "",
      transferSku: "",
      transferLot: "",
      designRevision: "",
      printerInkPaperProfile: "",
      accessoriesPlacementCooling: "",
      steps: [],
      createdAt: timestamp,
      updatedAt: timestamp,
      lastUsedAt: ""
    };
  }

  function normalizeStep(value, defaultUnit, preserveId) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const stageType = STAGE_TYPES.has(source.stageType) ? source.stageType : "press";
    const suppliedDuration = source.durationSeconds === undefined ? source.pressTimeSeconds : source.durationSeconds;
    const durationSeconds = suppliedDuration === "" || suppliedDuration === null || suppliedDuration === undefined
      ? "" : integer(suppliedDuration, "", 1, 9999);
    return {
      id: preserveId && text(source.id, 100) ? text(source.id, 100) : uuid(),
      stageType: stageType,
      name: text(source.name, 120),
      instruction: text(source.instruction || source.placementAction || source.finishAction, 500),
      machineNickname: text(source.machineNickname, 120),
      machineProfileId: text(source.machineProfileId, 100),
      platenZone: text(source.platenZone, 120),
      temperature: source.temperature === "" || source.temperature === null || source.temperature === undefined ? "" : number(source.temperature, "", 0, 999),
      temperatureUnit: UNITS.has(source.temperatureUnit) ? source.temperatureUnit : (UNITS.has(defaultUnit) ? defaultUnit : "F"),
      durationSeconds: durationSeconds,
      // Compatibility alias for v1-v3 adapters; non-press actions use durationSeconds.
      pressTimeSeconds: stageType === "press" || stageType === "prepress" ? durationSeconds : "",
      pressure: text(source.pressure, 120),
      repeatCount: integer(source.repeatCount, 1, 1, 99),
      placementAction: text(source.placementAction, 500),
      finishAction: text(source.finishAction, 500)
    };
  }

  function baseStepFromRecipe(source, defaultUnit) {
    return normalizeStep({
      id: source.stepId,
      stageType: "press",
      name: source.stepName || "",
      machineNickname: source.machineNickname,
      machineProfileId: source.machineProfileId,
      platenZone: source.platenZone,
      temperature: source.temperature,
      temperatureUnit: source.temperatureUnit,
      durationSeconds: source.durationSeconds === undefined ? source.pressTimeSeconds : source.durationSeconds,
      pressure: source.pressure,
      repeatCount: source.pressCount,
      placementAction: source.placementAction,
      finishAction: source.peelMethod
    }, defaultUnit, Boolean(source.stepId));
  }

  function normalizeRecipe(value, defaultUnit, preserveId) {
    const base = emptyRecipe(defaultUnit);
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const timestamp = nowIso();
    const providedSteps = Array.isArray(source.steps) ? source.steps.slice(0, MAX_STAGES).map(function (step) {
      return normalizeStep(step, source.temperatureUnit || defaultUnit, true);
    }) : [];
    let steps = providedSteps.length ? providedSteps : [baseStepFromRecipe(source, defaultUnit)];
    const seedStep = steps[0];
    let machineProfile = machineProfileSnapshot(source.machineProfile && typeof source.machineProfile === "object"
      ? source.machineProfile
      : { id: source.machineProfileId, nickname: seedStep.machineNickname || source.machineNickname,
        platenOrZone: seedStep.platenZone || source.platenZone });
    const machineProfileId = text(source.machineProfileId || machineProfile.id, 100);
    if (machineProfileId && machineProfile.id !== machineProfileId) machineProfile = Object.assign({}, machineProfile, { id: machineProfileId });
    steps = steps.map(function (step) {
      return Object.assign({}, step, {
        machineProfileId: step.machineProfileId || machineProfileId,
        machineNickname: step.machineNickname || machineProfile.nickname,
        platenZone: step.platenZone || machineProfile.platenOrZone
      });
    });
    const firstStep = steps[0];
    const processStructure = PROCESS_STRUCTURES.has(source.processStructure) ? source.processStructure : "other";
    const instructionSource = normalizeInstructionSource(source.instructionSource);
    const requestedStatus = RECIPE_STATUSES.has(source.status) ? source.status : "draft";
    const archived = source.archived === true || requestedStatus === "archived";
    const priorStatus = VALIDATION_STATUSES.has(source.archivedStatus) ? source.archivedStatus : "trial";
    const validationStatus = requestedStatus === "archived" ? priorStatus : requestedStatus;
    const status = validationStatus === "verified" && !text(source.verifiedBatchId, 100) ? "trial" : validationStatus;
    const createdAt = validDate(source.createdAt, timestamp);
    const verifiedAt = status === "verified" && source.verifiedAt ? validDate(source.verifiedAt, timestamp) : "";
    const suppliedUpdatedAt = validDate(source.updatedAt, timestamp);
    const updatedAt = new Date(Math.max(new Date(createdAt).getTime(), new Date(suppliedUpdatedAt).getTime(), verifiedAt ? new Date(verifiedAt).getTime() : -Infinity)).toISOString();
    return {
      setupSchemaVersion: 4,
      id: preserveId && text(source.id, 100) ? text(source.id, 100) : base.id,
      title: text(source.title, 140),
      customerJob: text(source.jobReference || source.customerJob, 180),
      jobReference: text(source.jobReference || source.customerJob, 180),
      processStructure: processStructure,
      blankMaterial: text(source.blankMaterial, 180),
      transferMedium: text(source.transferMedium, 180),
      machineProfileId: machineProfileId,
      machineProfile: machineProfile,
      instructionSource: instructionSource,
      machineNickname: firstStep.machineNickname,
      platenZone: firstStep.platenZone,
      temperature: firstStep.temperature,
      temperatureUnit: firstStep.temperatureUnit,
      pressTimeSeconds: firstStep.durationSeconds,
      pressure: firstStep.pressure,
      prePressSeconds: source.prePressSeconds === "" || source.prePressSeconds === null || source.prePressSeconds === undefined ? "" : integer(source.prePressSeconds, "", 0, 9999),
      peelMethod: firstStep.finishAction,
      pressCount: firstStep.repeatCount,
      defaultQuantity: integer(source.defaultQuantity, 1, 1, 999999),
      notes: text(source.notes, 5000),
      status: status,
      archived: archived,
      verifiedAt: verifiedAt,
      verifiedBatchId: status === "verified" ? text(source.verifiedBatchId, 100) : "",
      provenEvidenceCount: integer(source.provenEvidenceCount, 0, 0, MAX_RECORDS),
      persistedOperationalFingerprintV4: text(source.persistedOperationalFingerprintV4, 80),
      proofResetAt: source.proofResetAt ? validDate(source.proofResetAt, "") : "",
      blankSupplier: text(source.blankSupplier, 180),
      blankSku: text(source.blankSku, 180),
      blankLot: text(source.blankLot, 180),
      blankColourSize: text(source.blankColourSize, 180),
      transferSupplier: text(source.transferSupplier, 180),
      transferSku: text(source.transferSku, 180),
      transferLot: text(source.transferLot, 180),
      designRevision: text(source.designRevision, 180),
      printerInkPaperProfile: text(source.printerInkPaperProfile, 500),
      accessoriesPlacementCooling: text(source.accessoriesPlacementCooling, 1000),
      steps: steps,
      needsReview: source.needsReview === true,
      migrationOriginal: source.needsReview === true && source.migrationOriginal && typeof source.migrationOriginal === "object" && !Array.isArray(source.migrationOriginal) ? legacyRecipeSnapshot(source.migrationOriginal) : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastUsedAt: source.lastUsedAt ? validDate(source.lastUsedAt, "") : ""
    };
  }

  function legacyRecipeSnapshot(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    return boundedJsonSnapshot(source);
  }

  function quarantineStoredRecipe(source, defaultUnit) {
    const original = source.needsReview === true && source.migrationOriginal && typeof source.migrationOriginal === "object" && !Array.isArray(source.migrationOriginal) ? source.migrationOriginal : source;
    const prepared = uniqueLegacySteps(source, source.temperatureUnit || defaultUnit);
    const normalized = normalizeRecipe(prepared, defaultUnit, true);
    const safe = Object.assign({}, normalized, {
      defaultQuantity: invalidNumber(normalized.defaultQuantity, 1, 999999, true) ? 1 : normalized.defaultQuantity,
      prePressSeconds: normalized.prePressSeconds !== "" && invalidNumber(normalized.prePressSeconds, 0, 9999, true) ? "" : normalized.prePressSeconds,
      steps: normalized.steps.map(function (step) { return Object.assign({}, step, {
        temperature: step.temperature !== "" && invalidNumber(step.temperature, 0, 999, false) ? "" : step.temperature,
        pressTimeSeconds: step.pressTimeSeconds !== "" && invalidNumber(step.pressTimeSeconds, 1, 9999, true) ? "" : step.pressTimeSeconds,
        repeatCount: invalidNumber(step.repeatCount, 1, 99, true) ? 1 : step.repeatCount
      }); }),
      status: "draft", verifiedAt: "", verifiedBatchId: "", needsReview: true, migrationOriginal: legacyRecipeSnapshot(original)
    });
    return normalizeRecipe(safe, defaultUnit, true);
  }

  function normalizeStoredRecipe(value, defaultUnit) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    if (source.needsReview === true) return quarantineStoredRecipe(source, defaultUnit);
    const allowStarter = SYSTEM_STARTER_IDS.has(text(source.id, 100));
    const rawValid = source.setupSchemaVersion === 4 ? validateV4RecipeRaw(source, false, allowStarter)
      : source.archived === undefined ? validateV2RecipeRaw(source, false, allowStarter) : validateV3RecipeRaw(source, false, allowStarter);
    const normalized = normalizeRecipe(source, defaultUnit, true);
    if (rawValid && (!allowStarter || isCanonicalStarterRecipe(normalized))) return normalized;
    const validEditedStarter = allowStarter && (source.setupSchemaVersion === 4 ? validateV4RecipeRaw(source, false, false)
      : source.archived === undefined ? validateV2RecipeRaw(source, false, false) : validateV3RecipeRaw(source, false, false));
    if (validEditedStarter) return normalized;
    return quarantineStoredRecipe(source, defaultUnit);
  }

  function isCanonicalStarterRecipe(value) {
    const id = text(value && value.id, 100);
    const signature = STARTER_SIGNATURES[id];
    if (!signature) return false;
    const recipe = normalizeRecipe(value, value && value.temperatureUnit, true);
    const step = recipe.steps.length === 1 ? recipe.steps[0] : null;
    const emptyRecipeFields = ["customerJob", "jobReference", "blankMaterial", "prePressSeconds", "blankSupplier", "blankSku", "blankLot", "blankColourSize", "transferSupplier", "transferSku", "transferLot", "designRevision", "printerInkPaperProfile", "accessoriesPlacementCooling"];
    return Boolean(step) && recipe.id === id && recipe.title === signature[0] && recipe.processStructure === signature[1] && recipe.transferMedium === signature[2] &&
      recipe.defaultQuantity === 1 && recipe.notes === STARTER_TEMPLATE_NOTE && recipe.status === "draft" && recipe.archived === false && recipe.needsReview === false && !recipe.verifiedAt && !recipe.verifiedBatchId &&
      !instructionSourceChecked(recipe.instructionSource) && emptyRecipeFields.every(function (key) { return recipe[key] === ""; }) &&
      step.id === `${id}-step-1` && step.name === signature[3] && step.stageType === "press" && step.machineNickname === "" &&
      step.machineProfileId === "" && step.platenZone === "" && step.temperature === "" && UNITS.has(step.temperatureUnit) &&
      step.durationSeconds === "" && step.pressTimeSeconds === "" && step.pressure === "" && step.repeatCount === 1 &&
      step.instruction === "" && step.placementAction === "" && step.finishAction === "";
  }

  function isLegacyCanonicalStarterRecipe(value) {
    const id = text(value && value.id, 100);
    if (!SYSTEM_STARTER_IDS.has(id) || !LEGACY_CANONICAL_STARTER_METADATA[id]) return false;
    try {
      const recipe = normalizeRecipe(value, value && value.temperatureUnit, true);
      const metadata = JSON.stringify({ id: recipe.id, title: recipe.title, customerJob: recipe.customerJob,
        defaultQuantity: recipe.defaultQuantity, status: recipe.status, archived: recipe.archived === true,
        notes: recipe.notes, stepIds: recipe.steps.map(function (step) { return step.id; }),
        stepNames: recipe.steps.map(function (step) { return step.name; }) });
      return LEGACY_CANONICAL_STARTER_FINGERPRINTS.has(operationalFingerprint(recipe)) &&
        sha256(metadata) === LEGACY_CANONICAL_STARTER_METADATA[id];
    }
    catch (_) { return false; }
  }

  function deriveSetupTitle(blankMaterial, transferMedium) {
    const material = text(blankMaterial, 180);
    const transfer = text(transferMedium, 180);
    return text([material, transfer].filter(Boolean).join(" + "), 140);
  }

  function reuseSetup(recipeValue, reuseClass, changes, now) {
    const source = normalizeRecipe(recipeValue, recipeValue && recipeValue.temperatureUnit, true);
    const requestedKind = text(reuseClass, 40);
    const kind = requestedKind === "different_definition" ? SETUP_REUSE_CLASSES.MATERIALLY_DIFFERENT : requestedKind;
    const edits = changes && typeof changes === "object" && !Array.isArray(changes) ? changes : {};
    const timestamp = recipeMutationTime(source, now);
    if (kind === SETUP_REUSE_CLASSES.EXACT_REPEAT) {
      if (Object.keys(edits).length) throw new Error("exact_repeat_changes");
      const exact = recipeSnapshot(source);
      exact.customerJob = ""; exact.jobReference = "";
      return { reuseClass: kind, createsSetup: false,
        setup: normalizeRecipe(exact, exact.temperatureUnit, true), setupId: source.id };
    }
    if (![SETUP_REUSE_CLASSES.SAME_PRODUCT_VARIANT, SETUP_REUSE_CLASSES.MATERIALLY_DIFFERENT].includes(kind)) {
      throw new Error("reuse_class");
    }
    if (kind === SETUP_REUSE_CLASSES.SAME_PRODUCT_VARIANT) {
      const safeFields = new Set(["title", "notes", "defaultQuantity"]);
      if (Object.keys(edits).some(function (key) { return !safeFields.has(key); })) {
        throw new Error("materially_different_reuse_required");
      }
    }
    const newId = uuid();
    let candidate = normalizeRecipe(Object.assign({}, source, edits, {
      id: newId, status: "trial", archived: false, verifiedAt: "", verifiedBatchId: "",
      provenEvidenceCount: 0, proofResetAt: timestamp, createdAt: timestamp, updatedAt: timestamp,
      lastUsedAt: "", customerJob: "", jobReference: "",
      steps: (edits.steps || source.steps).map(function (step) { return Object.assign({}, step, { id: uuid() }); })
    }), edits.temperatureUnit || source.temperatureUnit, true);
    if (kind === SETUP_REUSE_CLASSES.MATERIALLY_DIFFERENT) {
      const explicitTraceability = {};
      ["blankSupplier", "blankSku", "blankLot", "blankColourSize", "transferSupplier", "transferSku", "transferLot",
        "designRevision", "printerInkPaperProfile"].forEach(function (key) {
        explicitTraceability[key] = Object.prototype.hasOwnProperty.call(edits, key) ? candidate[key] : "";
      });
      candidate = normalizeRecipe(Object.assign({}, candidate, {
        status: "draft", instructionSource: normalizeInstructionSource(null), prePressSeconds: "",
        peelMethod: "", accessoriesPlacementCooling: "", notes: Object.prototype.hasOwnProperty.call(edits, "notes") ? candidate.notes : "",
        ...explicitTraceability,
        steps: candidate.steps.map(function (step) { return Object.assign({}, step, {
          instruction: "", temperature: "", durationSeconds: "", pressTimeSeconds: "", pressure: "",
          repeatCount: 1, placementAction: "", finishAction: ""
        }); })
      }), candidate.temperatureUnit, true);
    }
    candidate.title = text(edits.title, 140) || (kind === SETUP_REUSE_CLASSES.SAME_PRODUCT_VARIANT
      ? source.title : deriveSetupTitle(candidate.blankMaterial, candidate.transferMedium));
    candidate.persistedOperationalFingerprintV4 = operationalFingerprintV4(candidate);
    return { reuseClass: kind, createsSetup: true, setup: normalizeRecipe(candidate, candidate.temperatureUnit, true),
      setupId: candidate.id, sourceSetupId: source.id };
  }

  function recipeSnapshot(recipe) {
    const normalized = normalizeRecipe(recipe, recipe.temperatureUnit, true);
    const snapshot = {};
    [
      "setupSchemaVersion", "id", "title", "customerJob", "jobReference", "processStructure", "blankMaterial", "transferMedium",
      "machineProfileId", "machineProfile", "instructionSource", "machineNickname", "platenZone",
      "temperature", "temperatureUnit", "pressTimeSeconds", "pressure", "prePressSeconds", "peelMethod",
      "pressCount", "defaultQuantity", "notes", "status", "archived", "verifiedAt", "verifiedBatchId", "provenEvidenceCount",
      "persistedOperationalFingerprintV4", "proofResetAt", "blankSupplier", "blankSku", "blankLot",
      "blankColourSize", "transferSupplier", "transferSku", "transferLot", "designRevision", "printerInkPaperProfile",
      "accessoriesPlacementCooling", "steps"
    ].forEach(function (key) { snapshot[key] = normalized[key]; });
    return snapshot;
  }

  function operationalDefinition(recipe) {
    const normalized = normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    return JSON.stringify({
      blankMaterial: normalized.blankMaterial,
      transferMedium: normalized.transferMedium,
      prePressSeconds: normalized.prePressSeconds,
      blankSupplier: normalized.blankSupplier,
      blankSku: normalized.blankSku,
      blankLot: normalized.blankLot,
      blankColourSize: normalized.blankColourSize,
      transferSupplier: normalized.transferSupplier,
      transferSku: normalized.transferSku,
      transferLot: normalized.transferLot,
      designRevision: normalized.designRevision,
      printerInkPaperProfile: normalized.printerInkPaperProfile,
      accessoriesPlacementCooling: normalized.accessoriesPlacementCooling,
      steps: normalized.steps.map(function (step) {
        return {
          machineNickname: step.machineNickname,
          platenZone: step.platenZone,
          temperature: step.temperature,
          temperatureUnit: step.temperatureUnit,
          pressTimeSeconds: step.pressTimeSeconds,
          pressure: step.pressure,
          repeatCount: step.repeatCount,
          placementAction: step.placementAction,
          finishAction: step.finishAction
        };
      })
    });
  }

  function operationalFingerprint(recipe) {
    return `sha256:${sha256(operationalDefinition(recipe))}`;
  }

  function recipeRevisionId(recipeId, recipe) {
    return `revision-v1:${sha256(`${text(recipeId, 100)}\n${operationalDefinition(recipe)}`)}`;
  }

  function legacyRecipeRevisionId(recipeId, recipe) {
    return `${text(recipeId, 100)}-${Math.abs(hashCode(operationalDefinition(recipe))).toString(36)}`;
  }

  function operationalDefinitionV4(recipe) {
    const normalized = normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    return JSON.stringify({
      processStructure: normalized.processStructure,
      blankMaterial: normalized.blankMaterial,
      transferMedium: normalized.transferMedium,
      blankSupplier: normalized.blankSupplier,
      blankSku: normalized.blankSku,
      blankLot: normalized.blankLot,
      blankColourSize: normalized.blankColourSize,
      transferSupplier: normalized.transferSupplier,
      transferSku: normalized.transferSku,
      transferLot: normalized.transferLot,
      designRevision: normalized.designRevision,
      printerInkPaperProfile: normalized.printerInkPaperProfile,
      accessoriesPlacementCooling: normalized.accessoriesPlacementCooling,
      prePressSeconds: normalized.prePressSeconds,
      machineProfile: machineProfileSnapshot(normalized.machineProfile),
      stages: normalized.steps.map(function (step) {
        return {
          stageType: step.stageType,
          name: step.name,
          instruction: step.instruction,
          machineProfileId: step.machineProfileId,
          machineNickname: step.machineNickname,
          platenZone: step.platenZone,
          temperature: step.temperature,
          temperatureUnit: step.temperatureUnit,
          durationSeconds: step.durationSeconds,
          pressure: step.pressure,
          repeatCount: step.repeatCount,
          placementAction: step.placementAction,
          finishAction: step.finishAction
        };
      })
    });
  }

  function provenanceDefinition(recipe) {
    const normalized = normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    return JSON.stringify(normalized.instructionSource);
  }

  function operationalFingerprintV4(recipe) {
    return `sha256:${sha256(operationalDefinitionV4(recipe))}`;
  }

  function provenanceFingerprint(recipe) {
    return `sha256:${sha256(provenanceDefinition(recipe))}`;
  }

  function exactSetupFingerprint(recipe) {
    return `sha256:${sha256(`${operationalDefinitionV4(recipe)}\n${provenanceDefinition(recipe)}`)}`;
  }

  function recipeRevisionIdV4(recipeId, recipe) {
    return `revision-v2:${sha256(`${text(recipeId, 100)}\n${operationalDefinitionV4(recipe)}\n${provenanceDefinition(recipe)}`)}`;
  }

  function deriveOutcome(quantityPlanned, quantityProcessed, quantityWaste, quantityReworked) {
    const planned = Number(quantityPlanned || 0);
    const processed = Number(quantityProcessed === "" || quantityProcessed === null || quantityProcessed === undefined
      ? planned : quantityProcessed);
    const waste = Number(quantityWaste || 0);
    const reworked = Number(quantityReworked || 0);
    if (waste > 0) return "failure";
    if (reworked > 0) return "rework";
    if (processed < planned) return "partial";
    return "success";
  }

  function normalizeIssue(value, preserveId) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    return {
      id: preserveId && text(source.id, 100) ? text(source.id, 100) : uuid(),
      quantity: integer(source.quantity, 1, 1, 999999),
      symptom: ISSUE_SYMPTOMS.has(source.symptom) ? source.symptom : "unknown",
      suspectedCause: ISSUE_CAUSES.has(source.suspectedCause) ? source.suspectedCause : "unknown",
      disposition: ISSUE_DISPOSITIONS.has(source.disposition) ? source.disposition : "reworked",
      note: text(source.note, 1000)
    };
  }

  function normalizeCorrection(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const previous = source.previous && typeof source.previous === "object" && !Array.isArray(source.previous) ? Object.assign({}, source.previous) : {};
    if (!Object.prototype.hasOwnProperty.call(previous, "quantityProcessed") &&
        Object.prototype.hasOwnProperty.call(previous, "quantityGood") && Object.prototype.hasOwnProperty.call(previous, "quantityWaste")) {
      previous.quantityProcessed = Number(previous.quantityGood || 0) + Number(previous.quantityWaste || 0);
    }
    if (previous.recordSchemaVersion === 3) {
      const planned = Number(previous.quantityPlanned || 0);
      const processed = Number(previous.quantityProcessed || 0);
      const waste = Number(previous.quantityWaste || 0);
      const reworked = Number(previous.quantityReworked || 0);
      previous.completionStatus = processed < planned ? "partial" : "complete";
      previous.outcome = deriveOutcome(planned, processed, waste, reworked);
      previous.failureReason = text((Array.isArray(previous.issues) ? previous.issues : []).map(function (issue) { return issue.note || issue.symptom; }).filter(Boolean).join("; "), 1000);
      if (previous.recipe && typeof previous.recipe === "object") previous.recipeRevisionId = recipeRevisionId(previous.recipeId || previous.recipe.id, previous.recipe);
    }
    return {
      correctedAt: validDate(source.correctedAt, nowIso()),
      previous: previous,
      note: text(source.note, 500)
    };
  }

  function legacyBatchSnapshot(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    return boundedJsonSnapshot(source);
  }

  function normalizeBatch(value, preserveId) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const timestamp = nowIso();
    const planned = integer(source.quantityPlanned, 1, 1, 999999);
    const reviewStatus = REVIEW_STATUSES.has(source.reviewStatus) ? source.reviewStatus : "complete";
    const suppliedGood = integer(source.quantityGood, 0, 0, 999999);
    const waste = integer(source.quantityWaste, 0, 0, 999999);
    const reworked = integer(source.quantityReworked, 0, 0, 999999);
    const processed = integer(source.quantityProcessed, Number(suppliedGood || 0) + Number(waste || 0), 0, 999999);
    const good = reviewStatus === "complete" && Number.isFinite(Number(processed)) && Number.isFinite(Number(waste))
      ? Math.max(0, Number(processed) - Number(waste)) : suppliedGood;
    const issues = Array.isArray(source.issues) ? source.issues.slice(0, 100).map(function (issue) { return normalizeIssue(issue, true); }) : [];
    const recipe = recipeSnapshot(source.recipe || {});
    const initialPressedSetup = recipeSnapshot(source.initialPressedSetup || source.firstPressedSetup || source.recipe || {});
    const setupChangedDuringRun = source.setupChangedDuringRun === true ||
      exactSetupFingerprint(initialPressedSetup) !== exactSetupFingerprint(recipe);
    const recipeId = text(source.setupId || source.recipeId, 100);
    const jobReference = text(source.jobReference || source.jobName, 180);
    const outcome = reviewStatus === "complete" ? deriveOutcome(planned, processed, waste, reworked) : (OUTCOMES.has(source.outcome) ? source.outcome : "partial");
    const startedAt = source.startedAt ? validDate(source.startedAt, "") : "";
    const completedAt = validDate(source.completedAt, timestamp);
    const completedDate = new Date(completedAt);
    const utcOffsetMinutes = Number.isInteger(source.utcOffsetMinutes) && source.utcOffsetMinutes >= -840 && source.utcOffsetMinutes <= 840 ? source.utcOffsetMinutes : -completedDate.getTimezoneOffset();
    const derivedWorkDate = workDateFor(completedAt, utcOffsetMinutes);
    let resolvedTimeZone = "";
    try { resolvedTimeZone = text(Intl.DateTimeFormat().resolvedOptions().timeZone, 100); } catch (_) {}
    const requestedTimeZone = text(source.timeZone, 100);
    const timeZone = requestedTimeZone && timeZoneOffsetAt(completedAt, requestedTimeZone) === utcOffsetMinutes
      ? requestedTimeZone : (resolvedTimeZone && timeZoneOffsetAt(completedAt, resolvedTimeZone) === utcOffsetMinutes ? resolvedTimeZone : "");
    const elapsedSeconds = startedAt ? Math.max(0, Math.round((new Date(completedAt).getTime() - new Date(startedAt).getTime()) / 1000)) : "";
    const firstPieceSource = source.firstPiece && typeof source.firstPiece === "object" && !Array.isArray(source.firstPiece) ? source.firstPiece : {};
    const firstPieceOutcome = FIRST_PIECE_OUTCOMES.has(firstPieceSource.outcome) ? firstPieceSource.outcome : "not_required";
    const firstPiece = {
      outcome: firstPieceOutcome,
      attemptedAt: firstPieceSource.attemptedAt ? validDate(firstPieceSource.attemptedAt, "") : "",
      completedAt: firstPieceSource.completedAt ? validDate(firstPieceSource.completedAt, "") : "",
      attempts: integer(firstPieceSource.attempts, firstPieceOutcome === "not_required" ? 0 : 1, 0, 99),
      note: text(firstPieceSource.note, 1000)
    };
    const qcChecks = Array.isArray(source.qcChecks) ? source.qcChecks.slice(0, 100).map(function (check) {
      const item = check && typeof check === "object" && !Array.isArray(check) ? check : {};
      return { checkedAt: validDate(item.checkedAt, completedAt), processedCount: integer(item.processedCount, 0, 0, planned),
        result: ["pass", "adjust", "end_early"].includes(item.result) ? item.result : "pass", note: text(item.note, 1000) };
    }) : [];
    const interruptions = Array.isArray(source.interruptions) ? source.interruptions.slice(0, 100).map(function (entry) {
      const item = entry && typeof entry === "object" && !Array.isArray(entry) ? entry : {};
      return { startedAt: validDate(item.startedAt, startedAt || completedAt), endedAt: item.endedAt ? validDate(item.endedAt, "") : "",
        reason: text(item.reason, 500), productionBegan: item.productionBegan === true };
    }) : [];
    const legacyInstructionValid = Boolean(source.manufacturerVerifiedAt) &&
      [operationalFingerprint(recipe), operationalDefinition(recipe)].includes(source.manufacturerVerificationFingerprint);
    const instructionCheckedAt = source.instructionCheckedAt ? validDate(source.instructionCheckedAt, "") :
      legacyInstructionValid ? validDate(source.manufacturerVerifiedAt, "") : "";
    const instructionCheckFingerprint = text(source.instructionCheckFingerprint, 80) ||
      (legacyInstructionValid ? exactSetupFingerprint(recipe) : "");
    return {
      recordSchemaVersion: 4,
      processSchemaVersion: 4,
      id: preserveId && text(source.id, 100) ? text(source.id, 100) : uuid(),
      setupId: recipeId,
      recipeId: recipeId,
      recipe: recipe,
      initialPressedSetup: initialPressedSetup,
      setupChangedDuringRun: setupChangedDuringRun,
      setupRevisionId: recipeRevisionIdV4(recipeId || recipe.id, recipe),
      recipeRevisionId: recipeRevisionId(recipeId || recipe.id, recipe),
      sourceBatchId: text(source.sourceBatchId, 100),
      jobReference: jobReference,
      jobName: jobReference,
      quantityPlanned: planned,
      quantityProcessed: processed,
      quantityGood: good,
      quantityWaste: waste,
      quantityReworked: reworked,
      outcome: outcome,
      completionStatus: Number(processed) < Number(planned) ? "partial" : "complete",
      issues: issues,
      failureReason: text(issues.map(function (issue) { return issue.note || issue.symptom; }).filter(Boolean).join("; "), 1000),
      notes: text(source.notes, 5000),
      runMode: RUN_MODES.has(source.runMode) ? source.runMode : "production",
      firstPiece: firstPiece,
      qcChecks: qcChecks,
      interruptions: interruptions,
      productionStartedAt: source.productionStartedAt ? validDate(source.productionStartedAt, "") : "",
      instructionCheckedAt: instructionCheckedAt,
      instructionCheckFingerprint: instructionCheckFingerprint,
      operationalFingerprintV4: text(source.operationalFingerprintV4, 80) || operationalFingerprintV4(recipe),
      provenanceFingerprint: text(source.provenanceFingerprint, 80) || provenanceFingerprint(recipe),
      exactSetupFingerprint: text(source.exactSetupFingerprint, 80) || exactSetupFingerprint(recipe),
      authorizationBasis: text(source.authorizationBasis, 80) || (source.processSchemaVersion === 4 ? "" : "legacy_migration"),
      startedAt: startedAt,
      completedAt: completedAt,
      workDate: derivedWorkDate,
      utcOffsetMinutes: utcOffsetMinutes,
      timeZone: timeZone,
      durationSeconds: source.durationSeconds === "" || source.durationSeconds === null || source.durationSeconds === undefined ? elapsedSeconds : integer(source.durationSeconds, elapsedSeconds, 0, 31536000),
      corrections: Array.isArray(source.corrections) ? source.corrections.map(normalizeCorrection) : [],
      reviewStatus: reviewStatus,
      legacyOriginal: reviewStatus === "legacy_needs_review" ? legacyBatchSnapshot(source.legacyOriginal || source) : null
    };
  }

  function migrateLegacyBatch(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const original = source.reviewStatus === "legacy_needs_review" && source.legacyOriginal && typeof source.legacyOriginal === "object" && !Array.isArray(source.legacyOriginal)
      ? source.legacyOriginal : source;
    const recipeSource = original.recipe && typeof original.recipe === "object" && !Array.isArray(original.recipe)
      ? original.recipe : (source.recipe && typeof source.recipe === "object" && !Array.isArray(source.recipe) ? source.recipe : {});
    const legacyRecipe = Object.assign({}, recipeSource);
    const legacyRecipeId = text(original.recipeId, 100) || text(source.recipeId, 100);
    if (legacyRecipeId) legacyRecipe.id = legacyRecipeId;
    return normalizeBatch(Object.assign({}, source, {
      recipeId: legacyRecipeId,
      recipe: uniqueLegacySteps(legacyRecipe, legacyRecipe.temperatureUnit),
      quantityProcessed: Number(original.quantityGood || 0) + Number(original.quantityWaste || 0),
      quantityReworked: 0,
      sourceBatchId: "",
      issues: [],
      corrections: [],
      startedAt: "",
      durationSeconds: "",
      timeZone: "",
      manufacturerVerifiedAt: "",
      manufacturerVerificationFingerprint: "",
      reviewStatus: "legacy_needs_review",
      legacyOriginal: legacyBatchSnapshot(original)
    }), true);
  }

  function normalizeStoredBatch(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const requiredShape = ["reviewStatus", "quantityReworked", "issues", "corrections", "recipe", "outcome", "quantityPlanned", "quantityGood", "quantityWaste", "completedAt"];
    if (!requiredShape.every(function (key) { return Object.prototype.hasOwnProperty.call(source, key); })) return migrateLegacyBatch(source);
    const storedSchemaVersion = source.recordSchemaVersion === undefined ? 2 : Number(source.recordSchemaVersion);
    const rawIsValid = source.processSchemaVersion === 4 ? validateV4BatchRaw(source) : storedSchemaVersion === 3 ? validateV3BatchRaw(source)
      : storedSchemaVersion === 2 ? validateV2BatchRaw(source) : false;
    if (!rawIsValid) return migrateLegacyBatch(source);
    const normalized = normalizeBatch(source, true);
    const canonicalRaw = normalized.processSchemaVersion === 4 ? validateV4BatchRaw(normalized) : validateV3BatchRaw(normalized);
    if (canonicalRaw === false || (normalized.reviewStatus !== "legacy_needs_review" && validateBatch(normalized).length)) return migrateLegacyBatch(source);
    return normalized;
  }

  function batchSetup(batch) { return batch && (batch.setup || batch.recipe) || null; }
  function batchSetupId(batch) { return text(batch && (batch.setupId || batch.recipeId), 100); }
  function batchJobReference(batch) { return text(batch && (batch.jobReference || batch.jobName), 180); }

  function validateRecipeInput(recipe) {
    const errors = [];
    if (!text(recipe.title, 140)) errors.push("title");
    if (!text(recipe.blankMaterial, 180)) errors.push("blankMaterial");
    if (invalidNumber(recipe.temperature, 0, 999, false)) errors.push("temperature");
    if (invalidNumber(recipe.pressTimeSeconds, 1, 9999, true)) errors.push("pressTimeSeconds");
    if (invalidNumber(recipe.prePressSeconds, 0, 9999, true)) errors.push("prePressSeconds");
    const hasSteps = Array.isArray(recipe.steps) && recipe.steps.length > 0;
    if ((!hasSteps && (recipe.pressCount === "" || recipe.pressCount === null || recipe.pressCount === undefined)) || (recipe.pressCount !== "" && recipe.pressCount !== null && recipe.pressCount !== undefined && invalidNumber(recipe.pressCount, 1, 99, true))) errors.push("pressCount");
    if (recipe.defaultQuantity === "" || recipe.defaultQuantity === null || recipe.defaultQuantity === undefined || invalidNumber(recipe.defaultQuantity, 1, 999999, true)) errors.push("defaultQuantity");
    if (Array.isArray(recipe.steps)) recipe.steps.forEach(function (step, index) {
      if (invalidNumber(step.temperature, 0, 999, false)) errors.push(`steps.${index}.temperature`);
      if (invalidNumber(step.pressTimeSeconds, 1, 9999, true)) errors.push(`steps.${index}.pressTimeSeconds`);
      if (step.repeatCount === "" || step.repeatCount === null || step.repeatCount === undefined || invalidNumber(step.repeatCount, 1, 99, true)) errors.push(`steps.${index}.repeatCount`);
      if (recipe.steps.length > 1 && !text(step.name, 120)) errors.push(`steps.${index}.name`);
    });
    return errors;
  }

  function validateRecipe(recipe) {
    return validateRecipeInput(recipe);
  }

  function validateVerifiableRecipe(recipe) {
    const errors = validateRecipeInput(recipe);
    ["transferMedium", "machineNickname", "temperature", "pressTimeSeconds", "pressure", "peelMethod"].forEach(function (key) {
      if (recipe[key] === "" || recipe[key] === null || recipe[key] === undefined) errors.push(key);
    });
    const steps = Array.isArray(recipe.steps) ? recipe.steps : [];
    if (!steps.length) errors.push("steps");
    steps.forEach(function (step, index) {
      ["name", "machineNickname", "platenZone", "temperature", "pressTimeSeconds", "pressure", "placementAction", "finishAction"].forEach(function (key) {
        if (step[key] === "" || step[key] === null || step[key] === undefined) errors.push(`steps.${index}.${key}`);
      });
    });
    return Array.from(new Set(errors));
  }

  function validateRunnableRecipe(recipe, boundary, utcOffsetMinutes, schemaOnly) {
    const normalized = normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    const errors = validateRecipeInput(normalized);
    if (normalized.status === "draft") errors.push("status");
    if (normalized.archived) errors.push("archived");
    if (normalized.needsReview) errors.push("needsReview");
    if (!PROCESS_STRUCTURES.has(normalized.processStructure) || normalized.processStructure === "blank") errors.push("processStructure");
    if (!normalized.title) errors.push("title");
    if (!normalized.blankMaterial) errors.push("blankMaterial");
    if (!normalized.transferMedium) errors.push("transferMedium");
    if (!normalized.machineProfileId) errors.push("machineProfileId");
    if (!normalized.machineProfile.nickname) errors.push("machineProfile.nickname");
    if (!(schemaOnly === true ? instructionSourceChecked(normalized.instructionSource) :
      instructionSourceCheckedAt(normalized.instructionSource, boundary, utcOffsetMinutes))) errors.push("instructionSource");
    const pressStages = normalized.steps.filter(function (step) { return step.stageType === "press"; });
    if (!pressStages.length) errors.push("pressStage");
    normalized.steps.forEach(function (step, index) {
      if (!STAGE_TYPES.has(step.stageType)) errors.push(`steps.${index}.stageType`);
      if (!step.name) errors.push(`steps.${index}.name`);
      if (step.stageType === "press") {
        if (step.temperature === "") errors.push(`steps.${index}.temperature`);
        if (step.durationSeconds === "") errors.push(`steps.${index}.durationSeconds`);
        if (!step.pressure) errors.push(`steps.${index}.pressure`);
        if (!step.machineProfileId && !step.machineNickname) errors.push(`steps.${index}.machineProfileId`);
      }
      if (step.durationSeconds !== "" && invalidNumber(step.durationSeconds, 1, 9999, true)) errors.push(`steps.${index}.durationSeconds`);
    });
    return Array.from(new Set(errors));
  }

  function validateBatchInput(batch) {
    const errors = [];
    if (batch.quantityPlanned === "" || batch.quantityPlanned === null || batch.quantityPlanned === undefined || invalidNumber(batch.quantityPlanned, 1, 999999, true)) errors.push("quantityPlanned");
    if (batch.quantityProcessed === "" || batch.quantityProcessed === null || batch.quantityProcessed === undefined || invalidNumber(batch.quantityProcessed, 0, 999999, true)) errors.push("quantityProcessed");
    if (batch.quantityGood === "" || batch.quantityGood === null || batch.quantityGood === undefined || invalidNumber(batch.quantityGood, 0, 999999, true)) errors.push("quantityGood");
    if (batch.quantityWaste === "" || batch.quantityWaste === null || batch.quantityWaste === undefined || invalidNumber(batch.quantityWaste, 0, 999999, true)) errors.push("quantityWaste");
    if (batch.quantityReworked === "" || batch.quantityReworked === null || batch.quantityReworked === undefined || invalidNumber(batch.quantityReworked, 0, 999999, true)) errors.push("quantityReworked");
    const issues = Array.isArray(batch.issues) ? batch.issues : [];
    issues.forEach(function (issue, index) {
      if (issue.quantity === "" || issue.quantity === null || issue.quantity === undefined || invalidNumber(issue.quantity, 1, 999999, true)) errors.push(`issues.${index}.quantity`);
    });
    return errors;
  }

  function validateBatch(batch) {
    if (batch.reviewStatus === "legacy_needs_review") return ["legacyNeedsReview"];
    const errors = validateBatchInput(batch);
    if (!OUTCOMES.has(batch.outcome)) errors.push("outcome");
    const planned = Number(batch.quantityPlanned || 0);
    const processed = Number(batch.quantityProcessed || 0);
    const waste = Number(batch.quantityWaste || 0);
    const reworked = Number(batch.quantityReworked || 0);
    const good = Number(batch.quantityGood || 0);
    const issues = Array.isArray(batch.issues) ? batch.issues : [];
    if (good + waste !== processed || processed > planned) errors.push("quantityReconcile");
    if (reworked > good) errors.push("quantityReworked");
    if (batch.outcome !== deriveOutcome(planned, processed, waste, reworked)) errors.push("outcomeConsistency");
    if ((waste > 0 || reworked > 0) && !issues.length) errors.push("issuesRequired");
    const discardedIssues = issues.filter(function (issue) { return issue.disposition === "discarded"; });
    const reworkedIssues = issues.filter(function (issue) { return issue.disposition === "reworked"; });
    const discardedTotal = discardedIssues.reduce(function (sum, issue) { return sum + Number(issue.quantity || 0); }, 0);
    const reworkedTotal = reworkedIssues.reduce(function (sum, issue) { return sum + Number(issue.quantity || 0); }, 0);
    if (discardedTotal !== waste || reworkedTotal !== reworked) errors.push("issueCoverage");
    issues.forEach(function (issue, index) {
      if (!ISSUE_SYMPTOMS.has(issue.symptom)) errors.push(`issues.${index}.symptom`);
      if (!ISSUE_CAUSES.has(issue.suspectedCause)) errors.push(`issues.${index}.suspectedCause`);
      if (!ISSUE_DISPOSITIONS.has(issue.disposition)) errors.push(`issues.${index}.disposition`);
      if ((issue.symptom === "other" || issue.suspectedCause === "other") && !text(issue.note, 1000)) errors.push(`issues.${index}.note`);
    });
    const completedTime = new Date(batch.completedAt).getTime();
    const startedTime = batch.startedAt ? new Date(batch.startedAt).getTime() : NaN;
    if (!Number.isFinite(completedTime)) errors.push("completedAt");
    if (batch.startedAt && (!Number.isFinite(startedTime) || startedTime > completedTime)) errors.push("completedAt");
    if ([3, 4].includes(batch.recordSchemaVersion)) {
      if (batch.startedAt) {
        const expectedDuration = Math.max(0, Math.round((completedTime - startedTime) / 1000));
        if (typeof batch.durationSeconds !== "number" || batch.durationSeconds !== expectedDuration) errors.push("durationSeconds");
      } else if (batch.durationSeconds !== "") errors.push("durationSeconds");
      if (!isCivilDate(batch.workDate) || !Number.isInteger(batch.utcOffsetMinutes) || workDateFor(batch.completedAt, batch.utcOffsetMinutes) !== batch.workDate || (batch.timeZone && timeZoneOffsetAt(batch.completedAt, batch.timeZone) !== batch.utcOffsetMinutes)) errors.push("completedAt");
      if (Boolean(batch.manufacturerVerifiedAt) !== Boolean(batch.manufacturerVerificationFingerprint)) errors.push("verificationFields");
      if (batch.manufacturerVerifiedAt) {
        const verifiedTime = new Date(batch.manufacturerVerifiedAt).getTime();
        if (!Number.isFinite(verifiedTime) || verifiedTime > completedTime || (batch.startedAt && verifiedTime < startedTime) || batch.manufacturerVerificationFingerprint !== operationalFingerprint(batch.recipe)) errors.push("verificationFields");
      }
    }
    if (batch.processSchemaVersion === 4) {
      if (!RUN_MODES.has(batch.runMode)) errors.push("runMode");
      if (!batch.firstPiece || !FIRST_PIECE_OUTCOMES.has(batch.firstPiece.outcome)) errors.push("firstPiece");
      if (!batch.firstPiece || invalidNumber(batch.firstPiece.attempts, 0, 99, true)) errors.push("firstPiece");
      if (batch.firstPiece && batch.firstPiece.attemptedAt && Number.isNaN(new Date(batch.firstPiece.attemptedAt).getTime())) errors.push("firstPiece");
      if (batch.firstPiece && batch.firstPiece.completedAt && Number.isNaN(new Date(batch.firstPiece.completedAt).getTime())) errors.push("firstPiece");
      if (batch.firstPiece) {
        const attemptedMs = batch.firstPiece.attemptedAt ? new Date(batch.firstPiece.attemptedAt).getTime() : NaN;
        const firstCompletedMs = batch.firstPiece.completedAt ? new Date(batch.firstPiece.completedAt).getTime() : NaN;
        if (batch.firstPiece.outcome === "pending") errors.push("firstPiece");
        else if (batch.firstPiece.outcome === "not_required") {
          if (batch.firstPiece.attempts !== 0 || batch.firstPiece.attemptedAt || batch.firstPiece.completedAt) errors.push("firstPiece");
        } else if (batch.firstPiece.attempts < 1 || !Number.isFinite(attemptedMs) || !Number.isFinite(firstCompletedMs) ||
            (batch.startedAt && attemptedMs < startedTime) || firstCompletedMs < attemptedMs || firstCompletedMs > completedTime) errors.push("firstPiece");
        if (["stop", "adjust_retry"].includes(batch.firstPiece.outcome) && batch.outcome === "success") errors.push("firstPiece");
        if (batch.firstPiece.attempts > 1 && batch.quantityWaste === 0 && batch.quantityReworked === 0 && !issues.length) errors.push("firstPiece");
      }
      if (!Array.isArray(batch.qcChecks) || batch.qcChecks.length > 100) errors.push("qcChecks");
      if (!Array.isArray(batch.interruptions) || batch.interruptions.length > 100) errors.push("interruptions");
      let priorQcTime = -Infinity; let priorQcCount = -1;
      (batch.qcChecks || []).forEach(function (check) {
        const checkedMs = new Date(check && check.checkedAt).getTime();
        if (!check || !["pass", "adjust", "end_early"].includes(check.result) || invalidNumber(check.processedCount, 0, processed, true) ||
            !Number.isFinite(checkedMs) || (batch.startedAt && checkedMs < startedTime) || checkedMs > completedTime ||
            checkedMs < priorQcTime || check.processedCount < priorQcCount) errors.push("qcChecks");
        priorQcTime = checkedMs; priorQcCount = check && check.processedCount;
      });
      let priorInterruptionEnd = -Infinity;
      (batch.interruptions || []).forEach(function (entry) {
        const startMs = new Date(entry && entry.startedAt).getTime(); const endMs = entry && entry.endedAt ? new Date(entry.endedAt).getTime() : startMs;
        if (!entry || !Number.isFinite(startMs) || !Number.isFinite(endMs) || (batch.startedAt && startMs < startedTime) ||
            startMs > completedTime || endMs < startMs || endMs > completedTime || startMs < priorInterruptionEnd ||
            (batch.authorizationBasis !== "legacy_migration" && !entry.endedAt) || entry.productionBegan !== true) errors.push("interruptions");
        priorInterruptionEnd = endMs;
      });
      if (batch.operationalFingerprintV4 !== operationalFingerprintV4(batch.recipe) ||
          batch.provenanceFingerprint !== provenanceFingerprint(batch.recipe) ||
          batch.exactSetupFingerprint !== exactSetupFingerprint(batch.recipe)) errors.push("setupFingerprint");
      if (!batch.initialPressedSetup || typeof batch.initialPressedSetup !== "object" ||
          batch.setupChangedDuringRun !== (exactSetupFingerprint(batch.initialPressedSetup) !== exactSetupFingerprint(batch.recipe))) errors.push("initialPressedSetup");
      if (Boolean(batch.instructionCheckedAt) !== Boolean(batch.instructionCheckFingerprint)) errors.push("instructionCheck");
      if (batch.instructionCheckedAt) {
        const checkedMs = new Date(batch.instructionCheckedAt).getTime();
        if (!Number.isFinite(checkedMs) || (batch.startedAt && checkedMs < startedTime) || checkedMs > completedTime ||
            batch.instructionCheckFingerprint !== batch.exactSetupFingerprint) errors.push("instructionCheck");
        if (batch.authorizationBasis !== "legacy_migration" &&
            !instructionSourceCheckedAt(batch.recipe.instructionSource, batch.instructionCheckedAt, batch.utcOffsetMinutes)) errors.push("instructionCheck");
      }
      if (batch.productionStartedAt) {
        const productionMs = new Date(batch.productionStartedAt).getTime();
        if (!Number.isFinite(productionMs) || (batch.startedAt && productionMs < startedTime) || productionMs > completedTime) errors.push("productionStartedAt");
        const checkedMs = batch.instructionCheckedAt ? new Date(batch.instructionCheckedAt).getTime() : NaN;
        const retryCompletionMs = batch.firstPiece && batch.firstPiece.completedAt ? new Date(batch.firstPiece.completedAt).getTime() : NaN;
        if (batch.authorizationBasis !== "legacy_migration" && Number.isFinite(checkedMs) && checkedMs > productionMs &&
            !(batch.firstPiece && batch.firstPiece.attempts > 1 && Number.isFinite(retryCompletionMs) && checkedMs <= retryCompletionMs)) errors.push("instructionCheck");
        if (batch.firstPiece) {
          const attemptedMs = batch.firstPiece.attemptedAt ? new Date(batch.firstPiece.attemptedAt).getTime() : NaN;
          if (Number.isFinite(attemptedMs) && ((batch.firstPiece.attempts <= 1 && attemptedMs < checkedMs) || attemptedMs < productionMs)) errors.push("firstPiece");
        }
        (batch.qcChecks || []).forEach(function (check) {
          if (new Date(check.checkedAt).getTime() < productionMs) errors.push("qcChecks");
        });
        (batch.interruptions || []).forEach(function (entry) {
          if (new Date(entry.startedAt).getTime() < productionMs) errors.push("interruptions");
        });
      }
    }
    return Array.from(new Set(errors));
  }

  function normalizeSearch(value) {
    return String(value === null || value === undefined ? "" : value).normalize("NFKD").replace(/[\u0300-\u036f]/g, "").replace(/[Iı]/g, "i").toLowerCase();
  }

  const recipeSearchCache = new WeakMap();
  const batchSearchCache = new WeakMap();

  function recipeSearchText(recipe) {
    if (recipeSearchCache.has(recipe)) return recipeSearchCache.get(recipe);
    const stepFields = (Array.isArray(recipe.steps) ? recipe.steps : []).reduce(function (result, step) {
      return result.concat([step.stageType, step.name, step.instruction, step.machineProfileId, step.machineNickname, step.platenZone,
        step.temperature, step.temperatureUnit, step.durationSeconds, step.pressTimeSeconds, step.repeatCount, step.pressure,
        step.placementAction, step.finishAction]);
    }, []);
    const machine = recipe.machineProfile || {}; const instruction = recipe.instructionSource || {};
    const haystack = [
      recipe.id, recipe.status, publicSetupStatus(recipe), recipe.needsReview ? "needs review migrated" : "", recipe.archived ? "archived" : "active",
      recipe.title, recipe.jobReference, recipe.customerJob, recipe.processStructure, recipe.blankMaterial, recipe.transferMedium,
      recipe.machineProfileId, machine.nickname, machine.brand, machine.model, machine.pressureMethod, machine.pressureScale,
      machine.platenOrZone, instruction.type, instruction.name, instruction.reference, instruction.checkedDate,
      instruction.revision, instruction.priorBatchId, recipe.machineNickname, recipe.platenZone,
      recipe.temperature, recipe.temperatureUnit, recipe.pressTimeSeconds, recipe.prePressSeconds, recipe.peelMethod, recipe.pressCount, recipe.defaultQuantity,
      recipe.notes, recipe.blankSupplier, recipe.blankSku, recipe.blankLot, recipe.blankColourSize, recipe.transferSupplier,
      recipe.transferSku, recipe.transferLot, recipe.designRevision, recipe.printerInkPaperProfile, recipe.accessoriesPlacementCooling,
      ...stepFields
    ].join(" ");
    const normalized = normalizeSearch(haystack); recipeSearchCache.set(recipe, normalized); return normalized;
  }

  function recipeMatches(recipe, query, normalizedQuery) {
    if (!query) return true;
    return recipeSearchText(recipe).includes(normalizedQuery === undefined ? normalizeSearch(query) : normalizedQuery);
  }

  function batchSearchText(batch) {
    if (batchSearchCache.has(batch)) return batchSearchCache.get(batch);
    const recipe = batch.recipe || {};
    const issueFields = (Array.isArray(batch.issues) ? batch.issues : []).reduce(function (result, issue) {
      return result.concat([issue.symptom, issue.suspectedCause, issue.disposition, issue.note]);
    }, []);
    const stepFields = (Array.isArray(recipe.steps) ? recipe.steps : []).reduce(function (result, step) {
      return result.concat([step.stageType, step.name, step.instruction, step.machineProfileId, step.machineNickname, step.platenZone,
        step.temperature, step.temperatureUnit, step.durationSeconds, step.pressTimeSeconds, step.repeatCount, step.pressure,
        step.placementAction, step.finishAction]);
    }, []);
    const correctionFields = (Array.isArray(batch.corrections) ? batch.corrections : []).reduce(function (result, correction) {
      const previous = correction.previous || {}; const previousRecipe = previous.recipe || {};
      const previousSteps = (Array.isArray(previousRecipe.steps) ? previousRecipe.steps : []).reduce(function (fields, step) { return fields.concat([step.name, step.machineNickname, step.platenZone, step.temperature, step.temperatureUnit, step.pressTimeSeconds, step.repeatCount, step.pressure, step.placementAction, step.finishAction]); }, []);
      const previousIssues = (Array.isArray(previous.issues) ? previous.issues : []).reduce(function (fields, issue) { return fields.concat([issue.symptom, issue.suspectedCause, issue.disposition, issue.note]); }, []);
      return result.concat([correction.note, previous.jobName, previous.notes, previous.outcome, previous.quantityPlanned, previous.quantityProcessed, previous.quantityGood, previous.quantityWaste, previous.quantityReworked, previous.startedAt, previous.completedAt, previous.durationSeconds, previous.workDate, previous.utcOffsetMinutes, previous.timeZone, previousRecipe.title, previousRecipe.customerJob, previousRecipe.blankMaterial, previousRecipe.transferMedium, previousRecipe.temperature, previousRecipe.temperatureUnit, previousRecipe.pressTimeSeconds, previousRecipe.prePressSeconds, previousRecipe.peelMethod, previousRecipe.pressCount, previousRecipe.defaultQuantity, previousRecipe.blankSupplier, previousRecipe.blankSku, previousRecipe.blankLot, previousRecipe.transferSupplier, previousRecipe.transferSku, previousRecipe.transferLot, previousRecipe.designRevision, previousRecipe.printerInkPaperProfile, previousRecipe.accessoriesPlacementCooling, ...previousSteps, ...previousIssues]);
    }, []);
    const haystack = [
      batch.id, batch.recipeId, batch.recipeRevisionId, batch.sourceBatchId, batch.outcome, batch.reviewStatus,
      batch.quantityPlanned, batch.quantityProcessed, batch.quantityGood, batch.quantityWaste, batch.quantityReworked, batch.startedAt, batch.completedAt, batch.durationSeconds, batch.workDate, batch.utcOffsetMinutes, batch.timeZone,
      recipe.title, recipe.jobReference, recipe.customerJob, recipe.processStructure, recipe.blankMaterial, recipe.transferMedium,
      recipe.machineProfileId, recipe.machineProfile && recipe.machineProfile.nickname, recipe.machineProfile && recipe.machineProfile.brand,
      recipe.machineProfile && recipe.machineProfile.model, recipe.instructionSource && recipe.instructionSource.type,
      recipe.instructionSource && recipe.instructionSource.name, recipe.instructionSource && recipe.instructionSource.reference,
      recipe.instructionSource && recipe.instructionSource.checkedDate, recipe.machineNickname, recipe.platenZone,
      recipe.temperature, recipe.temperatureUnit, recipe.pressTimeSeconds, recipe.prePressSeconds, recipe.peelMethod, recipe.pressCount, recipe.defaultQuantity,
      recipe.notes, recipe.blankSupplier, recipe.blankSku, recipe.blankLot, recipe.blankColourSize, recipe.transferSupplier,
      recipe.transferSku, recipe.transferLot, recipe.designRevision, recipe.printerInkPaperProfile, recipe.accessoriesPlacementCooling,
      batch.jobName, batch.failureReason, batch.notes, ...stepFields, ...issueFields, ...correctionFields
    ].join(" ");
    const normalized = normalizeSearch(haystack); batchSearchCache.set(batch, normalized); return normalized;
  }

  function batchMatches(batch, query, normalizedQuery) {
    if (!query) return true;
    return batchSearchText(batch).includes(normalizedQuery === undefined ? normalizeSearch(query) : normalizedQuery);
  }

  function sortRecipes(recipes) {
    return recipes.slice().sort(function (left, right) {
      const leftDate = left.lastUsedAt || left.updatedAt || left.createdAt;
      const rightDate = right.lastUsedAt || right.updatedAt || right.createdAt;
      return new Date(rightDate).getTime() - new Date(leftDate).getTime();
    });
  }

  function sortBatches(batches) {
    return batches.slice().sort(function (left, right) {
      return new Date(right.completedAt).getTime() - new Date(left.completedAt).getTime();
    });
  }

  function metrics(recipes, batches, referenceDate) {
    const date = referenceDate ? new Date(referenceDate) : new Date();
    const month = date.getMonth();
    const year = date.getFullYear();
    const completeBatches = batches.filter(function (batch) { return batch.reviewStatus !== "legacy_needs_review"; });
    const totals = completeBatches.reduce(function (result, batch) {
      result.planned += Number(batch.quantityPlanned || 0);
      result.processed += Number(batch.quantityProcessed || 0);
      result.good += Number(batch.quantityGood || 0);
      result.waste += Number(batch.quantityWaste || 0);
      result.reworked += Number(batch.quantityReworked || 0);
      return result;
    }, { planned: 0, processed: 0, good: 0, waste: 0, reworked: 0 });
    const wasteThisMonth = completeBatches.reduce(function (total, batch) {
      const completed = new Date(batch.completedAt);
      const fallbackDate = Number.isNaN(completed.getTime()) ? "" : [completed.getFullYear(), String(completed.getMonth() + 1).padStart(2, "0"), String(completed.getDate()).padStart(2, "0")].join("-");
      const workDate = /^\d{4}-\d{2}-\d{2}$/.test(batch.workDate || "") ? batch.workDate : fallbackDate;
      if (workDate.slice(0, 7) === `${year}-${String(month + 1).padStart(2, "0")}`) return total + Number(batch.quantityWaste || 0);
      return total;
    }, 0);
    const firstPassGood = Math.max(0, totals.good - totals.reworked);
    return {
      recipes: recipes.length,
      setups: recipes.length,
      batches: batches.length,
      sampleSize: completeBatches.length,
      lowData: completeBatches.length < 5,
      firstPassYield: totals.processed ? firstPassGood / totals.processed : null,
      finalYield: totals.processed ? totals.good / totals.processed : null,
      yieldRate: totals.processed ? Math.round((totals.good / totals.processed) * 100) : null,
      reworkRate: totals.processed ? Math.round((totals.reworked / totals.processed) * 100) : null,
      wasteRate: totals.processed ? Math.round((totals.waste / totals.processed) * 100) : null,
      wasteThisMonth: wasteThisMonth,
      unitsPlanned: totals.planned,
      unitsProcessed: totals.processed,
      unitsGood: totals.good,
      reviewPending: batches.length - completeBatches.length
    };
  }

  function assertUniqueBackupIds(records, errorCode) {
    const seen = new Set();
    records.forEach(function (record) {
      const id = text(record && record.id, 100);
      if (!id || seen.has(id)) throw new Error(errorCode);
      seen.add(id);
    });
  }

  function assertUniqueNestedIds(records, key, errorCode) {
    records.forEach(function (record) {
      const items = Array.isArray(record && record[key]) ? record[key] : [];
      if (!items.length) return;
      const seen = new Set();
      items.forEach(function (item) {
        const id = text(item && item.id, 100);
        if (!id || seen.has(id)) throw new Error(errorCode);
        seen.add(id);
      });
    });
  }

  function makeBackup(setups, batches, settings, machines) {
    const backup = {
      schema: "press-bench-log",
      schemaVersion: 4,
      appId: "APP-018",
      exportedAt: nowIso(),
      encrypted: false,
      machines: (machines || []).map(function (machine) { return normalizeMachineProfile(machine, true); }),
      setups: (setups || []).map(function (setup) { return normalizeRecipe(setup, setup.temperatureUnit, true); }),
      batches: batches.map(function (batch) { return normalizeBatch(batch, true); }),
      settings: portableSettings(settings)
    };
    // A backup produced by this version must always be restorable by this
    // version; this catches graph or derived-evidence corruption at export.
    parseBackup(JSON.stringify(backup));
    return backup;
  }

  function utf8ByteLength(value) {
    let bytes = 0;
    for (let index = 0; index < value.length; index += 1) {
      const code = value.charCodeAt(index);
      if (code < 0x80) bytes += 1;
      else if (code < 0x800) bytes += 2;
      else if (code >= 0xD800 && code <= 0xDBFF && index + 1 < value.length && value.charCodeAt(index + 1) >= 0xDC00 && value.charCodeAt(index + 1) <= 0xDFFF) { bytes += 4; index += 1; }
      else bytes += 3;
    }
    return bytes;
  }

  function exactTextField(source, key, maxLength) {
    return typeof source[key] === "string" && text(source[key], maxLength) === source[key];
  }

  function exactIsoDate(value, optional) {
    if (optional && value === "") return true;
    if (typeof value !== "string") return false;
    const parsed = new Date(value);
    return !Number.isNaN(parsed.getTime()) && parsed.toISOString() === value;
  }

  function exactObjectKeys(source, required, optional) {
    if (!source || typeof source !== "object" || Array.isArray(source)) return false;
    const allowed = new Set((required || []).concat(optional || []));
    const keys = Object.keys(source);
    return (required || []).every(function (key) { return Object.prototype.hasOwnProperty.call(source, key); }) &&
      keys.every(function (key) { return allowed.has(key); });
  }

  function validatePortableSettingsRaw(source) {
    const keys = ["settingsSchemaVersion", "language", "locale", "region", "defaultUnit", "dimensionUnit", "paperSize",
      "hapticsEnabled", "soundEnabled", "theme"];
    const acceptedLanguage = acceptedLanguageCode(source && source.language);
    const canonicalLanguage = acceptedLanguage ? canonicalLanguageId(acceptedLanguage) : "";
    if (!exactObjectKeys(source, keys) || source.settingsSchemaVersion !== 2 || !canonicalLanguage ||
        !SUPPORTED_LOCALES.has(source.locale) || LOCALE_PROFILES[source.locale].language !== canonicalLanguage ||
        !/^[A-Z]{2}$/.test(source.region) || !UNITS.has(source.defaultUnit) ||
        !DIMENSION_UNITS.has(source.dimensionUnit) || !PAPER_SIZES.has(source.paperSize) || !THEMES.has(source.theme)) return false;
    return typeof source.hapticsEnabled === "boolean" && typeof source.soundEnabled === "boolean";
  }

  function validateV2RecipeRaw(source, snapshot, allowLegacyIncomplete) {
    if (!source || typeof source !== "object" || Array.isArray(source)) return false;
    const textFields = {
      id: 100, title: 140, customerJob: 180, blankMaterial: 180, transferMedium: 180, machineNickname: 120,
      platenZone: 120, pressure: 120, peelMethod: 120, notes: 5000, verifiedAt: 100, verifiedBatchId: 100,
      blankSupplier: 180, blankSku: 180, blankLot: 180, blankColourSize: 180, transferSupplier: 180,
      transferSku: 180, transferLot: 180, designRevision: 180, printerInkPaperProfile: 500,
      accessoriesPlacementCooling: 1000
    };
    if (!Object.keys(textFields).every(function (key) { return exactTextField(source, key, textFields[key]); })) return false;
    if (!source.id || (!allowLegacyIncomplete && (!source.title || !source.blankMaterial)) || !RECIPE_STATUSES.has(source.status) || !UNITS.has(source.temperatureUnit)) return false;
    if (source.temperature !== "" && (typeof source.temperature !== "number" || invalidNumber(source.temperature, 0, 999, false))) return false;
    if (source.pressTimeSeconds !== "" && (typeof source.pressTimeSeconds !== "number" || invalidNumber(source.pressTimeSeconds, 1, 9999, true))) return false;
    if (source.prePressSeconds !== "" && (typeof source.prePressSeconds !== "number" || invalidNumber(source.prePressSeconds, 0, 9999, true))) return false;
    if (typeof source.pressCount !== "number" || typeof source.defaultQuantity !== "number" || invalidNumber(source.pressCount, 1, 99, true) || invalidNumber(source.defaultQuantity, 1, 999999, true)) return false;
    if (!Array.isArray(source.steps) || source.steps.length < 1 || source.steps.length > MAX_STAGES) return false;
    const stepIds = new Set();
    for (const step of source.steps) {
      if (!step || typeof step !== "object" || Array.isArray(step) || !exactTextField(step, "id", 100) || !step.id || stepIds.has(step.id)) return false;
      stepIds.add(step.id);
      const fields = { name: 120, machineNickname: 120, platenZone: 120, pressure: 120, placementAction: 500, finishAction: 500 };
      if (!Object.keys(fields).every(function (key) { return exactTextField(step, key, fields[key]); }) || !UNITS.has(step.temperatureUnit)) return false;
      if (step.temperature !== "" && (typeof step.temperature !== "number" || invalidNumber(step.temperature, 0, 999, false))) return false;
      if (step.pressTimeSeconds !== "" && (typeof step.pressTimeSeconds !== "number" || invalidNumber(step.pressTimeSeconds, 1, 9999, true))) return false;
      if (typeof step.repeatCount !== "number" || invalidNumber(step.repeatCount, 1, 99, true)) return false;
    }
    const firstStep = source.steps[0];
    if (source.machineNickname !== firstStep.machineNickname || source.platenZone !== firstStep.platenZone ||
        source.temperature !== firstStep.temperature || source.temperatureUnit !== firstStep.temperatureUnit ||
        source.pressTimeSeconds !== firstStep.pressTimeSeconds || source.pressure !== firstStep.pressure ||
        source.pressCount !== firstStep.repeatCount || source.peelMethod !== firstStep.finishAction) return false;
    if (!snapshot && (!exactIsoDate(source.createdAt, false) || !exactIsoDate(source.updatedAt, false) || !exactIsoDate(source.lastUsedAt, true))) return false;
    if (!snapshot && new Date(source.updatedAt).getTime() < new Date(source.createdAt).getTime()) return false;
    if (source.status === "verified" && (!source.verifiedBatchId || !exactIsoDate(source.verifiedAt, false))) return false;
    if (!snapshot && source.status === "verified" && (new Date(source.verifiedAt).getTime() < new Date(source.createdAt).getTime() || new Date(source.verifiedAt).getTime() > new Date(source.updatedAt).getTime())) return false;
    if (source.status !== "verified" && (source.verifiedAt || source.verifiedBatchId)) return false;
    return allowLegacyIncomplete || validateRecipeInput(source).length === 0;
  }

  function validateV3RecipeRaw(source, snapshot, allowLegacyIncomplete) {
    const needsReview = source && source.needsReview === true;
    if (source && source.needsReview !== undefined && typeof source.needsReview !== "boolean") return false;
    if (needsReview && (!source.migrationOriginal || typeof source.migrationOriginal !== "object" || Array.isArray(source.migrationOriginal) || !isBoundedJsonValue(source.migrationOriginal) || source.status !== "draft" || source.verifiedAt || source.verifiedBatchId)) return false;
    if (!needsReview && source && source.migrationOriginal !== undefined && source.migrationOriginal !== null) return false;
    return validateV2RecipeRaw(source, snapshot, allowLegacyIncomplete || needsReview) && typeof source.archived === "boolean" && source.status !== "archived";
  }

  function validateV2BatchRaw(source) {
    if (!source || typeof source !== "object" || Array.isArray(source)) return false;
    if (!exactTextField(source, "id", 100) || !source.id || !exactTextField(source, "recipeId", 100) || !exactTextField(source, "jobName", 180) || !exactTextField(source, "failureReason", 1000) || !exactTextField(source, "notes", 5000)) return false;
    if (!OUTCOMES.has(source.outcome) || !REVIEW_STATUSES.has(source.reviewStatus) || !exactIsoDate(source.completedAt, false)) return false;
    const legacyIncomplete = source.reviewStatus === "legacy_needs_review";
    const validationSource = Object.prototype.hasOwnProperty.call(source, "quantityProcessed") ? source : Object.assign({}, source, { quantityProcessed: Number(source.quantityGood || 0) + Number(source.quantityWaste || 0) });
    if (!legacyIncomplete && ["quantityPlanned", "quantityGood", "quantityWaste", "quantityReworked"].some(function (key) { return typeof source[key] !== "number"; })) return false;
    if ((!legacyIncomplete && validateBatchInput(validationSource).length) || !validateV2RecipeRaw(source.recipe, true, legacyIncomplete)) return false;
    if (!legacyIncomplete && (!source.recipeId || source.recipeId !== source.recipe.id)) return false;
    if (!Array.isArray(source.issues) || source.issues.length > MAX_ISSUES || !Array.isArray(source.corrections) || source.corrections.length > MAX_CORRECTIONS) return false;
    const issueIds = new Set();
    for (const issue of source.issues) {
      if (!issue || typeof issue !== "object" || Array.isArray(issue) || !exactTextField(issue, "id", 100) || !issue.id || issueIds.has(issue.id)) return false;
      issueIds.add(issue.id);
      if (typeof issue.quantity !== "number" || invalidNumber(issue.quantity, 1, 999999, true) || !ISSUE_SYMPTOMS.has(issue.symptom) || !ISSUE_CAUSES.has(issue.suspectedCause) || !ISSUE_DISPOSITIONS.has(issue.disposition) || !exactTextField(issue, "note", 1000)) return false;
    }
    let lastCorrectionTime = -Infinity;
    for (const correction of source.corrections) {
      if (!correction || typeof correction !== "object" || Array.isArray(correction) || !exactIsoDate(correction.correctedAt, false) || !exactTextField(correction, "note", 500) || !text(correction.note, 500) || !correction.previous || typeof correction.previous !== "object" || Array.isArray(correction.previous)) return false;
      const previous = correction.previous; const previousLegacy = previous.reviewStatus === "legacy_needs_review";
      const previousVersion = previous.recordSchemaVersion === undefined ? 2 : previous.recordSchemaVersion;
      const v3OnlyFields = ["recipeRevisionId", "sourceBatchId", "startedAt", "workDate", "utcOffsetMinutes", "timeZone", "durationSeconds", "manufacturerVerifiedAt", "manufacturerVerificationFingerprint", "completionStatus"];
      if ([3, 4].includes(previousVersion)) {
        if (!validateV3CorrectionSnapshotRaw(previous)) return false;
      } else if (previousVersion !== 2 || v3OnlyFields.some(function (key) { return Object.prototype.hasOwnProperty.call(previous, key); })) return false;
      const correctionTime = new Date(correction.correctedAt).getTime();
      if (correctionTime < new Date(previous.completedAt).getTime() || correctionTime < lastCorrectionTime || previous.id !== source.id || previous.recipeId !== source.recipeId) return false;
      lastCorrectionTime = correctionTime;
      if (!validateV2RecipeRaw(previous.recipe, true, previousLegacy) || !exactTextField(previous, "jobName", 180) || !OUTCOMES.has(previous.outcome) || !REVIEW_STATUSES.has(previous.reviewStatus) || !exactTextField(previous, "notes", 5000) || !exactIsoDate(previous.completedAt, false)) return false;
      if (!previousLegacy && (previous.recipe.id !== source.recipeId || previous.recipe.id !== previous.recipeId)) return false;
      if (["quantityPlanned", "quantityGood", "quantityWaste", "quantityReworked"].some(function (key) { return typeof previous[key] !== "number" || invalidNumber(previous[key], key === "quantityPlanned" ? 1 : 0, 999999, true); })) return false;
      if (!Array.isArray(previous.issues) || previous.issues.length > MAX_ISSUES) return false;
      const previousIssueIds = new Set();
      for (const issue of previous.issues) {
        if (!issue || typeof issue !== "object" || Array.isArray(issue) || !exactTextField(issue, "id", 100) || !issue.id || previousIssueIds.has(issue.id) || typeof issue.quantity !== "number" || invalidNumber(issue.quantity, 1, 999999, true) || !ISSUE_SYMPTOMS.has(issue.symptom) || !ISSUE_CAUSES.has(issue.suspectedCause) || !ISSUE_DISPOSITIONS.has(issue.disposition) || !exactTextField(issue, "note", 1000)) return false;
        previousIssueIds.add(issue.id);
      }
      if (previousLegacy ? (!previous.legacyOriginal || typeof previous.legacyOriginal !== "object" || Array.isArray(previous.legacyOriginal) || !isBoundedJsonValue(previous.legacyOriginal)) : previous.legacyOriginal !== null) return false;
      const previousValidation = Object.prototype.hasOwnProperty.call(previous, "quantityProcessed") ? previous : Object.assign({}, previous, { quantityProcessed: Number(previous.quantityGood || 0) + Number(previous.quantityWaste || 0) });
      if (!previousLegacy && validateBatch(previousValidation).length) return false;
    }
    if (source.corrections.length && lastCorrectionTime < new Date(source.completedAt).getTime()) return false;
    if (source.reviewStatus === "legacy_needs_review") return source.legacyOriginal && typeof source.legacyOriginal === "object" && !Array.isArray(source.legacyOriginal) && isBoundedJsonValue(source.legacyOriginal);
    return source.legacyOriginal === null && validateBatch(normalizeBatch(source, true)).length === 0;
  }

  function validateV3BatchRaw(source) {
    if (!validateV2BatchRaw(source) || source.recordSchemaVersion !== 3 || !validateV3RecipeRaw(source.recipe, true, source.reviewStatus === "legacy_needs_review")) return false;
    if (["recipeRevisionId", "sourceBatchId", "manufacturerVerificationFingerprint"].some(function (key) { return typeof source[key] !== "string"; })) return false;
    if (!exactTextField(source, "recipeRevisionId", 140) || ![recipeRevisionId(source.recipeId, source.recipe), legacyRecipeRevisionId(source.recipeId, source.recipe)].includes(source.recipeRevisionId) || !exactTextField(source, "sourceBatchId", 100) || source.sourceBatchId === source.id) return false;
    if (typeof source.quantityProcessed !== "number" || invalidNumber(source.quantityProcessed, 0, 999999, true)) return false;
    if (source.reviewStatus !== "legacy_needs_review" && (source.quantityGood + source.quantityWaste !== source.quantityProcessed || source.quantityProcessed > source.quantityPlanned || source.outcome !== deriveOutcome(source.quantityPlanned, source.quantityProcessed, source.quantityWaste, source.quantityReworked))) return false;
    if (source.completionStatus !== (source.quantityProcessed < source.quantityPlanned ? "partial" : "complete")) return false;
    if (source.startedAt !== "" && !exactIsoDate(source.startedAt, false)) return false;
    if (source.manufacturerVerifiedAt !== "" && !exactIsoDate(source.manufacturerVerifiedAt, false)) return false;
    const expectedFingerprint = operationalFingerprint(source.recipe);
    const legacyFingerprint = operationalDefinition(source.recipe);
    if (Boolean(source.manufacturerVerifiedAt) !== Boolean(source.manufacturerVerificationFingerprint) ||
        (source.manufacturerVerificationFingerprint && source.manufacturerVerificationFingerprint !== expectedFingerprint && source.manufacturerVerificationFingerprint !== legacyFingerprint)) return false;
    if (source.durationSeconds !== "" && (typeof source.durationSeconds !== "number" || invalidNumber(source.durationSeconds, 0, 31536000, true))) return false;
    const completedMs = new Date(source.completedAt).getTime();
    const startedMs = source.startedAt ? new Date(source.startedAt).getTime() : null;
    if (startedMs !== null && (completedMs < startedMs || source.durationSeconds !== Math.max(0, Math.round((completedMs - startedMs) / 1000)))) return false;
    if (startedMs === null && source.durationSeconds !== "") return false;
    if (source.manufacturerVerifiedAt) {
      const verifiedMs = new Date(source.manufacturerVerifiedAt).getTime();
      if (verifiedMs > completedMs || (startedMs !== null && verifiedMs < startedMs)) return false;
    }
    if (!isCivilDate(source.workDate) || !Number.isInteger(source.utcOffsetMinutes) || source.utcOffsetMinutes < -840 || source.utcOffsetMinutes > 840 || workDateFor(source.completedAt, source.utcOffsetMinutes) !== source.workDate) return false;
    if (!exactTextField(source, "timeZone", 100) || (source.timeZone && timeZoneOffsetAt(source.completedAt, source.timeZone) !== source.utcOffsetMinutes)) return false;
    const expectedReason = text(source.issues.map(function (issue) { return issue.note || issue.symptom; }).filter(Boolean).join("; "), 1000);
    if (source.failureReason !== expectedReason) return false;
    return true;
  }

  function validateV4MachineRaw(source) {
    const required = ["recordSchemaVersion", "id", "nickname", "brand", "model", "pressureMethod", "pressureScale",
      "platenOrZone", "lastExternalCheckDate", "notes", "archived", "createdAt", "updatedAt"];
    if (!exactObjectKeys(source, required) || source.recordSchemaVersion !== 1) return false;
    const fields = { id: 100, nickname: 120, brand: 120, model: 120, pressureMethod: 120, pressureScale: 120,
      platenOrZone: 120, lastExternalCheckDate: 10, notes: 1000 };
    if (!Object.keys(fields).every(function (key) { return exactTextField(source, key, fields[key]); })) return false;
    if (!source.id || !source.nickname || typeof source.archived !== "boolean") return false;
    if (source.lastExternalCheckDate && !isCivilDate(source.lastExternalCheckDate)) return false;
    return exactIsoDate(source.createdAt, false) && exactIsoDate(source.updatedAt, false) &&
      new Date(source.updatedAt).getTime() >= new Date(source.createdAt).getTime();
  }

  function validateV4RecipeRaw(source, snapshot, allowIncomplete) {
    const snapshotKeys = ["setupSchemaVersion", "id", "title", "customerJob", "jobReference", "processStructure",
      "blankMaterial", "transferMedium", "machineProfileId", "machineProfile", "instructionSource", "machineNickname",
      "platenZone", "temperature", "temperatureUnit", "pressTimeSeconds", "pressure", "prePressSeconds", "peelMethod",
      "pressCount", "defaultQuantity", "notes", "status", "archived", "verifiedAt", "verifiedBatchId",
      "provenEvidenceCount", "persistedOperationalFingerprintV4", "proofResetAt", "blankSupplier", "blankSku", "blankLot",
      "blankColourSize", "transferSupplier", "transferSku", "transferLot", "designRevision", "printerInkPaperProfile",
      "accessoriesPlacementCooling", "steps"];
    const storedKeys = snapshotKeys.concat(["needsReview", "migrationOriginal", "createdAt", "updatedAt", "lastUsedAt"]);
    if (!exactObjectKeys(source, snapshot ? snapshotKeys : storedKeys)) return false;
    if (!validateV3RecipeRaw(source, snapshot, allowIncomplete) || source.setupSchemaVersion !== 4 ||
        !PROCESS_STRUCTURES.has(source.processStructure) || !exactTextField(source, "jobReference", 180) ||
        !exactTextField(source, "machineProfileId", 100) || !exactTextField(source, "persistedOperationalFingerprintV4", 80) ||
        !exactTextField(source, "proofResetAt", 100) || !exactIsoDate(source.proofResetAt, true) ||
        typeof source.provenEvidenceCount !== "number" || invalidNumber(source.provenEvidenceCount, 0, MAX_RECORDS, true)) return false;
    if (!snapshot && source.proofResetAt && (new Date(source.proofResetAt).getTime() < new Date(source.createdAt).getTime() ||
        new Date(source.proofResetAt).getTime() > new Date(source.updatedAt).getTime())) return false;
    const machine = source.machineProfile;
    if (!exactObjectKeys(machine, ["id", "nickname", "brand", "model", "pressureMethod", "pressureScale", "platenOrZone", "lastExternalCheckDate"])) return false;
    const machineFields = { id: 100, nickname: 120, brand: 120, model: 120, pressureMethod: 120, pressureScale: 120,
      platenOrZone: 120, lastExternalCheckDate: 10 };
    if (!Object.keys(machineFields).every(function (key) { return exactTextField(machine, key, machineFields[key]); }) ||
        (machine.lastExternalCheckDate && !isCivilDate(machine.lastExternalCheckDate)) || machine.id !== source.machineProfileId) return false;
    const instruction = source.instructionSource;
    if (!exactObjectKeys(instruction, ["type", "name", "reference", "checkedDate", "revision", "priorBatchId"]) ||
        !INSTRUCTION_SOURCE_TYPES.has(instruction.type)) return false;
    const sourceFields = { name: 180, reference: 1000, checkedDate: 10, revision: 180, priorBatchId: 100 };
    if (!Object.keys(sourceFields).every(function (key) { return exactTextField(instruction, key, sourceFields[key]); }) ||
        (instruction.checkedDate && !isCivilDate(instruction.checkedDate))) return false;
    if (source.persistedOperationalFingerprintV4 && source.persistedOperationalFingerprintV4 !== operationalFingerprintV4(source)) return false;
    if (source.status === "verified" && (source.provenEvidenceCount < 1 || source.persistedOperationalFingerprintV4 !== operationalFingerprintV4(source))) return false;
    const stagesValid = source.steps.every(function (step) {
      return exactObjectKeys(step, ["id", "stageType", "name", "instruction", "machineNickname", "machineProfileId",
        "platenZone", "temperature", "temperatureUnit", "durationSeconds", "pressTimeSeconds", "pressure", "repeatCount",
        "placementAction", "finishAction"]) && STAGE_TYPES.has(step.stageType) && exactTextField(step, "instruction", 500) &&
        exactTextField(step, "machineProfileId", 100) &&
        (step.durationSeconds === "" || (typeof step.durationSeconds === "number" && !invalidNumber(step.durationSeconds, 1, 9999, true))) &&
        ((step.stageType === "press" || step.stageType === "prepress") ? step.pressTimeSeconds === step.durationSeconds : step.pressTimeSeconds === "");
    });
    if (!stagesValid) return false;
    // Draft is the only state allowed to contain incomplete operating data.
    // Archived Trial/Proven records remain complete even though they cannot run
    // until restored; active-machine availability is a graph concern.
    if (source.status !== "draft" && validateRunnableRecipe(Object.assign({}, source, { archived: false }), undefined, undefined, true).length) return false;
    return true;
  }

  function validateV4BatchRaw(source) {
    if (!source || Object.prototype.hasOwnProperty.call(source, "manufacturerVerifiedAt") ||
        Object.prototype.hasOwnProperty.call(source, "manufacturerVerificationFingerprint")) return false;
    const required = ["recordSchemaVersion", "processSchemaVersion", "id", "setupId", "recipeId", "recipe",
      "initialPressedSetup", "setupChangedDuringRun", "setupRevisionId", "recipeRevisionId", "sourceBatchId",
      "jobReference", "jobName", "quantityPlanned", "quantityProcessed", "quantityGood", "quantityWaste",
      "quantityReworked", "outcome", "completionStatus", "issues", "failureReason", "notes", "runMode",
      "firstPiece", "qcChecks", "interruptions", "productionStartedAt", "instructionCheckedAt",
      "instructionCheckFingerprint", "operationalFingerprintV4", "provenanceFingerprint", "exactSetupFingerprint",
      "authorizationBasis", "startedAt", "completedAt", "workDate", "utcOffsetMinutes", "timeZone",
      "durationSeconds", "corrections", "reviewStatus", "legacyOriginal"];
    if (!exactObjectKeys(source, required)) return false;
    const issueKeys = ["id", "quantity", "symptom", "suspectedCause", "disposition", "note"];
    const correctionKeys = ["correctedAt", "previous", "note"];
    if (!Array.isArray(source.issues) || !source.issues.every(function (issue) { return exactObjectKeys(issue, issueKeys); }) ||
        !Array.isArray(source.corrections) || !source.corrections.every(function (correction) {
          return exactObjectKeys(correction, correctionKeys) && correction.previous && correction.previous.recordSchemaVersion === 4 &&
            Array.isArray(correction.previous.corrections) && correction.previous.corrections.length === 0 &&
            validateV4BatchRaw(correction.previous);
        })) return false;
    const legacyShape = Object.assign({}, source, { recordSchemaVersion: 3, manufacturerVerifiedAt: "", manufacturerVerificationFingerprint: "" });
    if (!validateV3BatchRaw(legacyShape) || source.recordSchemaVersion !== 4 || source.processSchemaVersion !== 4) return false;
    if (!exactTextField(source, "setupId", 100) || source.setupId !== source.recipeId ||
        !exactTextField(source, "setupRevisionId", 140) || source.setupRevisionId !== recipeRevisionIdV4(source.setupId, source.recipe) ||
        !exactTextField(source, "jobReference", 180) || source.jobReference !== source.jobName) return false;
    if (!validateV4RecipeRaw(source.recipe, true, source.reviewStatus === "legacy_needs_review")) return false;
    if (!validateV4RecipeRaw(source.initialPressedSetup, true, source.reviewStatus === "legacy_needs_review") ||
        typeof source.setupChangedDuringRun !== "boolean") return false;
    const runBoundary = new Date(source.startedAt || source.completedAt).getTime();
    if ([source.recipe, source.initialPressedSetup].some(function (setup) {
      return setup.proofResetAt && (!Number.isFinite(runBoundary) || new Date(setup.proofResetAt).getTime() > runBoundary);
    })) return false;
    const firstPieceKeys = ["outcome", "attemptedAt", "completedAt", "attempts", "note"];
    if (!exactObjectKeys(source.firstPiece, firstPieceKeys) || !FIRST_PIECE_OUTCOMES.has(source.firstPiece.outcome) ||
        !exactIsoDate(source.firstPiece.attemptedAt, true) || !exactIsoDate(source.firstPiece.completedAt, true) ||
        typeof source.firstPiece.attempts !== "number" || invalidNumber(source.firstPiece.attempts, 0, 99, true) ||
        !exactTextField(source.firstPiece, "note", 1000)) return false;
    if (!RUN_MODES.has(source.runMode) || !Array.isArray(source.qcChecks) || source.qcChecks.length > 100 ||
        !Array.isArray(source.interruptions) || source.interruptions.length > 100) return false;
    if (!source.qcChecks.every(function (check) {
      return exactObjectKeys(check, ["checkedAt", "processedCount", "result", "note"]) && exactIsoDate(check.checkedAt, false) &&
        typeof check.processedCount === "number" && !invalidNumber(check.processedCount, 0, source.quantityPlanned, true) &&
        ["pass", "adjust", "end_early"].includes(check.result) && exactTextField(check, "note", 1000);
    })) return false;
    if (!source.interruptions.every(function (entry) {
      return exactObjectKeys(entry, ["startedAt", "endedAt", "reason", "productionBegan"]) && exactIsoDate(entry.startedAt, false) &&
        exactIsoDate(entry.endedAt, true) && exactTextField(entry, "reason", 500) && entry.productionBegan === true;
    })) return false;
    const exactTextFields = { productionStartedAt: 100, instructionCheckedAt: 100, instructionCheckFingerprint: 80,
      operationalFingerprintV4: 80, provenanceFingerprint: 80, exactSetupFingerprint: 80, authorizationBasis: 80 };
    if (!Object.keys(exactTextFields).every(function (key) { return exactTextField(source, key, exactTextFields[key]); }) ||
        !exactIsoDate(source.productionStartedAt, true) || !exactIsoDate(source.instructionCheckedAt, true)) return false;
    if (!AUTHORIZATION_BASES.has(source.authorizationBasis)) return false;
    if (source.authorizationBasis !== "legacy_migration" && (!source.productionStartedAt || !source.instructionCheckedAt ||
        !source.instructionCheckFingerprint || (source.runMode === "test" && (source.quantityPlanned !== 1 ||
          source.firstPiece.outcome === "not_required")))) return false;
    return validateBatch(source).length === 0;
  }

  function validateV3CorrectionSnapshotRaw(source) {
    if (!source || ![3, 4].includes(source.recordSchemaVersion)) return false;
    if (source.recordSchemaVersion === 4) return Array.isArray(source.corrections) && source.corrections.length === 0 && validateV4BatchRaw(source);
    const issues = Array.isArray(source.issues) ? source.issues : [];
    const processed = Number(source.quantityProcessed || 0);
    const planned = Number(source.quantityPlanned || 0);
    const candidate = Object.assign({}, source, {
      completionStatus: Object.prototype.hasOwnProperty.call(source, "completionStatus") ? source.completionStatus : (processed < planned ? "partial" : "complete"),
      failureReason: Object.prototype.hasOwnProperty.call(source, "failureReason") ? source.failureReason : text(issues.map(function (issue) { return issue.note || issue.symptom; }).filter(Boolean).join("; "), 1000),
      corrections: []
    });
    return source.processSchemaVersion === 4 ? validateV4BatchRaw(candidate) : validateV3BatchRaw(candidate);
  }

  function uniqueLegacySteps(recipe, defaultUnit) {
    const source = recipe && typeof recipe === "object" && !Array.isArray(recipe) ? Object.assign({}, recipe) : {};
    if (!Array.isArray(source.steps)) return source;
    const seen = new Set();
    source.steps = source.steps.map(function (step) {
      const next = Object.assign({}, step);
      let id = text(next.id, 100);
      if (!id || seen.has(id)) id = uuid();
      seen.add(id); next.id = id;
      if (!UNITS.has(next.temperatureUnit)) next.temperatureUnit = UNITS.has(defaultUnit) ? defaultUnit : "F";
      return next;
    });
    return source;
  }

  function validateLegacyBatchRaw(source) {
    if (!source || typeof source !== "object" || Array.isArray(source) || !text(source.id, 100) || !text(source.recipeId, 100)) return false;
    if (!source.recipe || typeof source.recipe !== "object" || Array.isArray(source.recipe)) return false;
    if (["quantityPlanned", "quantityGood", "quantityWaste"].some(function (key) { return typeof source[key] !== "number"; })) return false;
    if (!OUTCOMES.has(source.outcome) || !source.completedAt || Number.isNaN(new Date(source.completedAt).getTime())) return false;
    return validateBatchInput({
      quantityPlanned: source.quantityPlanned,
      quantityProcessed: Number(source.quantityGood || 0) + Number(source.quantityWaste || 0),
      quantityGood: source.quantityGood,
      quantityWaste: source.quantityWaste,
      quantityReworked: 0,
      issues: []
    }).length === 0;
  }

  function validateLegacyRecipeRaw(source, allowIncomplete) {
    if (!source || typeof source !== "object" || Array.isArray(source) || !exactTextField(source, "id", 100) || !source.id) return false;
    const textLimits = { title: 140, customerJob: 180, blankMaterial: 180, transferMedium: 180, machineNickname: 120, platenZone: 120, pressure: 120, peelMethod: 120, notes: 5000, blankSupplier: 180, blankSku: 180, blankLot: 180, blankColourSize: 180, transferSupplier: 180, transferSku: 180, transferLot: 180, designRevision: 180, printerInkPaperProfile: 500, accessoriesPlacementCooling: 1000 };
    if (Object.keys(textLimits).some(function (key) { return source[key] !== undefined && !exactTextField(source, key, textLimits[key]); })) return false;
    if (source.steps !== undefined) {
      if (!Array.isArray(source.steps) || source.steps.length > MAX_STAGES) return false;
      const stepLimits = { id: 100, name: 120, machineNickname: 120, platenZone: 120, pressure: 120, placementAction: 500, finishAction: 500 };
      for (const step of source.steps) {
        if (!step || typeof step !== "object" || Array.isArray(step) || Object.keys(stepLimits).some(function (key) { return step[key] !== undefined && !exactTextField(step, key, stepLimits[key]); })) return false;
      }
    }
    if (source.createdAt !== undefined && !exactIsoDate(source.createdAt, false)) return false;
    if (source.updatedAt !== undefined && !exactIsoDate(source.updatedAt, false)) return false;
    if (source.lastUsedAt !== undefined && !exactIsoDate(source.lastUsedAt, true)) return false;
    const prepared = uniqueLegacySteps(source, source.temperatureUnit);
    const normalized = normalizeRecipe(prepared, prepared.temperatureUnit, true);
    return allowIncomplete || validateRecipeInput(normalized).length === 0;
  }

  function evidenceAfterProofReset(recipe, evidence) {
    if (!recipe || !recipe.proofResetAt) return true;
    const resetAt = new Date(recipe.proofResetAt).getTime();
    const completedAt = new Date(evidence && evidence.completedAt).getTime();
    return Number.isFinite(resetAt) && Number.isFinite(completedAt) && completedAt > resetAt;
  }

  function hasVerificationEvidenceCore(recipe, batchById) {
    const evidence = batchById && batchById.get(recipe.verifiedBatchId);
    if (evidence && evidence.processSchemaVersion === 4) {
      return Boolean(evidenceAfterProofReset(recipe, evidence) && evidence.recipeId === recipe.id && evidence.reviewStatus === "complete" && evidence.outcome === "success" &&
        evidence.quantityProcessed === evidence.quantityPlanned && evidence.quantityGood === evidence.quantityPlanned &&
        evidence.quantityWaste === 0 && evidence.quantityReworked === 0 && Array.isArray(evidence.issues) && evidence.issues.length === 0 &&
        evidence.setupChangedDuringRun === false && evidence.authorizationBasis !== "legacy_migration" &&
        (!evidence.firstPiece || evidence.firstPiece.outcome === "not_required" || evidence.firstPiece.outcome === "pass") &&
        validateBatch(evidence).length === 0 && validateRunnableRecipe(recipe).length === 0 && instructionSourceChecked(recipe.instructionSource) &&
        instructionReferenceValid(recipe, batchById, evidence.startedAt || evidence.completedAt, evidence.id) &&
        evidence.instructionCheckedAt && evidence.instructionCheckFingerprint === exactSetupFingerprint(evidence.recipe) &&
        exactSetupFingerprint(recipe) === exactSetupFingerprint(evidence.recipe));
    }
    return Boolean(evidence && evidenceAfterProofReset(recipe, evidence) && evidence.recipeId === recipe.id && evidence.reviewStatus === "complete" && evidence.outcome === "success" &&
      evidence.quantityProcessed === evidence.quantityPlanned && evidence.quantityGood === evidence.quantityPlanned && evidence.quantityWaste === 0 && evidence.quantityReworked === 0 &&
      Array.isArray(evidence.issues) && evidence.issues.length === 0 && validateBatch(evidence).length === 0 && validateVerifiableRecipe(recipe).length === 0 &&
      operationalFingerprint(recipe) === operationalFingerprint(evidence.recipe));
  }

  function qualifyingEvidenceForRecipe(evidence, recipe, batchById) {
    return Boolean(evidence && recipe && evidenceAfterProofReset(recipe, evidence) && evidence.processSchemaVersion === 4 && evidence.recipeId === recipe.id &&
      evidence.reviewStatus === "complete" && evidence.outcome === "success" && evidence.quantityProcessed === evidence.quantityPlanned &&
      evidence.quantityGood === evidence.quantityPlanned && evidence.quantityWaste === 0 && evidence.quantityReworked === 0 &&
      Array.isArray(evidence.issues) && evidence.issues.length === 0 && evidence.setupChangedDuringRun === false &&
      evidence.authorizationBasis !== "legacy_migration" && (!evidence.firstPiece || evidence.firstPiece.outcome === "not_required" ||
        evidence.firstPiece.outcome === "pass") && validateBatch(evidence).length === 0 && validateRunnableRecipe(recipe).length === 0 &&
      instructionSourceChecked(recipe.instructionSource) && instructionReferenceValid(recipe, batchById,
        evidence.startedAt || evidence.completedAt, evidence.id) && evidence.instructionCheckedAt &&
      evidence.instructionCheckFingerprint === exactSetupFingerprint(evidence.recipe) &&
      exactSetupFingerprint(recipe) === exactSetupFingerprint(evidence.recipe));
  }

  function hasValidSnapshotVerificationEvidence(recipe, batchById) {
    if (!recipe || recipe.status !== "verified") return true;
    const evidence = batchById && batchById.get(recipe.verifiedBatchId);
    return hasVerificationEvidenceCore(recipe, batchById) && recipe.verifiedAt === evidence.completedAt;
  }

  function hasValidBatchSnapshotVerificationEvidence(ownerBatch, batchById) {
    if (!ownerBatch || !ownerBatch.recipe || ownerBatch.recipe.status !== "verified") return true;
    if (ownerBatch.reviewStatus !== "complete" || !hasValidSnapshotVerificationEvidence(ownerBatch.recipe, batchById)) return false;
    const evidence = batchById && batchById.get(ownerBatch.recipe.verifiedBatchId);
    if (!evidence) return false;
    if (evidence.id === ownerBatch.id) return true;
    const evidenceAt = new Date(evidence.completedAt).getTime();
    const ownerBoundary = new Date(ownerBatch.startedAt || ownerBatch.completedAt).getTime();
    return Number.isFinite(evidenceAt) && Number.isFinite(ownerBoundary) && evidenceAt <= ownerBoundary;
  }

  function hasValidVerificationEvidence(recipe, batchById) {
    if (!recipe || recipe.status !== "verified") return true;
    if (!hasValidSnapshotVerificationEvidence(recipe, batchById)) return false;
    const evidence = batchById && batchById.get(recipe.verifiedBatchId);
    const createdAt = new Date(recipe.createdAt).getTime();
    const updatedAt = new Date(recipe.updatedAt).getTime();
    const evidenceAt = evidence ? new Date(evidence.completedAt).getTime() : NaN;
    return Number.isFinite(createdAt) && Number.isFinite(updatedAt) && Number.isFinite(evidenceAt) && createdAt <= evidenceAt && evidenceAt <= updatedAt;
  }

  function canonicalizeBatchVerification(ownerBatch, batchById) {
    if (!ownerBatch || !ownerBatch.recipe || ownerBatch.recipe.status !== "verified") return ownerBatch;
    const evidence = batchById && batchById.get(ownerBatch.recipe.verifiedBatchId);
    const evidenceAt = evidence ? new Date(evidence.completedAt).getTime() : NaN;
    const ownerBoundary = new Date(ownerBatch.startedAt || ownerBatch.completedAt).getTime();
    const chronologyValid = Boolean(evidence) && (evidence.id === ownerBatch.id || (Number.isFinite(evidenceAt) && Number.isFinite(ownerBoundary) && evidenceAt <= ownerBoundary));
    const remainsVerified = ownerBatch.reviewStatus === "complete" && hasVerificationEvidenceCore(ownerBatch.recipe, batchById) && chronologyValid;
    const recipe = Object.assign({}, ownerBatch.recipe, remainsVerified
      ? { status: "verified", verifiedAt: evidence.completedAt }
      : { status: "trial", verifiedAt: "", verifiedBatchId: "" });
    if (recipe.status === ownerBatch.recipe.status && recipe.verifiedAt === ownerBatch.recipe.verifiedAt && recipe.verifiedBatchId === ownerBatch.recipe.verifiedBatchId) return ownerBatch;
    return normalizeBatch(Object.assign({}, ownerBatch, { recipe: recipe }), true);
  }

  function canonicalizeBatchVerifications(batches) {
    const values = Array.isArray(batches) ? batches : [];
    const batchById = new Map(values.map(function (batch) { return [batch.id, batch]; }));
    return values.map(function (batch) { return canonicalizeBatchVerification(batch, batchById); });
  }

  function canonicalizeRecipeVerification(recipe, batchById, mutationAt) {
    if (!recipe || recipe.status !== "verified" || hasValidVerificationEvidence(recipe, batchById)) return recipe;
    const evidence = batchById && batchById.get(recipe.verifiedBatchId);
    const evidenceAt = evidence ? new Date(evidence.completedAt).getTime() : NaN;
    const createdAt = new Date(recipe.createdAt).getTime();
    if (hasVerificationEvidenceCore(recipe, batchById) && Number.isFinite(createdAt) && Number.isFinite(evidenceAt) && createdAt <= evidenceAt) {
      return normalizeRecipe(Object.assign({}, recipe, {
        verifiedAt: evidence.completedAt,
        updatedAt: recipeMutationTime(recipe, evidence.completedAt, mutationAt)
      }), recipe.temperatureUnit, true);
    }
    return normalizeRecipe(Object.assign({}, recipe, {
      status: "trial", verifiedAt: "", verifiedBatchId: "", updatedAt: recipeMutationTime(recipe, mutationAt)
    }), recipe.temperatureUnit, true);
  }

  function invalidLineageBatchIds(batches) {
    const values = Array.isArray(batches) ? batches : [];
    const byId = new Map(values.map(function (batch) { return [batch.id, batch]; }));
    const invalid = new Set();
    values.forEach(function (batch) {
      if (batch.reviewStatus === "legacy_needs_review") return;
      const seen = new Set([batch.id]);
      let child = batch;
      while (child && child.sourceBatchId) {
        if (!byId.has(child.sourceBatchId)) { invalid.add(batch.id); break; }
        if (seen.has(child.sourceBatchId)) { invalid.add(batch.id); break; }
        const parent = byId.get(child.sourceBatchId);
        if (parent.reviewStatus === "legacy_needs_review") { invalid.add(batch.id); break; }
        const parentCompleted = new Date(parent.completedAt).getTime();
        const childBoundary = new Date(child.startedAt || child.completedAt).getTime();
        if (!Number.isFinite(parentCompleted) || !Number.isFinite(childBoundary) || parentCompleted > childBoundary) { invalid.add(batch.id); break; }
        seen.add(child.sourceBatchId);
        child = parent;
      }
    });
    return invalid;
  }

  function instructionReferenceValid(setup, batchById, boundary, dependentBatchId) {
    const source = setup && setup.instructionSource;
    if (!source || source.type !== "prior_successful_batch") return true;
    if (!source.priorBatchId || source.priorBatchId === dependentBatchId) return false;
    const prior = batchById && batchById.get(source.priorBatchId);
    if (!prior || prior.reviewStatus !== "complete" || prior.outcome !== "success" || validateBatch(prior).length) return false;
    const completed = new Date(prior.completedAt).getTime();
    const limit = boundary ? new Date(boundary).getTime() : Infinity;
    return Number.isFinite(completed) && Number.isFinite(limit) && completed <= limit;
  }

  function graphIntegrityErrors(machines, setups, batches) {
    const machineValues = Array.isArray(machines) ? machines : [];
    const machineById = new Map(machineValues.map(function (machine) { return [machine && machine.id, machine]; }).filter(function (entry) { return Boolean(entry[0]); }));
    const batchValues = Array.isArray(batches) ? batches : [];
    const batchById = new Map(batchValues.map(function (batch) { return [batch.id, batch]; }));
    const errors = [];
    function checkSetup(setup, boundary, dependentBatchId, path, requireActiveMachines) {
      if (!setup || typeof setup !== "object") { errors.push(`${path}.setup`); return; }
      const topMachine = machineById.get(setup.machineProfileId);
      if (setup.machineProfileId && (!topMachine || (requireActiveMachines && topMachine.archived === true))) errors.push(`${path}.machineProfileId`);
      if (setup.machineProfile && setup.machineProfile.id !== setup.machineProfileId) errors.push(`${path}.machineProfile.id`);
      if (requireActiveMachines && topMachine && setup.machineProfile &&
          ["brand", "model", "pressureMethod", "pressureScale", "platenOrZone"].some(function (field) {
            return setup.machineProfile[field] !== topMachine[field];
          })) errors.push(`${path}.machineProfile.semantic`);
      (setup.steps || []).forEach(function (step, index) {
        const stepMachine = step && machineById.get(step.machineProfileId);
        if (step && step.machineProfileId && (!stepMachine || (requireActiveMachines && stepMachine.archived === true))) errors.push(`${path}.steps.${index}.machineProfileId`);
      });
      if (!instructionReferenceValid(setup, batchById, boundary, dependentBatchId)) errors.push(`${path}.instructionSource.priorBatchId`);
    }
    (setups || []).forEach(function (setup, index) { checkSetup(setup, setup.updatedAt, "", `setups.${setup && setup.id || index}`, !setup.archived); });
    batchValues.forEach(function (batch, index) {
      const boundary = batch.startedAt || batch.completedAt;
      const batchPath = `batches.${batch && batch.id || index}`;
      checkSetup(batch.recipe, boundary, batch.id, `${batchPath}.recipe`, false);
      checkSetup(batch.initialPressedSetup, boundary, batch.id, `${batchPath}.initialPressedSetup`, false);
      (batch.corrections || []).forEach(function (correction, correctionIndex) {
        const previous = correction && correction.previous;
        if (!previous) return;
        const priorBoundary = previous.startedAt || previous.completedAt;
        checkSetup(previous.recipe, priorBoundary, previous.id, `${batchPath}.corrections.${correctionIndex}.previous.recipe`, false);
        if (previous.initialPressedSetup) checkSetup(previous.initialPressedSetup, priorBoundary, previous.id,
          `${batchPath}.corrections.${correctionIndex}.previous.initialPressedSetup`, false);
      });
    });
    (setups || []).forEach(function (setup, index) {
      const path = `setups.${setup && setup.id || index}`;
      if (!hasValidVerificationEvidence(setup, batchById)) errors.push(`${path}.provenEvidence`);
      if (setup && setup.setupSchemaVersion === 4) {
        const evidence = batchValues.filter(function (batch) {
          return batch.recipeId === setup.id && qualifyingEvidenceForRecipe(batch, setup, batchById);
        }).sort(function (left, right) { return new Date(right.completedAt) - new Date(left.completedAt); });
        if (setup.provenEvidenceCount !== evidence.length) errors.push(`${path}.provenEvidenceCount`);
        if (!setup.archived && evidence.length) {
          if (setup.status !== "verified" || setup.verifiedBatchId !== evidence[0].id || setup.verifiedAt !== evidence[0].completedAt) {
            errors.push(`${path}.provenEvidence`);
          }
        } else if (setup.status === "verified" || setup.verifiedAt || setup.verifiedBatchId) errors.push(`${path}.provenEvidence`);
      }
    });
    batchValues.forEach(function (batch, index) {
      if (!hasValidBatchSnapshotVerificationEvidence(batch, batchById)) errors.push(`batches.${batch && batch.id || index}.provenEvidence`);
    });
    invalidLineageBatchIds(batchValues).forEach(function (id) { errors.push(`batches.${id}.sourceBatchId`); });
    return Array.from(new Set(errors));
  }

  function rekeyImportedBatchRecipe(batch, reassignedRecipeIds) {
    const originalId = text(batch && (batch.setupId || batch.recipeId), 100);
    const replacementId = reassignedRecipeIds.get(originalId);
    if (!replacementId) return batch;
    const source = boundedJsonSnapshot(batch);
    source.setupId = replacementId; source.recipeId = replacementId;
    [source.recipe, source.initialPressedSetup, source.firstPressedSetup].forEach(function (snapshot) {
      if (snapshot && typeof snapshot === "object" && snapshot.id === originalId) snapshot.id = replacementId;
    });
    (source.corrections || []).forEach(function (correction) {
      const previous = correction && correction.previous;
      if (!previous || (previous.setupId || previous.recipeId) !== originalId) return;
      previous.setupId = replacementId; previous.recipeId = replacementId;
      [previous.recipe, previous.initialPressedSetup, previous.firstPressedSetup].forEach(function (snapshot) {
        if (snapshot && typeof snapshot === "object" && snapshot.id === originalId) snapshot.id = replacementId;
      });
      if (previous.recipe && previous.recordSchemaVersion === 3) previous.recipeRevisionId = recipeRevisionId(replacementId, previous.recipe);
      if (previous.recipe && previous.recordSchemaVersion === 4) {
        previous.recipeRevisionId = recipeRevisionId(replacementId, previous.recipe);
        previous.setupRevisionId = recipeRevisionIdV4(replacementId, previous.recipe);
      }
    });
    return normalizeBatch(source, true);
  }

  function parseBackup(raw) {
    if (typeof raw !== "string" || utf8ByteLength(raw) > MAX_BACKUP_BYTES) throw new Error("backup_size");
    let parsed;
    try { parsed = JSON.parse(raw.replace(/^\uFEFF/, "")); } catch (error) { throw new Error("backup_json"); }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("backup_shape");
    if (!isBoundedJsonValue(parsed, 60, 1000000)) throw new Error("backup_shape");
    const schemaVersion = parsed.schemaVersion;
    if (parsed.schema !== "press-bench-log" || ![1, 2, 3, 4].includes(schemaVersion) || (parsed.appId !== undefined && parsed.appId !== "APP-018")) throw new Error("backup_schema");
    if (schemaVersion === 4) {
      const topLevelKeys = Object.keys(parsed).sort();
      const requiredKeys = ["appId", "batches", "encrypted", "exportedAt", "machines", "schema", "schemaVersion", "settings", "setups"];
      const allowedKeys = new Set(requiredKeys.concat(["freeRunsUsed"]));
      if (requiredKeys.some(function (key) { return !Object.prototype.hasOwnProperty.call(parsed, key); }) ||
          topLevelKeys.some(function (key) { return !allowedKeys.has(key); })) throw new Error("backup_shape");
      if (parsed.appId !== "APP-018" || parsed.encrypted !== false || !exactIsoDate(parsed.exportedAt, false) ||
          !validatePortableSettingsRaw(parsed.settings) ||
          (parsed.freeRunsUsed !== undefined && (!Number.isInteger(parsed.freeRunsUsed) || parsed.freeRunsUsed < 0 || parsed.freeRunsUsed > 5))) throw new Error("backup_shape");
    }
    const rawRecipes = schemaVersion === 4 ? parsed.setups : parsed.recipes;
    if (!Array.isArray(rawRecipes) || !Array.isArray(parsed.batches) || (schemaVersion === 4 && !Array.isArray(parsed.machines))) throw new Error("backup_shape");
    const rawMachines = schemaVersion === 4 ? parsed.machines : [];
    if (rawMachines.length > MAX_RECORDS || rawRecipes.length > MAX_RECORDS || parsed.batches.length > MAX_RECORDS) throw new Error("backup_records");
    assertUniqueBackupIds(rawMachines, "backup_machine_id");
    assertUniqueBackupIds(rawRecipes, "backup_setup_id");
    assertUniqueBackupIds(parsed.batches, "backup_batch_id");
    if (schemaVersion >= 2) {
      assertUniqueNestedIds(rawRecipes, "steps", "backup_step_id");
      assertUniqueNestedIds(parsed.batches, "issues", "backup_issue_id");
      parsed.batches.forEach(function (batch) { if (batch && batch.recipe) assertUniqueNestedIds([batch.recipe], "steps", "backup_step_id"); });
    }
    const machines = rawMachines.map(function (machine) {
      if (!validateV4MachineRaw(machine)) throw new Error("backup_machine");
      return normalizeMachineProfile(machine, true);
    });
    const machineIds = new Set(machines.map(function (machine) { return machine.id; }));
    const occupiedRecipeIds = new Set(rawRecipes.map(function (recipe) { return text(recipe && recipe.id, 100); }));
    const reassignedRecipeIds = new Map();
    let recipes = rawRecipes.map(function (recipe) {
      const allowStarter = SYSTEM_STARTER_IDS.has(text(recipe && recipe.id, 100));
      const recipeValid = schemaVersion === 4 ? validateV4RecipeRaw(recipe, false, allowStarter || recipe.status === "draft")
        : schemaVersion === 3 ? validateV3RecipeRaw(recipe, false, allowStarter)
        : schemaVersion === 2 ? validateV2RecipeRaw(recipe, false, allowStarter) : validateLegacyRecipeRaw(recipe, allowStarter);
      if (!recipeValid) throw new Error("backup_recipe");
      const prepared = schemaVersion === 1 ? uniqueLegacySteps(recipe, recipe.temperatureUnit) : recipe;
      let normalized = normalizeRecipe(prepared, prepared.temperatureUnit, true);
      const legacySystemRecord = allowStarter && schemaVersion < 4 && isLegacyCanonicalStarterRecipe(normalized);
      if (allowStarter && schemaVersion < 4 && (isCanonicalStarterRecipe(normalized) || legacySystemRecord)) return null;
      if (allowStarter) {
        const structuralSavedSetup = schemaVersion === 4 && isCanonicalStarterRecipe(normalized);
        const validEditedStarter = structuralSavedSetup || (schemaVersion === 4 ? validateV4RecipeRaw(recipe, false, false)
          : schemaVersion === 3 ? validateV3RecipeRaw(recipe, false, false)
          : schemaVersion === 2 ? validateV2RecipeRaw(recipe, false, false) : validateLegacyRecipeRaw(recipe, false));
        if (!validEditedStarter) throw new Error("backup_recipe");
        let replacementId = uuid();
        while (!replacementId || occupiedRecipeIds.has(replacementId) || SYSTEM_STARTER_IDS.has(replacementId)) replacementId = uuid();
        occupiedRecipeIds.add(replacementId); reassignedRecipeIds.set(normalized.id, replacementId);
        normalized = normalizeRecipe(Object.assign({}, normalized, { id: replacementId, status: "draft", verifiedAt: "", verifiedBatchId: "",
          steps: structuralSavedSetup ? normalized.steps.map(function (step) { return Object.assign({}, step, { id: uuid() }); }) : normalized.steps,
          needsReview: !structuralSavedSetup, migrationOriginal: structuralSavedSetup ? null : legacyRecipeSnapshot(recipe) }), normalized.temperatureUnit, true);
      }
      return normalized;
    }).filter(Boolean);
    let batches = parsed.batches.map(function (batch) {
      const source = Object.assign({}, batch);
      if (schemaVersion === 1) {
        if (!validateLegacyBatchRaw(source)) throw new Error("backup_batch");
        source.recipe = uniqueLegacySteps(source.recipe, source.recipe && source.recipe.temperatureUnit);
        return rekeyImportedBatchRecipe(migrateLegacyBatch(source), reassignedRecipeIds);
      }
      if (schemaVersion === 4 ? !validateV4BatchRaw(source) : schemaVersion === 3 ? !validateV3BatchRaw(source) : !validateV2BatchRaw(source)) throw new Error("backup_batch");
      const normalized = rekeyImportedBatchRecipe(normalizeBatch(source, true), reassignedRecipeIds);
      if (normalized.reviewStatus !== "legacy_needs_review" && validateBatch(normalized).length) throw new Error("backup_batch");
      return normalized;
    });
    if (invalidLineageBatchIds(batches).size) throw new Error("backup_batch_lineage");
    let batchById = new Map(batches.map(function (batch) { return [batch.id, batch]; }));
    if (schemaVersion === 4 && batches.some(function (batch) { return !hasValidBatchSnapshotVerificationEvidence(batch, batchById); })) throw new Error("backup_verification");
    if (schemaVersion === 3) {
      const rawBatchById = new Map(parsed.batches.map(function (batch) { return [batch.id, batch]; }));
      if (parsed.batches.some(function (batch) { return !hasValidBatchSnapshotVerificationEvidence(batch, rawBatchById); }) ||
          rawRecipes.some(function (recipe) { return !hasValidVerificationEvidence(recipe, rawBatchById); })) throw new Error("backup_verification");
      recipes = recipes.map(function (recipe) { return recipe.status === "verified" ? normalizeRecipe(Object.assign({}, recipe,
        { status: "trial", verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0 }), recipe.temperatureUnit, true) : recipe; });
      batches = canonicalizeBatchVerifications(batches);
      batchById = new Map(batches.map(function (batch) { return [batch.id, batch]; }));
    }
    if (schemaVersion < 3) {
      batches = canonicalizeBatchVerifications(batches);
      batchById = new Map(batches.map(function (batch) { return [batch.id, batch]; }));
    }
    if (schemaVersion === 4) recipes.forEach(function (recipe) {
      if (!hasValidVerificationEvidence(recipe, batchById)) throw new Error("backup_verification");
      const evidence = batches.filter(function (batch) { return batch.recipeId === recipe.id && qualifyingEvidenceForRecipe(batch, recipe, batchById); })
        .sort(function (left, right) { return new Date(right.completedAt) - new Date(left.completedAt); });
      if (recipe.provenEvidenceCount !== evidence.length ||
          (recipe.persistedOperationalFingerprintV4 && recipe.persistedOperationalFingerprintV4 !== operationalFingerprintV4(recipe))) {
        throw new Error("backup_verification");
      }
      if (!recipe.archived && evidence.length) {
        if (recipe.status !== "verified" || recipe.verifiedBatchId !== evidence[0].id || recipe.verifiedAt !== evidence[0].completedAt ||
            recipe.persistedOperationalFingerprintV4 !== operationalFingerprintV4(recipe)) throw new Error("backup_verification");
      } else if (recipe.status === "verified" || recipe.verifiedAt || recipe.verifiedBatchId) throw new Error("backup_verification");
    });
    const storedBytes = machines.concat(recipes, batches).reduce(function (total, record) {
      const recordBytes = utf8ByteLength(JSON.stringify(record)) + 1;
      if (recordBytes > MAX_RECORD_BYTES) throw new Error("backup_record_size");
      return total + recordBytes;
    }, 0);
    if (storedBytes > MAX_DATA_BYTES) throw new Error("backup_size");
    const normalizedSettings = normalizeSettings(parsed.settings);
    if (utf8ByteLength(JSON.stringify({ machines: machines, recipes: recipes, batches: batches,
      settings: normalizedSettings, session: null })) > MAX_DATA_BYTES) throw new Error("backup_size");
    if (schemaVersion === 4) {
      const graphErrors = graphIntegrityErrors(machines, recipes, batches);
      if (graphErrors.some(function (error) { return error.includes("machineProfileId"); })) throw new Error("backup_machine_reference");
      if (graphErrors.some(function (error) { return error.includes("instructionSource.priorBatchId"); })) throw new Error("backup_instruction_reference");
      if (graphErrors.length) throw new Error("backup_batch_lineage");
    }
    return { schemaVersion: schemaVersion, machines: machines, setups: recipes, recipes: recipes,
      batches: batches, settings: normalizedSettings, encrypted: parsed.encrypted === true };
  }

  root.PressBenchDomain = Object.freeze({
    LANGUAGES: new Set(LANGUAGES),
    SUPPORTED_LOCALES: new Set(SUPPORTED_LOCALES),
    LOCALE_PROFILES: LOCALE_PROFILES,
    RTL_LANGUAGE_IDS: new Set(RTL_LANGUAGE_IDS),
    STORE_LOCALE_TAGS: STORE_LOCALE_TAGS,
    DEFAULT_LOCALE_BY_LANGUAGE: DEFAULT_LOCALE_BY_LANGUAGE,
    UNITS: UNITS,
    PAPER_SIZES: PAPER_SIZES,
    DIMENSION_UNITS: DIMENSION_UNITS,
    OUTCOMES: OUTCOMES,
    SETUP_STATUSES: new Set(["draft", "trial", "proven", "archived"]),
    RECIPE_STATUSES: RECIPE_STATUSES,
    PROCESS_STRUCTURES: PROCESS_STRUCTURES,
    STAGE_TYPES: STAGE_TYPES,
    INSTRUCTION_SOURCE_TYPES: INSTRUCTION_SOURCE_TYPES,
    RUN_MODES: RUN_MODES,
    PROGRESS_MODES: PROGRESS_MODES,
    SETUP_REUSE_CLASSES: SETUP_REUSE_CLASSES,
    AUTHORIZATION_BASES: AUTHORIZATION_BASES,
    FIRST_PIECE_OUTCOMES: FIRST_PIECE_OUTCOMES,
    RUN_PHASES: RUN_PHASES,
    ISSUE_SYMPTOMS: ISSUE_SYMPTOMS,
    ISSUE_CAUSES: ISSUE_CAUSES,
    ISSUE_DISPOSITIONS: ISSUE_DISPOSITIONS,
    REVIEW_STATUSES: REVIEW_STATUSES,
    SYSTEM_STARTER_IDS: SYSTEM_STARTER_IDS,
    MAX_RECORDS: MAX_RECORDS,
    MAX_STAGES: MAX_STAGES,
    MAX_ISSUES: MAX_ISSUES,
    MAX_CORRECTIONS: MAX_CORRECTIONS,
    MAX_BACKUP_BYTES: MAX_BACKUP_BYTES,
    MAX_DATA_BYTES: MAX_DATA_BYTES,
    MAX_RECORD_BYTES: MAX_RECORD_BYTES,
    TERMS_VERSION: TERMS_VERSION,
    SAFETY_ACK_VERSION: SAFETY_ACK_VERSION,
    PRIVACY_NOTICE_VERSION: PRIVACY_NOTICE_VERSION,
    utf8ByteLength: utf8ByteLength,
    sha256: sha256,
    nowIso: nowIso,
    uuid: uuid,
    text: text,
    isBoundedJsonValue: isBoundedJsonValue,
    recipeMutationTime: recipeMutationTime,
    setupMutationTime: recipeMutationTime,
    isCivilDate: isCivilDate,
    workDateFor: workDateFor,
    timeZoneOffsetAt: timeZoneOffsetAt,
    canonicalLanguageId: canonicalLanguageId,
    resolvedLocale: resolvedLocale,
    normalizeLanguageLocale: normalizeLanguageLocale,
    localeFallbackChain: localeFallbackChain,
    localeFacts: localeFacts,
    requireSupportedLocale: requireSupportedLocale,
    storeLocaleTags: storeLocaleTags,
    defaultSettings: defaultSettings,
    normalizeSettings: normalizeSettings,
    migrateSettings: migrateSettings,
    portableSettings: portableSettings,
    normalizeMachineProfile: normalizeMachineProfile,
    machineProfileSnapshot: machineProfileSnapshot,
    validateMachineProfile: validateMachineProfile,
    civilDateNotAfter: civilDateNotAfter,
    normalizeInstructionSource: normalizeInstructionSource,
    instructionSourceChecked: instructionSourceChecked,
    instructionSourceCheckedAt: instructionSourceCheckedAt,
    evidenceAfterProofReset: evidenceAfterProofReset,
    publicSetupStatus: publicSetupStatus,
    emptySetup: emptyRecipe,
    emptyRecipe: emptyRecipe,
    normalizeStep: normalizeStep,
    normalizeRecipe: normalizeRecipe,
    normalizeSetup: normalizeRecipe,
    normalizeStoredRecipe: normalizeStoredRecipe,
    normalizeStoredSetup: normalizeStoredRecipe,
    isCanonicalStarterRecipe: isCanonicalStarterRecipe,
    isLegacyCanonicalStarterRecipe: isLegacyCanonicalStarterRecipe,
    deriveSetupTitle: deriveSetupTitle,
    reuseSetup: reuseSetup,
    recipeSnapshot: recipeSnapshot,
    setupSnapshot: recipeSnapshot,
    operationalFingerprint: operationalFingerprint,
    operationalDefinitionV4: operationalDefinitionV4,
    operationalFingerprintV4: operationalFingerprintV4,
    provenanceFingerprint: provenanceFingerprint,
    exactSetupFingerprint: exactSetupFingerprint,
    recipeRevisionIdV4: recipeRevisionIdV4,
    setupRevisionId: recipeRevisionIdV4,
    deriveOutcome: deriveOutcome,
    normalizeIssue: normalizeIssue,
    normalizeBatch: normalizeBatch,
    migrateLegacyBatch: migrateLegacyBatch,
    normalizeStoredBatch: normalizeStoredBatch,
    batchSetup: batchSetup,
    batchSetupId: batchSetupId,
    batchJobReference: batchJobReference,
    rekeyImportedBatchRecipe: rekeyImportedBatchRecipe,
    validateRecipeInput: validateRecipeInput,
    validateSetupInput: validateRecipeInput,
    validateRecipe: validateRecipe,
    validateVerifiableRecipe: validateVerifiableRecipe,
    validateRunnableRecipe: validateRunnableRecipe,
    validateRunnableSetup: validateRunnableRecipe,
    hasValidSnapshotVerificationEvidence: hasValidSnapshotVerificationEvidence,
    hasValidBatchSnapshotVerificationEvidence: hasValidBatchSnapshotVerificationEvidence,
    hasValidVerificationEvidence: hasValidVerificationEvidence,
    canonicalizeBatchVerification: canonicalizeBatchVerification,
    canonicalizeBatchVerifications: canonicalizeBatchVerifications,
    canonicalizeRecipeVerification: canonicalizeRecipeVerification,
    instructionReferenceValid: instructionReferenceValid,
    graphIntegrityErrors: graphIntegrityErrors,
    invalidLineageBatchIds: invalidLineageBatchIds,
    validateBatchInput: validateBatchInput,
    validateBatch: validateBatch,
    validateV4MachineRaw: validateV4MachineRaw,
    validateV4RecipeRaw: validateV4RecipeRaw,
    validateV4BatchRaw: validateV4BatchRaw,
    validatePortableSettingsRaw: validatePortableSettingsRaw,
    normalizeSearch: normalizeSearch,
    recipeSearchText: recipeSearchText,
    setupSearchText: recipeSearchText,
    batchSearchText: batchSearchText,
    recipeMatches: recipeMatches,
    setupMatches: recipeMatches,
    batchMatches: batchMatches,
    sortRecipes: sortRecipes,
    sortSetups: sortRecipes,
    sortBatches: sortBatches,
    metrics: metrics,
    makeBackup: makeBackup,
    parseBackup: parseBackup,
    validateV4MachineRaw: validateV4MachineRaw,
    validateV4RecipeRaw: validateV4RecipeRaw,
    validateV4BatchRaw: validateV4BatchRaw
  });
})(typeof globalThis !== "undefined" ? globalThis : this);

(function (root) {
  "use strict";

  const D = root.PressBenchDomain;
  const FREE_RECIPE_LIMIT = D.MAX_RECORDS;
  const FREE_BATCH_LIMIT = 5;
  const MAX_DETAILED_REPORT_ROWS = 12000;
  const STARTER_TEMPLATE_VERSION = "APP-018-STRUCTURES-v5";
  const STARTER_PREFIX = "starter-template-";
  const MONETIZATION_MODEL = Object.freeze({
    free: { savedSetups: FREE_RECIPE_LIMIT, completedPresses: FREE_BATCH_LIMIT, timedTrial: false },
    ios: Object.freeze({
      productId: "pressbench_unlimited_monthly_ios",
      legacyProductIds: Object.freeze(["pressbench_unlimited_lifetime_ios"]),
      productType: "auto_renewable_subscription", recurring: true, period: "P1M", restoreAction: true,
      benefits: Object.freeze(["unlimited_presses", "pdf_xlsx_reports"]),
      pricing: Object.freeze({ baseStorefront: "US", baseCurrency: "USD", baseAmountMinor: 999, geoPriced: true })
    }),
    android: Object.freeze({
      productId: "pressbench_unlimited_lifetime_android",
      productType: "non_consumable", recurring: false, restoreAction: true,
      pricing: Object.freeze({ baseStorefront: "US", baseCurrency: "USD", baseAmountMinor: 499, geoPriced: true })
    }),
    priceSource: "store_product"
  });

  function isStarterRecipe(recipe) {
    return D.isCanonicalStarterRecipe(recipe);
  }

  function isStarterBatch(batch) {
    return false;
  }

  function userRecipeCount(recipes) {
    // Templates are not persistence records. Every setup actually present in
    // storage counts, including an untouched draft instantiated from one.
    return (recipes || []).length;
  }

  function userBatchCount(batches) {
    return (batches || []).filter(function (batch) { return !isStarterBatch(batch); }).length;
  }

  function usage(recipes, batches) {
    const setups = userRecipeCount(recipes);
    return {
      setups: setups,
      recipes: setups,
      batches: userBatchCount(batches),
      setupLimit: FREE_RECIPE_LIMIT,
      recipeLimit: FREE_RECIPE_LIMIT,
      batchLimit: FREE_BATCH_LIMIT
    };
  }

  // This predicate deliberately answers only the free-capacity question.
  // Paid access must come from PressBenchEntitlement.capabilities, never a
  // caller-supplied boolean.
  function canAdd(kind, recipes, batches, additional) {
    const setupKind = kind === "setup" || kind === "recipe";
    const count = setupKind ? userRecipeCount(recipes) : userBatchCount(batches);
    const limit = setupKind ? FREE_RECIPE_LIMIT : FREE_BATCH_LIMIT;
    return count + (additional || 1) <= limit;
  }

  function starterTemplates(defaultUnit) {
    const createdAt = D.nowIso();
    const definitions = [
      {
        id: STARTER_PREFIX + "standard-htv",
        title: "HTV setup",
        processStructure: "htv",
        blankMaterial: "",
        transferMedium: "Heat transfer vinyl (HTV)",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "polyester-dtf",
        title: "DTF setup",
        processStructure: "dtf",
        blankMaterial: "",
        transferMedium: "Direct-to-film transfer (DTF)",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "sublimation",
        title: "Sublimation setup",
        processStructure: "sublimation",
        blankMaterial: "",
        transferMedium: "Sublimation transfer",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "multi-stage",
        title: "Multi-stage setup",
        processStructure: "multi_stage",
        blankMaterial: "",
        transferMedium: "",
        name: "Stage 1"
      },
      {
        id: STARTER_PREFIX + "puff-vinyl",
        title: "Puff vinyl setup",
        processStructure: "htv",
        blankMaterial: "",
        transferMedium: "Puff heat transfer vinyl",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "screen-printed-transfer",
        title: "Screen-printed transfer setup",
        processStructure: "screen_printed_transfer",
        blankMaterial: "",
        transferMedium: "Screen-printed transfer",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "other",
        title: "Other process setup",
        processStructure: "other",
        blankMaterial: "",
        transferMedium: "",
        name: "Press"
      },
      {
        id: STARTER_PREFIX + "blank",
        title: "Blank setup",
        processStructure: "blank",
        blankMaterial: "",
        transferMedium: "",
        name: "Press"
      }
    ];
    return definitions.map(function (item) {
      const recipe = D.normalizeRecipe({
        id: item.id,
        title: item.title,
        processStructure: item.processStructure,
        blankMaterial: item.blankMaterial,
        transferMedium: item.transferMedium,
        prePressSeconds: "",
        defaultQuantity: 1,
        status: "draft",
        notes: "Structural starter only. It contains no operating values. Enter and check every value against the current equipment, transfer, substrate, and safety instructions before use.",
        steps: [{
          id: item.id + "-step-1",
          stageType: "press",
          name: item.name,
          machineNickname: "",
          platenZone: "",
          temperature: "",
          temperatureUnit: defaultUnit,
          durationSeconds: "",
          pressure: "",
          repeatCount: 1,
          placementAction: "",
          finishAction: ""
        }],
        createdAt: createdAt,
        updatedAt: createdAt
      }, defaultUnit, true);
      recipe.id = item.id;
      recipe.steps[0].id = item.id + "-step-1";
      recipe.createdAt = createdAt;
      recipe.updatedAt = createdAt;
      return recipe;
    });
  }

  function round(value, places) {
    const factor = 10 ** (places || 0);
    return Math.round((Number(value) + Number.EPSILON) * factor) / factor;
  }

  function temperatureToC(value, unit) {
    if (value === "" || value === null || value === undefined) return null;
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return null;
    return unit === "F" ? (numeric - 32) * 5 / 9 : numeric;
  }

  function temperatureToF(value, unit) {
    if (value === "" || value === null || value === undefined) return null;
    const numeric = Number(value);
    if (!Number.isFinite(numeric)) return null;
    return unit === "C" ? numeric * 9 / 5 + 32 : numeric;
  }

  function formatTemperature(value, unit) {
    if (value === "" || value === null || value === undefined) return "";
    const celsius = temperatureToC(value, unit);
    const fahrenheit = temperatureToF(value, unit);
    if (celsius === null || fahrenheit === null) return String(value);
    return `${round(fahrenheit, 1)}°F / ${round(celsius, 1)}°C`;
  }

  function formatPressure(value) {
    const raw = value === null || value === undefined ? "" : String(value).trim();
    const match = raw.match(/^(-?\d+(?:\.\d+)?)\s*(psi|bar)\b/i);
    if (!match) return raw;
    const numeric = Number(match[1]);
    if (!Number.isFinite(numeric)) return raw;
    const psi = match[2].toLowerCase() === "bar" ? numeric * 14.5037738 : numeric;
    const bar = match[2].toLowerCase() === "psi" ? numeric / 14.5037738 : numeric;
    return `${round(psi, 1)} PSI / ${round(bar, 2)} bar`;
  }

  function outcomeMix(batches) {
    return (batches || []).filter(function (batch) { return batch.reviewStatus !== "legacy_needs_review"; }).reduce(function (totals, batch) {
      const good = Math.max(0, Number(batch.quantityGood) || 0);
      const rework = Math.max(0, Math.min(good, Number(batch.quantityReworked) || 0));
      totals.success += Math.max(0, good - rework);
      totals.rework += rework;
      totals.waste += Math.max(0, Number(batch.quantityWaste) || 0);
      return totals;
    }, { success: 0, rework: 0, waste: 0 });
  }

  function firstStep(recipe) {
    return recipe && Array.isArray(recipe.steps) && recipe.steps.length ? recipe.steps[0] : (recipe || {});
  }

  function sampleSeries(values, maximum) {
    const source = Array.isArray(values) ? values : [];
    const limit = Math.max(2, Math.floor(Number(maximum) || 0));
    if (!limit || source.length <= limit) return source.slice();
    const sampled = [];
    for (let index = 0; index < limit; index += 1) sampled.push(source[Math.round(index * (source.length - 1) / (limit - 1))]);
    return sampled;
  }

  function temperaturePoints(recipes, batches, machine, maximum) {
    const previousByStage = new Map();
    const points = [];
    const machineFilter = D.text(machine, 180);
    (batches || []).slice().sort(function (a, b) { return new Date(a.completedAt) - new Date(b.completedAt); }).forEach(function (batch) {
      if (batch.reviewStatus === "legacy_needs_review") return;
      const steps = batch.recipe && Array.isArray(batch.recipe.steps) ? batch.recipe.steps : [];
      steps.forEach(function (step, index) {
        if (machineFilter && machineFilter !== "all" && D.text(step.machineNickname, 180) !== machineFilter) return;
        const current = temperatureToC(step.temperature, step.temperatureUnit);
        if (current === null) return;
        const key = `${batch.recipeId || "unknown"}:${D.text(step.id, 100) || `legacy-index-${index}`}`;
        if (!previousByStage.has(key)) { previousByStage.set(key, current); return; }
        const previous = previousByStage.get(key);
        points.push({ target: previous, actual: current, completedAt: batch.completedAt,
          batchId: batch.id, setupId: batch.recipeId || "", stepId: D.text(step.id, 100), stepIndex: index });
        previousByStage.set(key, current);
      });
    });
    return maximum ? sampleSeries(points, maximum) : points;
  }

  function recordedSetpointChanges(setups, batches, machine, maximum) {
    return temperaturePoints(setups, batches, machine, maximum).map(function (point) {
      return { previousRecordedSetpointC: point.target, currentRecordedSetpointC: point.actual,
        completedAt: point.completedAt, batchId: point.batchId, setupId: point.setupId,
        stepId: point.stepId, stepIndex: point.stepIndex };
    });
  }

  function localDayKey(date) {
    const value = new Date(date);
    if (Number.isNaN(value.getTime())) return "";
    return [value.getFullYear(), String(value.getMonth() + 1).padStart(2, "0"), String(value.getDate()).padStart(2, "0")].join("-");
  }

  function velocitySeries(batches, startOrDays, endValue) {
    let start; let end;
    if (typeof startOrDays === "number" && endValue === undefined) {
      const dayCount = Math.max(2, Number(startOrDays) || 7);
      end = new Date(); end = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 999);
      start = new Date(end.getFullYear(), end.getMonth(), end.getDate() - dayCount + 1);
    } else {
      start = new Date(startOrDays); end = new Date(endValue);
      if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()) || start > end) return [];
      start = new Date(start.getFullYear(), start.getMonth(), start.getDate());
      end = new Date(end.getFullYear(), end.getMonth(), end.getDate(), 23, 59, 59, 999);
    }
    const civilOrdinal = function (value) { return Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()) / 86400000; };
    const startOrdinal = civilOrdinal(start);
    const spanDays = Math.max(1, civilOrdinal(end) - startOrdinal + 1);
    const bucketDays = Math.max(1, Math.ceil(spanDays / 180));
    const bucketCount = Math.max(1, Math.ceil(spanDays / bucketDays));
    const values = [];
    const totals = new Map();
    (batches || []).forEach(function (batch) {
      if (batch.reviewStatus === "legacy_needs_review") return;
      const completed = new Date(batch.completedAt);
      if (Number.isNaN(completed.getTime())) return;
      let productionDay = completed;
      if (/^\d{4}-\d{2}-\d{2}$/.test(batch.workDate || "")) {
        const parts = batch.workDate.split("-").map(Number);
        productionDay = new Date(parts[0], parts[1] - 1, parts[2], 12);
      }
      const productionOrdinal = civilOrdinal(productionDay);
      if (productionOrdinal < startOrdinal || productionOrdinal > civilOrdinal(end)) return;
      const bucket = Math.min(bucketCount - 1, Math.max(0, Math.floor((productionOrdinal - startOrdinal) / bucketDays)));
      totals.set(bucket, (totals.get(bucket) || 0) + Math.max(0, Number(batch.quantityProcessed) || 0));
    });
    for (let bucket = 0; bucket < bucketCount; bucket += 1) {
      const date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + bucket * bucketDays);
      const key = localDayKey(date);
      values.push({ date: date, key: key, value: totals.get(bucket) || 0, bucketDays: bucketDays });
    }
    return values;
  }

  root.PressBenchBusiness = Object.freeze({
    FREE_SETUP_LIMIT: FREE_RECIPE_LIMIT,
    FREE_RECIPE_LIMIT: FREE_RECIPE_LIMIT,
    FREE_BATCH_LIMIT: FREE_BATCH_LIMIT,
    MAX_DETAILED_REPORT_ROWS: MAX_DETAILED_REPORT_ROWS,
    STARTER_TEMPLATE_VERSION: STARTER_TEMPLATE_VERSION,
    MONETIZATION_MODEL: MONETIZATION_MODEL,
    isStarterRecipe: isStarterRecipe,
    isStructuralStarter: isStarterRecipe,
    isStarterBatch: isStarterBatch,
    userRecipeCount: userRecipeCount,
    userSetupCount: userRecipeCount,
    userBatchCount: userBatchCount,
    usage: usage,
    canAdd: canAdd,
    starterTemplates: starterTemplates,
    temperatureToC: temperatureToC,
    formatTemperature: formatTemperature,
    formatPressure: formatPressure,
    outcomeMix: outcomeMix,
    sampleSeries: sampleSeries,
    temperaturePoints: temperaturePoints,
    recordedSetpointChanges: recordedSetpointChanges,
    velocitySeries: velocitySeries
  });
})(typeof globalThis !== "undefined" ? globalThis : this);

(function (root) {
  "use strict";

  const D = root.PressBenchDomain;
  const B = root.PressBenchBusiness;
  const ENTITLEMENT_SCHEMA_VERSION = 2;
  const OFFLINE_CONTINUITY_MS = 30 * 24 * 60 * 60 * 1000;
  const PLATFORMS = new Set(["none", "ios", "android"]);
  const PRODUCT_TYPES = new Set(["free", "non_consumable", "auto_renewable_subscription"]);
  const STATUSES = new Set(["free", "pending", "active", "expired", "refunded", "revoked", "unverified"]);
  const PURCHASE_STATES = new Set(["not_purchased", "pending", "purchased", "expired", "refunded", "revoked", "unverified"]);
  const STORES = new Set(["none", "app_store", "google_play"]);
  const NEGATIVE = new Set(["expired", "refunded", "revoked", "pending", "free", "unverified"]);
  const VERIFICATION_SOURCES = new Set(["none", "storekit2", "play_billing"]);
  const STORE_EVENT_ACTIONS = new Set(["automatic_refresh", "explicit_restore", "purchase"]);
  const ENTITLEMENT_TRUST_BOUNDARY = Object.freeze({
    authority: "native_store_adapter_only",
    ios: "StoreKit2_verified_current_entitlements_or_user_initiated_sync",
    android: "PlayBilling_PURCHASED_verified_and_acknowledged_non_consumable",
    rawCallerObjectsTrusted: false,
    portableBackupImportAllowed: false
  });

  function instant(value) {
    if (!value) return "";
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? "" : parsed.toISOString();
  }

  function normalizeEntitlement(value) {
    const source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    const platform = PLATFORMS.has(source.platform) ? source.platform : "none";
    const productType = PRODUCT_TYPES.has(source.productType) ? source.productType : "free";
    const status = STATUSES.has(source.status) ? source.status : "free";
    const clockFloor = instant(source.clockFloor);
    const verifiedAt = instant(source.verifiedAt);
    const expiresAt = instant(source.expiresAt);
    const legacyAcknowledged = source.schemaVersion !== ENTITLEMENT_SCHEMA_VERSION && platform === "android" &&
      status === "active" && source.storeVerified === true;
    let continuityUntil = instant(source.continuityUntil);
    if (!continuityUntil && verifiedAt && status === "active" && source.storeVerified === true) {
      continuityUntil = new Date(new Date(verifiedAt).getTime() + OFFLINE_CONTINUITY_MS).toISOString();
    }
    if (continuityUntil && verifiedAt) {
      const maximumContinuity = new Date(new Date(verifiedAt).getTime() + OFFLINE_CONTINUITY_MS).toISOString();
      if (new Date(continuityUntil).getTime() > new Date(maximumContinuity).getTime()) continuityUntil = maximumContinuity;
    }
    if (continuityUntil && expiresAt && new Date(continuityUntil).getTime() > new Date(expiresAt).getTime()) {
      continuityUntil = expiresAt;
    }
    return Object.freeze({
      schemaVersion: ENTITLEMENT_SCHEMA_VERSION,
      platform: platform,
      productType: productType,
      status: status,
      purchaseState: PURCHASE_STATES.has(source.purchaseState) ? source.purchaseState :
        status === "active" ? "purchased" : status === "pending" ? "pending" :
          status === "expired" ? "expired" : status === "refunded" ? "refunded" : status === "revoked" ? "revoked" :
            status === "unverified" ? "unverified" : "not_purchased",
      sourceStore: STORES.has(source.sourceStore) ? source.sourceStore : "none",
      productId: D.text(source.productId, 180),
      verificationSource: VERIFICATION_SOURCES.has(source.verificationSource) ? source.verificationSource : "none",
      storeVerified: source.storeVerified === true,
      verifiedAt: verifiedAt,
      acknowledged: source.acknowledged === true || legacyAcknowledged,
      acknowledgedAt: instant(source.acknowledgedAt),
      storeTransactionIdHash: D.text(source.storeTransactionIdHash, 100),
      terminalTransactionIdHash: D.text(source.terminalTransactionIdHash, 100),
      nativeVerificationIdHash: D.text(source.nativeVerificationIdHash, 100),
      storeEventAt: instant(source.storeEventAt),
      expiresAt: expiresAt,
      continuityUntil: continuityUntil,
      clockFloor: clockFloor
    });
  }

  function matchesCurrentProduct(entitlement) {
    const currentIos = entitlement.platform === "ios" && entitlement.sourceStore === "app_store" &&
      entitlement.productType === "auto_renewable_subscription" &&
      entitlement.productId === B.MONETIZATION_MODEL.ios.productId && entitlement.verificationSource === "storekit2";
    const legacyIos = entitlement.platform === "ios" && entitlement.sourceStore === "app_store" &&
      entitlement.productType === "non_consumable" &&
      B.MONETIZATION_MODEL.ios.legacyProductIds.includes(entitlement.productId) && entitlement.verificationSource === "storekit2";
    const currentAndroid = entitlement.productType === "non_consumable" &&
      entitlement.platform === "android" && entitlement.sourceStore === "google_play" &&
        entitlement.productId === B.MONETIZATION_MODEL.android.productId && entitlement.verificationSource === "play_billing";
    return currentIos || legacyIos || currentAndroid;
  }

  function evaluateEntitlement(value, at) {
    const entitlement = normalizeEntitlement(value);
    const requestedNow = new Date(at === undefined ? Date.now() : at);
    if (Number.isNaN(requestedNow.getTime())) throw new Error("entitlement_now");
    const floorMs = entitlement.clockFloor ? new Date(entitlement.clockFloor).getTime() : -Infinity;
    const now = new Date(Math.max(requestedNow.getTime(), floorMs));
    const evaluatedEntitlement = Object.freeze(Object.assign({}, entitlement, { clockFloor: now.toISOString() }));
    const verifiedMs = entitlement.verifiedAt ? new Date(entitlement.verifiedAt).getTime() : NaN;
    const trustedVerification = Number.isFinite(verifiedMs) && verifiedMs <= now.getTime();
    let paidAccess = false;
    let basis = "free";
    let requiresVerification = false;

    const exactProduct = matchesCurrentProduct(entitlement);
    const subscriptionCurrent = entitlement.productType !== "auto_renewable_subscription" ||
      Boolean(entitlement.expiresAt && new Date(entitlement.expiresAt).getTime() > now.getTime());
    const adapterProvenance = Boolean(entitlement.storeTransactionIdHash && entitlement.nativeVerificationIdHash && entitlement.storeEventAt);
    const androidAcknowledged = entitlement.platform !== "android" || entitlement.acknowledged === true;
    if (trustedVerification && adapterProvenance && exactProduct && subscriptionCurrent && androidAcknowledged && entitlement.storeVerified === true &&
        entitlement.status === "active" && !NEGATIVE.has(entitlement.status)) {
      paidAccess = true; basis = entitlement.platform === "ios" ? "ios_paid" : "android_paid";
    } else if (trustedVerification && adapterProvenance && exactProduct && subscriptionCurrent && androidAcknowledged && entitlement.storeVerified === true &&
        entitlement.status === "unverified" && entitlement.continuityUntil &&
        new Date(entitlement.continuityUntil).getTime() >= now.getTime()) {
      paidAccess = true; basis = entitlement.platform === "ios" ? "ios_cached_paid" : "android_cached_paid";
    }
    if ((entitlement.platform === "ios" || entitlement.platform === "android") && entitlement.status === "unverified") {
      requiresVerification = true;
    }
    return Object.freeze({ entitlement: evaluatedEntitlement, paidAccess: paidAccess, authorizationBasis: basis,
      requiresVerification: requiresVerification,
      verificationAction: requiresVerification ? entitlement.platform === "ios" ? "refresh_storekit_entitlements" : "query_play_purchases" : "none",
      requiresAcknowledgement: entitlement.platform === "android" && entitlement.purchaseState === "purchased" &&
        entitlement.acknowledged !== true,
      acknowledgementDeadlineAt: entitlement.platform === "android" && entitlement.purchaseState === "purchased" &&
        entitlement.acknowledged !== true && entitlement.verifiedAt ?
          new Date(new Date(entitlement.verifiedAt).getTime() + 3 * 24 * 60 * 60 * 1000).toISOString() : "",
      requestedAt: requestedNow.toISOString(), evaluatedAt: now.toISOString(),
      clockRollbackDetected: requestedNow.getTime() < now.getTime() });
  }

  function applyStoreEvent(currentValue, eventValue, at) {
    const current = normalizeEntitlement(currentValue);
    const event = eventValue && typeof eventValue === "object" && !Array.isArray(eventValue) ? eventValue : {};
    const action = STORE_EVENT_ACTIONS.has(event.action) ? event.action : "automatic_refresh";
    const platform = PLATFORMS.has(event.platform) ? event.platform : current.platform;
    if (platform !== "ios" && platform !== "android") throw new Error("store_platform");
    if (action === "explicit_restore" && event.userInitiated !== true) throw new Error("restore_requires_user_action");
    if (event.nativeAdapterVerified !== true) throw new Error("native_store_verification_required");
    const verificationSource = platform === "ios" ? "storekit2" : "play_billing";
    if (event.verificationSource && event.verificationSource !== verificationSource) throw new Error("store_verification_source");
    const sourceStore = platform === "ios" ? "app_store" : "google_play";
    const productId = D.text(event.productId, 180);
    const expectedProductId = platform === "ios" ? B.MONETIZATION_MODEL.ios.productId : B.MONETIZATION_MODEL.android.productId;
    const supportedProductIds = platform === "ios" ?
      [expectedProductId].concat(B.MONETIZATION_MODEL.ios.legacyProductIds) : [expectedProductId];
    const purchaseState = PURCHASE_STATES.has(event.purchaseState) ? event.purchaseState : "not_purchased";
    if (["purchased", "pending", "unverified", "expired", "refunded", "revoked"].includes(purchaseState) &&
        !supportedProductIds.includes(productId)) {
      throw new Error("store_product_mismatch");
    }
    const productType = platform === "ios" && productId === B.MONETIZATION_MODEL.ios.productId ?
      "auto_renewable_subscription" : "non_consumable";
    if (event.productType && event.productType !== productType) throw new Error("store_product_type");
    const now = instant(at === undefined ? Date.now() : at);
    if (!now) throw new Error("entitlement_now");
    const storeEventAt = instant(event.storeEventAt || now);
    if (!storeEventAt || new Date(storeEventAt).getTime() > new Date(now).getTime()) throw new Error("store_event_time");
    const nativeVerificationIdentity = D.text(event.nativeVerificationId, 500);
    if (!nativeVerificationIdentity) throw new Error("native_verification_identity");
    const nativeVerificationIdHash = `sha256:${D.sha256(nativeVerificationIdentity)}`;
    const transactionIdentity = D.text(event.transactionId || event.purchaseToken, 500);
    const transactionHash = transactionIdentity ? `sha256:${D.sha256(transactionIdentity)}` : "";
    const currentEventMs = current.storeEventAt ? new Date(current.storeEventAt).getTime() : -Infinity;
    const eventMs = new Date(storeEventAt).getTime();
    if (eventMs < currentEventMs) throw new Error("store_event_stale");
    const expiresAt = instant(event.expiresAt);
    if (productType === "auto_renewable_subscription" && purchaseState === "purchased" &&
        (!expiresAt || new Date(expiresAt).getTime() <= eventMs)) throw new Error("subscription_expiration");
    let continuityUntil = new Date(new Date(now).getTime() + OFFLINE_CONTINUITY_MS).toISOString();
    if (expiresAt && new Date(expiresAt).getTime() < new Date(continuityUntil).getTime()) continuityUntil = expiresAt;
    let next;
    if (purchaseState === "unverified") {
      if (current.platform !== platform || !matchesCurrentProduct(current) || !current.verifiedAt ||
          !current.storeTransactionIdHash || !current.nativeVerificationIdHash) {
        next = normalizeEntitlement({ platform: platform, status: "unverified", purchaseState: "unverified",
          sourceStore: sourceStore, productType: productType, productId: productId,
          verificationSource: verificationSource, nativeVerificationIdHash: nativeVerificationIdHash,
          storeEventAt: storeEventAt, expiresAt: expiresAt, clockFloor: now });
      } else {
        next = normalizeEntitlement(Object.assign({}, current, { status: "unverified", purchaseState: "unverified",
          nativeVerificationIdHash: nativeVerificationIdHash, storeEventAt: storeEventAt, clockFloor: now }));
      }
    } else if (purchaseState === "purchased") {
      if (!transactionIdentity) throw new Error("store_transaction_identity");
      if (current.terminalTransactionIdHash === transactionHash ||
          ["expired", "refunded", "revoked"].includes(current.purchaseState) && current.storeTransactionIdHash === transactionHash) {
        throw new Error("terminal_transaction_replay");
      }
      if (current.storeTransactionIdHash && current.storeTransactionIdHash !== transactionHash && eventMs <= currentEventMs) {
        throw new Error("store_event_stale");
      }
      const acknowledged = platform === "ios" || event.acknowledged === true;
      next = normalizeEntitlement({ platform: platform, productType: productType,
        status: acknowledged ? "active" : "pending", purchaseState: "purchased", sourceStore: sourceStore,
        productId: productId, verificationSource: verificationSource, storeVerified: true,
        verifiedAt: now, acknowledged: acknowledged, acknowledgedAt: acknowledged ? now : "",
        storeTransactionIdHash: transactionHash, terminalTransactionIdHash: current.terminalTransactionIdHash,
        nativeVerificationIdHash: nativeVerificationIdHash,
        storeEventAt: storeEventAt, expiresAt: expiresAt,
        continuityUntil: continuityUntil, clockFloor: now });
    } else if (purchaseState === "pending") {
      next = normalizeEntitlement({ platform: platform, productType: productType, status: "pending",
        purchaseState: "pending", sourceStore: sourceStore, productId: productId,
        verificationSource: verificationSource, storeVerified: true, verifiedAt: now,
        terminalTransactionIdHash: current.terminalTransactionIdHash,
        nativeVerificationIdHash: nativeVerificationIdHash, storeEventAt: storeEventAt,
        expiresAt: expiresAt, clockFloor: now });
    } else if (purchaseState === "expired" || purchaseState === "refunded" || purchaseState === "revoked") {
      if (!transactionHash) throw new Error("store_transaction_identity");
      if (current.storeTransactionIdHash && transactionHash !== current.storeTransactionIdHash) throw new Error("store_transaction_mismatch");
      const terminalBase = current.storeTransactionIdHash ? current : { productType: productType,
        storeTransactionIdHash: transactionHash, expiresAt: expiresAt };
      next = normalizeEntitlement(Object.assign({}, terminalBase, { platform: platform, status: purchaseState,
        purchaseState: purchaseState, sourceStore: sourceStore, productId: productId,
        verificationSource: verificationSource, storeVerified: true, verifiedAt: now,
        terminalTransactionIdHash: transactionHash,
        nativeVerificationIdHash: nativeVerificationIdHash, storeEventAt: storeEventAt,
        continuityUntil: "", clockFloor: now }));
    } else {
      next = normalizeEntitlement({ platform: platform, status: "free", purchaseState: "not_purchased",
        terminalTransactionIdHash: current.terminalTransactionIdHash,
        nativeVerificationIdHash: nativeVerificationIdHash, storeEventAt: storeEventAt, clockFloor: now });
    }
    const evaluation = evaluateEntitlement(next, now);
    return Object.freeze({ action: action, outcome: purchaseState, entitlement: next,
      paidAccess: evaluation.paidAccess, requiresAcknowledgement: evaluation.requiresAcknowledgement,
      requiresVerification: evaluation.requiresVerification, operationalRecordsRestored: false,
      consumptionAllowed: false,
      explanationCode: action === "explicit_restore" && purchaseState === "purchased" ? "purchase_restored_records_local_only" : "store_state_updated" });
  }

  function advanceClock(value, at) {
    return evaluateEntitlement(value, at).entitlement;
  }

  function capabilities(value, usage, at) {
    const evaluation = evaluateEntitlement(value, at);
    const counts = usage || {};
    const setupCount = Math.max(0, Number(counts.setups === undefined ? counts.recipes : counts.setups) || 0);
    const batchCount = Math.max(0, Number(counts.batches) || 0);
    return Object.freeze({
      evaluation: evaluation,
      canCreateSetup: setupCount < D.MAX_RECORDS,
      canReserveBatch: batchCount < B.FREE_BATCH_LIMIT || evaluation.paidAccess,
      canView: true,
      canSearch: true,
      canCorrect: true,
      canDelete: true,
      canCsv: false,
      canJsonBackup: false,
      canJsonRestore: false,
      existingRecordAccess: true,
      canPremiumReports: evaluation.paidAccess,
      canAdvancedAnalytics: evaluation.paidAccess
    });
  }

  root.PressBenchEntitlement = Object.freeze({
    ENTITLEMENT_SCHEMA_VERSION: ENTITLEMENT_SCHEMA_VERSION,
    OFFLINE_CONTINUITY_MS: OFFLINE_CONTINUITY_MS,
    ENTITLEMENT_TRUST_BOUNDARY: ENTITLEMENT_TRUST_BOUNDARY,
    PLATFORMS: PLATFORMS,
    PRODUCT_TYPES: PRODUCT_TYPES,
    STATUSES: STATUSES,
    PURCHASE_STATES: PURCHASE_STATES,
    STORES: STORES,
    VERIFICATION_SOURCES: VERIFICATION_SOURCES,
    normalizeEntitlement: normalizeEntitlement,
    evaluateEntitlement: evaluateEntitlement,
    applyStoreEvent: applyStoreEvent,
    advanceClock: advanceClock,
    capabilities: capabilities
  });
})(typeof globalThis !== "undefined" ? globalThis : this);

(function (root) {
  "use strict";

  const DB_NAME = "press-bench-log";
  const DB_VERSION = 2;
  const FALLBACK_KEY = "press-bench-log-compatible-v1";
  const INTERNAL_REPLACE_CAPABILITY = Object.freeze({});
  const BACKEND_KEY = "press-bench-log-storage-backend-v1";

  function requestResult(request) {
    return new Promise(function (resolve, reject) {
      request.onsuccess = function () { resolve(request.result); };
      request.onerror = function () { reject(request.error || new Error("storage_request")); };
    });
  }

  function transactionDone(transaction) {
    return new Promise(function (resolve, reject) {
      transaction.oncomplete = function () { resolve(); };
      transaction.onerror = function () { reject(transaction.error || new Error("storage_transaction")); };
      transaction.onabort = function () { reject(transaction.error || new Error("storage_abort")); };
    });
  }

  function openDatabase() {
    return new Promise(function (resolve, reject) {
      try {
        if (!root.indexedDB) return reject(new Error("indexeddb_unavailable"));
        let settled = false; let blockedTimer = null;
        const request = root.indexedDB.open(DB_NAME, DB_VERSION);
        request.onupgradeneeded = function () {
          const database = request.result;
          if (!database.objectStoreNames.contains("machines")) database.createObjectStore("machines", { keyPath: "id" });
          if (!database.objectStoreNames.contains("recipes")) database.createObjectStore("recipes", { keyPath: "id" });
          if (!database.objectStoreNames.contains("batches")) database.createObjectStore("batches", { keyPath: "id" });
          if (!database.objectStoreNames.contains("meta")) database.createObjectStore("meta", { keyPath: "key" });
        };
        request.onsuccess = function () {
          if (blockedTimer) clearTimeout(blockedTimer);
          if (settled) { request.result.close(); return; }
          settled = true; resolve(request.result);
        };
        request.onerror = function () { if (!settled) { settled = true; if (blockedTimer) clearTimeout(blockedTimer); reject(request.error || new Error("indexeddb_open")); } };
        request.onblocked = function () {
          if (!blockedTimer) blockedTimer = setTimeout(function () { if (!settled) { settled = true; reject(new Error("indexeddb_blocked")); } }, 5000);
        };
      } catch (error) { reject(error); }
    });
  }

  function withStorageLock(action) {
    const nodeRuntime = root.process && root.process.versions && root.process.versions.node;
    if (!nodeRuntime && root.navigator && root.navigator.locks && typeof root.navigator.locks.request === "function") {
      return root.navigator.locks.request(`${DB_NAME}-writer`, { mode: "exclusive" }, action);
    }
    return Promise.resolve().then(action);
  }

  function storageGraphErrors(domain, machines, setups, batches, session) {
    if (!domain || typeof domain.graphIntegrityErrors !== "function") return [];
    const errors = domain.graphIntegrityErrors(machines || [], setups || [], batches || []);
    const run = session && session.activeRun;
    if (!run) return errors;
    const machineById = new Map((machines || []).map(function (machine) { return [machine && machine.id, machine]; }).filter(function (entry) { return Boolean(entry[0]); }));
    const batchById = new Map((batches || []).map(function (batch) { return [batch.id, batch]; }));
    const snapshots = [run.setup, run.originalSetup, run.firstPressedSetup, run.lastPressedSetup].filter(Boolean);
    snapshots.forEach(function (setup, index) {
      const topMachine = machineById.get(setup.machineProfileId);
      if (setup.machineProfileId && (!topMachine || topMachine.archived === true)) errors.push(`session.setups.${index}.machineProfileId`);
      (setup.steps || []).forEach(function (step, stepIndex) {
        const stepMachine = step && machineById.get(step.machineProfileId);
        if (step && step.machineProfileId && (!stepMachine || stepMachine.archived === true)) errors.push(`session.setups.${index}.steps.${stepIndex}.machineProfileId`);
      });
      if (!domain.instructionReferenceValid(setup, batchById, run.startedAt, run.resultId)) {
        errors.push(`session.setups.${index}.instructionSource.priorBatchId`);
      }
    });
    if (run.sourceBatchId) {
      const sourceBatch = batchById.get(run.sourceBatchId);
      const sourceCompleted = sourceBatch && new Date(sourceBatch.completedAt).getTime();
      const runStarted = new Date(run.startedAt).getTime();
      if (!sourceBatch || sourceBatch.reviewStatus === "legacy_needs_review" || !Number.isFinite(sourceCompleted) ||
          !Number.isFinite(runStarted) || sourceCompleted > runStarted) errors.push("session.sourceBatchId");
    }
    return Array.from(new Set(errors));
  }

  function assertStorageGraph(domain, machines, setups, batches, session) {
    const errors = storageGraphErrors(domain, machines, setups, batches, session);
    if (!errors.length) return;
    if (errors.some(function (error) { return error.includes("machineProfileId"); })) throw new Error("machine_reference");
    if (errors.some(function (error) { return error.includes("instructionSource.priorBatchId"); })) throw new Error("instruction_reference");
    throw new Error("graph_integrity");
  }

  function storageRunIntentFingerprint(run, domain) {
    if (!run || !domain) return "";
    const permit = run.permit || {};
    const usage = permit.usageSnapshot || {};
    return `sha256:${domain.sha256(JSON.stringify([
      run.id, run.resultId, run.sourceSetupId || run.sourceRecipeId, run.sourceBatchId || "", run.runMode,
      run.quantity, run.utcOffsetMinutes, run.progressMode || "final_confirmation", run.jobReference || "", run.reservedAt, run.startedAt, domain.exactSetupFingerprint(run.originalSetup),
      run.originalOperationalFingerprint,
      permit.reservedAt, permit.authorizationBasis, permit.setupSlotReserved === true, permit.variantSlotReserved === true,
      permit.variantSetupId || "", permit.reservedBytes,
      usage.setups === undefined ? null : usage.setups,
      usage.batches === undefined ? null : usage.batches,
      usage.freeSetupLimit === undefined ? null : usage.freeSetupLimit,
      usage.freeBatchLimit === undefined ? null : usage.freeBatchLimit,
      usage.physicalLimit === undefined ? null : usage.physicalLimit,
      usage.migrated === true
    ]))}`;
  }

  function assertCanonicalStoredData(domain, machines, setups, batches, settings) {
    if (!domain) return;
    if ((machines || []).some(function (machine) { return !domain.validateV4MachineRaw(machine); })) throw new Error("machine_schema");
    if ((setups || []).some(function (setup) { return !domain.validateV4RecipeRaw(setup, false, setup && setup.status === "draft"); })) throw new Error("setup_schema");
    if ((batches || []).some(function (batch) { return !domain.validateV4BatchRaw(batch); })) throw new Error("batch_schema");
    if (settings) {
      const canonical = domain.normalizeSettings(settings);
      if (![2, 3, 4].includes(settings.settingsSchemaVersion) && JSON.stringify(canonical) !== JSON.stringify(settings)) {
        throw new Error("settings_schema");
      }
    }
  }

  function validateRunReservation(run, setups, batches, entitlement, now) {
    const domain = root.PressBenchDomain; const business = root.PressBenchBusiness; const access = root.PressBenchEntitlement;
    const permit = run && run.permit; const sourceSetupId = run && (run.sourceSetupId || run.sourceRecipeId);
    if (!domain || !business || !access || !run || !permit || permit.state !== "reserved" || !permit.id ||
        permit.runId !== run.id || permit.resultId !== run.resultId || permit.setupId !== sourceSetupId ||
        permit.setupFingerprint !== domain.exactSetupFingerprint(run.originalSetup) || permit.reservedAt !== run.reservedAt ||
        run.originalOperationalFingerprint !== domain.operationalFingerprintV4(run.originalSetup) ||
        !Number.isInteger(permit.reservedBytes) || permit.reservedBytes < domain.MAX_RECORD_BYTES ||
        permit.intentFingerprint !== storageRunIntentFingerprint(run, domain) || run.transitionSequence !== 0) throw new Error("run_permit_invalid");
    const legacyReservation = permit.authorizationBasis === "legacy_migration" && run.legacyGrandfathered === true;
    if (run.phase !== "preflight" || (!legacyReservation && (run.productionStarted === true || run.instructionCheckedAt))) throw new Error("run_reservation_state");
    const usage = { setups: business.userSetupCount(setups || []), batches: business.userBatchCount(batches || []) };
    if (!legacyReservation && (!permit.usageSnapshot || permit.usageSnapshot.setups !== usage.setups || permit.usageSnapshot.batches !== usage.batches)) {
      throw new Error("reservation_stale");
    }
    if (legacyReservation) {
      if (usage.batches >= domain.MAX_RECORDS) throw new Error("record_limit");
      return;
    }
    const setupExists = (setups || []).some(function (setup) { return setup.id === sourceSetupId; });
    if (permit.setupSlotReserved === true ? setupExists : !setupExists) throw new Error("reservation_stale");
    if (usage.batches >= domain.MAX_RECORDS || ((permit.setupSlotReserved || permit.variantSlotReserved) &&
        usage.setups >= domain.MAX_RECORDS)) throw new Error("record_limit");
    const evaluated = access.evaluateEntitlement(entitlement, now === undefined ? run.reservedAt : now);
    const requiresPaid = usage.batches >= business.FREE_BATCH_LIMIT;
    if (requiresPaid && !evaluated.paidAccess) throw new Error("batch_capacity_required");
    const expectedBasis = requiresPaid ? evaluated.authorizationBasis : "free";
    if (permit.authorizationBasis !== expectedBasis) throw new Error("run_permit_invalid");
  }

  function runSessionProgresses(current, next, domain) {
    if (!current || !next || !domain) return false;
    const previousSequence = Number(current.transitionSequence);
    const nextSequence = Number(next.transitionSequence);
    if (!Number.isInteger(previousSequence) || previousSequence < 0 || !Number.isInteger(nextSequence) ||
        nextSequence < previousSequence) return false;
    if (nextSequence === previousSequence) return JSON.stringify(next) === JSON.stringify(current);
    const previousEventAt = new Date(current.lastEventAt || current.startedAt).getTime();
    const nextEventAt = new Date(next.lastEventAt || next.startedAt).getTime();
    if (!Number.isFinite(previousEventAt) || !Number.isFinite(nextEventAt) || nextEventAt < previousEventAt) return false;
    if (current.productionStarted === true && next.productionStarted !== true) return false;
    if (current.productionStartedAt && next.productionStartedAt !== current.productionStartedAt) return false;
    if ((current.progressMode || "final_confirmation") !== (next.progressMode || "final_confirmation")) return false;
    if (current.firstPressedSetup && (!next.firstPressedSetup ||
        domain.exactSetupFingerprint(next.firstPressedSetup) !== domain.exactSetupFingerprint(current.firstPressedSetup))) return false;
    if (current.lastPressedSetup && (!next.lastPressedSetup || !next.lastPressedInstructionCheckedAt ||
        !next.lastPressedInstructionCheckFingerprint)) return false;
    if (current.lastPressedInstructionCheckedAt && new Date(next.lastPressedInstructionCheckedAt).getTime() <
        new Date(current.lastPressedInstructionCheckedAt).getTime()) return false;
    const previousFirst = current.firstPiece || {}; const nextFirst = next.firstPiece || {};
    if (Number(nextFirst.attempts || 0) < Number(previousFirst.attempts || 0)) return false;
    if (previousFirst.attemptedAt && nextFirst.attemptedAt !== previousFirst.attemptedAt) return false;
    const setupChanged = domain.exactSetupFingerprint(current.setup) !== domain.exactSetupFingerprint(next.setup);
    if (previousFirst.completedAt && !nextFirst.completedAt && !(setupChanged && next.phase === "preflight")) return false;
    if (previousFirst.completedAt && nextFirst.completedAt &&
        new Date(nextFirst.completedAt).getTime() < new Date(previousFirst.completedAt).getTime()) return false;
    if (previousFirst.outcome !== nextFirst.outcome && nextFirst.outcome === "pending" &&
        !(setupChanged && next.phase === "preflight")) return false;
    const previousQc = Array.isArray(current.qcChecks) ? current.qcChecks : [];
    const nextQc = Array.isArray(next.qcChecks) ? next.qcChecks : [];
    if (nextQc.length < previousQc.length || previousQc.some(function (entry, index) {
      return JSON.stringify(entry) !== JSON.stringify(nextQc[index]);
    })) return false;
    const previousInterruptions = Array.isArray(current.interruptions) ? current.interruptions : [];
    const nextInterruptions = Array.isArray(next.interruptions) ? next.interruptions : [];
    if (nextInterruptions.length < previousInterruptions.length || previousInterruptions.some(function (entry, index) {
      const candidate = nextInterruptions[index];
      if (!candidate || candidate.startedAt !== entry.startedAt || candidate.reason !== entry.reason ||
          candidate.productionBegan !== entry.productionBegan) return true;
      return entry.endedAt ? candidate.endedAt !== entry.endedAt : Boolean(candidate.endedAt) &&
        new Date(candidate.endedAt).getTime() < new Date(entry.startedAt).getTime();
    })) return false;
    if (current.legacyGrandfathered !== next.legacyGrandfathered || current.resumeResultPending !== next.resumeResultPending ||
        current.firstPiecePolicy !== next.firstPiecePolicy) return false;
    const previousCycles = Array.isArray(current.cycleEvents) ? current.cycleEvents : [];
    const nextCycles = Array.isArray(next.cycleEvents) ? next.cycleEvents : [];
    if (nextCycles.length < previousCycles.length || previousCycles.some(function (entry, index) {
      return JSON.stringify(entry) !== JSON.stringify(nextCycles[index]);
    })) return false;
    const processedDelta = Number(next.processedCount || 0) - Number(current.processedCount || 0);
    const grossDelta = Number(next.grossCompletedItems || 0) - Number(current.grossCompletedItems || 0);
    const undoneDelta = Number(next.undoneItems || 0) - Number(current.undoneItems || 0);
    const previousCredit = Number(current.firstPieceProcessedCredit || 0);
    const nextCredit = Number(next.firstPieceProcessedCredit || 0);
    if (nextCredit < previousCredit || grossDelta < 0 || undoneDelta < 0 ||
        processedDelta !== nextCredit - previousCredit + grossDelta - undoneDelta) return false;
    const appendedCycles = nextCycles.slice(previousCycles.length);
    if (grossDelta !== appendedCycles.filter(function (entry) { return entry.type === "complete"; })
      .reduce(function (sum, entry) { return sum + Number(entry.items || 0); }, 0) ||
        undoneDelta !== appendedCycles.filter(function (entry) { return entry.type === "undo"; })
          .reduce(function (sum, entry) { return sum + Number(entry.items || 0); }, 0)) return false;
    const previousDraft = current.resultDraft; const nextDraft = next.resultDraft;
    if (previousDraft && !nextDraft) return false;
    if (previousDraft && nextDraft && (nextDraft.revision < previousDraft.revision ||
        nextDraft.runId !== previousDraft.runId || nextDraft.resultId !== previousDraft.resultId ||
        nextDraft.completedAt !== previousDraft.completedAt ||
        nextDraft.revision === previousDraft.revision && JSON.stringify(nextDraft) !== JSON.stringify(previousDraft) ||
        nextDraft.revision > previousDraft.revision + 1 ||
        nextDraft.revision > previousDraft.revision && new Date(nextDraft.savedAt).getTime() <
          new Date(previousDraft.savedAt).getTime())) return false;
    const ranks = { preflight: 0, first_piece: 1, production_ready: 2, running: 3, paused: 3,
      result_pending: 4, committing: 5, completed: 6, aborted_before_start: 6 };
    if (["result_pending", "committing"].includes(current.phase) &&
        !(["result_pending", "committing", "completed"].includes(next.phase))) return false;
    const retryProgress = nextFirst.outcome === "adjust_retry" && Number(nextFirst.attempts || 0) > Number(previousFirst.attempts || 0);
    if ((ranks[next.phase] ?? -1) < (ranks[current.phase] ?? -1) &&
        !(current.phase === "committing" && next.phase === "result_pending") && !setupChanged && !retryProgress) return false;
    return true;
  }

  function sameRunReservation(current, next) {
    const left = current && current.permit; const right = next && next.permit;
    const process = root.PressBenchProcess;
    return Boolean(current && next && left && right && (!next.resultDraft || process && process.validResultDraft(next, next.resultDraft)) &&
      next.id === current.id && next.resultId === current.resultId &&
      right.id === left.id && right.runId === left.runId && right.resultId === left.resultId && right.setupId === left.setupId &&
      right.setupFingerprint === left.setupFingerprint && right.setupSlotReserved === left.setupSlotReserved &&
      right.variantSlotReserved === left.variantSlotReserved && right.variantSetupId === left.variantSetupId &&
      right.reservedAt === left.reservedAt &&
      right.authorizationBasis === left.authorizationBasis && right.reservedBytes === left.reservedBytes &&
      right.intentFingerprint === left.intentFingerprint && JSON.stringify(right.usageSnapshot) === JSON.stringify(left.usageSnapshot) &&
      right.state === "reserved" && right.intentFingerprint === storageRunIntentFingerprint(next, root.PressBenchDomain) &&
      runSessionProgresses(current, next, root.PressBenchDomain));
  }

  function sessionDraftsProgress(currentSession, nextSession) {
    const current = currentSession && currentSession.setupDraft;
    const next = nextSession && nextSession.setupDraft;
    const process = root.PressBenchProcess;
    if (next && (!process || typeof process.validSetupDraft !== "function" || !process.validSetupDraft(next))) return false;
    if (!current) return true;
    if (!next) {
      const clear = nextSession && nextSession.setupDraftClear;
      return Boolean(clear && clear.id === current.id && clear.revision === current.revision &&
        clear.fingerprint === `sha256:${root.PressBenchDomain.sha256(JSON.stringify([clear.id, clear.revision, clear.clearedAt]))}` &&
        new Date(clear.clearedAt).getTime() >= new Date(current.savedAt).getTime());
    }
    if (next.id !== current.id || next.revision < current.revision) return false;
    if (next.revision === current.revision) return JSON.stringify(next) === JSON.stringify(current);
    return next.revision === current.revision + 1 && new Date(next.savedAt).getTime() >= new Date(current.savedAt).getTime();
  }

  function sessionEnvelopeValid(session) {
    if (!session || session.schemaVersion !== 4 || !Object.prototype.hasOwnProperty.call(session, "activeRun") ||
        !Object.prototype.hasOwnProperty.call(session, "setupDraft") || typeof session.savedAt !== "string" ||
        Number.isNaN(new Date(session.savedAt).getTime())) return false;
    const process = root.PressBenchProcess;
    return !session.setupDraft || Boolean(process && typeof process.validSetupDraft === "function" &&
      process.validSetupDraft(session.setupDraft));
  }

  function assertMachineMutationCoverage(existingMachines, currentSetups, putMachines, putSetups, activeRun) {
    const process = root.PressBenchProcess; const domain = root.PressBenchDomain;
    if (!process || !domain) return;
    const existingById = new Map((existingMachines || []).map(function (machine) { return [machine.id, machine]; }));
    const putBySetupId = new Map((putSetups || []).map(function (setup) { return [setup.id, setup]; }));
    (putMachines || []).forEach(function (machine) {
      const before = existingById.get(machine.id); const classification = process.classifyMachineChange(before, machine);
      if (classification.changeClass !== "material") return;
      const runSetups = activeRun ? [activeRun.setup, activeRun.originalSetup, activeRun.firstPressedSetup, activeRun.lastPressedSetup].filter(Boolean) : [];
      if (runSetups.some(function (setup) { return setup.machineProfileId === machine.id || (setup.steps || []).some(function (step) {
        return step.machineProfileId === machine.id;
      }); })) throw new Error("active_run_conflict");
      (currentSetups || []).filter(function (setup) { return setup.machineProfileId === machine.id || (setup.steps || []).some(function (step) {
        return step.machineProfileId === machine.id;
      }); }).forEach(function (setup) {
        const replacement = putBySetupId.get(setup.id);
        const topLevelDependency = setup.machineProfileId === machine.id;
        const topSnapshot = replacement && replacement.machineProfile;
        const topSemanticMatches = !topLevelDependency || topSnapshot && ["brand", "model", "pressureMethod", "pressureScale", "platenOrZone"]
          .every(function (field) { return topSnapshot[field] === machine[field]; });
        const matchingSteps = replacement && (replacement.steps || []).filter(function (step) { return step.machineProfileId === machine.id; });
        const stepSnapshotsMatch = matchingSteps && matchingSteps.length && matchingSteps.every(function (step) {
          const oldStep = (setup.steps || []).find(function (candidate) { return candidate.id === step.id; });
          if (!oldStep || step.machineNickname !== machine.nickname) return false;
          return oldStep.platenZone === before.platenOrZone ? step.platenZone === machine.platenOrZone :
            step.platenZone === oldStep.platenZone;
        });
        const primarySnapshotPreserved = topLevelDependency || replacement &&
          JSON.stringify(replacement.machineProfile) === JSON.stringify(setup.machineProfile);
        if (!replacement || !topSemanticMatches || !stepSnapshotsMatch || !primarySnapshotPreserved ||
            replacement.status === "verified" || replacement.verifiedAt ||
            replacement.verifiedBatchId || Number(replacement.provenEvidenceCount || 0) !== 0 || !replacement.proofResetAt ||
            new Date(replacement.proofResetAt).getTime() < new Date(machine.updatedAt).getTime()) {
          throw new Error("machine_proof_reset_required");
        }
      });
    });
  }

  class LocalStore {
    constructor(database) { this.database = database; this.mode = "indexeddb"; this.closed = false; this.revision = null; }
    _transaction(stores, mode) {
      if (this.closed) throw new Error("storage_version_changed");
      return this.database.transaction(stores, mode);
    }
    async loadAll() {
      const transaction = this._transaction(["machines", "recipes", "batches", "meta"], "readonly");
      const machinesRequest = transaction.objectStore("machines").getAll();
      const recipesRequest = transaction.objectStore("recipes").getAll();
      const batchesRequest = transaction.objectStore("batches").getAll();
      const settingsRequest = transaction.objectStore("meta").get("settings");
      const sessionRequest = transaction.objectStore("meta").get("session");
      const revisionRequest = transaction.objectStore("meta").get("revision");
      const recoveryRequest = transaction.objectStore("meta").get("pre_restore_recovery");
      const lastRestoreRequest = transaction.objectStore("meta").get("last_restore");
      const result = await Promise.all([requestResult(machinesRequest), requestResult(recipesRequest), requestResult(batchesRequest),
        requestResult(settingsRequest), requestResult(sessionRequest), requestResult(revisionRequest),
        requestResult(recoveryRequest), requestResult(lastRestoreRequest), transactionDone(transaction)]);
      this.revision = result[5] && Number.isInteger(result[5].value) ? result[5].value : 0;
      const storedSettings = result[3] ? result[3].value : null;
      const settings = storedSettings && [2, 3, 4, 5].includes(storedSettings.settingsSchemaVersion) && root.PressBenchDomain
        ? root.PressBenchDomain.normalizeSettings(storedSettings) : storedSettings;
      return { machines: result[0] || [], setups: result[1] || [], recipes: result[1] || [], batches: result[2] || [],
        settings: settings, session: result[4] ? result[4].value : null,
        preRestoreRecovery: result[6] ? result[6].value : null, lastRestore: result[7] ? result[7].value : null };
    }
    async _commit(stores, mutator) {
      return withStorageLock(async () => {
        const names = ["machines", "recipes", "batches", "meta"];
        const transaction = this._transaction(names, "readwrite");
        const done = transactionDone(transaction);
        try {
          const revisionRecord = await requestResult(transaction.objectStore("meta").get("revision"));
          const currentRevision = revisionRecord && Number.isInteger(revisionRecord.value) ? revisionRecord.value : 0;
          if (this.revision === null) this.revision = currentRevision;
          if (currentRevision !== this.revision) throw new Error("storage_stale_write");
          await mutator(transaction);
          const machineValues = await requestResult(transaction.objectStore("machines").getAll());
          const recipeValues = await requestResult(transaction.objectStore("recipes").getAll());
          const batchValues = await requestResult(transaction.objectStore("batches").getAll());
          const settingsValue = await requestResult(transaction.objectStore("meta").get("settings"));
          const sessionValue = await requestResult(transaction.objectStore("meta").get("session"));
          const domain = root.PressBenchDomain;
          if (domain) {
            const records = machineValues.concat(recipeValues, batchValues);
            if (records.some(function (record) { return !domain.isBoundedJsonValue(record, 50, 1000000) ||
                domain.utf8ByteLength(JSON.stringify(record)) > domain.MAX_RECORD_BYTES; })) throw new Error("record_size");
            const payload = { machines: machineValues, recipes: recipeValues, batches: batchValues,
              settings: settingsValue ? settingsValue.value : null, session: sessionValue ? sessionValue.value : null };
            assertCanonicalStoredData(domain, machineValues, recipeValues, batchValues, settingsValue ? settingsValue.value : null);
            assertStorageGraph(domain, machineValues, recipeValues, batchValues, sessionValue ? sessionValue.value : null);
            if (!domain.isBoundedJsonValue(payload, 60, 1000000) ||
                domain.utf8ByteLength(JSON.stringify(payload)) > domain.MAX_DATA_BYTES) throw new Error("data_budget");
            const reservedRun = payload.session && payload.session.activeRun;
            if (reservedRun && reservedRun.permit && reservedRun.permit.state === "reserved" &&
                domain.utf8ByteLength(JSON.stringify(Object.assign({}, payload, { session: null }))) +
                  Number(reservedRun.permit.reservedBytes || 0) > domain.MAX_DATA_BYTES) throw new Error("byte_capacity_required");
          }
          const nextRevision = currentRevision + 1;
          transaction.objectStore("meta").put({ key: "revision", value: nextRevision });
          await done;
          this.revision = nextRevision;
        } catch (error) {
          try { transaction.abort(); } catch (_) {}
          try { await done; } catch (_) {}
          throw error;
        }
      });
    }
    async _putWithCapacity(transaction, storeName, record) {
      const domain = root.PressBenchDomain;
      if (domain && (!domain.isBoundedJsonValue(record, 50, 1000000) ||
          domain.utf8ByteLength(JSON.stringify(record)) > domain.MAX_RECORD_BYTES)) throw new Error("record_size");
      const objectStore = transaction.objectStore(storeName);
      const existing = await requestResult(objectStore.get(record.id));
      if (!existing) {
        const count = await requestResult(objectStore.count());
        const limit = root.PressBenchDomain && Number(root.PressBenchDomain.MAX_RECORDS) || 1000;
        if (count >= limit) throw new Error(`${storeName === "recipes" ? "recipe" : storeName === "batches" ? "batch" : "machine"}_limit`);
      }
      objectStore.put(record);
    }
    async _putManyWithCapacity(transaction, storeName, records) {
      const values = records || [];
      if (!values.length) return;
      const domain = root.PressBenchDomain;
      if (domain && values.some(function (record) { return !domain.isBoundedJsonValue(record, 50, 1000000) ||
          domain.utf8ByteLength(JSON.stringify(record)) > domain.MAX_RECORD_BYTES; })) throw new Error("record_size");
      const objectStore = transaction.objectStore(storeName);
      const count = await requestResult(objectStore.count());
      let additions = 0;
      for (const record of values) if (!await requestResult(objectStore.get(record.id))) additions += 1;
      const limit = root.PressBenchDomain && Number(root.PressBenchDomain.MAX_RECORDS) || 1000;
      if (count + additions > limit) throw new Error(`${storeName === "recipes" ? "recipe" : storeName === "batches" ? "batch" : "machine"}_limit`);
      values.forEach(function (record) { objectStore.put(record); });
    }
    async _reservedRun(transaction) {
      const record = await requestResult(transaction.objectStore("meta").get("session"));
      const run = record && record.value && record.value.activeRun;
      return run && run.permit && run.permit.state === "reserved" ? run : null;
    }
    async _guardStandaloneBatchWrite(transaction, batch) {
      const run = await this._reservedRun(transaction);
      if (!run) return;
      const existing = await requestResult(transaction.objectStore("batches").get(batch.id));
      if (!existing) throw new Error(batch.id === run.resultId ? "result_requires_graph_mutation" : "reserved_batch_slot");
    }
    async _guardStandaloneSetupWrite(transaction, setup) {
      const run = await this._reservedRun(transaction);
      if (!run || !run.permit.setupSlotReserved) return;
      const existing = await requestResult(transaction.objectStore("recipes").get(setup.id));
      if (!existing) throw new Error("reserved_setup_slot");
    }
    async saveMachine() { throw new Error("planner_required"); }
    async deleteMachine(id) { return this._commit(["machines","meta"],async t=>{const run=await this._reservedRun(t);if(run&&run.setup&&run.setup.machineProfileId===id)throw new Error("active_run_conflict");t.objectStore("machines").delete(id);}); }
    async saveRecipe() { throw new Error("planner_required"); }
    async saveSetup() { throw new Error("planner_required"); }
    async saveRecipeAndClearSession() { throw new Error("planner_required"); }
    async saveSetupAndClearSession() { throw new Error("planner_required"); }
    async deleteRecipe(id) { return this._commit(["recipes","meta"],async t=>{const run=await this._reservedRun(t);if(run&&(run.sourceSetupId||run.sourceRecipeId)===id)throw new Error("active_run_conflict");t.objectStore("recipes").delete(id);}); }
    async deleteSetup(id) { return this.deleteRecipe(id); }
    async saveBatch() { throw new Error("planner_required"); }
    async saveBatchAndRecipe() { throw new Error("planner_required"); }
    async saveBatchAndSetup() { throw new Error("planner_required"); }
    async saveDemo() { throw new Error("planner_required"); }
    async saveBatchWithRecipes() { throw new Error("planner_required"); }
    async deleteBatchWithRecipes() { throw new Error("planner_required"); }
    async applyGraphMutation(mutation) {
      const change = mutation || {}; const machines = change.putMachines || [], recipes = mergeRecords(change.putSetups, change.putRecipes), batches = change.putBatches || [];
      return this._commit(["machines", "recipes", "batches", "meta"], async t => {
        const machineStore = t.objectStore("machines"); const recipeStore = t.objectStore("recipes");
        const batchStore = t.objectStore("batches"); const metaStore = t.objectStore("meta");
        const sessionRecord = await requestResult(metaStore.get("session"));
        const activeRun = sessionRecord && sessionRecord.value && sessionRecord.value.activeRun;
        if (change.deleteAll === true) {
          if (change.deleteCapability !== INTERNAL_REPLACE_CAPABILITY) throw new Error("coordinated_delete_required");
          if (change.deleteConfirmation !== "DELETE") throw new Error("delete_confirmation");
          if (activeRun) throw new Error("active_run_conflict");
          machineStore.clear(); recipeStore.clear(); batchStore.clear();
          metaStore.put({ key: "settings", value: root.PressBenchDomain.defaultSettings() });
          metaStore.delete("session");
          metaStore.delete("pre_restore_recovery"); metaStore.delete("last_restore");
          return;
        }
        if (change.replaceAll) {
          const internalReplacement = change.internalCapability === INTERNAL_REPLACE_CAPABILITY;
          if (!internalReplacement && !change.verifiedRestore) throw new Error("verified_restore_required");
          if (change.verifiedRestore) {
            const recovery = await requestResult(metaStore.get("pre_restore_recovery"));
            if (!recovery || !recovery.value || recovery.value.id !== change.verifiedRestore.recoveryId ||
                recovery.value.state !== "prepared" ||
                recovery.value.sourceFingerprint !== change.verifiedRestore.sourceFingerprint) throw new Error("recovery_point_required");
            const current = await Promise.all([requestResult(machineStore.getAll()), requestResult(recipeStore.getAll()),
              requestResult(batchStore.getAll()), requestResult(metaStore.get("settings")), requestResult(metaStore.get("session"))]);
            const currentContext = { machines: current[0], setups: current[1], batches: current[2],
              settings: current[3] && current[3].value, session: current[4] && current[4].value };
            if (!root.PressBenchProcess || root.PressBenchProcess.operationalStateFingerprint(currentContext) !==
                change.verifiedRestore.sourceFingerprint) throw new Error("restore_stale");
            const targetHash = `sha256:${root.PressBenchDomain.sha256(JSON.stringify(change.replaceAll))}`;
            if (targetHash !== change.verifiedRestore.targetHash) throw new Error("restore_target_mismatch");
          }
          if (activeRun && activeRun.permit && activeRun.permit.state === "reserved") throw new Error("active_run_conflict");
          const replacement = change.replaceAll; const replacementMachines = replacement.machines || [];
          const replacementRecipes = replacement.setups || replacement.recipes || []; const replacementBatches = replacement.batches || [];
          const replacementSession = replacement.session || null;
          if (replacementSession && replacementSession.activeRun && replacementSession.activeRun.permit &&
              replacementSession.activeRun.permit.state === "reserved") throw new Error("run_reservation_required");
          const limit = root.PressBenchDomain && root.PressBenchDomain.MAX_RECORDS || 1000;
          if (replacementMachines.length > limit || replacementRecipes.length > limit || replacementBatches.length > limit) throw new Error("record_limit");
          machineStore.clear(); recipeStore.clear(); batchStore.clear();
          replacementMachines.forEach(function (machine) { machineStore.put(machine); });
          replacementRecipes.forEach(function (recipe) { recipeStore.put(recipe); });
          replacementBatches.forEach(function (batch) { batchStore.put(batch); });
          metaStore.put({ key: "settings", value: replacement.settings });
          if (replacementSession) metaStore.put({ key: "session", value: replacementSession }); else metaStore.delete("session");
          if (change.verifiedRestore) {
            const appliedAt = new Date().toISOString();
            const recovery = await requestResult(metaStore.get("pre_restore_recovery"));
            metaStore.put({ key: "pre_restore_recovery", value: Object.assign({}, recovery.value,
              { state: "applied", appliedAt: appliedAt, targetHash: change.verifiedRestore.targetHash }) });
            metaStore.put({ key: "last_restore", value: Object.assign({}, change.verifiedRestore, { appliedAt: appliedAt }) });
          }
          return;
        }
        const existingMachines = await requestResult(machineStore.getAll());
        const existingRecipes = await requestResult(recipeStore.getAll());
        assertMachineMutationCoverage(existingMachines, existingRecipes, machines, recipes, activeRun);
        let commitsReservedResult = false; let releasesReservedPermit = false;
        if (activeRun && activeRun.permit && activeRun.permit.state === "reserved") {
          const deletedSetupIds = mergeIds(change.deleteSetupIds, change.deleteRecipeIds);
          if (deletedSetupIds.includes(activeRun.sourceSetupId || activeRun.sourceRecipeId) ||
              (change.deleteMachineIds || []).includes(activeRun.setup && activeRun.setup.machineProfileId)) throw new Error("active_run_conflict");
          const reservedBatch = batches.find(function (batch) { return batch.id === activeRun.resultId; });
          commitsReservedResult = Boolean(reservedBatch);
          releasesReservedPermit = change.releasePermitId === activeRun.permit.id && !activeRun.productionStarted;
          const batchAdditions = [];
          for (const candidate of batches) if (!await requestResult(batchStore.get(candidate.id))) batchAdditions.push(candidate);
          if (batchAdditions.length && (!commitsReservedResult || batchAdditions.length !== 1 || batchAdditions[0].id !== activeRun.resultId)) {
            throw new Error("reserved_batch_slot");
          }
          const additions = [];
          for (const recipe of recipes) if (!await requestResult(recipeStore.get(recipe.id))) additions.push(recipe);
          if (activeRun.permit.setupSlotReserved === true || activeRun.permit.variantSlotReserved === true) {
            const reservedSetupId = activeRun.permit.setupSlotReserved ? activeRun.permit.setupId : activeRun.permit.variantSetupId;
            const reservedSetup = additions.find(function (recipe) { return recipe.id === reservedSetupId; });
            const existingReservedSetup = await requestResult(recipeStore.get(reservedSetupId));
            if (additions.length && (!commitsReservedResult || additions.length !== 1 || !reservedSetup)) throw new Error("reserved_setup_slot");
            if (commitsReservedResult && activeRun.permit.setupSlotReserved && !reservedSetup && (!existingReservedSetup ||
                root.PressBenchDomain.exactSetupFingerprint(existingReservedSetup) !== activeRun.permit.setupFingerprint)) {
              throw new Error("reserved_setup_required");
            }
          } else if (additions.length) throw new Error("reserved_setup_slot");
          if (commitsReservedResult) {
            const domain = root.PressBenchDomain;
            const process = root.PressBenchProcess; const proof = change.commitProof;
            if (!change.clearSession || !domain || reservedBatch.startedAt !== activeRun.startedAt ||
                reservedBatch.exactSetupFingerprint !== domain.exactSetupFingerprint(activeRun.setup) ||
                reservedBatch.instructionCheckFingerprint !== activeRun.instructionCheckFingerprint ||
                change.consumePermitId !== activeRun.permit.id || !process || !process.validResultDraft(activeRun, activeRun.resultDraft) ||
                !process.batchMatchesResultDraft(reservedBatch, activeRun.resultDraft) || !proof ||
                proof.permitId !== activeRun.permit.id || proof.runId !== activeRun.id || proof.resultId !== activeRun.resultId ||
                proof.draftRevision !== activeRun.resultDraft.revision ||
                proof.resultDraftFingerprint !== activeRun.resultDraft.contentFingerprint) throw new Error("reserved_result_mismatch");
          }
          if (!commitsReservedResult && !releasesReservedPermit && change.clearSession) throw new Error("reserved_permit_clear");
        }
        (change.deleteMachineIds || []).forEach(function (id) { t.objectStore("machines").delete(id); });
        mergeIds(change.deleteSetupIds, change.deleteRecipeIds).forEach(function (id) { t.objectStore("recipes").delete(id); });
        (change.deleteBatchIds || []).forEach(function (id) { t.objectStore("batches").delete(id); });
        await this._putManyWithCapacity(t, "machines", machines);
        await this._putManyWithCapacity(t, "recipes", recipes);
        await this._putManyWithCapacity(t, "batches", batches);
        if (change.clearSession) t.objectStore("meta").delete("session");
      });
    }
    async deleteBatch(id) { return this._commit("batches",t=>{t.objectStore("batches").delete(id);}); }
    async saveSettings(settings) { const normalized=root.PressBenchDomain.normalizeSettings(settings);return this._commit("meta",t=>{t.objectStore("meta").put({key:"settings",value:normalized});}); }
    async reserveRun(session, entitlement, now) { const saved=deepCopy(session);await this._commit(["recipes","batches","meta"],async t=>{if(!sessionEnvelopeValid(saved))throw new Error("session_schema");if(await this._reservedRun(t))throw new Error("active_run_conflict");const setups=await requestResult(t.objectStore("recipes").getAll());const batches=await requestResult(t.objectStore("batches").getAll());validateRunReservation(saved&&saved.activeRun,setups,batches,entitlement,now);t.objectStore("meta").put({key:"session",value:saved});});return saved; }
    async saveSession(session) { return this._commit("meta",async t=>{const record=await requestResult(t.objectStore("meta").get("session"));const currentSession=record&&record.value;const current=currentSession&&currentSession.activeRun;const next=session&&session.activeRun;if(session&&!sessionEnvelopeValid(session))throw new Error("session_schema");if(!sessionDraftsProgress(currentSession,session))throw new Error("setup_draft_stale");if(!current&&next)throw new Error("run_reservation_required");if(current&&!sameRunReservation(current,next))throw new Error(session?"active_run_conflict":"reserved_permit_clear");if(session)t.objectStore("meta").put({key:"session",value:session});else t.objectStore("meta").delete("session");}); }
    async _replaceAll(recipes,batches,settings,session,machines,capability) {
      if (capability !== INTERNAL_REPLACE_CAPABILITY) throw new Error("internal_capability_required");
      return this.applyGraphMutation({internalCapability:INTERNAL_REPLACE_CAPABILITY,replaceAll:{machines:machines||[],setups:recipes||[],batches:batches||[],settings:settings,session:session||null}});
    }
    async applyRestorePlan(plan) {
      const prepared = plan && plan.recoveryEnvelope; const receipt = plan && plan.restoreReceipt; const target = plan && plan.target;
      const domain = root.PressBenchDomain;
      if (!prepared || prepared.state !== "prepared" || !receipt || receipt.recoveryId !== prepared.id || !target ||
          prepared.sourceFingerprint !== receipt.sourceFingerprint ||
          prepared.payloadHash !== `sha256:${domain.sha256(JSON.stringify(prepared.payload))}` ||
          receipt.targetHash !== `sha256:${domain.sha256(JSON.stringify(target))}`) throw new Error("restore_plan");
      const before = await this.loadAll();
      if (before.lastRestore && before.lastRestore.recoveryId === receipt.recoveryId &&
          before.lastRestore.targetHash === receipt.targetHash) {
        const currentTarget = { machines: before.machines || [], setups: before.setups || before.recipes || [],
          batches: before.batches || [], settings: before.settings, session: before.session || null };
        if (`sha256:${domain.sha256(JSON.stringify(currentTarget))}` !== receipt.targetHash) throw new Error("restore_state_drift");
        return { alreadyApplied: true };
      }
      await this._commit(["meta"], async t => {
        const loaded = await Promise.all([requestResult(t.objectStore("machines").getAll()), requestResult(t.objectStore("recipes").getAll()),
          requestResult(t.objectStore("batches").getAll()), requestResult(t.objectStore("meta").get("settings")), requestResult(t.objectStore("meta").get("session"))]);
        const context = { machines: loaded[0], setups: loaded[1], batches: loaded[2], settings: loaded[3] && loaded[3].value,
          session: loaded[4] && loaded[4].value };
        if (root.PressBenchProcess.operationalStateFingerprint(context) !== receipt.sourceFingerprint) throw new Error("restore_stale");
        t.objectStore("meta").put({ key: "pre_restore_recovery", value: prepared });
      });
      const check = await this._commit(["meta"], async t => {
        const saved = await requestResult(t.objectStore("meta").get("pre_restore_recovery"));
        if (!saved || saved.value.payloadHash !== prepared.payloadHash || JSON.stringify(saved.value) !== JSON.stringify(prepared)) throw new Error("recovery_point_verify");
      });
      await this.applyGraphMutation({ replaceAll: target, verifiedRestore: receipt });
      return Object.assign({ applied: true }, check || {});
    }
    async replaceAll() { throw new Error("planner_required"); }
    async clearAll() { throw new Error("planner_required"); }
  }

  function emptyData() { return { machines: [], recipes: [], batches: [], settings: null, session: null }; }
  function deepCopy(value) {
    if (value == null) return value;
    if (root.PressBenchDomain && !root.PressBenchDomain.isBoundedJsonValue(value, 40, 1000000)) throw new Error("storage_corrupt");
    if (typeof root.structuredClone === "function") return root.structuredClone(value);
    return JSON.parse(JSON.stringify(value));
  }

  function normalizeFallbackData(data) {
    if (!data || typeof data !== "object" || Array.isArray(data)) throw new Error("storage_corrupt");
    return { machines: Array.isArray(data.machines) ? data.machines : [], recipes: Array.isArray(data.recipes) ? data.recipes : [],
      batches: Array.isArray(data.batches) ? data.batches : [], settings: data.settings || null, session: data.session || null,
      preRestoreRecovery: data.preRestoreRecovery || null, lastRestore: data.lastRestore || null };
  }

  function readStorageReplica(storage) {
    if (!storage) return null;
    const raw = storage.getItem(FALLBACK_KEY);
    if (!raw) return null;
    let parsed;
    try { parsed = JSON.parse(raw); } catch (_) { throw new Error("storage_corrupt"); }
    if (parsed && parsed.format === 2 && parsed.data) {
      return { format: 2, revision: Number(parsed.revision) || 0, savedAt: Number(parsed.savedAt) || 0, data: normalizeFallbackData(parsed.data) };
    }
    return { format: 2, revision: 0, savedAt: 0, data: normalizeFallbackData(parsed) };
  }

  function writeStorageReplica(storage, envelope) {
    if (!storage) return false;
    const serialized = JSON.stringify(envelope);
    storage.setItem(FALLBACK_KEY, serialized);
    return storage.getItem(FALLBACK_KEY) === serialized;
  }

  function fallbackInitialEnvelope() {
    const replicas = []; const corruptions = [];
    ["localStorage", "sessionStorage"].forEach(function (name) {
      try { const replica = readStorageReplica(root[name]); if (replica) replicas.push(replica); }
      catch (error) { corruptions.push(name); }
    });
    if (!replicas.length && corruptions.length) throw new Error("storage_corrupt");
    replicas.sort(function (left, right) { return right.revision - left.revision || right.savedAt - left.savedAt; });
    if (replicas.length > 1 && replicas[0].revision === replicas[1].revision &&
        JSON.stringify(replicas[0].data) !== JSON.stringify(replicas[1].data)) {
      throw new Error("storage_replica_conflict");
    }
    return replicas[0] || { format: 2, revision: 0, savedAt: 0, data: emptyData() };
  }

  function upsert(records, value) {
    const index = records.findIndex(function (item) { return item.id === value.id; });
    if (index >= 0) records[index] = deepCopy(value); else records.push(deepCopy(value));
  }

  function mergeRecords(primary, legacy) {
    const byId = new Map();
    (legacy || []).concat(primary || []).forEach(function (record) { if (record && record.id) byId.set(record.id, record); });
    return Array.from(byId.values());
  }

  function mergeIds(primary, legacy) {
    return Array.from(new Set((legacy || []).concat(primary || [])));
  }

  class CompatibleStore {
    constructor() {
      this.envelope = fallbackInitialEnvelope(); this.data = deepCopy(this.envelope.data); this.mode = "compatible";
    }
    _commit(mutator) {
      const latest = fallbackInitialEnvelope();
      if (latest.revision !== this.envelope.revision) throw new Error("storage_stale_write");
      const nextData = deepCopy(this.data); mutator(nextData);
      const limit = root.PressBenchDomain && Number(root.PressBenchDomain.MAX_RECORDS) || 1000;
      if ((nextData.machines || []).length > limit || (nextData.recipes || []).length > limit || (nextData.batches || []).length > limit) throw new Error("record_limit");
      if (root.PressBenchDomain) {
        const domain = root.PressBenchDomain;
        const records = (nextData.machines || []).concat(nextData.recipes || [], nextData.batches || []);
        if (records.some(function (record) { return !domain.isBoundedJsonValue(record, 50, 1000000) ||
            domain.utf8ByteLength(JSON.stringify(record)) > domain.MAX_RECORD_BYTES; })) throw new Error("record_size");
        assertCanonicalStoredData(domain, nextData.machines || [], nextData.recipes || [], nextData.batches || [], nextData.settings);
        assertStorageGraph(domain, nextData.machines || [], nextData.recipes || [], nextData.batches || [], nextData.session);
        const operationalPayload = Object.assign({}, nextData, { preRestoreRecovery: null, lastRestore: null });
        if (domain.utf8ByteLength(JSON.stringify(operationalPayload)) > 2_000_000) throw new Error("data_budget");
        if (domain.utf8ByteLength(JSON.stringify(nextData)) > 4_500_000) throw new Error("recovery_budget");
        const reservedRun = nextData.session && nextData.session.activeRun;
        if (reservedRun && reservedRun.permit && reservedRun.permit.state === "reserved" &&
            domain.utf8ByteLength(JSON.stringify(Object.assign({}, operationalPayload, { session: null }))) +
              Number(reservedRun.permit.reservedBytes || 0) > 2_000_000) throw new Error("byte_capacity_required");
      }
      const next = { format: 2, revision: this.envelope.revision + 1, savedAt: Date.now(), data: nextData };
      let durable = false;
      try { durable = writeStorageReplica(root.localStorage, next); } catch (_) {}
      if (!durable) throw new Error("storage_write_failed");
      try { writeStorageReplica(root.sessionStorage, next); } catch (_) {}
      this.envelope = next; this.data = nextData;
    }
    async loadAll() { const result=deepCopy(this.data);result.setups=result.recipes;
      if (result.settings && [2, 3, 4, 5].includes(result.settings.settingsSchemaVersion) && root.PressBenchDomain) {
        result.settings = root.PressBenchDomain.normalizeSettings(result.settings);
      }
      return result; }
    _reservedRun(data) {
      const run = data.session && data.session.activeRun;
      return run && run.permit && run.permit.state === "reserved" ? run : null;
    }
    _guardStandaloneBatchWrite(data, batch) {
      const run = this._reservedRun(data);
      if (!run || data.batches.some(function (item) { return item.id === batch.id; })) return;
      throw new Error(batch.id === run.resultId ? "result_requires_graph_mutation" : "reserved_batch_slot");
    }
    _guardStandaloneSetupWrite(data, setup) {
      const run = this._reservedRun(data);
      if (!run || !run.permit.setupSlotReserved || data.recipes.some(function (item) { return item.id === setup.id; })) return;
      throw new Error("reserved_setup_slot");
    }
    async saveMachine() { throw new Error("planner_required"); }
    async deleteMachine(id) { return withStorageLock(()=>this._commit(data=>{const run=this._reservedRun(data);if(run&&run.setup&&run.setup.machineProfileId===id)throw new Error("active_run_conflict");data.machines=data.machines.filter(x=>x.id!==id);})); }
    async saveRecipe() { throw new Error("planner_required"); }
    async saveSetup() { throw new Error("planner_required"); }
    async saveRecipeAndClearSession() { throw new Error("planner_required"); }
    async saveSetupAndClearSession() { throw new Error("planner_required"); }
    async deleteRecipe(id) { return withStorageLock(()=>this._commit(data=>{const run=this._reservedRun(data);if(run&&(run.sourceSetupId||run.sourceRecipeId)===id)throw new Error("active_run_conflict");data.recipes=data.recipes.filter(x=>x.id!==id);})); }
    async deleteSetup(id) { return this.deleteRecipe(id); }
    async saveBatch() { throw new Error("planner_required"); }
    async saveBatchAndRecipe() { throw new Error("planner_required"); }
    async saveBatchAndSetup() { throw new Error("planner_required"); }
    async saveDemo() { throw new Error("planner_required"); }
    async saveBatchWithRecipes() { throw new Error("planner_required"); }
    async deleteBatchWithRecipes() { throw new Error("planner_required"); }
    async applyGraphMutation(mutation) {
      const change = mutation || {};
      return withStorageLock(()=>this._commit(data=>{
        const activeRun = data.session && data.session.activeRun;
        if (change.deleteAll === true) {
          if (change.deleteCapability !== INTERNAL_REPLACE_CAPABILITY) throw new Error("coordinated_delete_required");
          if (change.deleteConfirmation !== "DELETE") throw new Error("delete_confirmation");
          if (activeRun) throw new Error("active_run_conflict");
          data.machines = []; data.recipes = []; data.batches = [];
          data.settings = deepCopy(root.PressBenchDomain.defaultSettings()); data.session = null;
          data.preRestoreRecovery = null; data.lastRestore = null;
          return;
        }
        if (change.replaceAll) {
          const internalReplacement = change.internalCapability === INTERNAL_REPLACE_CAPABILITY;
          if (!internalReplacement && !change.verifiedRestore) throw new Error("verified_restore_required");
          if (change.verifiedRestore && (!data.preRestoreRecovery || data.preRestoreRecovery.id !== change.verifiedRestore.recoveryId ||
              data.preRestoreRecovery.state !== "prepared" ||
              data.preRestoreRecovery.sourceFingerprint !== change.verifiedRestore.sourceFingerprint)) throw new Error("recovery_point_required");
          if (change.verifiedRestore && root.PressBenchProcess.operationalStateFingerprint(data) !==
              change.verifiedRestore.sourceFingerprint) throw new Error("restore_stale");
          if (change.verifiedRestore && `sha256:${root.PressBenchDomain.sha256(JSON.stringify(change.replaceAll))}` !==
              change.verifiedRestore.targetHash) throw new Error("restore_target_mismatch");
          if (activeRun && activeRun.permit && activeRun.permit.state === "reserved") throw new Error("active_run_conflict");
          const replacement = change.replaceAll; const replacementSession = replacement.session || null;
          if (replacementSession && replacementSession.activeRun && replacementSession.activeRun.permit &&
              replacementSession.activeRun.permit.state === "reserved") throw new Error("run_reservation_required");
          data.machines = deepCopy(replacement.machines || []);
          data.recipes = deepCopy(replacement.setups || replacement.recipes || []);
          data.batches = deepCopy(replacement.batches || []);
          data.settings = deepCopy(replacement.settings); data.session = deepCopy(replacementSession);
          if (change.verifiedRestore) {
            const appliedAt = new Date().toISOString();
            data.preRestoreRecovery = Object.assign({}, data.preRestoreRecovery, { state: "applied", appliedAt: appliedAt,
              targetHash: change.verifiedRestore.targetHash });
            data.lastRestore = Object.assign({}, change.verifiedRestore, { appliedAt: appliedAt });
          }
          return;
        }
        const deletedMachineIds = new Set(change.deleteMachineIds || []);
        const deletedRecipeIds = new Set(mergeIds(change.deleteSetupIds, change.deleteRecipeIds)); const deletedBatchIds = new Set(change.deleteBatchIds || []);
        assertMachineMutationCoverage(data.machines, data.recipes, change.putMachines || [],
          mergeRecords(change.putSetups, change.putRecipes), activeRun);
        if (activeRun && activeRun.permit && activeRun.permit.state === "reserved") {
          if (deletedRecipeIds.has(activeRun.sourceSetupId || activeRun.sourceRecipeId) ||
              deletedMachineIds.has(activeRun.setup && activeRun.setup.machineProfileId)) throw new Error("active_run_conflict");
          const reservedBatch = (change.putBatches || []).find(function (batch) { return batch.id === activeRun.resultId; });
          const commitsReservedResult = Boolean(reservedBatch);
          const releasesReservedPermit = change.releasePermitId === activeRun.permit.id && !activeRun.productionStarted;
          const batchAdditions = (change.putBatches || []).filter(function (batch) {
            return !data.batches.some(function (existing) { return existing.id === batch.id; });
          });
          if (batchAdditions.length && (!commitsReservedResult || batchAdditions.length !== 1 || batchAdditions[0].id !== activeRun.resultId)) {
            throw new Error("reserved_batch_slot");
          }
          const additions = mergeRecords(change.putSetups, change.putRecipes).filter(function (recipe) {
            return !data.recipes.some(function (existing) { return existing.id === recipe.id; });
          });
          if (activeRun.permit.setupSlotReserved === true || activeRun.permit.variantSlotReserved === true) {
            const reservedSetupId = activeRun.permit.setupSlotReserved ? activeRun.permit.setupId : activeRun.permit.variantSetupId;
            const reservedSetup = additions.find(function (recipe) { return recipe.id === reservedSetupId; });
            const existingReservedSetup = data.recipes.find(function (recipe) { return recipe.id === reservedSetupId; });
            if (additions.length && (!commitsReservedResult || additions.length !== 1 || !reservedSetup)) throw new Error("reserved_setup_slot");
            if (commitsReservedResult && activeRun.permit.setupSlotReserved && !reservedSetup && (!existingReservedSetup ||
                root.PressBenchDomain.exactSetupFingerprint(existingReservedSetup) !== activeRun.permit.setupFingerprint)) {
              throw new Error("reserved_setup_required");
            }
          } else if (additions.length) throw new Error("reserved_setup_slot");
          if (commitsReservedResult) {
            const domain = root.PressBenchDomain;
            const process = root.PressBenchProcess; const proof = change.commitProof;
            if (!change.clearSession || !domain || reservedBatch.startedAt !== activeRun.startedAt ||
                reservedBatch.exactSetupFingerprint !== domain.exactSetupFingerprint(activeRun.setup) ||
                reservedBatch.instructionCheckFingerprint !== activeRun.instructionCheckFingerprint ||
                change.consumePermitId !== activeRun.permit.id || !process || !process.validResultDraft(activeRun, activeRun.resultDraft) ||
                !process.batchMatchesResultDraft(reservedBatch, activeRun.resultDraft) || !proof ||
                proof.permitId !== activeRun.permit.id || proof.runId !== activeRun.id || proof.resultId !== activeRun.resultId ||
                proof.draftRevision !== activeRun.resultDraft.revision ||
                proof.resultDraftFingerprint !== activeRun.resultDraft.contentFingerprint) throw new Error("reserved_result_mismatch");
          }
          if (!commitsReservedResult && !releasesReservedPermit && change.clearSession) throw new Error("reserved_permit_clear");
        }
        data.machines = data.machines.filter(function (machine) { return !deletedMachineIds.has(machine.id); });
        data.recipes = data.recipes.filter(function (recipe) { return !deletedRecipeIds.has(recipe.id); });
        data.batches = data.batches.filter(function (batch) { return !deletedBatchIds.has(batch.id); });
        (change.putMachines || []).forEach(function (machine) { upsert(data.machines, machine); });
        mergeRecords(change.putSetups, change.putRecipes).forEach(function (recipe) { upsert(data.recipes, recipe); });
        (change.putBatches || []).forEach(function (batch) { upsert(data.batches, batch); });
        const limit = root.PressBenchDomain && Number(root.PressBenchDomain.MAX_RECORDS) || 1000;
        if (data.machines.length > limit) throw new Error("machine_limit");
        if (data.recipes.length > limit) throw new Error("recipe_limit");
        if (data.batches.length > limit) throw new Error("batch_limit");
        if (change.clearSession) data.session = null;
      }));
    }
    async deleteBatch(id) { return withStorageLock(()=>this._commit(data=>{data.batches=data.batches.filter(x=>x.id!==id);})); }
    async saveSettings(settings) { const normalized=root.PressBenchDomain.normalizeSettings(settings);return withStorageLock(()=>this._commit(data=>{data.settings=deepCopy(normalized);})); }
    async reserveRun(session, entitlement, now) { const saved=deepCopy(session);await withStorageLock(()=>this._commit(data=>{if(!sessionEnvelopeValid(saved))throw new Error("session_schema");if(this._reservedRun(data))throw new Error("active_run_conflict");validateRunReservation(saved&&saved.activeRun,data.recipes,data.batches,entitlement,now);data.session=saved;}));return saved; }
    async saveSession(session) { return withStorageLock(()=>this._commit(data=>{const currentSession=data.session;const current=this._reservedRun(data);const next=session&&session.activeRun;if(session&&!sessionEnvelopeValid(session))throw new Error("session_schema");if(!sessionDraftsProgress(currentSession,session))throw new Error("setup_draft_stale");if(!current&&next)throw new Error("run_reservation_required");if(current&&!sameRunReservation(current,next))throw new Error(session?"active_run_conflict":"reserved_permit_clear");data.session=deepCopy(session);})); }
    async _replaceAll(recipes,batches,settings,session,machines,capability) {
      if (capability !== INTERNAL_REPLACE_CAPABILITY) throw new Error("internal_capability_required");
      return this.applyGraphMutation({internalCapability:INTERNAL_REPLACE_CAPABILITY,replaceAll:{machines:machines||[],setups:recipes||[],batches:batches||[],settings:settings,session:session||null}});
    }
    async applyRestorePlan(plan) {
      const prepared = plan && plan.recoveryEnvelope; const receipt = plan && plan.restoreReceipt; const target = plan && plan.target;
      const domain = root.PressBenchDomain;
      if (!prepared || prepared.state !== "prepared" || !receipt || receipt.recoveryId !== prepared.id || !target ||
          prepared.sourceFingerprint !== receipt.sourceFingerprint ||
          prepared.payloadHash !== `sha256:${domain.sha256(JSON.stringify(prepared.payload))}` ||
          receipt.targetHash !== `sha256:${domain.sha256(JSON.stringify(target))}`) throw new Error("restore_plan");
      if (this.data.lastRestore && this.data.lastRestore.recoveryId === receipt.recoveryId &&
          this.data.lastRestore.targetHash === receipt.targetHash) {
        const currentTarget = { machines: this.data.machines || [], setups: this.data.recipes || [],
          batches: this.data.batches || [], settings: this.data.settings, session: this.data.session || null };
        if (`sha256:${domain.sha256(JSON.stringify(currentTarget))}` !== receipt.targetHash) throw new Error("restore_state_drift");
        return { alreadyApplied: true };
      }
      await withStorageLock(()=>this._commit(data=>{
        if (root.PressBenchProcess.operationalStateFingerprint(data) !== receipt.sourceFingerprint) throw new Error("restore_stale");
        data.preRestoreRecovery = deepCopy(prepared);
      }));
      const durable = this.data.preRestoreRecovery;
      if (!durable || durable.payloadHash !== prepared.payloadHash || JSON.stringify(durable) !== JSON.stringify(prepared)) throw new Error("recovery_point_verify");
      await this.applyGraphMutation({ replaceAll: target, verifiedRestore: receipt });
      return { applied: true };
    }
    async replaceAll() { throw new Error("planner_required"); }
    async clearAll() { throw new Error("planner_required"); }
  }

  function backendChoice() {
    try { return root.localStorage && root.localStorage.getItem(BACKEND_KEY); } catch (_) { return null; }
  }

  function rememberBackend(value) {
    try { if (root.localStorage) root.localStorage.setItem(BACKEND_KEY, value); } catch (_) {}
  }

  function hasData(value) {
    return Boolean(value && ((value.machines && value.machines.length) || (value.setups && value.setups.length) ||
      (value.recipes && value.recipes.length) || (value.batches && value.batches.length) || value.settings || value.session));
  }

  function clearFallbackReplicas() {
    try { if (root.localStorage) root.localStorage.removeItem(FALLBACK_KEY); } catch (_) {}
    try { if (root.sessionStorage) root.sessionStorage.removeItem(FALLBACK_KEY); } catch (_) {}
  }

  function inspectCompatibleReplica() {
    try { return fallbackInitialEnvelope().data; }
    catch (error) { throw Object.assign(new Error("alternate_backend_inspection_failed"), { cause: error }); }
  }

  async function inspectIndexedReplica() {
    if (!root.indexedDB) return null;
    let database = null;
    try {
      database = await openDatabase();
      const store = new LocalStore(database);
      return await store.loadAll();
    } catch (error) {
      throw Object.assign(new Error("alternate_backend_inspection_failed"), { cause: error });
    } finally { if (database) { try { database.close(); } catch (_) {} } }
  }

  async function retireAlternateBackend(activeMode) {
    if (activeMode === "indexeddb") {
      try {
        if (root.localStorage) root.localStorage.removeItem(FALLBACK_KEY);
        if (root.sessionStorage) root.sessionStorage.removeItem(FALLBACK_KEY);
        const localGone = !root.localStorage || !root.localStorage.getItem(FALLBACK_KEY);
        const sessionGone = !root.sessionStorage || !root.sessionStorage.getItem(FALLBACK_KEY);
        return localGone && sessionGone;
      } catch (_) { return false; }
    }
    if (activeMode !== "compatible" || !root.indexedDB) return true;
    let database = null;
    try {
      database = await openDatabase();
      const alternate = new LocalStore(database);
      await alternate.loadAll();
      await alternate.applyGraphMutation({ deleteAll: true, deleteConfirmation: "DELETE",
        deleteCapability: INTERNAL_REPLACE_CAPABILITY });
      return true;
    } catch (_) { return false; }
    finally { if (database) { try { database.close(); } catch (_) {} } }
  }

  async function createStore() {
    const pinned = backendChoice();
    if (pinned === "compatible") return new CompatibleStore();
    let database = null;
    try {
      database = await openDatabase();
      const local = new LocalStore(database);
      database.onversionchange = function () {
        local.closed = true; database.close();
        try { root.dispatchEvent(new Event("pressbench-storage-versionchange")); } catch (_) {}
      };
      if (!pinned) {
        const indexedData = await local.loadAll();
        let fallback = null;
        try { fallback = fallbackInitialEnvelope().data; } catch (error) { if (!hasData(indexedData)) throw error; }
        if (fallback && hasData(fallback)) {
          if (hasData(indexedData)) throw new Error("storage_backend_conflict");
          const transferable = root.PressBenchProcess && typeof root.PressBenchProcess.migrateLoadedData === "function"
            ? root.PressBenchProcess.migrateLoadedData(fallback) : fallback;
          const transferableDraftSession = transferable.session && !transferable.session.activeRun ? transferable.session : null;
          await local._replaceAll(transferable.recipes, transferable.batches, transferable.settings, transferableDraftSession,
            transferable.machines || [], INTERNAL_REPLACE_CAPABILITY);
          if (transferable.session && transferable.session.activeRun) await local.reserveRun(transferable.session, null);
          clearFallbackReplicas();
        }
      }
      rememberBackend("indexeddb");
      return local;
    } catch (error) {
      if (database) { try { database.close(); } catch (_) {} }
      if (pinned === "indexeddb" || (error && ["indexeddb_blocked", "storage_backend_conflict", "storage_corrupt"].includes(error.message))) throw error;
      const compatible = new CompatibleStore(); rememberBackend("compatible"); return compatible;
    }
  }

  async function applyDeleteAll(store, plan) {
    if (!store || typeof store.loadAll !== "function" || typeof store.applyGraphMutation !== "function" ||
        !plan || !plan.mutation || plan.mutation.deleteAll !== true || plan.mutation.deleteConfirmation !== "DELETE") {
      throw new Error("delete_plan");
    }
    const current = await store.loadAll();
    if (current.session && current.session.activeRun) throw new Error("active_run_conflict");
    let alternate = null; let alternateUnreadable = false;
    try { alternate = store.mode === "indexeddb" ? inspectCompatibleReplica() : await inspectIndexedReplica(); }
    catch (error) {
      if (store.mode !== "indexeddb" || !error.cause || error.cause.message !== "storage_corrupt") throw error;
      alternateUnreadable = true;
    }
    if (alternate && alternate.session && alternate.session.activeRun) throw new Error("active_run_conflict");
    if (!await retireAlternateBackend(store.mode)) throw new Error("alternate_backend_delete_failed");
    try {
      await store.applyGraphMutation(Object.assign({}, plan.mutation, { deleteCapability: INTERNAL_REPLACE_CAPABILITY }));
    } catch (error) {
      throw Object.assign(new Error("delete_partial_failure"), { cause: error,
        alternateBackendCleared: true, activeBackendCleared: false });
    }
    const after = await store.loadAll();
    if ((after.machines || []).length || (after.setups || after.recipes || []).length ||
        (after.batches || []).length || after.session) throw new Error("delete_verify_failed");
    return Object.freeze({ deleted: true, alternateBackendCleared: true, alternateUnreadable: alternateUnreadable,
      entitlementUnaffected: true });
  }

  async function inspectRecovery() {
    const snapshot = { capturedAt: new Date().toISOString(), localStorageRaw: "", sessionStorageRaw: "", fallback: null, indexeddb: null, errors: [] };
    try { snapshot.localStorageRaw = root.localStorage ? (root.localStorage.getItem(FALLBACK_KEY) || "") : ""; } catch (_) { snapshot.errors.push("localStorage_read"); }
    try { snapshot.sessionStorageRaw = root.sessionStorage ? (root.sessionStorage.getItem(FALLBACK_KEY) || "") : ""; } catch (_) { snapshot.errors.push("sessionStorage_read"); }
    try { snapshot.fallback = deepCopy(fallbackInitialEnvelope().data); } catch (error) { snapshot.errors.push(error && error.message || "fallback_read"); }
    let database = null;
    try {
      database = await openDatabase();
      snapshot.indexeddb = await new LocalStore(database).loadAll();
    } catch (error) { snapshot.errors.push(error && error.message || "indexeddb_read"); }
    finally { if (database) { try { database.close(); } catch (_) {} } }
    return snapshot;
  }

  function selectRecoveryBackend(value) {
    if (!["indexeddb", "compatible"].includes(value) || !root.localStorage) throw new Error("storage_recovery_choice");
    root.localStorage.setItem(BACKEND_KEY, value);
    if (root.localStorage.getItem(BACKEND_KEY) !== value) throw new Error("storage_recovery_choice");
  }

  root.PressBenchStorage = Object.freeze({ DB_VERSION: DB_VERSION, STORE_NAMES: Object.freeze(["machines", "recipes", "batches", "meta"]),
    create: createStore, inspectRecovery: inspectRecovery, selectRecoveryBackend: selectRecoveryBackend,
    retireAlternateBackend: retireAlternateBackend, applyDeleteAll: applyDeleteAll, hasData: hasData });
})(typeof globalThis !== "undefined" ? globalThis : this);
(function (root) {
  "use strict";

  const D = root.PressBenchDomain;
  const B = root.PressBenchBusiness;
  if (!D || !B) throw new Error("pressbench_logic_dependencies_missing");

  const SESSION_SCHEMA_VERSION = 2;
  const SAVE_CHOICES = new Set(["batch_only", "update_recipe", "save_variant"]);

  function clone(value) {
    if (!D.isBoundedJsonValue(value, 40, 1000000)) throw new Error("storage_corrupt");
    return JSON.parse(JSON.stringify(value));
  }

  function integer(value, min, max, code) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < min || parsed > max) throw new Error(code);
    return parsed;
  }

  function serializedBytes(value) {
    return D.utf8ByteLength(JSON.stringify(value === undefined ? null : value));
  }

  function activeDataLimit(storageMode) {
    return storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
  }

  function measureDataBytes(recipes, batches, settings, session) {
    return serializedBytes(recipes || []) + serializedBytes(batches || []) + serializedBytes(settings || null) + serializedBytes(session || null);
  }

  function withinDataBudget(recipes, batches, settings, session, storageMode) {
    return measureDataBytes(recipes, batches, settings, session) <= activeDataLimit(storageMode);
  }

  function createActiveRun(recipe, options) {
    const source = options || {};
    const normalized = D.normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    const errors = D.validateRecipeInput(normalized);
    if (errors.length) throw Object.assign(new Error("recipe_validation"), { fields: errors });
    if (normalized.archived === true || normalized.status === "archived") throw new Error("recipe_archived");
    const quantity = integer(source.quantity === undefined ? normalized.defaultQuantity : source.quantity, 1, 999999, "quantity");
    const startedAt = source.startedAt || D.nowIso();
    if (Number.isNaN(new Date(startedAt).getTime())) throw new Error("startedAt");
    return {
      id: D.uuid(),
      resultId: D.uuid(),
      sourceRecipeId: D.text(source.sourceRecipeId || normalized.id, 100),
      sourceBatchId: D.text(source.sourceBatchId, 100),
      originalRecipe: D.recipeSnapshot(normalized),
      recipe: D.recipeSnapshot(normalized),
      jobName: D.text(source.jobName, 180),
      quantity: quantity,
      startedAt: new Date(startedAt).toISOString(),
      manufacturerVerified: false,
      manufacturerVerifiedAt: "",
      manufacturerVerifiedFingerprint: "",
      resultDraft: null
    };
  }

  function updateRunRecipe(run, recipe) {
    const next = clone(run);
    const normalized = D.normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    if (D.validateRecipeInput(normalized).length) throw new Error("recipe_validation");
    const previousFingerprint = D.operationalFingerprint(next.recipe);
    next.recipe = D.recipeSnapshot(normalized);
    if (previousFingerprint !== D.operationalFingerprint(next.recipe)) {
      next.manufacturerVerified = false;
      next.manufacturerVerifiedAt = "";
      next.manufacturerVerifiedFingerprint = "";
      next.resultDraft = null;
    }
    return next;
  }

  function confirmManufacturer(run, confirmedAt) {
    const next = clone(run);
    const at = confirmedAt || D.nowIso();
    const instant = new Date(at);
    if (Number.isNaN(instant.getTime()) || instant < new Date(next.startedAt)) throw new Error("manufacturerVerifiedAt");
    next.manufacturerVerified = true;
    next.manufacturerVerifiedAt = instant.toISOString();
    next.manufacturerVerifiedFingerprint = D.operationalFingerprint(next.recipe);
    return next;
  }

  function manufacturerConfirmationValid(run) {
    return Boolean(run && run.manufacturerVerified === true && run.manufacturerVerifiedAt &&
      run.manufacturerVerifiedFingerprint === D.operationalFingerprint(run.recipe));
  }

  function buildTimerStages(recipe) {
    const normalized = D.normalizeRecipe(recipe, recipe && recipe.temperatureUnit, true);
    const stages = [];
    const prePress = Number(normalized.prePressSeconds);
    if (Number.isFinite(prePress) && prePress > 0) {
      stages.push({ key: "prepress", sourceStepId: "", kind: "prepress", sequence: 1, repeat: 1, seconds: prePress });
    }
    normalized.steps.forEach(function (step, index) {
      const seconds = Number(step.pressTimeSeconds);
      if (!Number.isFinite(seconds) || seconds <= 0) return;
      const repeats = Math.max(1, Number(step.repeatCount) || 1);
      for (let repeat = 1; repeat <= repeats; repeat += 1) {
        stages.push({
          key: `${step.id}:${repeat}`,
          sourceStepId: step.id,
          kind: "press",
          sequence: index + 1,
          repeat: repeat,
          seconds: seconds,
          name: D.text(step.name, 120),
          machineNickname: D.text(step.machineNickname, 180),
          platenZone: D.text(step.platenZone, 120),
          temperature: step.temperature,
          temperatureUnit: step.temperatureUnit,
          pressure: step.pressure,
          placementAction: D.text(step.placementAction, 500),
          finishAction: D.text(step.finishAction, 500)
        });
      }
    });
    return stages;
  }

  function timerPlanFingerprint(recipe) {
    return JSON.stringify(buildTimerStages(recipe).map(function (stage) {
      return [stage.kind, stage.sourceStepId, stage.repeat, stage.seconds];
    }));
  }

  function createTimer(run, index) {
    const stages = buildTimerStages(run.recipe);
    if (!stages.length) throw new Error("timer_no_stages");
    const stageIndex = integer(index === undefined ? 0 : index, 0, stages.length - 1, "timer_index");
    const duration = stages[stageIndex].seconds * 1000;
    return { runId: run.id, planFingerprint: timerPlanFingerprint(run.recipe), stages: stages, index: stageIndex,
      totalMs: duration, remainingMs: duration, endAt: 0, running: false, completed: false, notified: false };
  }

  function reconcileTimer(timer, now) {
    const next = clone(timer); const instant = Number(now === undefined ? Date.now() : now);
    if (next.running) {
      next.remainingMs = Math.max(0, next.endAt - instant);
      if (next.remainingMs === 0) { next.running = false; next.completed = true; next.endAt = 0; }
    }
    return next;
  }

  function startTimer(timer, now) {
    const instant = Number(now === undefined ? Date.now() : now);
    const next = reconcileTimer(timer, instant);
    if (next.completed) return next;
    next.running = true; next.endAt = instant + next.remainingMs; return next;
  }

  function pauseTimer(timer, now) {
    const next = reconcileTimer(timer, now); next.running = false; next.endAt = 0; return next;
  }

  function resetTimer(timer) {
    const next = clone(timer); const duration = Number(next.stages[next.index].seconds) * 1000;
    next.totalMs = duration; next.remainingMs = duration; next.endAt = 0; next.running = false; next.completed = false; next.notified = false; return next;
  }

  function moveTimer(timer, direction) {
    const next = clone(timer);
    const index = Math.max(0, Math.min(next.stages.length - 1, next.index + (direction < 0 ? -1 : 1)));
    next.index = index; return resetTimer(next);
  }

  function sessionSnapshot(activeRun, timer, recipeDraft) {
    return activeRun || recipeDraft ? { schemaVersion: SESSION_SCHEMA_VERSION, activeRun: activeRun ? clone(activeRun) : null,
      timer: timer ? clone(timer) : null, recipeDraft: recipeDraft ? clone(recipeDraft) : null } : null;
  }

  function restoreSession(source, batches, defaultUnit, now) {
    if (!source || typeof source !== "object" || ![1, 2].includes(source.schemaVersion)) return null;
    const restored = { activeRun: null, timer: null, recipeDraft: null };
    try {
      if (source.recipeDraft && source.recipeDraft.source && typeof source.recipeDraft.key === "string" && serializedBytes(source.recipeDraft) <= D.MAX_RECORD_BYTES) restored.recipeDraft = clone(source.recipeDraft);
      const run = source.activeRun;
      if (run && typeof run.id === "string" && run.id && typeof run.resultId === "string" && run.resultId &&
          !(batches || []).some(function (batch) { return batch.id === run.resultId; }) && run.recipe &&
          integer(run.quantity, 1, 999999, "quantity") && !Number.isNaN(new Date(run.startedAt).getTime())) {
        const nextRun = clone(run); nextRun.recipe = D.normalizeRecipe(nextRun.recipe, nextRun.recipe.temperatureUnit || defaultUnit, true);
        if (!D.validateRecipeInput(nextRun.recipe).length) {
          nextRun.originalRecipe = D.recipeSnapshot(nextRun.originalRecipe || nextRun.recipe);
          const validConfirmation = source.schemaVersion === 2 && manufacturerConfirmationValid(nextRun);
          if (!validConfirmation) { nextRun.manufacturerVerified = false; nextRun.manufacturerVerifiedAt = ""; nextRun.manufacturerVerifiedFingerprint = ""; }
          if (nextRun.resultDraft && (serializedBytes(nextRun.resultDraft) > D.MAX_RECORD_BYTES || ((nextRun.resultDraft.issues || []).length > D.MAX_ISSUES))) delete nextRun.resultDraft;
          restored.activeRun = nextRun;
        }
      }
      if (restored.activeRun && source.timer && source.timer.runId === restored.activeRun.id) {
        const stages = buildTimerStages(restored.activeRun.recipe); const timer = clone(source.timer);
        if (timer.index >= 0 && timer.index < stages.length && typeof timer.running === "boolean" && typeof timer.completed === "boolean" && !(timer.running && timer.completed)) {
          const duration = stages[timer.index].seconds * 1000; const instant = Number(now === undefined ? Date.now() : now);
          timer.stages = stages; timer.planFingerprint = timerPlanFingerprint(restored.activeRun.recipe); timer.totalMs = duration;
          timer.remainingMs = timer.completed ? 0 : Math.min(duration, Math.max(0, timer.running ? timer.endAt - instant : timer.remainingMs));
          timer.endAt = timer.running ? instant + timer.remainingMs : 0; timer.notified = timer.completed && timer.notified === true;
          restored.timer = timer;
        }
      }
    } catch (_) { return null; }
    return restored.activeRun || restored.recipeDraft ? restored : null;
  }

  function analyticsBatches(batches, filter) {
    const options = filter || {}; const outcomes = options.outcomes ? new Set(options.outcomes) : null;
    const start = options.start ? new Date(options.start) : null; const end = options.end ? new Date(options.end) : null;
    return (batches || []).filter(function (batch) {
      if (batch.reviewStatus === "legacy_needs_review") return false;
      const completed = new Date(batch.completedAt);
      if (start && completed < start || end && completed > end) return false;
      if (outcomes && !outcomes.has(batch.outcome)) return false;
      if (options.machine && options.machine !== "all" && !(batch.recipe.steps || []).some(function (step) { return step.machineNickname === options.machine; })) return false;
      return true;
    });
  }

  // Kept only as a read/migration adapter for v0.19 sessions. New callers use
  // PressBenchProcess below. Unsafe legacy run mutators are intentionally not
  // reachable from this adapter.
  root.PressBenchLegacyRuntimeV19 = Object.freeze({
    SESSION_SCHEMA_VERSION: SESSION_SCHEMA_VERSION,
    restoreSession: restoreSession, analyticsBatches: analyticsBatches
  });

})(typeof globalThis !== "undefined" ? globalThis : this);

(function (root) {
  "use strict";

  const D = root.PressBenchDomain;
  const B = root.PressBenchBusiness;
  const E = root.PressBenchEntitlement;
  const LEGACY_ADAPTER = root.PressBenchLegacyRuntimeV19;
  if (!D || !B || !E) throw new Error("pressbench_process_dependencies_missing");

  const SESSION_SCHEMA_VERSION = 4;
  const RESULT_DRAFT_SCHEMA_VERSION = 1;
  const SETUP_DRAFT_SCHEMA_VERSION = 1;
  const PERMIT_SCHEMA_VERSION = 3;
  // Setup field/stage caps bound a canonical setup below this amount; the
  // result reservation uses the full per-record ceiling.
  const MAX_SETUP_RESERVATION_BYTES = 250_000;
  const SAVE_CHOICES = new Set(["batch_only", "update_recipe", "save_variant"]);
  const FIRST_PIECE_POLICIES = new Set(["required_for_unproven", "recommended"]);
  const PROGRESS_MODES = new Set(["final_confirmation", "live_cycles"]);
  const ARCHITECTURE_REQUIREMENTS = Object.freeze({
    operationalDataLocation: "device_only", publisherOperationalDataAccess: false, accountRequired: false,
    publisherCloudSync: false, trackingSdk: false, advertisingSdk: "none", remotePushToken: false,
    routineNetworkBoundary: "store_entitlement_only", automaticOsBackupForOperationalDatabase: "excluded",
    nativeStoreVerificationRequired: true, entitlementPortableBackup: false,
    manualJsonBackupEncrypted: false, notificationContent: "generic_no_job_reference",
    equipmentControlOrMeasurement: false
  });

  function clone(value) {
    if (!D.isBoundedJsonValue(value, 50, 1000000)) throw new Error("storage_corrupt");
    return JSON.parse(JSON.stringify(value));
  }

  function atIso(value) {
    const date = new Date(value === undefined ? Date.now() : value);
    if (Number.isNaN(date.getTime())) throw new Error("invalid_time");
    return date.toISOString();
  }

  function integer(value, min, max, code) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < min || parsed > max) throw new Error(code);
    return parsed;
  }

  function setupsOf(context) {
    return context && Array.isArray(context.setups) ? context.setups : context && Array.isArray(context.recipes) ? context.recipes : [];
  }

  function usageOf(context) {
    return { setups: B.userRecipeCount(setupsOf(context)), batches: B.userBatchCount(context && context.batches || []) };
  }

  function runIntentFingerprint(run) {
    if (!run) return "";
    const permit = run.permit || {};
    const usage = permit.usageSnapshot || {};
    return `sha256:${D.sha256(JSON.stringify([
      run.id, run.resultId, run.sourceSetupId || run.sourceRecipeId, run.sourceBatchId || "", run.runMode,
      run.quantity, run.utcOffsetMinutes, run.progressMode || "final_confirmation", run.jobReference || "", run.reservedAt, run.startedAt, D.exactSetupFingerprint(run.originalSetup),
      run.originalOperationalFingerprint,
      permit.reservedAt, permit.authorizationBasis, permit.setupSlotReserved === true, permit.variantSlotReserved === true,
      permit.variantSetupId || "", permit.reservedBytes,
      usage.setups === undefined ? null : usage.setups,
      usage.batches === undefined ? null : usage.batches,
      usage.freeSetupLimit === undefined ? null : usage.freeSetupLimit,
      usage.freeBatchLimit === undefined ? null : usage.freeBatchLimit,
      usage.physicalLimit === undefined ? null : usage.physicalLimit,
      usage.migrated === true
    ]))}`;
  }

  function legacyRunIntentFingerprintV2(run) {
    if (!run) return "";
    const permit = run.permit || {}; const usage = permit.usageSnapshot || {};
    const legacyUsage = usage.migrated === true ? { migrated: true } : {
      setups: usage.setups, batches: usage.batches,
      freeSetupLimit: usage.freeSetupLimit, freeBatchLimit: usage.freeBatchLimit,
      physicalLimit: usage.physicalLimit
    };
    return `sha256:${D.sha256(JSON.stringify([
      run.id, run.resultId, run.sourceSetupId || run.sourceRecipeId, run.sourceBatchId || "", run.runMode,
      run.quantity, run.utcOffsetMinutes, run.progressMode || "final_confirmation", run.jobReference || "", run.reservedAt, run.startedAt, D.exactSetupFingerprint(run.originalSetup),
      run.originalOperationalFingerprint,
      permit.reservedAt, permit.authorizationBasis, permit.setupSlotReserved === true, permit.variantSlotReserved === true,
      permit.variantSetupId || "", permit.reservedBytes, legacyUsage
    ]))}`;
  }

  function legalReady(settings) {
    const value = D.normalizeSettings(settings);
    return value.termsAcceptedVersion === D.TERMS_VERSION && Boolean(value.termsAcceptedAt) &&
      value.safetyAcceptedVersion === D.SAFETY_ACK_VERSION && Boolean(value.safetyAcceptedAt) &&
      value.privacyNoticeVersionViewed === D.PRIVACY_NOTICE_VERSION && Boolean(value.privacyNoticeViewedAt);
  }

  function operationalReadiness(settings) {
    const value = D.normalizeSettings(settings);
    const missing = [];
    if (value.termsAcceptedVersion !== D.TERMS_VERSION || !value.termsAcceptedAt) missing.push("terms_acceptance");
    if (value.safetyAcceptedVersion !== D.SAFETY_ACK_VERSION || !value.safetyAcceptedAt) missing.push("safety_acceptance");
    if (value.privacyNoticeVersionViewed !== D.PRIVACY_NOTICE_VERSION || !value.privacyNoticeViewedAt) {
      missing.push("privacy_notice_presentation");
    }
    if (!value.temperatureUnitConfirmedAt || value.confirmedTemperatureUnit !== value.defaultUnit) {
      missing.push("temperature_unit_confirmation");
    }
    return Object.freeze({ ready: missing.length === 0, missing: Object.freeze(missing) });
  }

  function requireOperationalReadiness(settings) {
    const readiness = operationalReadiness(settings);
    if (!readiness.ready) throw Object.assign(new Error("operational_readiness_required"), {
      requirements: readiness.missing.slice()
    });
    return readiness;
  }

  function acceptLegal(settings, acceptance, now) {
    const source = acceptance || {};
    if (source.termsAccepted !== true || source.safetyAccepted !== true) throw new Error("legal_acceptance_required");
    if (source.privacyPresented !== true && source.privacyViewed !== true) throw new Error("privacy_notice_required");
    const timestamp = atIso(now);
    return D.normalizeSettings(Object.assign({}, settings, {
      termsAcceptedVersion: D.TERMS_VERSION, termsAcceptedAt: timestamp,
      safetyAcceptedVersion: D.SAFETY_ACK_VERSION, safetyAcceptedAt: timestamp,
      privacyNoticeVersionViewed: D.PRIVACY_NOTICE_VERSION,
      privacyNoticeViewedAt: timestamp
    }));
  }

  function recordReminderDecision(settings, decision) {
    const states = { grant: "granted", deny: "denied", not_now: "dismissed" };
    if (!states[decision]) throw new Error("reminder_decision");
    return D.normalizeSettings(Object.assign({}, settings, { reminderPermission: states[decision] }));
  }

  function confirmTemperatureUnit(settings, unit, now) {
    if (!D.UNITS.has(unit)) throw new Error("temperature_unit");
    return D.normalizeSettings(Object.assign({}, settings, { defaultUnit: unit,
      confirmedTemperatureUnit: unit, temperatureUnitConfirmedAt: atIso(now) }));
  }

  function markBackupCompleted(settings, batchCount, now) {
    if (!Number.isInteger(batchCount) && now === undefined) { now = batchCount; batchCount = undefined; }
    const count = Number.isInteger(batchCount) ? batchCount : D.normalizeSettings(settings).lastBackupBatchCount;
    return D.normalizeSettings(Object.assign({}, settings, { lastBackupAt: atIso(now),
      lastBackupBatchCount: count }));
  }

  function evaluateStartup(context, now) {
    const value = context || {};
    const session = value.session && typeof value.session === "object" ? value.session : null;
    const activeRun = session && session.activeRun || null;
    const setupDraft = session && session.setupDraft || null;
    const result = activeRun && (activeRun.resultDraft || activeRun.recoveredResultValues) || null;
    const entitlementEvaluation = E.evaluateEntitlement(value.entitlement, now);
    const capabilities = E.capabilities(value.entitlement, usageOf(value), now);
    const physicalProductionBegan = Boolean(activeRun && (activeRun.productionStarted === true ||
      activeRun.productionStartedAt || activeRun.firstPressedSetup));
    const interruptedRestore = Boolean(value.preRestoreRecovery && value.preRestoreRecovery.state === "prepared");
    const readiness = operationalReadiness(value.settings);
    const recoveryRequired = Boolean(value.recoveryRequired === true || value.storageConflict === true ||
      value.recoverableSnapshot || activeRun || setupDraft || result || interruptedRestore);
    return Object.freeze({
      recoveryRequired: recoveryRequired,
      storageConflict: value.storageConflict === true,
      recoverableSnapshotAvailable: Boolean(value.recoverableSnapshot),
      interruptedRestore: interruptedRestore,
      legalAcceptanceRequired: !value.settings || !legalReady(value.settings),
      privacyNoticePresentationRequired: !value.settings ||
        D.normalizeSettings(value.settings).privacyNoticeVersionViewed !== D.PRIVACY_NOTICE_VERSION ||
        !D.normalizeSettings(value.settings).privacyNoticeViewedAt,
      temperatureUnitConfirmationRequired: readiness.missing.includes("temperature_unit_confirmation"),
      operationalReadiness: readiness,
      entitlementEvaluation: entitlementEvaluation,
      capabilities: capabilities,
      requiresStoreVerification: entitlementEvaluation.requiresVerification,
      hasOperationalData: Boolean((value.machines || []).length || setupsOf(value).length || (value.batches || []).length),
      resumableRunPhase: activeRun && activeRun.phase || "",
      resumableSetupDraft: setupDraft ? clone(setupDraft) : null,
      resumableResultDraft: result ? clone(result) : null,
      resumableResultDraftVerified: Boolean(activeRun && activeRun.resultDraft && validResultDraft(activeRun, activeRun.resultDraft)),
      activeRun: activeRun ? Object.freeze({ id: activeRun.id, resultId: activeRun.resultId, phase: activeRun.phase,
        physicalProductionBegan: physicalProductionBegan, canReleasePermit: !physicalProductionBegan,
        mustRecordResult: physicalProductionBegan }) : null,
      canCompleteReservedRun: Boolean(activeRun && permitValid(activeRun)),
      canCommitReservedResult: Boolean(activeRun && permitValid(activeRun) && activeRun.resultDraft)
    });
  }

  function processStructure(key, defaultUnit) {
    const templates = B.starterTemplates(defaultUnit);
    const match = templates.find(function (item) { return item.processStructure === key; }) ||
      templates.find(function (item) { return item.processStructure === "blank"; });
    if (!match) throw new Error("process_structure");
    const setup = D.normalizeRecipe(Object.assign({}, match, { id: undefined, title: key === "blank" ? "" : match.title,
      notes: "", status: "draft", createdAt: undefined, updatedAt: undefined }), defaultUnit, false);
    setup.steps.forEach(function (step) { step.id = D.uuid(); });
    return setup;
  }

  function prepareSetupForSave(value, context, now) {
    if (value && Array.isArray(value.steps) && value.steps.length > D.MAX_STAGES) throw new Error("stage_limit");
    const normalized = D.normalizeRecipe(value, value && value.temperatureUnit, true);
    const currentFingerprint = D.operationalFingerprintV4(normalized);
    const existing = context && context.existing;
    const mutationAt = D.recipeMutationTime(normalized, now);
    if (existing) {
      const definitionChanged = D.exactSetupFingerprint(existing) !== D.exactSetupFingerprint(normalized);
      const restoredFromArchive = existing.archived === true && normalized.archived === false;
      normalized.proofResetAt = definitionChanged || restoredFromArchive ? mutationAt : (existing.proofResetAt || "");
    }
    const runnableCandidate = Object.assign({}, normalized, { status: "trial" });
    normalized.status = D.validateRunnableRecipe(runnableCandidate).length ? "draft" : "trial";
    normalized.verifiedAt = ""; normalized.verifiedBatchId = "";
    normalized.provenEvidenceCount = 0;
    normalized.persistedOperationalFingerprintV4 = currentFingerprint;
    normalized.updatedAt = mutationAt;
    const prepared = D.normalizeRecipe(normalized, normalized.temperatureUnit, true);
    return recomputeProvenSetups([prepared], context && context.batches || []).recipes[0];
  }

  function planSaveSetup(context, setupValue, now) {
    const value = context || {}; const current = setupsOf(value); const batches = value.batches || [];
    const suppliedId = D.text(setupValue && setupValue.id, 100);
    const existing = current.find(function (setup) { return setup.id === suppliedId; }) || null;
    if (!existing) requireOperationalReadiness(value.settings);
    if (!existing && current.length >= D.MAX_RECORDS) throw new Error("setup_physical_limit");
    let source = Object.assign({}, setupValue, { customerJob: "", jobReference: "" });
    if (!existing && D.SYSTEM_STARTER_IDS.has(suppliedId)) source = Object.assign({}, setupValue, { id: undefined,
      customerJob: "", jobReference: "",
      steps: (setupValue.steps || []).map(function (step) { return Object.assign({}, step, { id: D.uuid() }); }) });
    const setup = prepareSetupForSave(source, { batches: batches, existing: existing }, now);
    if (!D.validateV4RecipeRaw(setup, false, setup.status === "draft")) throw new Error("setup_schema");
    const projected = current.filter(function (item) { return item.id !== setup.id; }).concat(setup);
    const graphErrors = D.graphIntegrityErrors(value.machines || [], projected, batches);
    if (graphErrors.some(function (error) { return error.includes("machineProfileId"); })) throw new Error("machine_reference");
    if (graphErrors.some(function (error) { return error.includes("instructionSource.priorBatchId"); })) throw new Error("instruction_reference");
    if (graphErrors.length) throw new Error("graph_integrity");
    if (D.utf8ByteLength(JSON.stringify(setup)) > D.MAX_RECORD_BYTES) throw new Error("record_size");
    const dataLimit = value.storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
    const payloadBytes = D.utf8ByteLength(JSON.stringify({ machines: value.machines || [], setups: projected,
      batches: batches, settings: value.settings || null, session: value.session || null }));
    if (payloadBytes > dataLimit) throw new Error("data_budget");
    return { setup: setup, setups: projected, mutation: { putSetups: [setup], clearSession: false } };
  }

  function planSaveMachine(context, machineValue, now) {
    const value = context || {}; const machines = value.machines || [];
    const suppliedId = D.text(machineValue && machineValue.id, 100);
    const existing = machines.find(function (machine) { return machine.id === suppliedId; }) || null;
    if (!existing) requireOperationalReadiness(value.settings);
    if (!existing && machines.length >= D.MAX_RECORDS) throw new Error("machine_limit");
    const mutationAt = D.recipeMutationTime(existing || machineValue, machineValue && machineValue.updatedAt, now);
    const machine = D.normalizeMachineProfile(Object.assign({}, machineValue, existing ? {
      id: existing.id, createdAt: existing.createdAt, updatedAt: mutationAt
    } : {}), Boolean(existing) || Boolean(suppliedId));
    const errors = D.validateMachineProfile(machine); if (errors.length) throw Object.assign(new Error("machine_validation"), { fields: errors });
    if (!D.validateV4MachineRaw(machine)) throw new Error("machine_schema");
    if (D.utf8ByteLength(JSON.stringify(machine)) > D.MAX_RECORD_BYTES) throw new Error("record_size");
    const projected = machines.filter(function (item) { return item.id !== machine.id; }).concat(machine);
    const classification = classifyMachineChange(existing, machine, machineValue && machineValue.materialChangeConfirmed === true);
    const dependentSetups = existing && classification.changeClass === "material" ? setupsOf(value).filter(function (setup) {
      return setup.machineProfileId === machine.id || (setup.steps || []).some(function (step) { return step.machineProfileId === machine.id; });
    }) : [];
    if (dependentSetups.length && value.session && value.session.activeRun) {
      const run = value.session.activeRun;
      if (run.setup && (run.setup.machineProfileId === machine.id || (run.setup.steps || []).some(function (step) {
        return step.machineProfileId === machine.id;
      }))) throw new Error("active_run_conflict");
    }
    const resetById = new Map(dependentSetups.map(function (setupValue) {
      const setup = D.normalizeRecipe(setupValue, setupValue.temperatureUnit, true);
      const snapshot = D.machineProfileSnapshot(machine);
      if (setup.machineProfileId === machine.id) {
        setup.machineProfile = snapshot; setup.machineNickname = snapshot.nickname;
        setup.platenZone = setup.platenZone === existing.platenOrZone ? snapshot.platenOrZone : setup.platenZone;
      }
      setup.steps = setup.steps.map(function (step) { return step.machineProfileId === machine.id ? Object.assign({}, step, {
        machineNickname: snapshot.nickname,
        platenZone: step.platenZone === existing.platenOrZone ? snapshot.platenOrZone : step.platenZone
      }) : step; });
      setup.status = "trial"; setup.verifiedAt = ""; setup.verifiedBatchId = "";
      setup.provenEvidenceCount = 0; setup.proofResetAt = mutationAt; setup.updatedAt = mutationAt;
      setup.persistedOperationalFingerprintV4 = D.operationalFingerprintV4(setup);
      const normalized = D.normalizeRecipe(setup, setup.temperatureUnit, true);
      if (D.validateRunnableRecipe(Object.assign({}, normalized, { archived: false })).length) normalized.status = "draft";
      return [normalized.id, D.normalizeRecipe(normalized, normalized.temperatureUnit, true)];
    }));
    const nextSetups = setupsOf(value).map(function (setup) { return resetById.get(setup.id) || setup; });
    const graphErrors = D.graphIntegrityErrors(projected, nextSetups, value.batches || []);
    if (graphErrors.length) throw Object.assign(new Error("graph_integrity"), { fields: graphErrors });
    const dataLimit = value.storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
    if (D.utf8ByteLength(JSON.stringify({ machines: projected, setups: nextSetups, batches: value.batches || [],
      settings: value.settings || null, session: value.session || null })) > dataLimit) throw new Error("data_budget");
    return { machine: machine, machines: projected, setups: nextSetups, recipes: nextSetups,
      changeClass: classification.changeClass, changedFields: classification.changedFields,
      affectedSetupIds: Array.from(resetById.keys()),
      mutation: { putMachines: [machine], putSetups: Array.from(resetById.values()), clearSession: false } };
  }

  function classifyMachineChange(beforeValue, afterValue, materialChangeConfirmed) {
    if (!beforeValue) return Object.freeze({ changeClass: "new", changedFields: [] });
    const before = D.normalizeMachineProfile(beforeValue, true); const after = D.normalizeMachineProfile(afterValue, true);
    const semantic = new Set(["brand", "model", "pressureMethod", "pressureScale", "platenOrZone"]);
    const fields = ["nickname", "notes", "brand", "model", "pressureMethod", "pressureScale", "platenOrZone",
      "lastExternalCheckDate", "archived"];
    const changedFields = fields.filter(function (field) { return before[field] !== after[field]; });
    let changeClass = changedFields.some(function (field) { return semantic.has(field); }) ||
      materialChangeConfirmed === true && changedFields.length ? "material" :
      changedFields.includes("archived") ? "lifecycle" : changedFields.length ? "metadata" : "none";
    return Object.freeze({ changeClass: changeClass, changedFields: changedFields });
  }

  function archiveSetup(value, now) {
    const setup = D.normalizeRecipe(value, value && value.temperatureUnit, true);
    setup.archived = true; setup.status = setup.status === "draft" ? "draft" : "trial";
    setup.verifiedAt = ""; setup.verifiedBatchId = ""; setup.provenEvidenceCount = 0;
    setup.updatedAt = D.recipeMutationTime(setup, now); return D.normalizeRecipe(setup, setup.temperatureUnit, true);
  }

  function restoreArchivedSetup(value, now) {
    const setup = D.normalizeRecipe(value, value && value.temperatureUnit, true);
    setup.archived = false; setup.status = "trial"; setup.verifiedAt = ""; setup.verifiedBatchId = "";
    setup.provenEvidenceCount = 0;
    setup.updatedAt = D.recipeMutationTime(setup, now);
    setup.proofResetAt = setup.updatedAt;
    return D.normalizeRecipe(setup, setup.temperatureUnit, true);
  }

  function firstPieceRequired(setup, policy) {
    // Unproven or changed setups always require a recorded first piece. The
    // recommendation policy applies only to unchanged Proven production runs.
    return D.publicSetupStatus(setup) !== "proven";
  }

  function frozenRunSetup(setupValue) {
    const snapshot = D.recipeSnapshot(setupValue);
    snapshot.customerJob = ""; snapshot.jobReference = "";
    return snapshot;
  }

  function reusableSetupFacts(context) {
    const value = context || {};
    const activeMachines = (value.machines || []).filter(function (machine) { return machine.archived !== true; });
    function unique(values) { return Array.from(new Set(values.filter(Boolean))).sort(); }
    return Object.freeze({
      soleActiveMachineCandidate: activeMachines.length === 1 ? clone(activeMachines[0]) : null,
      materialSuggestions: unique(setupsOf(value).map(function (setup) { return D.text(setup.blankMaterial, 180); })),
      transferSuggestions: unique(setupsOf(value).map(function (setup) { return D.text(setup.transferMedium, 180); })),
      sourceSuggestions: unique(setupsOf(value).map(function (setup) {
        const source = D.normalizeInstructionSource(setup.instructionSource);
        return D.instructionSourceChecked(source) ? JSON.stringify(source) : "";
      })).map(function (source) { return JSON.parse(source); })
    });
  }

  function checkedToday(sourceValue, now, utcOffsetMinutes) {
    const date = new Date(now === undefined ? Date.now() : now);
    if (Number.isNaN(date.getTime())) throw new Error("invalid_time");
    const offset = Number.isInteger(utcOffsetMinutes) ? utcOffsetMinutes : -date.getTimezoneOffset();
    const civil = D.workDateFor(date.toISOString(), offset);
    return D.normalizeInstructionSource(Object.assign({}, sourceValue, { checkedDate: civil }));
  }

  function qcPolicy(run) {
    const quantity = Number(run && run.quantity || 0);
    const unproven = run && run.firstPiece && run.firstPiece.required === true;
    if (!run || run.runMode !== "production" || quantity < 10) return Object.freeze({ enabled: false, firstAt: null, every: null });
    return Object.freeze({ enabled: true, firstAt: 1, every: unproven ? 10 : 25 });
  }

  function qcDueForRun(run) {
    const policy = qcPolicy(run);
    if (!policy.enabled) return false;
    const checks = Array.isArray(run.qcChecks) ? run.qcChecks : [];
    const lastProcessed = checks.length ? Number(checks[checks.length - 1].processedCount) || 0 : 0;
    const nextAt = lastProcessed === 0 ? policy.firstAt : lastProcessed + policy.every;
    return Number(run.processedCount || 0) >= nextAt;
  }

  function recommendedSaveChoice(run, liveSetup) {
    if (!run || !liveSetup) return "save_variant";
    const changed = D.operationalFingerprintV4(run.setup) !== D.operationalFingerprintV4(liveSetup) ||
      D.provenanceFingerprint(run.setup) !== D.provenanceFingerprint(liveSetup);
    if (!changed) return "update_recipe";
    return run.permit && run.permit.variantSlotReserved ? "save_variant" : "batch_only";
  }

  function issueDefaults(resultValue, disposition) {
    const result = resultValue || {};
    if (!["discarded", "reworked"].includes(disposition)) throw new Error("issue_disposition");
    const quantity = disposition === "discarded" ? Number(result.quantityWaste || 0) : Number(result.quantityReworked || 0);
    if (!Number.isInteger(quantity) || quantity < 1) throw new Error("issue_quantity");
    return Object.freeze({ quantity: quantity, disposition: disposition, symptom: "unknown",
      suspectedCause: "unknown", note: "" });
  }

  function inspectActiveRunConflict(context) {
    const run = context && context.session && context.session.activeRun;
    if (!run) return null;
    const physicalProductionBegan = Boolean(run.productionStarted === true || run.productionStartedAt || run.firstPressedSetup);
    return Object.freeze({ runId: run.id, resultId: run.resultId, phase: run.phase,
      physicalProductionBegan: physicalProductionBegan, canReleasePermit: !physicalProductionBegan,
      mustRecordResult: physicalProductionBegan });
  }

  function authorizeRun(context, setupValue, options) {
    const value = context || {}; const source = options || {};
    const conflict = inspectActiveRunConflict(value);
    if (conflict) return { authorized: false, code: "active_run_conflict", conflict: conflict };
    requireOperationalReadiness(value.settings);
    if (setupValue && Array.isArray(setupValue.steps) && setupValue.steps.length > D.MAX_STAGES) throw new Error("stage_limit");
    const recipes = setupsOf(value); const batches = value.batches || []; const now = atIso(source.now);
    const nowDate = new Date(now);
    const utcOffsetMinutes = Number.isInteger(source.utcOffsetMinutes) && source.utcOffsetMinutes >= -840 && source.utcOffsetMinutes <= 840
      ? source.utcOffsetMinutes : -nowDate.getTimezoneOffset();
    let setup = D.normalizeRecipe(setupValue, setupValue && setupValue.temperatureUnit, true);
    setup = recomputeProvenSetups([setup], batches, now).recipes[0];
    const setupErrors = D.validateRunnableRecipe(setup, now, utcOffsetMinutes);
    if (setupErrors.length) throw Object.assign(new Error("setup_not_runnable"), { fields: setupErrors });
    const runMode = D.RUN_MODES.has(source.runMode) ? source.runMode : (D.publicSetupStatus(setup) === "proven" ? "production" : "test");
    if (runMode === "production" && D.publicSetupStatus(setup) !== "proven" && source.confirmUnprovenProduction !== true) {
      throw new Error("unproven_production_confirmation");
    }
    if (!D.instructionReferenceValid(setup, new Map(batches.map(function (batch) { return [batch.id, batch]; })), now, "")) {
      throw Object.assign(new Error("setup_not_runnable"), { fields: ["instructionSource.priorBatchId"] });
    }
    if (Array.isArray(value.machines)) {
      const runGraphErrors = D.graphIntegrityErrors(value.machines, [setup], batches);
      const setupPath = `setups.${setup.id}`;
      const setupGraphErrors = runGraphErrors.filter(function (error) { return error === setupPath || error.startsWith(`${setupPath}.`); });
      if (setupGraphErrors.length) throw Object.assign(new Error("setup_not_runnable"), { fields: setupGraphErrors });
      const referencedMachineIds = new Set([setup.machineProfileId].concat((setup.steps || []).map(function (step) { return step.machineProfileId; })).filter(Boolean));
      if ((value.machines || []).some(function (machine) {
        return referencedMachineIds.has(machine.id) && machine.lastExternalCheckDate &&
          !D.civilDateNotAfter(machine.lastExternalCheckDate, now, utcOffsetMinutes);
      }) || setup.machineProfile.lastExternalCheckDate &&
        !D.civilDateNotAfter(setup.machineProfile.lastExternalCheckDate, now, utcOffsetMinutes)) {
        throw Object.assign(new Error("setup_not_runnable"), { fields: ["machineProfile.lastExternalCheckDate"] });
      }
    }
    if (!D.instructionSourceCheckedAt(setup.instructionSource, now, utcOffsetMinutes)) throw Object.assign(new Error("setup_not_runnable"), { fields: ["instructionSource"] });
    const usage = usageOf(value);
    const requestedSourceBatchId = D.text(source.sourceBatchId, 100);
    if (requestedSourceBatchId) {
      const sourceBatch = batches.find(function (batch) { return batch.id === requestedSourceBatchId; });
      if (!sourceBatch || sourceBatch.reviewStatus === "legacy_needs_review" ||
          new Date(sourceBatch.completedAt).getTime() > new Date(now).getTime()) throw new Error("source_batch_reference");
    }
    if (new Date(now).getTime() < new Date(setup.updatedAt || setup.createdAt).getTime()) throw new Error("run_time");
    const evaluation = E.evaluateEntitlement(value.entitlement, now);
    const existingSetup = recipes.some(function (item) { return item.id === setup.id; });
    if (batches.length >= D.MAX_RECORDS) throw new Error("batch_physical_limit");
    if (!existingSetup && recipes.length >= D.MAX_RECORDS) throw new Error("setup_physical_limit");
    if (usage.batches >= B.FREE_BATCH_LIMIT && !evaluation.paidAccess) throw new Error("batch_capacity_required");
    const runSetup = frozenRunSetup(setup);
    const runId = D.uuid(); const resultId = D.uuid(); const setupFingerprint = D.exactSetupFingerprint(runSetup);
    const sourceSetupId = setup.id;
    const variantSlotReserved = existingSetup && recipes.length < D.MAX_RECORDS && source.reserveVariantSlot === true;
    const requiresPaidCapacity = usage.batches >= B.FREE_BATCH_LIMIT;
    const authorizationBasis = requiresPaidCapacity ? evaluation.authorizationBasis : "free";
    const quantity = runMode === "test" ? 1 : integer(source.quantity === undefined ? setup.defaultQuantity : source.quantity, 1, 999999, "quantity");
    const reservationBytes = D.MAX_RECORD_BYTES + (!existingSetup || variantSlotReserved ? MAX_SETUP_RESERVATION_BYTES : 0);
    const permit = { schemaVersion: PERMIT_SCHEMA_VERSION, id: D.uuid(), runId: runId, resultId: resultId,
      setupId: sourceSetupId, setupFingerprint: setupFingerprint, reservedAt: now, authorizationBasis: authorizationBasis,
      setupSlotReserved: !existingSetup, variantSlotReserved: variantSlotReserved,
      variantSetupId: variantSlotReserved ? D.uuid() : "", reservedBytes: reservationBytes, intentFingerprint: "",
      usageSnapshot: { setups: usage.setups, batches: usage.batches, freeSetupLimit: B.FREE_RECIPE_LIMIT,
        freeBatchLimit: B.FREE_BATCH_LIMIT, physicalLimit: D.MAX_RECORDS }, state: "reserved" };
    const policy = FIRST_PIECE_POLICIES.has(source.firstPiecePolicy) ? source.firstPiecePolicy : "required_for_unproven";
    const required = runMode === "test" || firstPieceRequired(setup, policy);
    const progressMode = PROGRESS_MODES.has(source.progressMode) ? source.progressMode : "final_confirmation";
    const run = {
      schemaVersion: 4, id: runId, resultId: resultId, permit: permit, sourceSetupId: sourceSetupId, sourceRecipeId: sourceSetupId,
      sourceBatchId: requestedSourceBatchId, originalSetup: runSetup, setup: clone(runSetup),
      originalOperationalFingerprint: D.operationalFingerprintV4(runSetup), operationalFingerprint: D.operationalFingerprintV4(runSetup),
      exactSetupFingerprint: setupFingerprint, runMode: runMode, progressMode: progressMode, jobReference: D.text(source.jobReference, 180),
      quantity: quantity, utcOffsetMinutes: utcOffsetMinutes, phase: "preflight", reservedAt: now, startedAt: now, productionStarted: false, productionStartedAt: "",
      lastEventAt: now, transitionSequence: 0,
      processedCount: 0, firstPieceProcessedCredit: 0, grossCompletedItems: 0, undoneItems: 0, cycleEvents: [],
      resultPendingAt: "", stagePlanFingerprint: timerPlanFingerprint(setup), stageIndex: 0,
      instructionCheckedAt: "", instructionCheckFingerprint: "", firstPiecePolicy: policy,
      instructionReferenceValidatedId: setup.instructionSource.type === "prior_successful_batch" ? setup.instructionSource.priorBatchId : "",
      firstPressedSetup: null, lastPressedSetup: null,
      lastPressedInstructionCheckedAt: "", lastPressedInstructionCheckFingerprint: "",
      lastPressedFirstPiece: null,
      firstPiece: { required: required, outcome: required ? "pending" : "not_required", attempts: 0, attemptedAt: "", completedAt: "", note: "" },
      qcChecks: [], interruptions: [], timer: null, resultDraft: null
    };
    permit.intentFingerprint = runIntentFingerprint(run); Object.freeze(permit);
    const session = sessionSnapshot(run, null, value.session && value.session.setupDraft);
    const dataLimit = value.storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
    const basePayload = { machines: value.machines || [], recipes: recipes, batches: batches, settings: value.settings || null, session: null };
    const fullPayload = Object.assign({}, basePayload, { session: session });
    if (D.utf8ByteLength(JSON.stringify(basePayload)) + reservationBytes > dataLimit ||
        D.utf8ByteLength(JSON.stringify(fullPayload)) > dataLimit) throw new Error("byte_capacity_required");
    return { authorized: true, permit: clone(permit), run: run, session: session };
  }

  function permitValid(run) {
    const permit = run && run.permit;
    const sourceSetupId = run && (run.sourceSetupId || run.sourceRecipeId);
    return Boolean(permit && permit.schemaVersion === PERMIT_SCHEMA_VERSION && permit.state === "reserved" && permit.id &&
      permit.runId === run.id && permit.resultId === run.resultId && permit.setupId === sourceSetupId &&
      permit.setupFingerprint === D.exactSetupFingerprint(run.originalSetup) && permit.reservedAt === run.reservedAt &&
      run.originalOperationalFingerprint === D.operationalFingerprintV4(run.originalSetup) &&
      Number.isInteger(permit.reservedBytes) && permit.reservedBytes >= D.MAX_RECORD_BYTES &&
      permit.intentFingerprint === runIntentFingerprint(run));
  }

  function legacyPermitV2Valid(run) {
    const permit = run && run.permit;
    const sourceSetupId = run && (run.sourceSetupId || run.sourceRecipeId);
    return Boolean(permit && permit.schemaVersion === 2 && permit.state === "reserved" && permit.id &&
      permit.runId === run.id && permit.resultId === run.resultId && permit.setupId === sourceSetupId &&
      permit.setupFingerprint === D.exactSetupFingerprint(run.originalSetup) && permit.reservedAt === run.reservedAt &&
      run.originalOperationalFingerprint === D.operationalFingerprintV4(run.originalSetup) &&
      Number.isInteger(permit.reservedBytes) && permit.reservedBytes >= D.MAX_RECORD_BYTES &&
      permit.intentFingerprint === legacyRunIntentFingerprintV2(run));
  }

  function instructionCheckValid(run) {
    return Boolean(run && run.instructionCheckedAt && run.instructionCheckFingerprint === D.exactSetupFingerprint(run.setup) &&
      run.exactSetupFingerprint === D.exactSetupFingerprint(run.setup));
  }

  function markPressedSetup(run, timestamp) {
    if (!instructionCheckValid(run)) throw new Error("instruction_check_required");
    if (!run.firstPressedSetup) run.firstPressedSetup = D.recipeSnapshot(run.setup);
    run.lastPressedSetup = D.recipeSnapshot(run.setup);
    run.lastPressedInstructionCheckedAt = run.instructionCheckedAt;
    run.lastPressedInstructionCheckFingerprint = run.instructionCheckFingerprint;
    run.lastPressedFirstPiece = clone(run.firstPiece);
    run.productionStarted = true; run.productionStartedAt = run.productionStartedAt || timestamp;
  }

  function enterResultPending(run, timestamp) {
    run.resultPendingAt = run.resultPendingAt || timestamp;
    run.phase = "result_pending";
    return run;
  }

  function buildProcessStages(setupValue) {
    const setup = D.normalizeRecipe(setupValue, setupValue && setupValue.temperatureUnit, true);
    const stages = [];
    const hasExplicitPrepress = setup.steps.some(function (step) { return step.stageType === "prepress"; });
    const hasExplicitPlacement = setup.steps.some(function (step) { return step.stageType === "placement"; });
    const hasExplicitFinish = setup.steps.some(function (step) { return ["peel", "cool", "postpress"].includes(step.stageType); });
    if (!hasExplicitPrepress && Number(setup.prePressSeconds) > 0) {
      stages.push({ key: "legacy-prepress", sourceStepId: "", stageType: "prepress", name: "Pre-press", instruction: "",
        sequence: stages.length + 1, repeat: 1, seconds: Number(setup.prePressSeconds), timed: true });
    }
    setup.steps.forEach(function (step) {
      if (step.stageType === "press" && step.placementAction && !hasExplicitPlacement) {
        stages.push({ key: `${step.id}:placement`, sourceStepId: step.id, stageType: "placement", name: "Placement",
          instruction: step.placementAction, sequence: stages.length + 1, repeat: 1, seconds: 0, timed: false });
      }
      const repeats = step.stageType === "press" ? Math.max(1, Number(step.repeatCount) || 1) : 1;
      for (let repeat = 1; repeat <= repeats; repeat += 1) {
        const seconds = Number(step.durationSeconds);
        stages.push({ key: `${step.id}:${repeat}`, sourceStepId: step.id, stageType: step.stageType, name: step.name,
          instruction: step.instruction, sequence: stages.length + 1, repeat: repeat,
          seconds: Number.isFinite(seconds) && seconds > 0 ? seconds : 0, timed: Number.isFinite(seconds) && seconds > 0,
          machineProfileId: step.machineProfileId, machineNickname: step.machineNickname, platenZone: step.platenZone,
          temperature: step.temperature, temperatureUnit: step.temperatureUnit, pressure: step.pressure });
      }
      if (step.stageType === "press" && step.finishAction && !hasExplicitFinish) {
        stages.push({ key: `${step.id}:finish`, sourceStepId: step.id, stageType: "peel", name: "Finish action",
          instruction: step.finishAction, sequence: stages.length + 1, repeat: 1, seconds: 0, timed: false });
      }
    });
    return stages;
  }

  function timerPlanFingerprint(setup) {
    return `timer-v2:${D.exactSetupFingerprint(setup)}:${JSON.stringify(buildProcessStages(setup).map(function (stage) {
      return [stage.sourceStepId, stage.stageType, stage.repeat, stage.seconds];
    }))}`;
  }

  function createTimer(run, index) {
    if (!instructionCheckValid(run)) throw new Error("instruction_check_required");
    const stages = buildProcessStages(run.setup);
    if (!stages.length) throw new Error("timer_no_stages");
    const selected = integer(index === undefined ? 0 : index, 0, stages.length - 1, "timer_index");
    const totalMs = stages[selected].seconds * 1000;
    return { schemaVersion: 2, runId: run.id, planFingerprint: timerPlanFingerprint(run.setup), stages: stages,
      index: selected, totalMs: totalMs, remainingMs: totalMs, endAt: 0, running: false, completed: !stages[selected].timed,
      notified: false, lastObservedAt: 0 };
  }

  function reconcileTimer(timerValue, now) {
    const timer = clone(timerValue); const instant = Number(now === undefined ? Date.now() : now);
    if (!Number.isFinite(instant)) throw new Error("timer_now");
    const observedInstant = Math.max(Number(timer.lastObservedAt) || instant, instant);
    if (timer.running) {
      timer.remainingMs = Math.min(Number(timer.remainingMs) || timer.totalMs, timer.totalMs,
        Math.max(0, Number(timer.endAt) - observedInstant));
      if (timer.remainingMs === 0) { timer.running = false; timer.completed = true; timer.endAt = 0; }
    }
    timer.lastObservedAt = observedInstant;
    return timer;
  }

  function startTimer(timerValue, now) {
    const timer = reconcileTimer(timerValue, now);
    if (timer.completed || timer.totalMs === 0) return timer;
    timer.running = true; timer.endAt = timer.lastObservedAt + timer.remainingMs; return timer;
  }

  function pauseTimer(timerValue, now) {
    const timer = reconcileTimer(timerValue, now); timer.running = false; timer.endAt = 0; return timer;
  }

  function moveTimer(timerValue, direction) {
    const timer = clone(timerValue); const index = Math.max(0, Math.min(timer.stages.length - 1, timer.index + (direction < 0 ? -1 : 1)));
    const stage = timer.stages[index]; timer.index = index; timer.totalMs = stage.seconds * 1000; timer.remainingMs = timer.totalMs;
    timer.endAt = 0; timer.running = false; timer.completed = !stage.timed; timer.notified = false; return timer;
  }

  function resetTimer(timerValue) {
    const timer = clone(timerValue); const stage = timer.stages[timer.index];
    timer.totalMs = stage.seconds * 1000; timer.remainingMs = timer.totalMs; timer.endAt = 0;
    timer.running = false; timer.completed = !stage.timed; timer.notified = false; return timer;
  }

  function completedTimerPlan(timer) {
    return Boolean(timer && timer.completed === true && Array.isArray(timer.stages) &&
      timer.stages.length > 0 && timer.index === timer.stages.length - 1);
  }

  function restartTimerPlan(timerValue) {
    const timer = clone(timerValue); const stage = timer.stages[0];
    timer.index = 0; timer.totalMs = stage.seconds * 1000; timer.remainingMs = timer.totalMs;
    timer.endAt = 0; timer.running = false; timer.completed = !stage.timed;
    timer.notified = false; timer.lastObservedAt = 0; return timer;
  }

  function transitionRun(runValue, eventValue) {
    const run = clone(runValue); const event = eventValue || {}; const type = D.text(event.type, 80);
    if (!permitValid(run) && !["COMMIT_SUCCEEDED", "RELEASE_PERMIT"].includes(type)) throw new Error("run_permit_invalid");
    if (["completed", "aborted_before_start"].includes(run.phase)) throw new Error("run_terminal");
    const requestedTimestamp = atIso(event.at);
    const floorTime = Math.max(new Date(run.reservedAt).getTime(), run.lastEventAt ? new Date(run.lastEventAt).getTime() : -Infinity);
    const requestedTime = new Date(requestedTimestamp).getTime();
    const clockRollbackDetected = requestedTime < floorTime;
    const timestamp = new Date(Math.max(requestedTime, floorTime)).toISOString();
    const priorSequence = run.transitionSequence === undefined ? 0 : Number(run.transitionSequence);
    if (!Number.isInteger(priorSequence) || priorSequence < 0 || priorSequence >= Number.MAX_SAFE_INTEGER) throw new Error("run_sequence");
    run.transitionSequence = priorSequence + 1; run.lastEventAt = timestamp;
    if (clockRollbackDetected) run.clockRollbackDetected = true;

    function closeOpenInterruptions() {
      run.interruptions = (run.interruptions || []).map(function (item) {
        return item.endedAt ? item : Object.assign({}, item, { endedAt: timestamp });
      });
    }

    if (["CONFIRM_INSTRUCTIONS", "ACKNOWLEDGE_LEGACY_RESUME"].includes(type)) {
      if (run.phase !== "preflight") throw new Error("run_transition");
      if (event.confirmed !== true) throw new Error("instruction_check_required");
      if (run.legacyGrandfathered === true && run.resumeResultPending === true && run.productionStarted === true) {
        run.instructionCheckedAt = timestamp; run.instructionCheckFingerprint = D.exactSetupFingerprint(run.setup);
        run.exactSetupFingerprint = run.instructionCheckFingerprint;
        run.lastPressedSetup = D.recipeSnapshot(run.setup);
        run.lastPressedInstructionCheckedAt = run.instructionCheckedAt;
        run.lastPressedInstructionCheckFingerprint = run.instructionCheckFingerprint;
        run.lastPressedFirstPiece = clone(run.firstPiece);
        const openLegacy = run.interruptions[run.interruptions.length - 1];
        if (openLegacy && !openLegacy.endedAt) openLegacy.endedAt = timestamp;
        return enterResultPending(run, timestamp);
      }
      const runnableErrors = D.validateRunnableRecipe(run.setup, timestamp, run.utcOffsetMinutes);
      if (runnableErrors.length) throw Object.assign(new Error("setup_not_runnable"), { fields: runnableErrors });
      if (!D.instructionSourceChecked(run.setup.instructionSource)) throw new Error("instruction_source_required");
      if (run.setup.instructionSource.type === "prior_successful_batch" &&
          run.instructionReferenceValidatedId !== run.setup.instructionSource.priorBatchId) throw new Error("instruction_reference");
      run.instructionCheckedAt = timestamp; run.instructionCheckFingerprint = D.exactSetupFingerprint(run.setup);
      run.exactSetupFingerprint = run.instructionCheckFingerprint;
      if (run.resumeResultPending === true) return enterResultPending(run, timestamp);
      run.phase = run.firstPiece.required && run.firstPiece.outcome !== "pass" ? "first_piece" : "production_ready";
      return run;
    }

    if (type === "EDIT_SETUP") {
      if (!event.setup || ["result_pending", "committing"].includes(run.phase)) throw new Error("run_transition");
      if (run.phase === "paused") closeOpenInterruptions();
      let setup = D.normalizeRecipe(event.setup, event.setup.temperatureUnit, true);
      const errors = D.validateRunnableRecipe(setup, timestamp, run.utcOffsetMinutes); if (errors.length) throw Object.assign(new Error("setup_not_runnable"), { fields: errors });
      if (setup.instructionSource.type === "prior_successful_batch" &&
          setup.instructionSource.priorBatchId !== run.instructionReferenceValidatedId) {
        const prior = event.instructionSourceBatch;
        const byId = new Map(prior && prior.id ? [[prior.id, prior]] : []);
        if (!D.instructionReferenceValid(setup, byId, run.startedAt, run.resultId)) throw new Error("instruction_reference");
        run.instructionReferenceValidatedId = setup.instructionSource.priorBatchId;
      } else if (setup.instructionSource.type !== "prior_successful_batch") run.instructionReferenceValidatedId = "";
      const changed = D.operationalFingerprintV4(run.setup) !== D.operationalFingerprintV4(setup) ||
        D.provenanceFingerprint(run.setup) !== D.provenanceFingerprint(setup);
      if (changed) setup = D.normalizeRecipe(Object.assign({}, setup, {
        status: "trial", verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0,
        persistedOperationalFingerprintV4: D.operationalFingerprintV4(setup)
      }), setup.temperatureUnit, true);
      run.setup = D.recipeSnapshot(setup); run.operationalFingerprint = D.operationalFingerprintV4(setup);
      run.exactSetupFingerprint = D.exactSetupFingerprint(setup);
      if (changed) {
        run.instructionCheckedAt = ""; run.instructionCheckFingerprint = ""; run.timer = null; run.resultDraft = null;
        run.stagePlanFingerprint = timerPlanFingerprint(setup); run.stageIndex = 0;
        run.firstPiece = { required: true, outcome: "pending", attempts: run.firstPiece.attempts || 0,
          attemptedAt: run.firstPiece.attemptedAt || "", completedAt: "", note: "" };
        run.phase = "preflight";
      }
      return run;
    }

    if (["TIMER_INITIALIZE", "TIMER_START", "TIMER_PAUSE", "TIMER_TICK", "TIMER_NEXT", "TIMER_PREVIOUS", "TIMER_RESET", "TIMER_RESTART_PLAN"].includes(type)) {
      if (!["first_piece", "production_ready", "running", "paused"].includes(run.phase) || !instructionCheckValid(run)) throw new Error("run_transition");
      if (type === "TIMER_INITIALIZE") run.timer = createTimer(run, event.index);
      else {
        if (!run.timer || run.timer.runId !== run.id || run.timer.planFingerprint !== timerPlanFingerprint(run.setup)) throw new Error("timer_stale");
        const instant = new Date(timestamp).getTime();
      if (type === "TIMER_START") {
          run.timer = startTimer(run.timer, instant);
          const stage = run.timer.stages[run.timer.index];
          if (["prepress", "press", "postpress"].includes(stage.stageType)) {
            markPressedSetup(run, timestamp);
            if (run.runMode === "production" && run.phase === "production_ready") run.phase = "running";
          }
        } else if (type === "TIMER_PAUSE") run.timer = pauseTimer(run.timer, instant);
        else if (type === "TIMER_TICK") run.timer = reconcileTimer(run.timer, instant);
        else if (type === "TIMER_NEXT") {
          run.timer = reconcileTimer(run.timer, instant);
          if (!run.timer.completed) throw new Error("timer_stage_incomplete");
          run.timer = moveTimer(run.timer, 1);
        } else if (type === "TIMER_PREVIOUS") run.timer = moveTimer(run.timer, -1);
        else if (type === "TIMER_RESET") run.timer = resetTimer(run.timer);
        else if (type === "TIMER_RESTART_PLAN") run.timer = restartTimerPlan(run.timer);
      }
      run.stageIndex = run.timer.index; return run;
    }

    if (type === "RECORD_FIRST_PIECE") {
      if (run.phase !== "first_piece" || !instructionCheckValid(run)) throw new Error("run_transition");
      if (!["pass", "adjust_retry", "stop"].includes(event.outcome)) throw new Error("first_piece_outcome");
      if (!completedTimerPlan(run.timer)) throw new Error("timer_plan_incomplete");
      run.firstPiece.attempts = integer((run.firstPiece.attempts || 0) + 1, 1, 99, "first_piece_attempts");
      run.firstPiece.attemptedAt = run.firstPiece.attemptedAt || timestamp; run.firstPiece.outcome = event.outcome;
      run.firstPiece.completedAt = timestamp; run.firstPiece.note = D.text(event.note, 1000);
      markPressedSetup(run, timestamp);
      run.firstPieceProcessedCredit = Math.max(Number(run.firstPieceProcessedCredit || 0), 1);
      run.processedCount = Math.max(run.processedCount, 1);
      if (event.outcome === "pass") {
        if (run.runMode === "test") return enterResultPending(run, timestamp);
        run.timer = restartTimerPlan(run.timer); run.stageIndex = 0; run.phase = "production_ready";
      }
      else if (event.outcome === "adjust_retry") {
        run.instructionCheckedAt = ""; run.instructionCheckFingerprint = ""; run.timer = null; run.phase = "preflight";
      } else return enterResultPending(run, timestamp);
      return run;
    }

    if (type === "START_PRODUCTION") {
      if (run.phase !== "production_ready" || !instructionCheckValid(run) ||
          (run.firstPiece.required && run.firstPiece.outcome !== "pass")) throw new Error("run_transition");
      markPressedSetup(run, timestamp);
      if (!run.timer) run.timer = createTimer(run, 0);
      else run.timer = restartTimerPlan(run.timer);
      run.stageIndex = 0; run.phase = "running"; return run;
    }
    if (type === "RECORD_PROGRESS") {
      if (run.schemaVersion >= 4 && run.legacyGrandfathered !== true) throw new Error("complete_cycle_required");
      if (!run.productionStarted || !["running", "paused"].includes(run.phase)) throw new Error("run_transition");
      const processed = integer(event.processedCount, 0, run.quantity, "processedCount");
      if (processed < run.processedCount) throw new Error("processedCount");
      if (processed > run.processedCount) {
        const delta = processed - run.processedCount;
        run.cycleEvents = (run.cycleEvents || []).concat({ id: D.uuid(), type: "complete", items: delta,
          at: timestamp, targetEventId: "", migratedProgress: true });
        run.grossCompletedItems = Number(run.grossCompletedItems || 0) + delta;
        markPressedSetup(run, timestamp);
      }
      run.processedCount = processed; return run;
    }
    if (type === "COMPLETE_CYCLE") {
      if (run.progressMode !== "live_cycles" || !run.productionStarted || run.phase !== "running" ||
          !instructionCheckValid(run) || event.cycleComplete !== true) throw new Error("run_transition");
      if (!completedTimerPlan(run.timer)) throw new Error("timer_plan_incomplete");
      const items = integer(event.items === undefined ? 1 : event.items, 1, run.quantity, "cycle_items");
      if (run.processedCount + items > run.quantity) throw new Error("processedCount");
      const cycle = { id: D.uuid(), type: "complete", items: items, at: timestamp, targetEventId: "" };
      run.cycleEvents = (run.cycleEvents || []).concat(cycle); run.grossCompletedItems = Number(run.grossCompletedItems || 0) + items;
      run.processedCount += items; markPressedSetup(run, timestamp);
      run.timer = restartTimerPlan(run.timer); run.stageIndex = 0;
      return run;
    }
    if (type === "UNDO_CYCLE") {
      if (run.progressMode !== "live_cycles" || run.resultDraft || !["running", "paused"].includes(run.phase)) throw new Error("run_transition");
      const events = run.cycleEvents || []; const undone = new Set(events.filter(function (item) { return item.type === "undo"; })
        .map(function (item) { return item.targetEventId; }));
      const target = events.slice().reverse().find(function (item) { return item.type === "complete" && !undone.has(item.id); });
      if (!target || event.targetEventId && event.targetEventId !== target.id) throw new Error("undo_cycle");
      const floor = Math.max(Number(run.firstPieceProcessedCredit || 0),
        ...(run.qcChecks || []).map(function (check) { return Number(check.processedCount) || 0; }));
      if (run.processedCount - target.items < floor) throw new Error("undo_cycle");
      run.cycleEvents = events.concat({ id: D.uuid(), type: "undo", items: target.items, at: timestamp, targetEventId: target.id });
      run.undoneItems = Number(run.undoneItems || 0) + target.items; run.processedCount -= target.items; return run;
    }
    if (type === "PAUSE") {
      if (run.phase !== "running") throw new Error("run_transition");
      if (run.interruptions.length >= 100) throw new Error("interruption_limit");
      if (run.timer && run.timer.running) run.timer = pauseTimer(run.timer, new Date(timestamp).getTime());
      run.phase = "paused"; run.interruptions.push({ startedAt: timestamp, endedAt: "", reason: D.text(event.reason, 500), productionBegan: true }); return run;
    }
    if (type === "RESUME") {
      if (run.phase !== "paused") throw new Error("run_transition");
      const open = run.interruptions[run.interruptions.length - 1]; if (open && !open.endedAt) open.endedAt = timestamp;
      run.phase = "running"; return run;
    }
    if (type === "RECORD_QC") {
      if (!run.productionStarted || !["running", "paused"].includes(run.phase) || !["pass", "adjust", "end_early"].includes(event.result)) throw new Error("run_transition");
      if (run.qcChecks.length >= 100) throw new Error("qc_limit");
      run.qcChecks.push({ checkedAt: timestamp, processedCount: run.processedCount, result: event.result, note: D.text(event.note, 1000) });
      if (event.result === "adjust") {
        if (run.timer && run.timer.running) run.timer = pauseTimer(run.timer, new Date(timestamp).getTime());
        const open = run.interruptions.slice().reverse().find(function (item) { return !item.endedAt; });
        if (open) open.reason = open.reason || "qc_adjustment";
        else {
          if (run.interruptions.length >= 100) throw new Error("interruption_limit");
          run.interruptions.push({ startedAt: timestamp, endedAt: "", reason: "qc_adjustment", productionBegan: true });
        }
        run.phase = "paused";
      }
      if (event.result === "end_early") {
        if (run.timer && run.timer.running) run.timer = pauseTimer(run.timer, new Date(timestamp).getTime());
        closeOpenInterruptions();
        return enterResultPending(run, timestamp);
      }
      return run;
    }
    if (type === "END_RUN") {
      if (!run.productionStarted) throw new Error("discard_unstarted_or_resume");
      if (qcDueForRun(run)) throw new Error("qc_required");
      if (event.reason === "operator_finish" &&
          (run.progressMode === "live_cycles" && run.processedCount !== run.quantity ||
           run.progressMode === "final_confirmation" && !completedTimerPlan(run.timer))) {
        throw new Error("timer_plan_incomplete");
      }
      if (!run.lastPressedSetup || !run.lastPressedInstructionCheckedAt || !run.lastPressedInstructionCheckFingerprint) throw new Error("instruction_check_required");
      run.setup = D.recipeSnapshot(run.lastPressedSetup); run.operationalFingerprint = D.operationalFingerprintV4(run.setup);
      run.exactSetupFingerprint = D.exactSetupFingerprint(run.setup); run.instructionCheckedAt = run.lastPressedInstructionCheckedAt;
      run.instructionCheckFingerprint = run.lastPressedInstructionCheckFingerprint;
      if (run.lastPressedFirstPiece) run.firstPiece = clone(run.lastPressedFirstPiece);
      run.stagePlanFingerprint = timerPlanFingerprint(run.setup); run.stageIndex = 0; run.timer = null;
      closeOpenInterruptions();
      if (run.timer && run.timer.running) run.timer = pauseTimer(run.timer, new Date(timestamp).getTime());
      if (event.reason) {
        if (run.interruptions.length >= 100) throw new Error("interruption_limit");
        run.interruptions.push({ startedAt: timestamp, endedAt: timestamp, reason: D.text(event.reason, 500), productionBegan: true });
      }
      if (run.firstPiece && run.firstPiece.outcome === "pending") {
        run.firstPiece.outcome = "stop"; run.firstPiece.attempts = Math.max(1, Number(run.firstPiece.attempts) || 0);
        run.firstPiece.attemptedAt = run.firstPiece.attemptedAt || run.productionStartedAt || timestamp;
        run.firstPiece.completedAt = timestamp;
      }
      return enterResultPending(run, timestamp);
    }
    if (type === "DISCARD_UNSTARTED") {
      if (run.productionStarted || event.confirmed !== true) throw new Error("started_run_must_record");
      run.permit.state = "released"; run.permit.releasedAt = timestamp; run.phase = "aborted_before_start"; return run;
    }
    if (type === "SAVE_RESULT_DRAFT") {
      if (run.phase !== "result_pending" || !run.productionStarted || !instructionCheckValid(run)) throw new Error("run_transition");
      run.resultDraft = buildResultDraftEnvelope(run, event.result || {}, timestamp, false); return run;
    }
    if (type === "CONFIRM_ALL_GOOD") {
      if (run.phase !== "result_pending" || !run.productionStarted || !instructionCheckValid(run)) throw new Error("result_state");
      const confirmed = integer(event.confirmedPlannedQuantity, 1, 999999, "confirmedPlannedQuantity");
      if (event.explicitConfirmation !== true || confirmed !== run.quantity) throw new Error("all_good_confirmation");
      if (run.progressMode === "live_cycles" && run.processedCount !== run.quantity) throw new Error("live_count_incomplete");
      run.resultDraft = buildResultDraftEnvelope(run, { quantityProcessed: run.quantity, quantityWaste: 0,
        quantityReworked: 0, issues: [], notes: event.notes, saveChoice: event.saveChoice,
        variantTitle: event.variantTitle }, timestamp, true); return run;
    }
    if (type === "BEGIN_COMMIT") {
      if (run.phase !== "result_pending" || !validResultDraft(run, run.resultDraft)) throw new Error("result_draft_required");
      run.phase = "committing"; return run;
    }
    if (type === "COMMIT_FAILED") {
      if (run.phase !== "committing") throw new Error("run_transition");
      run.phase = "result_pending"; run.lastCommitError = D.text(event.code, 120); return run;
    }
    if (type === "COMMIT_SUCCEEDED") {
      if (run.phase !== "committing" && run.phase !== "result_pending") throw new Error("run_transition");
      run.permit.state = "consumed"; run.permit.consumedAt = timestamp; run.phase = "completed"; return run;
    }
    throw new Error("run_event");
  }

  function resultDraft(run, overrides) {
    const source = Object.assign({
      quantityProcessed: run.runMode === "test" && run.firstPiece.outcome === "pass" ? 1 : Number(run.processedCount || 0),
      quantityWaste: 0, quantityReworked: 0, issues: [], notes: "", saveChoice: "batch_only"
    }, overrides || {});
    source.quantityPlanned = run.quantity;
    source.quantityProcessed = integer(source.quantityProcessed, 0, run.quantity, "quantityProcessed");
    source.quantityWaste = integer(source.quantityWaste, 0, source.quantityProcessed, "quantityWaste");
    source.quantityGood = source.quantityProcessed - source.quantityWaste;
    source.quantityReworked = integer(source.quantityReworked, 0, source.quantityGood, "quantityReworked");
    source.firstPassGood = source.quantityGood - source.quantityReworked;
    source.notProcessed = source.quantityPlanned - source.quantityProcessed;
    source.outcome = D.deriveOutcome(source.quantityPlanned, source.quantityProcessed, source.quantityWaste, source.quantityReworked);
    source.completedAt = atIso(source.completedAt || run.resultPendingAt || run.lastEventAt);
    source.saveChoice = SAVE_CHOICES.has(source.saveChoice) ? source.saveChoice : "batch_only";
    source.issues = (source.issues || []).map(function (issue) { return D.normalizeIssue(issue, Boolean(issue && issue.id)); });
    return { quantityPlanned: source.quantityPlanned, quantityProcessed: source.quantityProcessed,
      quantityGood: source.quantityGood, quantityWaste: source.quantityWaste, quantityReworked: source.quantityReworked,
      firstPassGood: source.firstPassGood, notProcessed: source.notProcessed, outcome: source.outcome,
      issues: source.issues, notes: D.text(source.notes, 5000), completedAt: source.completedAt,
      saveChoice: source.saveChoice };
  }

  function resultDraftContentFingerprint(draft) {
    return `sha256:${D.sha256(JSON.stringify([
      draft.schemaVersion, draft.revision, draft.savedAt,
      draft.runId, draft.resultId, draft.completedAt, draft.quantityPlanned, draft.quantityProcessed,
      draft.quantityGood, draft.quantityWaste, draft.quantityReworked, draft.firstPassGood, draft.notProcessed,
      draft.outcome, draft.issues, draft.notes, draft.saveChoice, draft.variantTitle, draft.resultKind,
      draft.confirmationFingerprint,
      draft.setupFingerprint, draft.instructionCheckFingerprint
    ]))}`;
  }

  function validateResultFacts(run, result) {
    const planned = integer(result.quantityPlanned, 1, 999999, "quantityPlanned");
    const processed = integer(result.quantityProcessed, 0, planned, "quantityProcessed");
    const waste = integer(result.quantityWaste, 0, processed, "quantityWaste");
    const good = integer(result.quantityGood, 0, processed, "quantityGood");
    const reworkedCount = integer(result.quantityReworked, 0, good, "quantityReworked");
    if (planned !== run.quantity || good !== processed - waste || result.firstPassGood !== good - reworkedCount ||
        result.notProcessed !== planned - processed || result.outcome !== D.deriveOutcome(planned, processed, waste, reworkedCount) ||
        !SAVE_CHOICES.has(result.saveChoice) || D.text(result.notes, 5000) !== result.notes || !Array.isArray(result.issues) ||
        result.issues.some(function (issue) { return JSON.stringify(issue) !== JSON.stringify(D.normalizeIssue(issue, true)); })) {
      throw new Error("result_validation");
    }
    const recordedProgress = Math.max(Number(run.processedCount) || 0,
      ...(run.qcChecks || []).map(function (check) { return Number(check.processedCount) || 0; }));
    if (result.quantityProcessed < recordedProgress) throw new Error("progress_result_mismatch");
    if (["stop", "adjust_retry"].includes(run.firstPiece.outcome) && result.outcome === "success") throw new Error("exception_result_required");
    if (run.firstPiece.attempts > 1 && result.quantityWaste === 0 && result.quantityReworked === 0 && !result.issues.length) {
      throw new Error("exception_result_required");
    }
    const discarded = result.issues.filter(function (issue) { return issue.disposition === "discarded"; })
      .reduce(function (sum, issue) { return sum + issue.quantity; }, 0);
    const reworked = result.issues.filter(function (issue) { return issue.disposition === "reworked"; })
      .reduce(function (sum, issue) { return sum + issue.quantity; }, 0);
    if (discarded !== result.quantityWaste || reworked !== result.quantityReworked) throw new Error("issue_coverage");
    if (result.completedAt !== run.resultPendingAt) throw new Error("completedAt");
  }

  function buildResultDraftEnvelope(run, raw, savedAt, allGoodConfirmed) {
    if (raw && Array.isArray(raw.issues) && raw.issues.length > D.MAX_ISSUES) throw new Error("issue_limit");
    const result = resultDraft(run, Object.assign({}, raw, { completedAt: run.resultPendingAt }));
    const effectiveSavedAt = new Date(savedAt).getTime() < new Date(run.resultPendingAt).getTime() ? run.resultPendingAt : savedAt;
    validateResultFacts(run, result);
    const previous = run.resultDraft;
    const draft = Object.assign({}, result, {
      schemaVersion: RESULT_DRAFT_SCHEMA_VERSION, runId: run.id, resultId: run.resultId,
      revision: previous ? previous.revision + 1 : 1, savedAt: atIso(effectiveSavedAt),
      variantTitle: D.text(raw && raw.variantTitle, 140), setupFingerprint: D.exactSetupFingerprint(run.setup),
      instructionCheckFingerprint: run.instructionCheckFingerprint,
      resultKind: allGoodConfirmed === true ? "all_good" : allGoodConfirmed === "legacy_migrated" ? "legacy_migrated" : "exception",
      confirmationFingerprint: allGoodConfirmed === true ? `sha256:${D.sha256(JSON.stringify([
        run.id, run.resultId, run.quantity, run.resultPendingAt, true
      ]))}` : "", contentFingerprint: ""
    });
    if (draft.outcome === "success" && draft.quantityProcessed === draft.quantityPlanned &&
        draft.quantityWaste === 0 && draft.quantityReworked === 0 && !draft.issues.length && allGoodConfirmed === false) {
      throw new Error("all_good_confirmation");
    }
    draft.contentFingerprint = resultDraftContentFingerprint(draft);
    return Object.freeze(draft);
  }

  function validResultDraft(run, draft) {
    try {
      const cleanAllGoodFacts = Boolean(draft && draft.outcome === "success" &&
        draft.quantityProcessed === draft.quantityPlanned && draft.quantityProcessed === run.quantity &&
        draft.quantityGood === draft.quantityProcessed && draft.quantityWaste === 0 &&
        draft.quantityReworked === 0 && Array.isArray(draft.issues) && draft.issues.length === 0);
      const keys = ["schemaVersion", "runId", "resultId", "revision", "savedAt", "completedAt", "quantityPlanned",
        "quantityProcessed", "quantityGood", "quantityWaste", "quantityReworked", "firstPassGood", "notProcessed",
        "outcome", "issues", "notes", "saveChoice", "variantTitle", "setupFingerprint",
        "instructionCheckFingerprint", "resultKind", "confirmationFingerprint", "contentFingerprint"];
    if (!draft || draft.schemaVersion !== RESULT_DRAFT_SCHEMA_VERSION || draft.runId !== run.id ||
          Object.keys(draft).length !== keys.length || keys.some(function (key) { return !Object.prototype.hasOwnProperty.call(draft, key); }) ||
          draft.resultId !== run.resultId || !Number.isInteger(draft.revision) || draft.revision < 1 ||
          new Date(draft.savedAt).getTime() < new Date(run.resultPendingAt).getTime() ||
          draft.setupFingerprint !== D.exactSetupFingerprint(run.setup) ||
          draft.instructionCheckFingerprint !== run.instructionCheckFingerprint ||
          !["all_good", "exception", "legacy_migrated"].includes(draft.resultKind) ||
          (draft.resultKind === "all_good") !== Boolean(draft.confirmationFingerprint) ||
          (draft.resultKind !== "legacy_migrated" && (draft.resultKind === "all_good") !== cleanAllGoodFacts) ||
          (draft.resultKind === "legacy_migrated" && !(run.legacyGrandfathered === true || run.migratedFromSessionSchema === 3 ||
            run.permit && run.permit.authorizationBasis === "legacy_migration")) ||
          (draft.resultKind === "all_good" && draft.confirmationFingerprint !== `sha256:${D.sha256(JSON.stringify([
            run.id, run.resultId, run.quantity, run.resultPendingAt, true
          ]))}`) ||
          draft.contentFingerprint !== resultDraftContentFingerprint(draft)) return false;
      validateResultFacts(run, draft); return true;
    } catch (_) { return false; }
  }

  function saveResultDraft(runValue, raw, at) {
    return transitionRun(runValue, { type: "SAVE_RESULT_DRAFT", result: raw, at: at });
  }

  function confirmAllGood(runValue, confirmation, at) {
    const source = confirmation || {};
    return transitionRun(runValue, { type: "CONFIRM_ALL_GOOD", confirmedPlannedQuantity: source.confirmedPlannedQuantity,
      explicitConfirmation: source.explicitConfirmation, notes: source.notes, saveChoice: source.saveChoice,
      variantTitle: source.variantTitle, at: at });
  }

  function planDiscardUnstarted(runValue, at) {
    const run = transitionRun(runValue, { type: "DISCARD_UNSTARTED", confirmed: true, at: at });
    return { run: run, releasedPermit: clone(run.permit), clearSession: true,
      mutation: { releasePermitId: run.permit.id, clearSession: true } };
  }

  function isQualifyingEvidence(batch, setup, allBatches) {
    const batchById = new Map((allBatches || []).map(function (item) { return [item.id, item]; }));
    return Boolean(batch && setup && D.evidenceAfterProofReset(setup, batch) && batch.processSchemaVersion === 4 && batch.recipeId === setup.id && D.validateBatch(batch).length === 0 && batch.reviewStatus === "complete" &&
      batch.outcome === "success" && batch.quantityProcessed === batch.quantityPlanned && batch.quantityGood === batch.quantityPlanned &&
      batch.quantityWaste === 0 && batch.quantityReworked === 0 && Array.isArray(batch.issues) && batch.issues.length === 0 &&
      batch.setupChangedDuringRun === false && batch.authorizationBasis !== "legacy_migration" &&
      D.validateRunnableRecipe(setup).length === 0 && D.instructionSourceChecked(setup.instructionSource) &&
      (!batch.firstPiece || batch.firstPiece.outcome === "not_required" || batch.firstPiece.outcome === "pass") &&
      D.instructionReferenceValid(setup, batchById, batch.startedAt || batch.completedAt, batch.id) &&
      batch.instructionCheckedAt && batch.instructionCheckFingerprint === D.exactSetupFingerprint(batch.recipe) &&
      D.exactSetupFingerprint(setup) === D.exactSetupFingerprint(batch.recipe));
  }

  function recomputeProvenSetups(recipesValue, batchesValue, now) {
    let batches = D.canonicalizeBatchVerifications((batchesValue || []).map(function (batch) { return D.normalizeBatch(batch, true); }));
    const timestamp = atIso(now);
    const recipes = (recipesValue || []).map(function (recipeValue) {
      const recipe = D.normalizeRecipe(recipeValue, recipeValue && recipeValue.temperatureUnit, true);
      const before = [recipe.status, recipe.verifiedAt, recipe.verifiedBatchId, recipe.provenEvidenceCount,
        recipe.persistedOperationalFingerprintV4].join("|");
      const evidence = batches.filter(function (batch) {
        return batch.recipeId === recipe.id && isQualifyingEvidence(batch, recipe, batches);
      }).sort(function (left, right) { return new Date(right.completedAt) - new Date(left.completedAt); });
      if (evidence.length && !recipe.archived) {
        recipe.status = "verified"; recipe.verifiedAt = evidence[0].completedAt; recipe.verifiedBatchId = evidence[0].id;
      } else if (recipe.status === "verified") {
        recipe.status = D.validateRunnableRecipe(recipe).length ? "draft" : "trial"; recipe.verifiedAt = ""; recipe.verifiedBatchId = "";
      }
      recipe.provenEvidenceCount = evidence.length;
      recipe.persistedOperationalFingerprintV4 = D.operationalFingerprintV4(recipe);
      const after = [recipe.status, recipe.verifiedAt, recipe.verifiedBatchId, recipe.provenEvidenceCount,
        recipe.persistedOperationalFingerprintV4].join("|");
      if (before !== after) recipe.updatedAt = D.recipeMutationTime(recipe, timestamp);
      return D.normalizeRecipe(recipe, recipe.temperatureUnit, true);
    });
    batches = batches.map(function (batch) {
      if (!batch.recipe || batch.recipe.status !== "verified") return batch;
      const ownerRecipe = batch.recipe;
      const ownerBoundary = new Date(batch.startedAt || batch.completedAt).getTime();
      const historicalEvidence = batches.filter(function (item) {
        const completed = new Date(item.completedAt).getTime();
        return item.recipeId === batch.recipeId && Number.isFinite(completed) && (item.id === batch.id || completed <= ownerBoundary) &&
          isQualifyingEvidence(item, ownerRecipe, batches);
      }).sort(function (left, right) { return new Date(right.completedAt) - new Date(left.completedAt); });
      if (historicalEvidence.length) {
        const evidence = historicalEvidence[0];
        return D.normalizeBatch(Object.assign({}, batch, { recipe: Object.assign({}, batch.recipe, {
          status: "verified", verifiedAt: evidence.completedAt, verifiedBatchId: evidence.id,
          provenEvidenceCount: historicalEvidence.length, persistedOperationalFingerprintV4: D.operationalFingerprintV4(ownerRecipe)
        }) }), true);
      }
      return D.normalizeBatch(Object.assign({}, batch, { recipe: Object.assign({}, batch.recipe, {
        status: "trial", verifiedAt: "", verifiedBatchId: ""
      }) }), true);
    });
    return { setups: recipes, recipes: recipes, batches: batches };
  }

  function proofSummary(setup, batches) {
    const value = D.normalizeRecipe(setup, setup && setup.temperatureUnit, true);
    const matches = (batches || []).filter(function (batch) { return batch.recipeId === value.id && isQualifyingEvidence(batch, value, batches || []); });
    return Object.freeze({ sourceChecked: D.instructionSourceChecked(value.instructionSource), sourceCheckedDate: value.instructionSource.checkedDate,
      proven: matches.length > 0, cleanMatchingBatches: matches.length, publicStatus: value.archived ? "archived" : matches.length ? "proven" : D.publicSetupStatus(value) });
  }

  function batchMatchesResultDraft(batch, draft) {
    return Boolean(batch && draft && batch.id === draft.resultId && batch.completedAt === draft.completedAt &&
      batch.quantityPlanned === draft.quantityPlanned && batch.quantityProcessed === draft.quantityProcessed &&
      batch.quantityGood === draft.quantityGood && batch.quantityWaste === draft.quantityWaste &&
      batch.quantityReworked === draft.quantityReworked && batch.outcome === draft.outcome &&
      batch.notes === draft.notes && JSON.stringify(batch.issues || []) === JSON.stringify(draft.issues || []));
  }

  function planResultCommit(context, runValue, rawResult) {
    const value = context || {}; const run = clone(runValue);
    if (!permitValid(run)) throw new Error("run_permit_invalid");
    if (run.phase !== "result_pending" && run.phase !== "committing") throw new Error("result_state");
    if (!run.productionStarted || !instructionCheckValid(run)) throw new Error("instruction_check_required");
    if (!validResultDraft(run, run.resultDraft)) throw new Error("result_draft_required");
    if (rawResult && JSON.stringify(rawResult) !== JSON.stringify(run.resultDraft)) throw new Error("result_draft_mismatch");
    const recipes = clone(setupsOf(value)); const batches = clone(value.batches || []);
    const alreadySaved = batches.find(function (batch) { return batch.id === run.resultId; });
    if (alreadySaved) {
      if (D.validateBatch(alreadySaved).length || alreadySaved.startedAt !== run.startedAt ||
          alreadySaved.exactSetupFingerprint !== D.exactSetupFingerprint(run.setup) ||
          alreadySaved.instructionCheckFingerprint !== run.instructionCheckFingerprint ||
          !batchMatchesResultDraft(alreadySaved, run.resultDraft)) throw new Error("result_id_conflict");
      const canonicalExisting = recomputeProvenSetups(recipes, batches, alreadySaved.completedAt);
      const existingBatch = canonicalExisting.batches.find(function (batch) { return batch.id === run.resultId; });
      const existingSetup = canonicalExisting.recipes.find(function (recipe) { return recipe.id === existingBatch.recipeId; }) || null;
      return { batch: existingBatch, setup: existingSetup, recipe: existingSetup,
        setups: canonicalExisting.recipes, recipes: canonicalExisting.recipes, batches: canonicalExisting.batches, warnings: [], alreadyCommitted: true,
        consumedPermit: Object.assign({}, run.permit, { state: "consumed", consumedAt: existingBatch.completedAt }),
        mutation: { putSetups: canonicalExisting.recipes, putBatches: [existingBatch], consumePermitId: run.permit.id,
          commitProof: { permitId: run.permit.id, runId: run.id, resultId: run.resultId,
            draftRevision: run.resultDraft.revision, resultDraftFingerprint: run.resultDraft.contentFingerprint },
          clearSession: true }, clearSession: true };
    }
    const result = clone(run.resultDraft);
    const recordedProgress = Math.max(Number(run.processedCount) || 0, ...(run.qcChecks || []).map(function (check) { return Number(check.processedCount) || 0; }));
    if (result.quantityProcessed < recordedProgress) throw new Error("progress_result_mismatch");
    if (["stop", "adjust_retry"].includes(run.firstPiece.outcome) && result.outcome === "success") throw new Error("exception_result_required");
    if (run.firstPiece.attempts > 1 && result.quantityWaste === 0 && result.quantityReworked === 0 && !(result.issues || []).length) {
      throw new Error("exception_result_required");
    }
    if (new Date(result.completedAt).getTime() < new Date(run.startedAt).getTime()) throw new Error("completedAt");
    const sourceSetupId = run.sourceSetupId || run.sourceRecipeId;
    const live = recipes.find(function (item) { return item.id === sourceSetupId; }) || null;
    const legacyResult = run.legacyGrandfathered === true || run.permit.authorizationBasis === "legacy_migration" ||
      result.resultKind === "legacy_migrated";
    let actual = D.normalizeRecipe(run.setup, run.setup.temperatureUnit, true);
    if (legacyResult) {
      actual = D.normalizeRecipe(Object.assign({}, actual, {
        status: "draft", verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0,
        persistedOperationalFingerprintV4: D.operationalFingerprintV4(actual)
      }), actual.temperatureUnit, true);
    }
    if (!D.instructionReferenceValid(actual, new Map(batches.map(function (item) { return [item.id, item]; })), run.startedAt, run.resultId)) {
      throw new Error("instruction_reference");
    }
    const changed = !live || D.operationalFingerprintV4(live) !== D.operationalFingerprintV4(actual) ||
      D.provenanceFingerprint(live) !== D.provenanceFingerprint(actual);
    let saveChoice = result.saveChoice; const warnings = [];
    if (legacyResult) {
      // A recovered v0.19 run may lack v4 machine/provenance fields. Preserve
      // the separately migrated live setup and record only the auditable batch.
      saveChoice = "batch_only";
      warnings.push("legacy_setup_preserved");
    }
    if (!changed) saveChoice = "update_recipe";
    if (legacyResult) saveChoice = "batch_only";
    if (!live && run.permit.setupSlotReserved === true) saveChoice = "save_variant";
    if (saveChoice === "update_recipe" && !live) saveChoice = "save_variant";
    if (saveChoice === "save_variant") {
      const reservedSetupSlot = run.permit.setupSlotReserved === true || run.permit.variantSlotReserved === true;
      if (recipes.length >= D.MAX_RECORDS || !reservedSetupSlot) {
        saveChoice = "batch_only"; warnings.push("variant_not_saved_capacity");
      }
    }

    let recipeToSave = null; let recipeId = sourceSetupId || actual.id;
    if (saveChoice === "save_variant") {
      const reservedNewSetup = run.permit.setupSlotReserved === true && !live;
      const variantId = reservedNewSetup ? sourceSetupId : run.permit.variantSetupId;
      const variant = D.normalizeRecipe(Object.assign({}, actual, { id: variantId,
        title: reservedNewSetup ? actual.title : D.text(result.variantTitle || `${actual.title} — Variant`, 140), status: "trial",
        verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0,
      persistedOperationalFingerprintV4: D.operationalFingerprintV4(actual), createdAt: reservedNewSetup ? run.reservedAt : result.completedAt,
        updatedAt: result.completedAt, lastUsedAt: result.completedAt }), actual.temperatureUnit, true);
      recipeToSave = variant; recipeId = variant.id;
    } else if (saveChoice === "update_recipe" && live) {
      recipeToSave = D.normalizeRecipe(Object.assign({}, actual, { id: live.id, createdAt: live.createdAt,
        updatedAt: D.recipeMutationTime(live, result.completedAt), lastUsedAt: result.completedAt, status: "trial",
        verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0,
        persistedOperationalFingerprintV4: D.operationalFingerprintV4(actual) }), actual.temperatureUnit, true);
      recipeId = live.id;
    } else if (live && !changed) {
      recipeToSave = D.normalizeRecipe(Object.assign({}, live, { lastUsedAt: result.completedAt }), live.temperatureUnit, true);
    }

    actual.id = recipeId;
    const batchInput = {
      id: run.resultId, recipeId: recipeId, recipe: actual, sourceBatchId: run.sourceBatchId,
      initialPressedSetup: run.firstPressedSetup || actual,
      jobName: run.jobReference, quantityPlanned: result.quantityPlanned, quantityProcessed: result.quantityProcessed,
      quantityGood: result.quantityGood, quantityWaste: result.quantityWaste, quantityReworked: result.quantityReworked,
      outcome: result.outcome, issues: result.issues, notes: result.notes, startedAt: run.startedAt, completedAt: result.completedAt,
      utcOffsetMinutes: run.utcOffsetMinutes,
      runMode: run.runMode, firstPiece: run.firstPiece, qcChecks: run.qcChecks, interruptions: run.interruptions,
      productionStartedAt: run.productionStartedAt, instructionCheckedAt: run.instructionCheckedAt,
      instructionCheckFingerprint: run.instructionCheckFingerprint, operationalFingerprintV4: D.operationalFingerprintV4(actual),
      provenanceFingerprint: D.provenanceFingerprint(actual), exactSetupFingerprint: D.exactSetupFingerprint(actual),
      authorizationBasis: legacyResult ? "legacy_migration" : run.permit.authorizationBasis
    };
    let batch = D.normalizeBatch(batchInput, true);
    let errors = D.validateBatchInput(batch).concat(D.validateBatch(batch));
    const projected = batches.filter(function (item) { return item.id !== batch.id; }).concat(batch);
    if (D.invalidLineageBatchIds(projected).has(batch.id)) errors.push("sourceBatchId");
    if (errors.length) throw Object.assign(new Error("result_validation"), { fields: Array.from(new Set(errors)) });

    const qualifies = isQualifyingEvidence(batch, actual, projected) && Boolean(recipeToSave);
    if (recipeToSave && qualifies) {
      recipeToSave.status = "verified"; recipeToSave.verifiedAt = result.completedAt; recipeToSave.verifiedBatchId = batch.id;
      recipeToSave = D.normalizeRecipe(recipeToSave, recipeToSave.temperatureUnit, true);
      batch = D.normalizeBatch(Object.assign({}, batch, { recipeId: recipeToSave.id, recipe: recipeToSave }), true);
    }
    const nextBatches = batches.filter(function (item) { return item.id !== batch.id; }).concat(batch);
    const nextRecipes = recipeToSave ? recipes.filter(function (item) { return item.id !== recipeToSave.id; }).concat(recipeToSave) : recipes;
    const canonical = recomputeProvenSetups(nextRecipes, nextBatches, result.completedAt);
    if (Array.isArray(value.machines)) {
      const graphErrors = D.graphIntegrityErrors(value.machines, canonical.recipes, canonical.batches);
      if (graphErrors.some(function (error) { return error.includes("machineProfileId"); })) throw new Error("machine_reference");
      if (graphErrors.some(function (error) { return error.includes("instructionSource.priorBatchId"); })) throw new Error("instruction_reference");
      if (graphErrors.length) throw new Error("graph_integrity");
    }
    const committedBatch = canonical.batches.find(function (item) { return item.id === batch.id; }) || batch;
    const committedRecipe = recipeToSave ? canonical.recipes.find(function (item) { return item.id === recipeToSave.id; }) || recipeToSave : null;
    const payloadBytes = D.utf8ByteLength(JSON.stringify({ machines: value.machines || [], recipes: canonical.recipes,
      batches: canonical.batches, settings: value.settings || null }));
    const dataLimit = value.storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
    if (!D.validateV4BatchRaw(committedBatch)) throw Object.assign(new Error("batch_schema"), { fields: D.validateBatch(committedBatch), record: committedBatch });
    if (payloadBytes > dataLimit || D.utf8ByteLength(JSON.stringify(committedBatch)) > D.MAX_RECORD_BYTES) throw new Error("data_budget");
    return { batch: committedBatch, setup: committedRecipe, recipe: committedRecipe,
      setups: canonical.recipes, recipes: canonical.recipes, batches: canonical.batches,
      warnings: warnings, consumedPermit: Object.assign({}, run.permit, { state: "consumed", consumedAt: result.completedAt }),
      mutation: { putSetups: committedRecipe ? [committedRecipe] : [], putBatches: [committedBatch],
        consumePermitId: run.permit.id, commitProof: { permitId: run.permit.id, runId: run.id,
          resultId: run.resultId, draftRevision: run.resultDraft.revision,
          resultDraftFingerprint: run.resultDraft.contentFingerprint }, clearSession: true }, clearSession: true };
  }

  function planCorrection(context, batchId, correctionValue) {
    const value = context || {}; const correction = correctionValue || {};
    const recipes = clone(setupsOf(value)); const batches = clone(value.batches || []);
    const previous = batches.find(function (item) { return item.id === batchId; });
    if (!previous) throw new Error("batch_missing");
    if ((previous.corrections || []).length >= D.MAX_CORRECTIONS) throw new Error("correction_limit");
    const reason = D.text(correction.reason || correction.note, 500); if (!reason) throw new Error("correction_reason");
    const allowed = ["jobName", "jobReference", "quantityPlanned", "quantityProcessed", "quantityWaste", "quantityReworked", "issues", "notes", "completedAt"];
    const changes = correction.changes && typeof correction.changes === "object" && !Array.isArray(correction.changes) ? correction.changes : {};
    if (Array.isArray(changes.issues) && changes.issues.length > D.MAX_ISSUES) throw new Error("issue_limit");
    const source = clone(previous);
    allowed.forEach(function (key) { if (Object.prototype.hasOwnProperty.call(changes, key)) source[key] = clone(changes[key]); });
    if (Object.prototype.hasOwnProperty.call(changes, "jobReference")) source.jobName = source.jobReference;
    else if (Object.prototype.hasOwnProperty.call(changes, "jobName")) source.jobReference = source.jobName;
    source.id = previous.id; source.recipeId = previous.recipeId; source.recipe = clone(previous.recipe);
    source.quantityGood = Math.max(0, Number(source.quantityProcessed) - Number(source.quantityWaste));
    source.outcome = D.deriveOutcome(source.quantityPlanned, source.quantityProcessed, source.quantityWaste, source.quantityReworked);
    source.corrections = clone(previous.corrections || []);
    let corrected = D.normalizeBatch(source, true); const errors = D.validateBatch(corrected);
    const projection = batches.filter(function (item) { return item.id !== batchId; }).concat(corrected);
    const baselineInvalidLineage = D.invalidLineageBatchIds(batches);
    if (Array.from(D.invalidLineageBatchIds(projection)).some(function (id) { return !baselineInvalidLineage.has(id); })) errors.push("sourceBatchId");
    if (errors.length) throw Object.assign(new Error("correction_validation"), { fields: Array.from(new Set(errors)) });
    const latest = source.corrections.reduce(function (maximum, item) { return Math.max(maximum, new Date(item.correctedAt).getTime() || 0); }, 0);
    const correctedAt = atIso(correction.correctedAt);
    if (new Date(correctedAt).getTime() <= Math.max(new Date(previous.completedAt).getTime(),
      new Date(corrected.completedAt).getTime(), latest)) throw new Error("correction_time");
    const priorSnapshot = clone(previous); priorSnapshot.corrections = [];
    corrected.corrections = source.corrections.concat({ correctedAt: correctedAt, previous: priorSnapshot, note: reason });
    corrected = D.normalizeBatch(corrected, true);
    const nextBatches = batches.map(function (item) { return item.id === batchId ? corrected : item; });
    const canonical = recomputeProvenSetups(recipes, nextBatches, correctedAt);
    const baselineGraphErrors = new Set(D.graphIntegrityErrors(value.machines || [], recipes, batches));
    const introducedGraphErrors = D.graphIntegrityErrors(value.machines || [], canonical.recipes, canonical.batches).filter(function (error) {
      return !baselineGraphErrors.has(error) && (Array.isArray(value.machines) || !error.includes("machineProfileId"));
    });
    if (introducedGraphErrors.length) throw Object.assign(new Error("correction_validation"), { fields: introducedGraphErrors });
    const finalBatch = canonical.batches.find(function (item) { return item.id === batchId; });
    if (!D.validateV4BatchRaw(finalBatch)) throw new Error("batch_schema");
    if (D.utf8ByteLength(JSON.stringify(finalBatch)) > D.MAX_RECORD_BYTES) throw new Error("record_size");
    return { correctedBatch: finalBatch, setups: canonical.recipes, recipes: canonical.recipes, batches: canonical.batches,
      mutation: { putSetups: canonical.recipes, putBatches: canonical.batches, clearSession: false } };
  }

  function planDeleteBatch(context, batchId) {
    const value = context || {}; const batches = clone(value.batches || []); const recipes = clone(setupsOf(value));
    if (value.session && value.session.activeRun &&
        (value.session.activeRun.resultId === batchId || value.session.activeRun.sourceBatchId === batchId ||
          value.session.activeRun.setup && value.session.activeRun.setup.instructionSource &&
          value.session.activeRun.setup.instructionSource.priorBatchId === batchId)) throw new Error("active_run_conflict");
    if (!batches.some(function (item) { return item.id === batchId; })) throw new Error("batch_missing");
    const remaining = batches.filter(function (item) { return item.id !== batchId; });
    const canonical = recomputeProvenSetups(recipes, remaining);
    const baselineGraphErrors = new Set(D.graphIntegrityErrors(value.machines || [], recipes, batches));
    const dependencyPaths = D.graphIntegrityErrors(value.machines || [], canonical.recipes, canonical.batches).filter(function (error) {
      return !baselineGraphErrors.has(error);
    });
    if (dependencyPaths.some(function (error) { return error.includes("instructionSource.priorBatchId"); })) {
      throw Object.assign(new Error("batch_instruction_dependency"), { dependencies: dependencyPaths });
    }
    if (dependencyPaths.length) throw Object.assign(new Error("batch_dependency"), { dependencies: dependencyPaths });
    return { setups: canonical.recipes, recipes: canonical.recipes, batches: canonical.batches,
      mutation: { deleteBatchIds: [batchId], putSetups: canonical.recipes, putBatches: canonical.batches, clearSession: false } };
  }

  function planDeleteSetup(context, setupId) {
    const value = context || {};
    if (value.session && value.session.activeRun &&
        (value.session.activeRun.sourceSetupId || value.session.activeRun.sourceRecipeId) === setupId) throw new Error("active_run_conflict");
    if (!setupsOf(value).some(function (item) { return item.id === setupId; })) throw new Error("setup_missing");
    return { mutation: { deleteSetupIds: [setupId], clearSession: false },
      setups: setupsOf(value).filter(function (item) { return item.id !== setupId; }),
      recipes: setupsOf(value).filter(function (item) { return item.id !== setupId; }), batches: clone(value.batches || []) };
  }

  function sessionSnapshot(activeRun, timer, setupDraft) {
    if (!activeRun && !setupDraft) return null;
    const run = activeRun ? clone(activeRun) : null;
    if (run && timer) run.timer = clone(timer);
    const normalizedSetupDraft = setupDraft ? normalizeSetupDraft(setupDraft) : null;
    const snapshot = { schemaVersion: SESSION_SCHEMA_VERSION, activeRun: run, setupDraft: normalizedSetupDraft,
      savedAt: atIso() };
    if (D.utf8ByteLength(JSON.stringify(snapshot)) > D.MAX_RECORD_BYTES) throw new Error("session_size");
    return snapshot;
  }

  function setupDraftFingerprint(envelope) {
    return `sha256:${D.sha256(JSON.stringify([envelope.id, envelope.revision, envelope.savedAt,
      envelope.baseSetupId, envelope.setup]))}`;
  }

  function normalizeSetupDraft(value, now) {
    const source = value && value.schemaVersion === SETUP_DRAFT_SCHEMA_VERSION && value.setup ? value : { setup: value };
    const setup = D.normalizeRecipe(source.setup, source.setup && source.setup.temperatureUnit, true);
    if (!D.validateV4RecipeRaw(setup, false, true)) throw new Error("setup_draft");
    const envelope = { schemaVersion: SETUP_DRAFT_SCHEMA_VERSION, id: D.text(source.id, 100) || D.uuid(),
      revision: Number.isInteger(source.revision) && source.revision > 0 ? source.revision : 1,
      savedAt: source.savedAt ? atIso(source.savedAt) : atIso(now), baseSetupId: D.text(source.baseSetupId, 100),
      setup: setup, contentFingerprint: "" };
    envelope.contentFingerprint = setupDraftFingerprint(envelope); return envelope;
  }

  function validSetupDraft(value) {
    try {
      const keys = ["schemaVersion", "id", "revision", "savedAt", "baseSetupId", "setup", "contentFingerprint"];
      if (!value || value.schemaVersion !== SETUP_DRAFT_SCHEMA_VERSION || Object.keys(value).length !== keys.length ||
          keys.some(function (key) { return !Object.prototype.hasOwnProperty.call(value, key); }) || !value.id ||
          !Number.isInteger(value.revision) || value.revision < 1 || Number.isNaN(new Date(value.savedAt).getTime()) ||
          !D.validateV4RecipeRaw(value.setup, false, true)) return false;
      return value.contentFingerprint === setupDraftFingerprint(value) &&
        JSON.stringify(normalizeSetupDraft(value, value.savedAt)) === JSON.stringify(value);
    } catch (_) { return false; }
  }

  function saveSetupDraft(sessionValue, setupValue, options) {
    const session = sessionValue && typeof sessionValue === "object" ? clone(sessionValue) :
      { schemaVersion: SESSION_SCHEMA_VERSION, activeRun: null, setupDraft: null, savedAt: atIso(options && options.now) };
    const prior = session.setupDraft; const requestedAt = atIso(options && options.now);
    const savedAt = prior && new Date(requestedAt).getTime() < new Date(prior.savedAt).getTime() ? prior.savedAt : requestedAt;
    const baseSetupId = options && Object.prototype.hasOwnProperty.call(options, "baseSetupId")
      ? options.baseSetupId : prior && prior.baseSetupId;
    const candidate = normalizeSetupDraft({ schemaVersion: SETUP_DRAFT_SCHEMA_VERSION,
      id: prior && prior.id,
      revision: prior ? prior.revision + 1 : 1, savedAt: savedAt,
      baseSetupId: baseSetupId, setup: setupValue });
    session.schemaVersion = SESSION_SCHEMA_VERSION; session.setupDraft = candidate; session.savedAt = candidate.savedAt;
    if (requestedAt !== savedAt) session.clockRollbackDetected = true;
    return session;
  }

  function clearSetupDraft(sessionValue, expectedRevision, now) {
    const session = clone(sessionValue);
    if (!session.setupDraft || session.setupDraft.revision !== expectedRevision) throw new Error("setup_draft_stale");
    const clearedAt = atIso(now);
    session.setupDraftClear = { id: session.setupDraft.id, revision: expectedRevision,
      clearedAt: clearedAt, fingerprint: `sha256:${D.sha256(JSON.stringify([session.setupDraft.id, expectedRevision, clearedAt]))}` };
    session.setupDraft = null; session.savedAt = clearedAt; return session;
  }

  function restoreSession(source, batches, defaultUnit, now) {
    if (!source || typeof source !== "object" || Array.isArray(source)) return null;
    try {
      if ([1, 2].includes(source.schemaVersion)) {
        const adapter = LEGACY_ADAPTER;
        const legacy = adapter && adapter.restoreSession(source, batches, defaultUnit, now);
        if (!legacy) return null;
        let migratedRun = null;
        if (legacy.activeRun) {
          const old = legacy.activeRun; const setup = D.normalizeRecipe(old.recipe, old.recipe && old.recipe.temperatureUnit || defaultUnit, true);
          const runId = old.id; const resultId = old.resultId; const reservedAt = atIso(old.startedAt || now);
          const legacyTimer = legacy.timer;
          const timerProgressed = Boolean(legacyTimer && (legacyTimer.running === true || legacyTimer.completed === true ||
            (Number.isFinite(Number(legacyTimer.remainingMs)) &&
              Number.isFinite(Number(legacyTimer.totalMs)) && Number(legacyTimer.remainingMs) < Number(legacyTimer.totalMs))));
          const began = Boolean(old.resultDraft || timerProgressed);
          const permit = { schemaVersion: PERMIT_SCHEMA_VERSION, id: D.uuid(), runId: runId, resultId: resultId,
            setupId: old.sourceRecipeId || setup.id, setupFingerprint: D.exactSetupFingerprint(setup), reservedAt: reservedAt,
            authorizationBasis: "legacy_migration", setupSlotReserved: false, reservedBytes: D.MAX_RECORD_BYTES,
            intentFingerprint: "", usageSnapshot: { migrated: true }, state: "reserved" };
          migratedRun = {
            schemaVersion: 4, id: runId, resultId: resultId, permit: permit,
            sourceSetupId: old.sourceRecipeId || setup.id, sourceRecipeId: old.sourceRecipeId || setup.id,
            sourceBatchId: old.sourceBatchId || "", originalSetup: D.recipeSnapshot(setup), setup: D.recipeSnapshot(setup),
            originalOperationalFingerprint: D.operationalFingerprintV4(setup), operationalFingerprint: D.operationalFingerprintV4(setup),
            exactSetupFingerprint: D.exactSetupFingerprint(setup), runMode: "production", jobReference: D.text(old.jobName, 180),
            quantity: old.quantity, phase: "preflight", progressMode: "final_confirmation", reservedAt: reservedAt, startedAt: reservedAt,
            lastEventAt: reservedAt, transitionSequence: 0,
            productionStarted: began, productionStartedAt: began ? reservedAt : "", processedCount: old.resultDraft && Number(old.resultDraft.quantityProcessed) || 0,
            firstPieceProcessedCredit: 0, grossCompletedItems: old.resultDraft && Number(old.resultDraft.quantityProcessed) || 0,
            undoneItems: 0, cycleEvents: [], resultPendingAt: "",
            stagePlanFingerprint: timerPlanFingerprint(setup), stageIndex: 0,
            instructionCheckedAt: "", instructionCheckFingerprint: "", firstPiecePolicy: "required_for_unproven",
            instructionReferenceValidatedId: setup.instructionSource.type === "prior_successful_batch" &&
              D.instructionReferenceValid(setup, new Map((batches || []).map(function (batch) { return [batch.id, batch]; })), reservedAt, resultId)
              ? setup.instructionSource.priorBatchId : "",
            legacyGrandfathered: true, resumeResultPending: began,
            firstPiece: { required: !began, outcome: began ? "not_required" : "pending", attempts: 0, attemptedAt: "", completedAt: "", note: "" },
            qcChecks: [], interruptions: began ? [{ startedAt: reservedAt, endedAt: "", reason: "migrated_active_run", productionBegan: true }] : [],
            timer: null, resultDraft: null, recoveredResultValues: old.resultDraft ? clone(old.resultDraft) : null
          };
          permit.intentFingerprint = runIntentFingerprint(migratedRun);
        }
        return migratedRun || legacy.recipeDraft ? { schemaVersion: SESSION_SCHEMA_VERSION, activeRun: migratedRun,
          setupDraft: legacy.recipeDraft ? normalizeSetupDraft(legacy.recipeDraft, now) : null,
          savedAt: atIso(now), migratedFromSessionSchema: source.schemaVersion } : null;
      }
      if (source.schemaVersion === 3) {
        const upgraded = clone(source); upgraded.schemaVersion = SESSION_SCHEMA_VERSION;
        if (upgraded.setupDraft) upgraded.setupDraft = normalizeSetupDraft(upgraded.setupDraft, upgraded.savedAt || now);
        if (upgraded.activeRun) {
          const run = upgraded.activeRun;
          run.migratedFromSessionSchema = 3;
          run.progressMode = PROGRESS_MODES.has(run.progressMode) ? run.progressMode : "final_confirmation";
          const firstCredit = Number(run.firstPieceProcessedCredit === undefined ?
            run.firstPiece && run.firstPiece.outcome !== "pending" && run.productionStarted ? 1 : 0 : run.firstPieceProcessedCredit);
          run.firstPieceProcessedCredit = firstCredit;
          run.grossCompletedItems = Number(run.grossCompletedItems === undefined ?
            Math.max(0, Number(run.processedCount || 0) - firstCredit) : run.grossCompletedItems);
          run.undoneItems = Number(run.undoneItems || 0); run.cycleEvents = Array.isArray(run.cycleEvents) ? run.cycleEvents : [];
          run.resultPendingAt = run.resultPendingAt || (run.resultDraft && run.resultDraft.completedAt) ||
            (run.phase === "result_pending" || run.phase === "committing" ? run.lastEventAt : "");
          if (run.resultDraft && run.resultPendingAt) {
            const rawDraft = clone(run.resultDraft);
            try { run.resultDraft = buildResultDraftEnvelope(Object.assign({}, run, { resultDraft: null }), rawDraft,
              upgraded.savedAt || now, "legacy_migrated"); }
            catch (_) { run.resultDraft = null; run.recoveredResultValues = rawDraft; }
          }
          if (run.phase === "committing") run.phase = "result_pending";
        }
        return restoreSession(upgraded, batches, defaultUnit, now);
      }
      if (source.schemaVersion !== SESSION_SCHEMA_VERSION) return null;
      const restored = { schemaVersion: SESSION_SCHEMA_VERSION, activeRun: null, setupDraft: null,
        savedAt: source.savedAt ? atIso(source.savedAt) : atIso(now) };
      if (source.setupDraft && D.utf8ByteLength(JSON.stringify(source.setupDraft)) <= D.MAX_RECORD_BYTES) {
        const draft = normalizeSetupDraft(source.setupDraft, now);
        if (draft.contentFingerprint === source.setupDraft.contentFingerprint) restored.setupDraft = draft;
      }
      if (source.activeRun) {
        const run = clone(source.activeRun);
        if (!run.id || !run.resultId || (batches || []).some(function (batch) { return batch.id === run.resultId; })) return restored.setupDraft ? restored : null;
        if (run.transitionSequence === undefined) run.transitionSequence = 0;
        if (!Number.isInteger(run.transitionSequence) || run.transitionSequence < 0) return restored.setupDraft ? restored : null;
        run.setup = D.recipeSnapshot(D.normalizeRecipe(run.setup, run.setup && run.setup.temperatureUnit || defaultUnit, true));
        run.originalSetup = D.recipeSnapshot(D.normalizeRecipe(run.originalSetup || run.setup, run.setup.temperatureUnit, true));
        if (!Number.isInteger(run.utcOffsetMinutes) || run.utcOffsetMinutes < -840 || run.utcOffsetMinutes > 840) {
          run.utcOffsetMinutes = -new Date(run.reservedAt || run.startedAt).getTimezoneOffset();
        }
        if (run.permit && run.permit.schemaVersion === 1) return restored.setupDraft ? restored : null;
        if (run.permit && run.permit.schemaVersion === 2) {
          if (!legacyPermitV2Valid(run)) return restored.setupDraft ? restored : null;
          run.permit.schemaVersion = PERMIT_SCHEMA_VERSION;
          run.permit.intentFingerprint = runIntentFingerprint(run);
        }
        if (run.instructionReferenceValidatedId === undefined) run.instructionReferenceValidatedId =
          run.setup.instructionSource.type === "prior_successful_batch" &&
          D.instructionReferenceValid(run.setup, new Map((batches || []).map(function (batch) { return [batch.id, batch]; })), run.startedAt, run.resultId)
            ? run.setup.instructionSource.priorBatchId : "";
        const planFingerprint = timerPlanFingerprint(run.setup);
        if (run.stagePlanFingerprint !== planFingerprint) {
          if (!(run.legacyGrandfathered === true && run.phase === "preflight")) return restored.setupDraft ? restored : null;
          run.stagePlanFingerprint = planFingerprint; run.stageIndex = 0; run.timer = null;
        }
        const runnableErrors = D.validateRunnableRecipe(run.setup,
          run.lastEventAt || run.startedAt || run.reservedAt, run.utcOffsetMinutes);
        if (!permitValid(run) || (runnableErrors.length && !(run.legacyGrandfathered === true && run.phase === "preflight")) ||
            !D.RUN_MODES.has(run.runMode) || !D.RUN_PHASES.has(run.phase)) return restored.setupDraft ? restored : null;
        if (!["preflight", "first_piece"].includes(run.phase) && !instructionCheckValid(run)) return restored.setupDraft ? restored : null;
        if (run.resultDraft && !validResultDraft(run, run.resultDraft)) {
          run.recoveredResultValues = clone(run.resultDraft); run.resultDraft = null;
          if (run.phase === "committing") run.phase = "result_pending";
        }
        if (run.timer) {
          if (run.timer.runId !== run.id || run.timer.planFingerprint !== timerPlanFingerprint(run.setup)) run.timer = null;
          else { run.timer = reconcileTimer(run.timer, now); run.stageIndex = run.timer.index; }
        }
        restored.activeRun = run;
      }
      return restored.activeRun || restored.setupDraft ? restored : null;
    } catch (_) { return null; }
  }

  function inspectBackup(raw) {
    const source = D.parseBackup(raw);
    if (source.encrypted === true) throw new Error("backup_encryption_unsupported");
    const parsed = source.schemaVersion < 4 ? migrateLoadedData(source) : source;
    return { schemaVersion: source.schemaVersion, targetSchemaVersion: 4, machines: parsed.machines.length,
      setups: parsed.recipes.length, batches: parsed.batches.length, encrypted: false,
      warning: "backup_not_encrypted", parsed: parsed };
  }

  function migrateLoadedData(data, now) {
    const source = data && typeof data === "object" && !Array.isArray(data) ? data : {};
    const reassigned = new Map(); const occupied = new Set();
    let recipes = setupsOf(source).map(function (raw) {
      const originalId = D.text(raw && raw.id, 100);
      const systemId = D.SYSTEM_STARTER_IDS.has(originalId);
      const normalized = D.normalizeStoredRecipe(raw, raw && raw.temperatureUnit);
      const oldSystemTemplate = systemId && D.isLegacyCanonicalStarterRecipe(normalized);
      const structuralSavedSetup = systemId && raw && raw.setupSchemaVersion === 4 && D.isCanonicalStarterRecipe(normalized);
      if (systemId && !structuralSavedSetup && (D.isCanonicalStarterRecipe(normalized) || oldSystemTemplate)) return null;
      if (systemId) {
        const stem = D.operationalFingerprint(normalized).slice(7, 23); let replacement = `migrated-setup-${stem}`; let suffix = 1;
        while (occupied.has(replacement) || D.SYSTEM_STARTER_IDS.has(replacement)) replacement = `migrated-setup-${stem}-${suffix++}`;
        reassigned.set(originalId, replacement); normalized.id = replacement; normalized.status = "draft";
        if (structuralSavedSetup) normalized.steps = normalized.steps.map(function (step) { return Object.assign({}, step, { id: D.uuid() }); });
        normalized.verifiedAt = ""; normalized.verifiedBatchId = "";
        normalized.needsReview = !structuralSavedSetup; normalized.migrationOriginal = structuralSavedSetup ? null : clone(raw);
      }
      occupied.add(normalized.id); return D.normalizeRecipe(normalized, normalized.temperatureUnit, true);
    }).filter(Boolean);
    let batches = (source.batches || []).map(function (raw) {
      return D.rekeyImportedBatchRecipe(D.normalizeStoredBatch(raw), reassigned);
    });
    const machinesById = new Map((source.machines || []).map(function (raw) {
      const machine = D.normalizeMachineProfile(raw, true); return [machine.id, machine];
    }).filter(function (entry) { return entry[0] && D.validateMachineProfile(entry[1]).length === 0; }));
    recipes = recipes.map(function (recipe) {
      if (!recipe.machineProfileId && recipe.machineNickname) {
        const fingerprint = D.operationalFingerprint(recipe).slice(7, 23); const id = `legacy-machine-${fingerprint}`;
        if (!machinesById.has(id)) machinesById.set(id, D.normalizeMachineProfile({ id: id, nickname: recipe.machineNickname,
          platenOrZone: recipe.platenZone, createdAt: recipe.createdAt, updatedAt: recipe.updatedAt }, true));
        recipe = D.normalizeRecipe(Object.assign({}, recipe, { machineProfileId: id, machineProfile: machinesById.get(id),
          steps: recipe.steps.map(function (step) { return Object.assign({}, step, { machineProfileId: id }); }),
          status: recipe.status === "verified" ? "trial" : recipe.status, verifiedAt: "", verifiedBatchId: "" }), recipe.temperatureUnit, true);
      }
      if (D.validateRunnableRecipe(Object.assign({}, recipe, { archived: false })).length) {
        recipe = D.normalizeRecipe(Object.assign({}, recipe, {
          status: "draft", verifiedAt: "", verifiedBatchId: "", provenEvidenceCount: 0,
          persistedOperationalFingerprintV4: D.operationalFingerprintV4(recipe)
        }), recipe.temperatureUnit, true);
      }
      return recipe;
    });
    const canonical = recomputeProvenSetups(recipes, batches, now);
    batches = canonical.batches;
    return { machines: Array.from(machinesById.values()), setups: canonical.recipes, recipes: canonical.recipes, batches: batches,
      settings: D.normalizeSettings(source.settings), session: restoreSession(source.session, batches,
        D.normalizeSettings(source.settings).defaultUnit, now), entitlement: null };
  }

  function planRestore(context, raw) {
    const value = context || {};
    if (value.session && (value.session.activeRun || value.session.setupDraft)) throw new Error("active_recovery_conflict");
    const preview = inspectBackup(raw); const parsed = preview.parsed;
    const restoreLimit = value.storageMode === "compatible" ? 2_000_000 : D.MAX_DATA_BYTES;
    if (D.utf8ByteLength(JSON.stringify({ machines: parsed.machines, recipes: parsed.recipes, batches: parsed.batches,
      settings: parsed.settings, session: null })) > restoreLimit) throw new Error("data_budget");
    const recoveryPoint = preRestoreBackup(value);
    const target = { machines: parsed.machines, setups: parsed.setups, batches: parsed.batches,
      settings: parsed.settings, session: null };
    const recoveryEnvelope = { schemaVersion: 1, id: D.uuid(), createdAt: atIso(), state: "prepared",
      sourceFingerprint: operationalStateFingerprint(value), payload: recoveryPoint,
      payloadHash: `sha256:${D.sha256(JSON.stringify(recoveryPoint))}` };
    const receipt = { recoveryId: recoveryEnvelope.id, sourceFingerprint: recoveryEnvelope.sourceFingerprint,
      targetHash: `sha256:${D.sha256(JSON.stringify(target))}` };
    return { preview: Object.assign({}, preview, { parsed: undefined }), recoveryPoint: recoveryPoint,
      recoveryEnvelope: recoveryEnvelope, restoreReceipt: receipt, restored: parsed, target: target,
      requiresDurableRecoveryPoint: true, requiresConfirmation: true, entitlementUnaffected: true };
  }

  function planRollback(context, recoveryValue) {
    const value = context || {};
    if (value.session && (value.session.activeRun || value.session.setupDraft)) throw new Error("active_recovery_conflict");
    const recovery = recoveryValue || value.preRestoreRecovery;
    if (!recovery || recovery.schemaVersion !== 1 || recovery.state !== "applied" || !recovery.payload ||
        recovery.payload.schema !== "press-bench-pre-restore-recovery" || recovery.payload.schemaVersion !== 1 ||
        recovery.payload.appId !== "APP-018" ||
        recovery.payloadHash !== `sha256:${D.sha256(JSON.stringify(recovery.payload))}`) throw new Error("rollback_recovery_invalid");
    const payload = recovery.payload;
    const target = { machines: clone(payload.machines || []), setups: clone(payload.setups || []),
      batches: clone(payload.batches || []), settings: D.normalizeSettings(payload.settings), session: null };
    const currentRecoveryPoint = preRestoreBackup(value);
    const recoveryEnvelope = { schemaVersion: 1, id: D.uuid(), createdAt: atIso(), state: "prepared",
      sourceFingerprint: operationalStateFingerprint(value), payload: currentRecoveryPoint,
      payloadHash: `sha256:${D.sha256(JSON.stringify(currentRecoveryPoint))}` };
    const receipt = { recoveryId: recoveryEnvelope.id, sourceFingerprint: recoveryEnvelope.sourceFingerprint,
      targetHash: `sha256:${D.sha256(JSON.stringify(target))}` };
    return { rollbackOfRecoveryId: recovery.id, recoveryPoint: currentRecoveryPoint,
      recoveryEnvelope: recoveryEnvelope, restoreReceipt: receipt, target: target,
      requiresDurableRecoveryPoint: true, requiresConfirmation: true, entitlementUnaffected: true };
  }

  function operationalStateFingerprint(context) {
    const value = context || {};
    function ordered(items) { return (items || []).slice().sort(function (a, b) { return String(a.id).localeCompare(String(b.id)); }); }
    return `sha256:${D.sha256(JSON.stringify({ machines: ordered(value.machines), setups: ordered(setupsOf(value)),
      batches: ordered(value.batches), settings: value.settings || null, session: value.session || null }))}`;
  }

  function preRestoreBackup(context) {
    const value = context || {};
    if (value.session && (value.session.activeRun || value.session.setupDraft)) throw new Error("active_recovery_conflict");
    return { schema: "press-bench-pre-restore-recovery", schemaVersion: 1, appId: "APP-018", capturedAt: atIso(),
      machines: clone(value.machines || []), setups: clone(setupsOf(value)), batches: clone(value.batches || []),
      settings: D.normalizeSettings(value.settings || D.defaultSettings()), session: null };
  }

  function planDeleteAll(context, confirmation) {
    if (confirmation !== "DELETE") throw new Error("delete_confirmation");
    if (context && context.session && context.session.activeRun) throw new Error("active_run_conflict");
    return { machines: [], setups: [], recipes: [], batches: [], settings: D.defaultSettings(), session: null,
      entitlementUnaffected: true, requiresCoordinatedStorageDelete: true,
      purchaseEntitlementUnaffected: true, requiredWarning: "store_purchase_not_deleted",
      mutation: { deleteAll: true, deleteConfirmation: "DELETE" } };
  }

  function insights(context, filter, now) {
    const value = context || {};
    const access = E.capabilities(value.entitlement, usageOf(value), now);
    if (!access.canAdvancedAnalytics) return { allowed: false, reason: "paid_access_required" };
    const recipes = setupsOf(value); const batches = value.batches || [];
    const selected = LEGACY_ADAPTER.analyticsBatches(batches, filter || {});
    const totals = selected.reduce(function (result, batch) {
      result.processed += Number(batch.quantityProcessed || 0); result.finalGood += Number(batch.quantityGood || 0);
      result.reworked += Number(batch.quantityReworked || 0); result.waste += Number(batch.quantityWaste || 0); return result;
    }, { processed: 0, finalGood: 0, reworked: 0, waste: 0 });
    const firstPassGood = Math.max(0, totals.finalGood - totals.reworked);
    const setpointChanges = B.recordedSetpointChanges(recipes || [], selected, filter && filter.machine || "all");
    return { allowed: true, sampleSize: selected.length, lowData: selected.length < 5,
      firstPassYield: totals.processed ? firstPassGood / totals.processed : null,
      finalYield: totals.processed ? totals.finalGood / totals.processed : null,
      reworkRate: totals.processed ? totals.reworked / totals.processed : null,
      wasteRate: totals.processed ? totals.waste / totals.processed : null,
      recordedSetpointChanges: setpointChanges, outcomeMix: B.outcomeMix(selected), throughput: B.velocitySeries(selected, 30) };
  }

  function capacityStatus(context, now) {
    const usage = usageOf(context || {}); const access = E.capabilities(context && context.entitlement, usage, now);
    return { usage: usage, freeSetupLimit: B.FREE_RECIPE_LIMIT, freeBatchLimit: B.FREE_BATCH_LIMIT,
      physicalSetupLimit: D.MAX_RECORDS, physicalBatchLimit: D.MAX_RECORDS, access: access };
  }

  function setupLibrary(recipes, batches, filters) {
    const options = filters || {}; const query = D.normalizeSearch(options.query || "");
    const statuses = options.statuses ? new Set(options.statuses) : null;
    return D.sortRecipes(recipes || []).filter(function (recipe) {
      const summary = proofSummary(recipe, batches || []);
      if (query && !D.recipeMatches(recipe, query, query)) return false;
      if (statuses && !statuses.has(summary.publicStatus)) return false;
      if (options.processStructure && recipe.processStructure !== options.processStructure) return false;
      if (options.material && !D.normalizeSearch(recipe.blankMaterial).includes(D.normalizeSearch(options.material))) return false;
      if (options.machine && options.machine !== recipe.machineProfileId && options.machine !== recipe.machineProfile.nickname) return false;
      if (options.recentIssues && !(batches || []).some(function (batch) { return batch.recipeId === recipe.id && (batch.issues || []).length; })) return false;
      return true;
    }).map(function (recipe) {
      const related = D.sortBatches((batches || []).filter(function (batch) { return batch.recipeId === recipe.id; }));
      return { setup: recipe, evidence: proofSummary(recipe, batches || []), sourceCheckedDate: recipe.instructionSource.checkedDate,
        lastOutcome: related[0] ? related[0].outcome : "", sampleSize: related.length };
    });
  }

  function reportCapability(context, format, recordsOrFilter, now) {
    const kind = String(format || "").toLowerCase();
    if (["csv", "json"].includes(kind)) return { allowed: false, reason: "unsupported_format" };
    if (!["xlsx", "pdf"].includes(kind)) return { allowed: false, reason: "unsupported_format" };
    if (!E.capabilities(context && context.entitlement, usageOf(context || {}), now).canPremiumReports) return { allowed: false, reason: "paid_access_required" };
    if (typeof recordsOrFilter === "number") return { allowed: false, reason: "dataset_required" };
    const records = Array.isArray(recordsOrFilter) ? recordsOrFilter :
      LEGACY_ADAPTER.analyticsBatches(context && context.batches || [], recordsOrFilter || {});
    const rows = records.length;
    if (kind === "xlsx" && rows > B.MAX_DETAILED_REPORT_ROWS) return { allowed: false, reason: "detailed_row_limit", maximumRows: B.MAX_DETAILED_REPORT_ROWS };
    return { allowed: true, reason: "paid_report", detailedRows: rows };
  }

  function planReport(context, format, recordsOrFilter, now) {
    const capability = reportCapability(context, format, recordsOrFilter, now);
    if (!capability.allowed) return capability;
    const kind = String(format || "").toLowerCase();
    const records = Array.isArray(recordsOrFilter) ? recordsOrFilter :
      LEGACY_ADAPTER.analyticsBatches(context && context.batches || [], recordsOrFilter || {});
    const canonical = records.map(function (record) { return clone(record); });
    return { allowed: true, reason: capability.reason, format: kind, detailedRows: canonical.length,
      recordIds: canonical.map(function (record) { return record.id; }),
      datasetFingerprint: `sha256:${D.sha256(JSON.stringify(canonical))}`, records: canonical };
  }

  function completionSummary(batch, setup, context) {
    const finalGood = Number(batch.quantityGood || 0); const reworked = Number(batch.quantityReworked || 0);
    const batches = (context && context.batches || []).filter(function (item) { return item.id !== batch.id; }).concat(batch);
    const setups = setupsOf(context).filter(function (item) { return !setup || item.id !== setup.id; }).concat(setup ? [setup] : []);
    const summaryContext = Object.assign({}, context || {}, { setups: setups, batches: batches });
    return { planned: batch.quantityPlanned, processed: batch.quantityProcessed, finalGood: finalGood,
      firstPassGood: Math.max(0, finalGood - reworked), notProcessed: Math.max(0, batch.quantityPlanned - batch.quantityProcessed),
      waste: batch.quantityWaste, rework: reworked, setupEvidence: proofSummary(setup || batch.recipe, batches),
      capacity: capacityStatus(summaryContext, batch.completedAt) };
  }

  root.PressBenchProcess = Object.freeze({
    SESSION_SCHEMA_VERSION: SESSION_SCHEMA_VERSION, PERMIT_SCHEMA_VERSION: PERMIT_SCHEMA_VERSION,
    RESULT_DRAFT_SCHEMA_VERSION: RESULT_DRAFT_SCHEMA_VERSION, ARCHITECTURE_REQUIREMENTS: ARCHITECTURE_REQUIREMENTS,
    legalReady: legalReady, operationalReadiness: operationalReadiness,
    requireOperationalReadiness: requireOperationalReadiness,
    acceptLegal: acceptLegal, confirmTemperatureUnit: confirmTemperatureUnit,
    recordReminderDecision: recordReminderDecision,
    runIntentFingerprint: runIntentFingerprint,
    markBackupCompleted: markBackupCompleted,
    evaluateStartup: evaluateStartup,
    processStructure: processStructure, prepareSetupForSave: prepareSetupForSave, archiveSetup: archiveSetup,
    reusableSetupFacts: reusableSetupFacts, checkedToday: checkedToday, qcPolicy: qcPolicy,
    recommendedSaveChoice: recommendedSaveChoice, issueDefaults: issueDefaults,
    SETUP_REUSE_CLASSES: D.SETUP_REUSE_CLASSES, reuseSetup: D.reuseSetup,
    planSaveSetup: planSaveSetup, planSaveMachine: planSaveMachine, classifyMachineChange: classifyMachineChange,
    restoreArchivedSetup: restoreArchivedSetup, usageOf: usageOf, capacityStatus: capacityStatus,
    setupLibrary: setupLibrary, reportCapability: reportCapability, planReport: planReport,
    planStartRun: authorizeRun, authorizeRun: authorizeRun, inspectActiveRunConflict: inspectActiveRunConflict,
    permitValid: permitValid, instructionCheckValid: instructionCheckValid,
    firstPieceRequired: firstPieceRequired, buildProcessStages: buildProcessStages, timerPlanFingerprint: timerPlanFingerprint,
    createTimer: createTimer, reconcileTimer: reconcileTimer, startTimer: startTimer, pauseTimer: pauseTimer,
    moveTimer: moveTimer, resetTimer: resetTimer,
    transitionRun: transitionRun, resultDraft: resultDraft, saveResultDraft: saveResultDraft,
    confirmAllGood: confirmAllGood, validResultDraft: validResultDraft,
    batchMatchesResultDraft: batchMatchesResultDraft, planResultCommit: planResultCommit,
    planDiscardUnstarted: planDiscardUnstarted,
    isQualifyingEvidence: isQualifyingEvidence, recomputeProvenSetups: recomputeProvenSetups, proofSummary: proofSummary,
    planCorrection: planCorrection, planDeleteBatch: planDeleteBatch, planDeleteSetup: planDeleteSetup,
    sessionSnapshot: sessionSnapshot, saveSetupDraft: saveSetupDraft, clearSetupDraft: clearSetupDraft,
    validSetupDraft: validSetupDraft,
    restoreSession: restoreSession, inspectBackup: inspectBackup,
    preRestoreBackup: preRestoreBackup, planRestore: planRestore, planRollback: planRollback,
    operationalStateFingerprint: operationalStateFingerprint,
    migrateLoadedData: migrateLoadedData,
    planDeleteAll: planDeleteAll, insights: insights, completionSummary: completionSummary
  });

  try { delete root.PressBenchLegacyRuntimeV19; } catch (_) {}

  if (typeof module !== "undefined" && module.exports) {
    module.exports = Object.freeze({ meta: root.PressBenchLogicMeta, domain: D, business: B, entitlement: E,
      runtime: root.PressBenchProcess, process: root.PressBenchProcess, storage: root.PressBenchStorage });
  }
})(typeof globalThis !== "undefined" ? globalThis : this);
