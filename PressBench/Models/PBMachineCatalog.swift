import Foundation

/// Manufacturer/model identity and working-area reference data used only to
/// prefill editable local machine profiles. It never controls a machine or
/// implies endorsement, compatibility, or a safe operating recipe.
enum PBMachineCatalog {
    struct Entry: Equatable {
        let brand: String
        let model: String
        let platen: String
        let type: String
    }

    private static func make(_ brand: String, _ rows: [(String, String, String)]) -> [Entry] {
        rows.map { Entry(brand: brand, model: $0.0, platen: $0.1, type: $0.2) }
    }

    static let entries: [Entry] =
        make("Geo Knight", [
            ("DK7", "Cap platen", "Cap"), ("DK7T", "Cap platen", "Cap"),
            ("DC7", "Cap platen", "Multipurpose"), ("DC7AP", "Cap platen", "Automatic"),
            ("DK3", "Mug element", "Mug"), ("DK3D", "Mug element", "Mug"),
            ("DC-MUG", "Mug element", "Mug"), ("DK8", "6 × 8 in", "Clamshell"),
            ("DK8T", "6 × 8 in", "Clamshell"), ("DC8", "6 × 8 in", "Multipurpose"),
            ("DC8AP", "6 × 8 in", "Automatic"), ("DK14S", "12 × 14 in", "Swing-away"),
            ("DK16", "14 × 16 in", "Clamshell"), ("DK16A", "14 × 16 in", "Automatic"),
            ("DC16", "14 × 16 in", "Multipurpose"), ("DC16AP", "14 × 16 in", "Automatic"),
            ("DC16APT", "14 × 16 in", "Automatic"), ("DK20", "16 × 20 in", "Clamshell"),
            ("DK20A", "16 × 20 in", "Automatic"), ("DK20S", "16 × 20 in", "Swing-away"),
            ("DK20SP", "16 × 20 in", "Pneumatic"), ("DK20SPT", "16 × 20 in", "Pneumatic"),
            ("394-TS", "16 × 20 in / 20 × 25 in", "Automatic"),
            ("394-MTS", "16 × 20 in / 20 × 25 in", "Automatic"),
            ("DK25S", "20 × 25 in", "Swing-away"), ("DK25SP", "20 × 25 in", "Pneumatic"),
            ("DK32AP", "26 × 32 in", "Pneumatic"),
            ("MaxiPress 32 × 42", "32 × 42 in", "Large format"),
            ("MaxiPress Air 32 × 42", "32 × 42 in", "Large format"),
            ("MaxiPress 44 × 64", "44 × 64 in", "Large format"),
            ("MaxiPress Air 44 × 64", "44 × 64 in", "Large format"),
            ("931", "54 × 103 in", "Large format")
        ]) + make("HIX", [
            ("HT-400", "15 × 15 in", "Clamshell"), ("HT-600", "16 × 20 in", "Clamshell"),
            ("S-650", "16 × 20 in", "Automatic"), ("N-680", "15 × 15 in", "Pneumatic"),
            ("N-880", "16 × 20 in", "Pneumatic"), ("SwingMan 20", "16 × 20 in", "Swing-away"),
            ("SideKick 20", "2 × 16 × 20 in", "Dual platen")
        ]) + make("Secabo", [
            ("TD7 LITE x Laser", "40 × 50 cm", "Dual platen"),
            ("TD7 SMART x Laser", "40 × 50 cm", "Dual platen"),
            ("TC5 LITE", "38 × 38 cm", "Clamshell"), ("TS5 LITE", "38 × 38 cm", "Swing-away"),
            ("TS7 SMART", "40 × 50 cm", "Swing-away"), ("C5 Clam", "38 × 38 cm", "Clamshell"),
            ("TC1", "15 × 15 cm", "Clamshell"), ("TC2", "23 × 33 cm", "Clamshell"),
            ("TC5 SMART", "38 × 38 cm", "Clamshell"),
            ("TC5 SMART MEMBRAN", "38 × 38 cm", "Clamshell"),
            ("TC7 SMART", "40 × 50 cm", "Clamshell"),
            ("TC7 SMART MEMBRAN", "40 × 50 cm", "Clamshell"),
            ("TC7 LITE", "40 × 50 cm", "Clamshell"), ("TP10", "80 × 100 cm", "Pneumatic"),
            ("THE BEAST", "40 × 50 cm", "Swing-away"), ("TCC SMART", "Cap platen", "Cap"),
            ("TM1", "75–90 mm mug element", "Mug"), ("TCB SMART", "Ball platen", "Ball"),
            ("TS7 LITE", "40 × 50 cm", "Swing-away")
        ]) + make("Hotronix", [
            ("Fusion IQ", "16 × 20 in", "Swing-away"),
            ("Air Fusion IQ", "16 × 20 in", "Pneumatic"),
            ("Dual Air Fusion IQ", "2 × 16 × 20 in", "Dual platen"),
            ("360 IQ Hat Press", "Hat platen", "Cap"),
            ("Auto Open 6 × 6", "6 × 6 in", "Automatic"),
            ("Auto Open 6 × 6 LowRider", "6 × 6 in", "Automatic"),
            ("Auto Open 11 × 15", "11 × 15 in", "Automatic"),
            ("Auto Open 16 × 16", "16 × 16 in", "Automatic"),
            ("Auto Open 16 × 20", "16 × 20 in", "Automatic"),
            ("Auto Open Hover", "16 × 20 in", "Automatic"),
            ("Auto Open Cap", "Cap platen", "Cap"),
            ("MAXX Clam 11 × 15", "11 × 15 in", "Clamshell"),
            ("MAXX Clam 15 × 15", "15 × 15 in", "Clamshell"),
            ("MAXX Clam 16 × 20", "16 × 20 in", "Clamshell"),
            ("MAXX Cap", "Cap platen", "Cap"), ("A2Z (A2Z15)", "15 × 15 in", "Clamshell"),
            ("EASY Craft", "9 × 12 in", "Clamshell")
        ]) + make("HTVRONT", [
            ("A100 Auto Multi Heat Press", "Flat / hat / tumbler modules", "Multipurpose"),
            ("Auto Heat Press", "15 × 15 in", "Automatic"),
            ("Auto Heat Press 2", "15 × 15 in", "Automatic"),
            ("A200 Auto Tumbler Heat Press", "Straight tumbler / glass element", "Mug"),
            ("A300 Auto Hat Heat Press", "Hat platen", "Cap"),
            ("H17 Phone Case Heat Press", "Phone-case vacuum bed", "Multipurpose"),
            ("H10 Heat Press", "12 × 10 in", "Clamshell"),
            ("Mini2 Heat Press", "Mini platen", "Portable"),
            ("Auto Tumbler Heat Press 120V", "Tumbler element", "Mug"),
            ("Manual Hat Heat Press 110V", "Hat platen", "Cap")
        ]) + make("Cricut", [
            ("Autopress", "15 × 12 in", "Automatic"),
            ("EasyPress 3 (9 × 9)", "9 × 9 in", "Portable"),
            ("EasyPress 3 (12 × 10)", "12 × 10 in", "Portable"),
            ("EasyPress 2 (6 × 7)", "6 × 7 in", "Portable"),
            ("EasyPress 2 (9 × 9)", "9 × 9 in", "Portable"),
            ("EasyPress 2 (12 × 10)", "12 × 10 in", "Portable"),
            ("EasyPress Mini", "1.9 × 3.25 in", "Portable"),
            ("Hat Press", "5 × 3 in curved", "Cap")
        ])

    static var brands: [String] {
        Array(Set(entries.map(\.brand))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func models(for brand: String) -> [String] {
        entries.filter { same($0.brand, brand) }.map(\.model)
    }

    static func entry(brand: String, model: String) -> Entry? {
        entries.first { same($0.brand, brand) && same($0.model, model) }
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
