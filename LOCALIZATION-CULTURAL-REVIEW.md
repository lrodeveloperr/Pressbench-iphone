# PressBench 31-Language Cultural Localization Review

## Scope and decisions

- Reviewed the current customer-facing native-wrapper inventory in screen context, not as isolated sentences.
- Localized interface/system copy and human-facing PDF/XLSX report copy.
- Preserved operator-entered production content exactly as recorded; the app never silently translates job names, setup titles, machine nicknames, supplier names, notes, or free-text operating values.
- Kept CSV/JSON schema keys canonical and language-neutral for import/export compatibility; these are data formats, not human-facing reports.
- Replaced physical left/right navigation symbols with semantic forward/back behavior for RTL.
- External policy pages remain English; non-English UI explicitly tells the user this instead of presenting an unreviewed legal translation.

## Language-by-language review

| Language | Locale behavior | Setups tab | Runs tab | Evidence status | First-pass yield | Cultural/terminology decision |
|---|---|---|---|---|---|---|
| English (`en`) | en-US (also en-CA/en-GB by region) | Setups | Runs | Proven | First-pass yield | Neutral shop-floor English; time-of-day greeting removed. Keeps established terms such as platen and first-pass yield. |
| Español (`es`) | es-MX (es-ES in Spain) | Procesos | Ejecuciones | Probado | Rendimiento a la primera | Uses region-neutral production terminology. Bottom tab uses “Procesos”; production runs use “Ejecuciones” rather than colloquial “corridas”. |
| Português (`pt`) | pt-PT (pt-BR in Brazil) | Configurações | Execuções | Testado | Rendimento à primeira passagem | Portuguese manufacturing wording with locale-specific PT/BR formatting. Compact navigation avoids overlong literal labels; “Testado” avoids sounding like external certification. |
| Français (`fr`) | fr-FR (fr-CA in Canada) | Réglages | Séries | Éprouvé | Rendement au premier passage | Uses “rebut” for scrap/waste and “éprouvé” for tried-and-tested. Machine “in use” is shortened to “Occupée” on the compact badge. |
| Deutsch (`de`) | de-DE | Prozesse | Durchläufe | Bewährt | Erstausbeute | Uses manufacturing terms “Erstteil”, “Erstausbeute”, “Ausschuss”; compact tabs use “Prozesse” and “Durchläufe”. “Bewährt” signals tried-and-tested, not certification. |
| Italiano (`it`) | it-IT | Setup | Cicli | Testato | Resa al primo passaggio | Technical “Setup” is retained where culturally natural; “resa al primo passaggio” and “scarto” are used in reports. “Testato” is used for the evidence-backed state. |
| Nederlands (`nl`) | nl-NL | Processen | Productieruns | Beproefd | Opbrengst bij eerste doorgang | Uses “Processen”, “Productieruns”, “opbrengst bij eerste doorgang”, and “uitval”; avoids consumer-app wording. |
| Polski (`pl`) | pl-PL | Procesy | Przebiegi | Sprawdzony | Uzysk za pierwszym przejściem | Uses “Procesy”, “Przebiegi”, “pierwsza sztuka”, and “Sprawdzony”; compact navigation is shortened to fit without truncation. |
| Türkçe (`tr`) | tr-TR | Prosesler | Üretim | Denenmiş | İlk geçiş verimi | Uses “Prosesler” and a compact “Üretim” tab; “İlk parça / İlk geçiş verimi / Fire” fit Turkish production vocabulary. “Denenmiş” avoids certification tone. |
| Română (`ro`) | ro-RO | Procese | Rulări | Testat | Randament la prima trecere | Uses “Procese”, “Rulări”, “prima piesă”, and “rebut”; “Testat” is used instead of a stronger certification-like “dovedit”. |
| Čeština (`cs`) | cs-CZ | Procesy | Výrobní série | Osvědčené | Výtěžnost na první průchod | Uses “Procesy”, “Výrobní série”, “První kus”, “Výtěžnost na první průchod”, and “Zmetky”. “Osvědčené” reads as proven in practice. |
| Українська (`uk`) | uk-UA | Процеси | Запуски | Випробувано | Вихід з першого проходу | Compact tabs use “Процеси / Запуски”. “Випробувано” and “Останнє успішне випробування” emphasize practical evidence rather than formal approval. |
| Русский (`ru`) | ru-RU | Процессы | Запуски | Опробовано | Выход годных с первого прохода | Compact tabs use “Процессы / Запуски / Прессы”. “Опробовано” and “Последний успешный результат” reduce certification ambiguity. |
| العربية (`ar`) | ar-SA | العمليات | دورات الإنتاج | مُجرّب | معدل النجاح من المرة الأولى | Full RTL. Uses practical production language and “مُجرّب” for tried/tested. Directional navigation is semantic and mirrors automatically; Western UI assumptions are removed. |
| 中文 (`zh`) | zh-Hans; zh-Hant for TW/HK/MO or Hant device locale | 工艺设置 | 生产运行 | 已有成功记录 | 一次合格率 | Simplified/Traditional script follows device region/script without adding a 32nd language choice. Uses industry-standard “一次合格率”; “已有成功记录/已有成功紀錄” avoids certification implications. |
| 日本語 (`ja`) | ja-JP | 工程設定 | 生産実行 | 実績あり | 初回合格率 | Uses manufacturing-oriented “初品”, “初回合格率”, “廃棄”, and status “実績あり”; avoids a literal certification-style rendering of Proven. |
| 한국어 (`ko`) | ko-KR | 공정 설정 | 생산 실행 | 실적 있음 | 1차 합격률 | Uses “초도품”, “1차 합격률”, “폐기”; status is “실적 있음” to mean there is a successful track record, not official validation. |
| हिन्दी (`hi`) | hi-IN | प्रक्रिया सेटअप | उत्पादन रन | परीक्षित | पहली बार में सफल दर | Accessible Hindi production wording with “परीक्षित” for tested. Numbers/dates follow hi-IN locale while operator-entered names stay unchanged. |
| اردو (`ur`) | ur-PK | عملیات | پیداواری رنز | آزمودہ | پہلی بار کامیابی کی شرح | Full RTL. “آزمودہ” conveys tried-and-tested more naturally than a formal proof/certification term; numbers/dates use ur-PK locale. |
| বাংলা (`bn`) | bn-BD | প্রক্রিয়া সেটআপ | উৎপাদন রান | পরীক্ষিত | প্রথমবার সফলতার হার | Uses accessible Bengali production language; “পরীক্ষিত” conveys tested. Locale formatting follows bn-BD and user-entered records are preserved verbatim. |
| Tiếng Việt (`vi`) | vi-VN | Quy trình | Lượt sản xuất | Có kết quả tốt | Tỷ lệ đạt ngay lần đầu | Uses “Quy trình / Lượt sản xuất / Tỷ lệ đạt ngay lần đầu / Phế phẩm”. Evidence status is phrased as “Có kết quả tốt” rather than formal certification. |
| Bahasa Indonesia (`id`) | id-ID | Proses | Sesi produksi | Teruji | Tingkat lolos pertama | Uses “Proses / Sesi produksi / Tingkat lolos pertama / Produk terbuang”. “Teruji” is used for tried/tested evidence. |
| ไทย (`th`) | th-TH | ขั้นตอน | รอบการผลิต | ผ่านการทดสอบ | อัตราผ่านครั้งแรก | Compact tab uses “ขั้นตอน”; production uses “รอบการผลิต”. Evidence wording uses “ผ่านการทดสอบ” rather than formal proof language. |
| Filipino (`fil`) | fil-PH | Proseso | Mga run | Subok na | First-pass yield | Deliberate technical Taglish where it is more natural for Filipino shop software (e.g. “Mga run”, “First-pass yield”) instead of forced, uncommon purist translations. |
| Bahasa Melayu (`ms`) | ms-MY | Proses | Kitaran | Telah diuji | Kadar lulus kali pertama | Uses “Proses / Kitaran / Kadar lulus kali pertama / Buangan”. “Telah diuji” conveys tested in practice. |
| Suomi (`fi`) | fi-FI | Prosessit | Ajot | Hyväksi todettu | Ensikierroksen saanto | Uses concise manufacturing vocabulary “Prosessit / Ajot / Ensikierroksen saanto / Hylky”. “Hyväksi todettu” is a natural tried-and-tested status. |
| Svenska (`sv`) | sv-SE | Processer | Körningar | Beprövad | Förstapassutbyte | Uses “Processer / Körningar / Förstapassutbyte / Kassation”. “Beprövad” is culturally natural and avoids formal certification. |
| Dansk (`da`) | da-DK | Processer | Kørsler | Afprøvet | Udbytte ved første gennemløb | Uses “Processer / Kørsler / Udbytte ved første gennemløb / Kassation”. “Afprøvet” communicates tried/tested. |
| Norsk bokmål (`nb`) | nb-NO | Oppsett | Kjøringer | Utprøvd | Utbytte ved første gjennomløp | Uses compact “Oppsett / Kjøringer”, with “Utbytte ved første gjennomløp / Kassasjon”. “Utprøvd” fits practical evidence. |
| Ελληνικά (`el`) | el-GR | Διαδικασίες | Παραγωγή | Δοκιμασμένο | Απόδοση πρώτης διέλευσης | Compact tabs use “Διαδικασίες / Παραγωγή”. Uses “Πρώτο τεμάχιο / Απόδοση πρώτης διέλευσης / Απορρίψεις”; “Δοκιμασμένο” means tried/tested. |
| עברית (`he`) | he-IL | הגדרות תהליך | הרצות ייצור | נוסה | תפוקה במעבר ראשון | Full RTL. Status is “נוסה” and latest evidence is “תוצאה מוצלחת אחרונה”, avoiding certification tone; semantic navigation mirrors automatically. |

### Chinese script variant

Traditional Chinese (`zh-Hant`) is a locale/script override under the single 中文 language choice. Key manufacturing terms include **已有成功紀錄**, **一次良率**, and **報廢**. The app does not silently cross from Simplified to Traditional or vice versa when the device script is known.

## Remaining human-review gate

This pass is an expert product-localization review and code QA, not a substitute for independent native-speaker sign-off on legal copy. Before public release, the highest-value final check is in-context native-speaker review on compact iPhones for the markets you expect to monetize most heavily. The external Terms, Privacy and Safety pages are intentionally **not** machine/model-translated in this package; they remain English until separately approved legal translations exist.
