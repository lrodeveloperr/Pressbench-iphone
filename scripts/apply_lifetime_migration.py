from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    s = read(path)
    count = s.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one match, found {count}: {old[:100]!r}")
    write(path, s.replace(old, new))


# Deterministic monetization contract: lifetime primary; monthly retained only for legacy buyers.
replace_once(
    "PressBench/Resources/PressBenchLogic.js",
    '''    ios: Object.freeze({
        productId: "pressbench_unlimited_monthly_ios",
        legacyProductIds: Object.freeze(["pressbench_unlimited_lifetime_ios"]),
        productType: "auto_renewable_subscription", recurring: true, period: "P1M", restoreAction: true,
        benefits: Object.freeze(["unlimited_presses", "pdf_xlsx_reports"]),
        pricing: Object.freeze({ baseStorefront: "US", baseCurrency: "USD", baseAmountMinor: 699, geoPriced: true })
      }),''',
    '''    ios: Object.freeze({
        productId: "pressbench_unlimited_lifetime_ios",
        legacyProductIds: Object.freeze(["pressbench_unlimited_monthly_ios"]),
        productType: "non_consumable", recurring: false, restoreAction: true,
        benefits: Object.freeze(["unlimited_presses", "pdf_xlsx_reports"]),
        pricing: Object.freeze({ baseStorefront: "US", baseCurrency: "USD", baseAmountMinor: 3999, geoPriced: true })
      }),''',
)
replace_once("PressBench/Resources/PressBenchLogic.js", "const FREE_BATCH_LIMIT = 5;", "const FREE_BATCH_LIMIT = 3;")
replace_once(
    "PressBench/Resources/PressBenchLogic.js",
    '''    const productType = platform === "ios" && productId === B.MONETIZATION_MODEL.ios.productId ?
      "auto_renewable_subscription" : "non_consumable";''',
    '''    const productType = platform === "ios" ?
      (productId === B.MONETIZATION_MODEL.ios.productId ? "non_consumable" :
       B.MONETIZATION_MODEL.ios.legacyProductIds.includes(productId) ? "auto_renewable_subscription" : "non_consumable") :
      "non_consumable";''',
)

# Only a legacy monthly entitlement should expose Apple's subscription-management surface.
replace_once(
    "PressBench/Models/PressBenchStore.swift",
    'isPro && string(currentEntitlement["productId"]) == PurchaseManager.productID',
    'isPro && string(currentEntitlement["productId"]) == PurchaseManager.legacySubscriptionProductID',
)

# StoreKit lifetime price must never be described as monthly.
replace_once(
    "PressBench/Views/ProductionEditors.swift",
    '''    private var subscribeTitle: String {
        guard let price = store.productDisplayPrice else { return t("upgrade.unlock") }
        let monthlyPrice = PBL10n.format("upgrade.pricePerMonthFormat", language: language, locale: locale, price as NSString)
        return "\\(t("upgrade.unlock")) · \\(monthlyPrice)"
    }''',
    '''    private var subscribeTitle: String {
        guard let price = store.productDisplayPrice else { return t("upgrade.unlock") }
        return "\\(t("upgrade.unlock")) · \\(price)"
    }''',
)

reports = read("PressBench/Views/ReportsView.swift")
pattern = re.compile(r'''if let price = store\.productDisplayPrice \{\s*Text\(PBL10n\.format\(\s*"upgrade\.pricePerMonthFormat",\s*language: language,\s*locale: locale,\s*price as NSString\s*\)\)\s*\}''', re.S)
reports, n = pattern.subn('''if let price = store.productDisplayPrice {
                                    Text(price)
                                }''', reports, count=1)
if n != 1:
    raise SystemExit(f"ReportsView price block replacements={n}")
write("PressBench/Views/ReportsView.swift", reports)

# Canonical English source strings.
replace_once(
    "build_l10n.py",
    "'upgrade.body': ('Upgrade explanation', 'Unlimited press runs and PDF or XLSX reports. Renews monthly until canceled.'),",
    "'upgrade.body': ('Upgrade explanation', 'Unlimited press runs and PDF or XLSX reports. One-time purchase.'),",
)
replace_once("build_l10n.py", "'upgrade.unlock': ('Upgrade action', 'Subscribe'),", "'upgrade.unlock': ('Upgrade action', 'Unlock forever'),")
replace_once(
    "build_l10n.py",
    "'upgrade.pricePerMonthFormat': ('Monthly subscription price', '%1$@ per month'),",
    "'upgrade.pricePerMonthFormat': ('One-time purchase price', '%1$@ one time'),",
)
replace_once(
    "build_l10n.py",
    "'purchase.unavailable': ('Subscription availability status', 'The subscription is unavailable right now. Try again in a moment.'),",
    "'purchase.unavailable': ('Purchase availability status', 'The lifetime purchase is unavailable right now. Try again in a moment.'),",
)
replace_once(
    "phrases.tsv",
    "Unlimited press runs and PDF or XLSX reports. Renews monthly until canceled.\tupgrade.body",
    "Unlimited press runs and PDF or XLSX reports. One-time purchase.\tupgrade.body",
)
replace_once("phrases.tsv", "Subscribe\tupgrade.unlock", "Unlock forever\tupgrade.unlock")

# Product-specific translations for the four affected paywall strings.
body = {
    'en':'Unlimited press runs and PDF or XLSX reports. One-time purchase.','es':'Ejecuciones de prensado ilimitadas e informes PDF o XLSX. Compra única.','pt':'Prensagens ilimitadas e relatórios PDF ou XLSX. Compra única.','fr':'Pressages illimités et rapports PDF ou XLSX. Achat unique.','de':'Unbegrenzte Pressvorgänge und PDF- oder XLSX-Berichte. Einmaliger Kauf.','it':'Pressature illimitate e report PDF o XLSX. Acquisto una tantum.','nl':'Onbeperkt persen en PDF- of XLSX-rapporten. Eenmalige aankoop.','pl':'Nielimitowane prasowania oraz raporty PDF lub XLSX. Jednorazowy zakup.','tr':'Sınırsız baskı ve PDF ya da XLSX raporları. Tek seferlik satın alma.','ro':'Presări nelimitate și rapoarte PDF sau XLSX. Achiziție unică.','cs':'Neomezené lisování a sestavy PDF nebo XLSX. Jednorázový nákup.','uk':'Необмежені пресування та звіти PDF або XLSX. Одноразова покупка.','ru':'Неограниченные прессования и отчёты PDF или XLSX. Разовая покупка.','ar':'عمليات ضغط غير محدودة وتقارير PDF أو XLSX. شراء لمرة واحدة.','zh':'无限次压烫，并可生成 PDF 或 XLSX 报告。一次性购买。','ja':'プレス回数無制限とPDFまたはXLSXレポート。買い切りです。','ko':'무제한 프레스와 PDF 또는 XLSX 보고서. 일회성 구매입니다.','hi':'असीमित प्रेस और PDF या XLSX रिपोर्ट। एक बार की खरीद।','ur':'لامحدود پریس اور PDF یا XLSX رپورٹس۔ ایک بار کی خریداری۔','bn':'সীমাহীন প্রেস এবং PDF বা XLSX প্রতিবেদন। এককালীন ক্রয়।','vi':'Lượt ép không giới hạn và báo cáo PDF hoặc XLSX. Mua một lần.','id':'Pengepresan tanpa batas serta laporan PDF atau XLSX. Pembelian satu kali.','th':'กดได้ไม่จำกัดและมีรายงาน PDF หรือ XLSX ซื้อครั้งเดียว','fil':'Walang limitasyong pag-press at may PDF o XLSX na ulat. Isang beses na pagbili.','ms':'Tekanan tanpa had dan laporan PDF atau XLSX. Pembelian sekali sahaja.','fi':'Rajoittamattomat puristukset sekä PDF- tai XLSX-raportit. Kertaosto.','sv':'Obegränsade pressningar och PDF- eller XLSX-rapporter. Engångsköp.','da':'Ubegrænsede presninger og PDF- eller XLSX-rapporter. Engangskøb.','nb':'Ubegrensede pressinger og PDF- eller XLSX-rapporter. Engangskjøp.','el':'Απεριόριστες πρέσες και αναφορές PDF ή XLSX. Εφάπαξ αγορά.','he':'לחיצות ללא הגבלה ודוחות PDF או XLSX. רכישה חד-פעמית.','zh-Hant':'無限次壓燙，並可產生 PDF 或 XLSX 報告。一次性購買。'
}
unlock = {'en':'Unlock forever','es':'Desbloquear para siempre','pt':'Desbloquear para sempre','fr':'Débloquer à vie','de':'Dauerhaft freischalten','it':'Sblocca per sempre','nl':'Voor altijd ontgrendelen','pl':'Odblokuj na zawsze','tr':'Kalıcı olarak aç','ro':'Deblochează permanent','cs':'Odemknout navždy','uk':'Розблокувати назавжди','ru':'Разблокировать навсегда','ar':'فتح دائم','zh':'永久解锁','ja':'永久にロック解除','ko':'영구 잠금 해제','hi':'हमेशा के लिए अनलॉक करें','ur':'ہمیشہ کے لیے کھولیں','bn':'স্থায়ীভাবে আনলক করুন','vi':'Mở khóa vĩnh viễn','id':'Buka selamanya','th':'ปลดล็อกถาวร','fil':'I-unlock habambuhay','ms':'Buka untuk selamanya','fi':'Avaa pysyvästi','sv':'Lås upp permanent','da':'Lås op permanent','nb':'Lås opp permanent','el':'Μόνιμο ξεκλείδωμα','he':'פתיחה לצמיתות','zh-Hant':'永久解鎖'}
unavailable = {'en':'The lifetime purchase is unavailable right now. Try again in a moment.','es':'La compra permanente no está disponible ahora. Inténtalo de nuevo en un momento.','pt':'A compra permanente não está disponível agora. Tente novamente em instantes.','fr':'L’achat définitif est indisponible pour le moment. Réessayez dans un instant.','de':'Der dauerhafte Kauf ist derzeit nicht verfügbar. Versuche es gleich noch einmal.','it':'L’acquisto permanente non è disponibile al momento. Riprova tra poco.','nl':'De permanente aankoop is nu niet beschikbaar. Probeer het zo opnieuw.','pl':'Zakup bezterminowy jest teraz niedostępny. Spróbuj ponownie za chwilę.','tr':'Kalıcı satın alma şu anda kullanılamıyor. Birazdan tekrar deneyin.','ro':'Achiziția permanentă nu este disponibilă momentan. Încercați din nou în curând.','cs':'Trvalý nákup teď není dostupný. Zkuste to za chvíli znovu.','uk':'Постійна покупка зараз недоступна. Спробуйте ще раз за мить.','ru':'Постоянная покупка сейчас недоступна. Повторите попытку чуть позже.','ar':'الشراء الدائم غير متاح الآن. حاول مرة أخرى بعد قليل.','zh':'永久购买目前不可用。请稍后重试。','ja':'永久購入は現在利用できません。しばらくしてからもう一度お試しください。','ko':'영구 구매를 지금 이용할 수 없습니다. 잠시 후 다시 시도하세요.','hi':'स्थायी खरीद अभी उपलब्ध नहीं है। थोड़ी देर में फिर कोशिश करें।','ur':'مستقل خرید ابھی دستیاب نہیں ہے۔ تھوڑی دیر بعد دوبارہ کوشش کریں۔','bn':'স্থায়ী ক্রয়টি এখন উপলভ্য নয়। একটু পরে আবার চেষ্টা করুন।','vi':'Giao dịch mua vĩnh viễn hiện chưa khả dụng. Hãy thử lại sau giây lát.','id':'Pembelian permanen sedang tidak tersedia. Coba lagi sebentar lagi.','th':'การซื้อแบบถาวรยังไม่พร้อมใช้งานในขณะนี้ โปรดลองอีกครั้งในอีกสักครู่','fil':'Hindi available ngayon ang permanenteng pagbili. Subukan muli makalipas ang ilang sandali.','ms':'Pembelian kekal tidak tersedia sekarang. Cuba lagi sebentar lagi.','fi':'Pysyvä osto ei ole juuri nyt saatavilla. Yritä hetken kuluttua uudelleen.','sv':'Det permanenta köpet är inte tillgängligt just nu. Försök igen om en stund.','da':'Det permanente køb er ikke tilgængeligt lige nu. Prøv igen om et øjeblik.','nb':'Det permanente kjøpet er ikke tilgjengelig akkurat nå. Prøv igjen om litt.','el':'Η μόνιμη αγορά δεν είναι διαθέσιμη αυτή τη στιγμή. Δοκιμάστε ξανά σε λίγο.','he':'הרכישה הקבועה אינה זמינה כרגע. נסו שוב בעוד רגע.','zh-Hant':'永久購買目前無法使用。請稍後再試。'}

mt_path = ROOT / "monetization_translations.json"
mt = json.loads(mt_path.read_text(encoding="utf-8"))
mt['upgrade.body'] = body
mt['upgrade.unlock'] = unlock
mt['upgrade.pricePerMonthFormat'] = {k: ('%1$@ one time' if k == 'en' else '%1$@') for k in unlock}
mt['purchase.unavailable'] = unavailable
mt_path.write_text(json.dumps(mt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

# UI tests must look for the new customer-facing language.
ui = read("PressBenchUITests/FirstUseFlowUITests.swift")
ui = ui.replace("The subscription is unavailable right now. Try again in a moment.", "The lifetime purchase is unavailable right now. Try again in a moment.")
ui = ui.replace('app.buttons["Subscribe"]', 'app.buttons["Unlock forever"]')
write("PressBenchUITests/FirstUseFlowUITests.swift", ui)

# Replace the old entitlement smoke-test block with permanent + legacy-expiry assertions.
smoke = read("scripts/engine_smoke.js")
pattern = re.compile(r'// A fabricated local boolean must never create paid access\..*?assert\.equal\(B\.MONETIZATION_MODEL\.ios\.pricing\.baseAmountMinor, 699\);', re.S)
replacement = '''// A fabricated local boolean must never create paid access.
assert.equal(E.evaluateEntitlement({paidAccess:true, productId:'pressbench_unlimited_lifetime_ios'}, now).paidAccess, false);

// Verified non-consumable lifetime purchase remains entitled without an expiry.
const purchasedEvent = {
  action:'purchase', platform:'ios', userInitiated:true, nativeAdapterVerified:true,
  verificationSource:'storekit2', productId:'pressbench_unlimited_lifetime_ios',
  productType:'non_consumable', purchaseState:'purchased', transactionId:'1000000000001',
  nativeVerificationId:'storekit2:1000000000001:1000000000001:pressbench_unlimited_lifetime_ios:1787155200', storeEventAt:now
};
let purchaseResult = E.applyStoreEvent(entitlement, purchasedEvent, now);
entitlement = purchaseResult.entitlement;
assert.equal(E.evaluateEntitlement(entitlement, now).paidAccess, true);
assert.equal(E.evaluateEntitlement(entitlement, iso(400 * 24 * 60 * 60)).paidAccess, true);
context.entitlement = entitlement;

// A legacy monthly entitlement remains recognized only until its verified expiry.
const legacyEvent = {...purchasedEvent, productId:'pressbench_unlimited_monthly_ios', productType:'auto_renewable_subscription',
  transactionId:'1000000000002', nativeVerificationId:'storekit2:1000000000002:1000000000002:pressbench_unlimited_monthly_ios:1787155200',
  expiresAt:iso(31 * 24 * 60 * 60)};
const legacyEntitlement = E.applyStoreEvent(E.normalizeEntitlement({}), legacyEvent, now).entitlement;
assert.equal(E.evaluateEntitlement(legacyEntitlement, iso(20 * 24 * 60 * 60)).paidAccess, true);
assert.equal(E.evaluateEntitlement(legacyEntitlement, iso(32 * 24 * 60 * 60)).paidAccess, false);

assert.equal(B.FREE_BATCH_LIMIT, 3);
assert.equal(B.MONETIZATION_MODEL.ios.productType, 'non_consumable');
assert.equal(B.MONETIZATION_MODEL.ios.recurring, false);
assert.equal(B.MONETIZATION_MODEL.ios.pricing.baseAmountMinor, 3999);'''
smoke, n = pattern.subn(replacement, smoke, count=1)
if n != 1:
    raise SystemExit(f"engine smoke block replacements={n}")
write("scripts/engine_smoke.js", smoke)

# Integrity checker protects the new contract.
ri = read("scripts/release_integrity.py")
ri = ri.replace("['pressbench_unlimited_monthly_ios', 'pressbench_unlimited_lifetime_ios',\n        'productType: \"auto_renewable_subscription\"', 'recurring: true', 'baseAmountMinor: 699',", "['pressbench_unlimited_lifetime_ios', 'pressbench_unlimited_monthly_ios',\n        'productType: \"non_consumable\"', 'recurring: false', 'baseAmountMinor: 3999',")
ri = ri.replace("'monthly iOS subscription or grandfathered lifetime entitlement is missing'", "'lifetime iOS purchase or legacy monthly entitlement is missing'")
ri = ri.replace("'FREE_BATCH_LIMIT = 5'", "'FREE_BATCH_LIMIT = 3'")
ri = ri.replace("'five-press free allowance or unrestricted setup library changed'", "'three-press free allowance or unrestricted setup library changed'")
ri = ri.replace("['pressbench_unlimited_monthly_ios',\n        'pressbench_unlimited_lifetime_ios', '.autoRenewable', 'subscriptionPeriod.unit == .month',\n        'transaction.expirationDate']", "['pressbench_unlimited_lifetime_ios',\n        'pressbench_unlimited_monthly_ios', '.nonConsumable', 'legacySubscriptionProductID',\n        'transaction.expirationDate']")
ri = ri.replace("'native subscription verification or lifetime grandfathering is incomplete'", "'native lifetime verification or legacy-subscription migration is incomplete'")
ri = ri.replace("'freePressLimit = 5'", "'freePressLimit = 3'")
write("scripts/release_integrity.py", ri)

print("PressBench lifetime migration source patch applied")
