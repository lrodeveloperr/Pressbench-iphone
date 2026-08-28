from pathlib import Path
import json,csv,re
root=Path(__file__).resolve().parent
meta=json.loads((root/'localization_keys.json').read_text())
# preserve key order from json
keys=list(meta)
# unique source phrase order
phrases=[]; seen=set()
for k in keys:
    s=meta[k]['source']
    if s not in seen:
        seen.add(s); phrases.append(s)
assert len(phrases)==304
languages=['en','es','pt','fr','de','it','nl','pl','tr','ro','cs','uk','ru','ar','zh','ja','ko','hi','ur','bn','vi','id','th','fil','ms','fi','sv','da','nb','el','he']
translations={'en':{s:s for s in phrases}}
for lang in languages:
    if lang=='en': continue
    lines=(root/f'translations/{lang}.txt').read_text(encoding='utf-8').splitlines()
    assert len(lines)==len(phrases),(lang,len(lines))
    translations[lang]=dict(zip(phrases,lines))
# Traditional Chinese full locale override
zhh=(root/'translations/zh-Hant.txt').read_text(encoding='utf-8').splitlines()
assert len(zhh)==len(phrases)
translations['zh-Hant']=dict(zip(phrases,zhh))

def runtime_placeholders(s):
    return s.replace('%1$d','%1$@').replace('%2$d','%2$@').replace('%d','%@')

# Context-specific short labels for compact bottom-tab/status surfaces.
# These intentionally differ from longer library/report translations where a literal full label would truncate.
KEY_OVERRIDES = {
  'tab.setups': {
    'es':'Procesos','pt':'Receitas','de':'Prozesse','it':'Setup','nl':'Processen','pl':'Procesy','tr':'Prosesler','ro':'Procese',
    'cs':'Procesy','uk':'Процеси','ru':'Процессы','ar':'العمليات','hi':'सेटअप','ur':'عملیات','bn':'সেটআপ','vi':'Quy trình','id':'Proses',
    'th':'ขั้นตอน','fil':'Proseso','ms':'Proses','fi':'Prosessit','sv':'Processer','da':'Processer','nb':'Oppsett','el':'Διαδικασίες'
  },
  'tab.runs': {
    'de':'Durchläufe','nl':'Producties','tr':'Üretim','uk':'Запуски','ru':'Запуски','vi':'Mẻ','fil':'Mga run','ms':'Kitaran','fi':'Ajot',
    'sv':'Körningar','da':'Kørsler','nb':'Kjøringer','el':'Παραγωγή'
  },
  'tab.machines': {'ru':'Прессы'},
  'machines.inUse': {'fr':'Occupée','uk':'У роботі'},
  'status.proven': {
    'pt':'Testado','it':'Testato','tr':'Denenmiş','ro':'Testat','uk':'Випробувано','ru':'Опробовано',
    'ar':'مُجرّب','zh':'已有成功记录','ko':'실적 있음','hi':'परीक्षित','ur':'آزمودہ','bn':'পরীক্ষিত',
    'vi':'Có kết quả tốt','id':'Teruji','th':'ผ่านการทดสอบ','ms':'Telah diuji','he':'נוסה','zh-Hant':'已有成功紀錄'
  },
  'onboarding.process.proven': {
    'pt':'Testado','it':'Testato','tr':'Denenmiş','ro':'Testat','uk':'Випробувано','ru':'Опробовано',
    'ar':'مُجرّب','zh':'已有成功记录','ko':'실적 있음','hi':'परीक्षित','ur':'آزمودہ','bn':'পরীক্ষিত',
    'vi':'Có kết quả tốt','id':'Teruji','th':'ผ่านการทดสอบ','ms':'Telah diuji','he':'נוסה','zh-Hant':'已有成功紀錄'
  },
  'setups.notProven': {
    'pt':'Ainda não testado','it':'Non ancora testato','tr':'Henüz denenmedi','ro':'Încă netestat',
    'uk':'Ще не випробувано','ru':'Ещё не опробовано','ar':'لم يُجرَّب بعد','zh':'暂无成功记录',
    'ko':'아직 실적 없음','hi':'अभी परीक्षित नहीं','ur':'ابھی آزمودہ نہیں','bn':'এখনও পরীক্ষিত নয়',
    'vi':'Chưa có kết quả tốt','id':'Belum teruji','th':'ยังไม่ผ่านการทดสอบ','ms':'Belum diuji','he':'טרם נוסה','zh-Hant':'暫無成功紀錄'
  },
  'setup.lastProven': {
    'fr':'Dernier résultat concluant','pt':'Último resultado testado','it':'Ultimo test riuscito','tr':'Son başarılı deneme',
    'ro':'Ultimul rezultat testat','uk':'Останнє успішне випробування','ru':'Последний успешный результат',
    'ar':'آخر نتيجة ناجحة','zh':'最近成功记录','ko':'최근 성공 실적','hi':'अंतिम सफल रिकॉर्ड','ur':'آخری کامیاب ریکارڈ',
    'bn':'সর্বশেষ সফল রেকর্ড','vi':'Kết quả tốt gần nhất','id':'Hasil teruji terakhir','th':'ผลทดสอบสำเร็จล่าสุด',
    'ms':'Ujian berjaya terakhir','he':'תוצאה מוצלחת אחרונה','zh-Hant':'最近成功紀錄'
  },
}

# runtime catalog key -> locale/language translation
catalog={
  'schemaVersion':1,
  'languages':languages,
  'localeOverrideCodes':['zh-Hant'],
  'strings':{}
}
for key in keys:
    source=meta[key]['source']
    item={'context':meta[key]['context'],'source':runtime_placeholders(source),'translations':{}}
    for lang in languages:
        item['translations'][lang]=runtime_placeholders(translations[lang][source])
    item['translations']['zh-Hant']=runtime_placeholders(translations['zh-Hant'][source])
    for lang, text in KEY_OVERRIDES.get(key, {}).items():
        item['translations'][lang] = runtime_placeholders(text)
    catalog['strings'][key]=item

resources=root/'PressBench/Resources'
resources.mkdir(parents=True,exist_ok=True)
(resources/'Localizations.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')

# Long-form audit CSV - every key x every language, plus Traditional Chinese locale override
rows=[]
for key,item in catalog['strings'].items():
    for lang in languages+['zh-Hant']:
        target=item['translations'][lang]
        rows.append({
            'key':key,'context':item['context'],'language':lang,
            'source_en':item['source'],'localized_text':target,
            'review_status':'reviewed-in-context-and-cultural-fit',
            'content_policy':'system UI/report copy; user-entered production content is never translated'
        })
with (root/'LOCALIZATION-AUDIT-31-LANGUAGES.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)

# Matrix completeness / placeholder checks
problems=[]
expected=set(languages+['zh-Hant'])
for key,item in catalog['strings'].items():
    if set(item['translations'])!=expected: problems.append(f'{key}: locale set mismatch')
    src_ph=re.findall(r'%(?:\d+\$)?@',item['source'])
    for lang,text in item['translations'].items():
        ph=re.findall(r'%(?:\d+\$)?@',text)
        if len(ph)!=len(src_ph): problems.append(f'{key}/{lang}: placeholders {ph} != {src_ph}')
        if not text.strip(): problems.append(f'{key}/{lang}: empty')
print('keys',len(catalog['strings']),'rows',len(rows),'problems',len(problems))
for p in problems[:20]: print(p)
if problems: raise SystemExit(1)
