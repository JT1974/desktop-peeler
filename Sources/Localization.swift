import Foundation

// Translation. Every user-facing text is written in English in the code and looked up in
// the active language file. A language file is JSON:
//   { "code": "hu", "name": "Magyar", "strings": { "<English text>": "<translation>", ... } }
// Built-in files live in the app bundle (Resources/Languages); files the user adds are
// copied to ~/Library/Application Support/Desktop Peeler/Languages and override built-in
// files with the same code. Missing texts stay in English.

/// Marks a text for translation without translating it yet. Used for texts stored as data
/// (category titles, action names) that are translated where they are shown, with `L`.
func N(_ key: String) -> String {
    return key
}

/// Translates an English text into the active language.
func L(_ key: String) -> String {
    return Localizer.shared.translate(key)
}

/// Translates a format text (for example "%d items") and fills in the values.
func L(_ key: String, _ args: CVarArg...) -> String {
    return String(format: Localizer.shared.translate(key), arguments: args)
}

struct Language: Identifiable {
    let code: String
    let name: String
    let url: URL?          // nil only for the built-in English fallback
    let imported: Bool     // added by the user, can be removed
    var id: String { code }
}

final class Localizer: ObservableObject {
    static let shared = Localizer()
    static let systemChoice = "system"
    private static let preferenceKey = "language"

    @Published private(set) var languages: [Language] = []
    /// Code of the language in use.
    @Published private(set) var active = "en"
    /// "system" or a language code. Saved between launches.
    @Published var choice: String {
        didSet {
            UserDefaults.standard.set(choice, forKey: Localizer.preferenceKey)
            apply()
        }
    }

    private var table: [String: String] = [:]
    private let lock = NSLock()   // texts are also translated on background threads

    static var importFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Desktop Peeler/Languages", isDirectory: true)
    }

    /// The English file a translator fills in.
    var templateURL: URL? {
        return Bundle.main.url(forResource: "en", withExtension: "json", subdirectory: "Languages")
    }

    private init() {
        choice = UserDefaults.standard.string(forKey: Localizer.preferenceKey) ?? Localizer.systemChoice
        reload()
    }

    func translate(_ key: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        return table[key] ?? key
    }

    /// Re-reads the built-in and the added language files.
    func reload() {
        var found: [String: Language] = ["en": Language(code: "en", name: "English", url: nil, imported: false)]
        let folders: [(URL?, Bool)] = [
            (Bundle.main.resourceURL?.appendingPathComponent("Languages"), false),
            (Localizer.importFolder, true)
        ]
        for (folder, imported) in folders {
            guard let folder = folder,
                  let files = try? FileManager.default.contentsOfDirectory(
                    at: folder, includingPropertiesForKeys: nil, options: []) else { continue }
            for file in files where file.pathExtension.lowercased() == "json" {
                if let parsed = try? Localizer.parse(file) {
                    found[parsed.code] = Language(code: parsed.code, name: parsed.name, url: file, imported: imported)
                }
            }
        }
        languages = found.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        apply()
    }

    /// The first of the Mac's preferred languages that has a file, otherwise English.
    var systemLanguage: String {
        let codes = Set(languages.map { $0.code })
        for preferred in Locale.preferredLanguages {
            let lower = preferred.lowercased()
            if codes.contains(lower) { return lower }
            let base = String(lower.split(separator: "-").first ?? "")
            if codes.contains(base) { return base }
        }
        return "en"
    }

    func name(of code: String) -> String {
        return languages.first { $0.code == code }?.name ?? code
    }

    private func apply() {
        let code = choice == Localizer.systemChoice ? systemLanguage : choice
        let language = languages.first { $0.code == code }
        var strings: [String: String] = [:]
        if let url = language?.url, let parsed = try? Localizer.parse(url) {
            strings = parsed.strings
        }
        lock.lock()
        table = strings
        lock.unlock()
        active = language?.code ?? "en"
    }

    private struct FileError: LocalizedError {
        let errorDescription: String?
    }

    static func parse(_ url: URL) throws -> (code: String, name: String, strings: [String: String]) {
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = (root["code"] as? String)?.lowercased(),
              code.range(of: "^[a-z]{2,3}(-[a-z0-9]{2,8})?$", options: .regularExpression) != nil,
              let name = root["name"] as? String, !name.isEmpty,
              let strings = root["strings"] as? [String: String] else {
            throw FileError(errorDescription: L("This is not a Desktop Peeler language file. It needs “code”, “name” and “strings” entries."))
        }
        return (code, name, strings)
    }

    /// Copies a language file into the app's language folder. Returns an error text, or nil.
    func importFile(_ url: URL) -> String? {
        do {
            let parsed = try Localizer.parse(url)
            let fm = FileManager.default
            try fm.createDirectory(at: Localizer.importFolder, withIntermediateDirectories: true)
            let target = Localizer.importFolder.appendingPathComponent(parsed.code + ".json")
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: url, to: target)
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Moves an added language file to the Trash.
    func remove(_ language: Language) {
        guard language.imported, let url = language.url else { return }
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        reload()
    }
}
