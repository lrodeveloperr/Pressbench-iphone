#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
ROOT=Path(__file__).resolve().parents[1]
CAT=ROOT/'PressBench/Resources/Localizations.json'
EXPECTED=['en','es','pt','fr','de','it','nl','pl','tr','ro','cs','uk','ru','ar','zh','ja','ko','hi','ur','bn','vi','id','th','fil','ms','fi','sv','da','nb','el','he']
OVERRIDES=['zh-Hant']
c=json.loads(CAT.read_text(encoding='utf-8'))
errors=[]
if c.get('languages')!=EXPECTED: errors.append(f"language list mismatch: {c.get('languages')}")
expected_codes=set(EXPECTED+OVERRIDES)
ph=re.compile(r'%(?:\d+\$)?@')
# Proper names, unit names, and strings made only of runtime formatting tokens
# are the only values allowed to remain identical to English.
IDENTICAL_TO_ENGLISH_ALLOWLIST={
    'app.name', 'more.versionFormat', 'runs.unitsProgress',
    'onboarding.temperature.fahrenheit', 'onboarding.temperature.celsius'
}
for key,item in c.get('strings',{}).items():
    tr=item.get('translations',{})
    if set(tr)!=expected_codes: errors.append(f'{key}: translation-code set mismatch')
    source_ph=ph.findall(item.get('source',''))
    for code in expected_codes:
        text=tr.get(code,'')
        if not isinstance(text,str) or not text.strip(): errors.append(f'{key}/{code}: empty')
        if len(ph.findall(text))!=len(source_ph): errors.append(f'{key}/{code}: placeholder mismatch')
        if code != 'en' and key not in IDENTICAL_TO_ENGLISH_ALLOWLIST and text.strip() == tr.get('en','').strip():
            errors.append(f'{key}/{code}: untranslated English value')
# Catalog and canonical source inventory must describe exactly the same keys.
inventory=json.loads((ROOT/'localization_keys.json').read_text(encoding='utf-8'))
if set(inventory) != set(c.get('strings',{})):
    errors.append('localization_keys.json and Localizations.json key sets differ')

# These keys are composed dynamically or are referenced by in-flight operator
# flows, so a literal-only Swift scan cannot prove their presence.
REQUIRED_DYNAMIC_KEYS={
    'run.finishRun', 'run.nextItem', 'error.freeLimit', 'backup.signInFailed',
    'run.mode.test.help', 'run.mode.production.help',
    'run.progress.live.help', 'run.progress.final.help',
    'run.reuse.exactRepeat.help', 'run.reuse.sameProductVariant.help',
    'run.reuse.materiallyDifferent.help'
}
for key in sorted(REQUIRED_DYNAMIC_KEYS-set(c.get('strings',{}))):
    errors.append(f'missing required dynamic localization key {key}')
# Excel sheet names: max 31 chars; forbidden []:*?/\\; unique within every locale.
sheet_keys=['report.sheet.summary','report.sheet.runs','report.sheet.setups','report.sheet.issues']
for code in expected_codes:
    vals=[c['strings'][k]['translations'][code] for k in sheet_keys]
    if len(set(vals))!=len(vals): errors.append(f'{code}: duplicate report sheet names')
    for val in vals:
        if len(val)>31 or re.search(r'[\[\]:*?/\\]',val): errors.append(f'{code}: invalid Excel sheet name {val!r}')
# Every literal localization key referenced by Swift must exist.
known=set(c['strings'])
ref_re=re.compile(r'(?:PBL10n\.(?:text|format)|\bt)\(\s*"([a-zA-Z0-9_.-]+)"')
for path in (ROOT/'PressBench').rglob('*.swift'):
    text=path.read_text(encoding='utf-8')
    for key in ref_re.findall(text):
        if key not in known: errors.append(f'{path.relative_to(ROOT)}: unknown localization key {key}')

# Checklist: fixed user-facing SwiftUI copy must come from the catalog. Product
# names and unit symbols are the only fixed literals permitted at the view layer;
# interpolated values are checked through their formatting/localization helpers.
ui_literal_re=re.compile(
    r'\b(?:Text|Label|Button|Section|Picker|Toggle|navigationTitle|confirmationDialog|alert|accessibilityLabel|ContentUnavailableView|LabeledContent)'
    r'\(\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
)
fixed_ui_allowlist={'PressBench','°F','°C'}
for path in (ROOT/'PressBench/Views').rglob('*.swift'):
    text=path.read_text(encoding='utf-8')
    for value in ui_literal_re.findall(text):
        if r'\(' not in value and re.search(r'[A-Za-z]',value) and value not in fixed_ui_allowlist:
            errors.append(f'{path.relative_to(ROOT)}: fixed English UI literal {value!r}')

# Checklist: projections and exports must not manufacture English presentation
# strings or expose internal English enum/technical codes.
store_source=(ROOT/'PressBench/Models/PressBenchStore.swift').read_text(encoding='utf-8')
report_source=(ROOT/'PressBench/Reports/PressBenchReportExporter.swift').read_text(encoding='utf-8')
localization_source=(ROOT/'PressBench/Localization/PBLocalization.swift').read_text(encoding='utf-8')
for fragment in ['stage: "Completed"', '"\\(duration) sec"', '"\\(value) s"', '"\\($0)s"', 'stageName(']:
    if fragment in store_source:
        errors.append(f'PressBenchStore.swift: English projection fragment remains: {fragment}')
for fragment in ['batch["outcome"] as? String', '.text("datasetFingerprint")', '"\\(duration) sec"']:
    if fragment in report_source:
        errors.append(f'PressBenchReportExporter.swift: raw English/internal report value remains: {fragment}')
for required in [
    'static func seconds', 'static func decimal',
    'case "first_piece": return "onboarding.process.firstPiece"',
    'case "result_pending", "committing": return "onboarding.process.result"',
    'case "completed": return "runState.completed"',
    'extension SetupStageDraft'
]:
    if required not in localization_source:
        errors.append(f'PBLocalization.swift: missing localization projection guard {required}')
for required in ['localizedIssueValue(', 'PBFormat.seconds(duration, locale: locale)', 'PBFormat.decimal(value, locale: locale)']:
    if required not in report_source:
        errors.append(f'PressBenchReportExporter.swift: missing localized export guard {required}')

# Checklist: every bundled preset must be present, translated, non-empty, and
# unique in every supported locale. Operator-entered values remain verbatim.
prefill_source=(ROOT/'PressBench/Models/PBPrefillCatalog.swift').read_text(encoding='utf-8')
prefill_catalog=json.loads((ROOT/'PressBench/Resources/PrefillLocalizations.json').read_text(encoding='utf-8'))
prefill_canonical=json.loads((ROOT/'prefill_localization_source.json').read_text(encoding='utf-8'))
prefill_overrides=json.loads((ROOT/'prefill_translation_overrides.json').read_text(encoding='utf-8'))
prefill_counts={
    'platenSizes':18, 'materials':20, 'transferMedia':18, 'pressureDescriptions':5,
    'instructionSources':5, 'placementActions':16, 'finishActions':16
}
if prefill_catalog.get('languages') != EXPECTED or prefill_catalog.get('localeOverrideCodes') != OVERRIDES:
    errors.append('preset catalog locale codes do not match the app localization contract')
if set(prefill_catalog.get('groups',{})) != set(prefill_counts):
    errors.append('preset catalog group set mismatch')
for group,count in prefill_counts.items():
    locales=prefill_catalog.get('groups',{}).get(group,{})
    if set(locales) != expected_codes:
        errors.append(f'presets/{group}: locale-code set mismatch')
    if prefill_canonical.get(group) != locales.get('en'):
        errors.append(f'presets/{group}: English runtime values differ from canonical source')
    english=locales.get('en',[])
    for code in expected_codes:
        values=locales.get(code,[])
        if len(values) != count:
            errors.append(f'presets/{group}/{code}: expected {count} values, found {len(values)}')
            continue
        if any(not isinstance(value,str) or not value.strip() for value in values):
            errors.append(f'presets/{group}/{code}: empty value')
        folded=[value.strip().casefold() for value in values]
        if len(set(folded)) != len(folded):
            errors.append(f'presets/{group}/{code}: duplicate localized choice')
        if code != 'en':
            for index,(source,value) in enumerate(zip(english,values)):
                universal_dimension=bool(re.fullmatch(r'\d+ × \d+ cm',source))
                if source.strip().casefold() == value.strip().casefold() and not universal_dimension:
                    errors.append(f'presets/{group}/{code}/{index}: untranslated English preset {source!r}')
                leaked_english=re.search(
                    r'\b(?:backing|protective sheet|heat-resistant pad|foam pad|data sheet|cotton tote|canvas tote|mouse pad|glass blank|wood blank|slate blank)\b',
                    value,
                    re.I
                )
                if leaked_english:
                    errors.append(f'presets/{group}/{code}/{index}: English preset fragment {leaked_english.group()!r}')
            if group == 'platenSizes' and any(re.search(r'\b(?:in|inch|inches)\b',value,re.I) for value in values[:10]):
                errors.append(f'presets/{group}/{code}: English inch label remains')
for group,locales in prefill_overrides.items():
    for code,replacements in locales.items():
        for index,value in replacements.items():
            actual=prefill_catalog.get('groups',{}).get(group,{}).get(code,[])
            if int(index) >= len(actual) or actual[int(index)] != value:
                errors.append(f'presets/{group}/{code}/{index}: reviewed override is not applied')
if 'language == .en ? bundled : []' in prefill_source:
    errors.append('PBPrefillCatalog.swift: obsolete English-only preset gate remains')
for marker in ['PrefillLocalizations', 'localizedChoices(for:', 'localizedValue(', 'legacyEnglishAliases', 'locale: Locale']:
    if marker not in prefill_source:
        errors.append(f'PBPrefillCatalog.swift: localized preset runtime marker missing: {marker}')
editors_source=(ROOT/'PressBench/Views/ProductionEditors.swift').read_text(encoding='utf-8')
if editors_source.count('PBPrefillCatalog.customerVisibleChoices(') != 7 or editors_source.count('locale: locale') < 8:
    errors.append('ProductionEditors.swift: not every preset dropdown uses locale-aware choices')
if store_source.count('localizedPreset(') < 25 or 'localizedSetupTitle(' not in store_source:
    errors.append('PressBenchStore.swift: stored preset values are not consistently localized for display')
if 'instructionSource: [string(source?["type"])' in store_source:
    errors.append('PressBenchStore.swift: internal English instruction-source type leaks into UI')
if report_source.count('localizedPreset(') < 10 or 'localizedSetupTitle(' not in report_source:
    errors.append('PressBenchReportExporter.swift: stored preset values are not consistently localized in reports')
# Directional icons must be semantic for RTL.
for path in (ROOT/'PressBench').rglob('*.swift'):
    text=path.read_text(encoding='utf-8')
    if re.search(r'chevron\.(?:left|right)|arrow\.(?:left|right)',text):
        errors.append(f'{path.relative_to(ROOT)}: physical left/right icon used instead of semantic direction')
if errors:
    print('LOCALIZATION VERIFY: FAIL')
    for e in errors: print('-',e)
    sys.exit(1)
print(f"LOCALIZATION VERIFY: PASS — {len(c['strings'])} keys × {len(expected_codes)} locale codes; {len(EXPECTED)} language choices")
