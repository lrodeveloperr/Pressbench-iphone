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
for key,item in c.get('strings',{}).items():
    tr=item.get('translations',{})
    if set(tr)!=expected_codes: errors.append(f'{key}: translation-code set mismatch')
    source_ph=ph.findall(item.get('source',''))
    for code in expected_codes:
        text=tr.get(code,'')
        if not isinstance(text,str) or not text.strip(): errors.append(f'{key}/{code}: empty')
        if len(ph.findall(text))!=len(source_ph): errors.append(f'{key}/{code}: placeholder mismatch')
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
