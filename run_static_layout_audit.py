from pathlib import Path
import json,subprocess,re
try:
    from PIL import ImageFont
except Exception as e:
    raise SystemExit(f'Pillow required for local QA: {e}')
root=Path(__file__).resolve().parent
c=json.loads((root/'PressBench/Resources/Localizations.json').read_text(encoding='utf-8'))
codes=c['languages']+['zh-Hant']
families={'ar':'Noto Sans Arabic','ur':'Noto Sans Arabic','he':'Noto Sans Hebrew','hi':'Noto Sans Devanagari','bn':'Noto Sans Bengali','th':'Noto Sans Thai','zh':'Noto Sans CJK SC','zh-Hant':'Noto Sans CJK TC','ja':'Noto Sans CJK JP','ko':'Noto Sans CJK KR'}
def path_for(code):
    fam=families.get(code,'Noto Sans')
    return subprocess.check_output(['fc-match','-f','%{file}',fam],text=True).strip()
def width(text,code,size):
    return float(ImageFont.truetype(path_for(code),size).getlength(text))
slots={
 'bottom-tab': (['tab.home','tab.setups','tab.runs','tab.machines','tab.more'],68,10),
 'status-badge': (['status.proven','status.trial','status.draft','runState.running','runState.completed','machines.available','machines.inUse'],105,11),
 'primary-button': (['common.continue','common.openPressBench','setup.startRun','runs.resume','runs.pause','runs.end','more.viewOnboarding'],330,15),
 'reuse-option-two-lines': (['run.exactRepeat','run.sameProductVariant','run.materiallyDifferent'],552,17),
 'reuse-header-two-lines': (['run.jobDifference'],620,28),
 'settings-row': (['settings.appearance','accessibility.textSize','accessibility.reduceMotion','accessibility.differentiateWithoutColor','accessibility.openSettings','settings.deleteLocalData'],300,17),
}
results=[]; issues=[]
for code in codes:
    for slot,(keys,limit,size) in slots.items():
        for key in keys:
            text=c['strings'][key]['translations'][code]
            measured=round(width(text,code,size),1)
            row={'language':code,'slot':slot,'key':key,'text':text,'width':measured,'limit':limit,'pass':measured<=limit}
            results.append(row)
            if not row['pass']: issues.append(row)
# Home legal links share one HStack; assess the combined intrinsic width plus spacing rather than forcing equal columns.
for code in codes:
    keys=['home.legal.privacy','home.legal.terms','home.legal.safety']
    measured=round(sum(width(c['strings'][k]['translations'][code],code,13) for k in keys)+32,1)
    row={'language':code,'slot':'home-legal-links-combined','key':','.join(keys),'text':' | '.join(c['strings'][k]['translations'][code] for k in keys),'width':measured,'limit':335,'pass':measured<=335}
    results.append(row)
    if not row['pass']: issues.append(row)
summary={'languageChoices':31,'testedLocaleCodes':len(codes),'localizationKeys':len(c['strings']),'textSlotTests':len(results),'textSlotFailures':len(issues),'failures':issues}
(root/'LOCALIZATION-STATIC-LAYOUT-QA.json').write_text(json.dumps({'summary':summary,'results':results},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
if issues: raise SystemExit(1)
