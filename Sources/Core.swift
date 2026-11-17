import Foundation
import CoreServices

// MARK: - Shell helpers

struct ShellResult {
    let status: Int32
    let output: String
    var ok: Bool { status == 0 }
}

enum Shell {
    /// Runs a program and returns its combined stdout+stderr.
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return ShellResult(status: -1, output: error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8) ?? ""
        return ShellResult(status: process.terminationStatus,
                           output: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Runs an AppleScript given as separate lines.
    static func appleScript(_ lines: [String]) -> ShellResult {
        var args: [String] = []
        for line in lines {
            args.append("-e")
            args.append(line)
        }
        return run("/usr/bin/osascript", args)
    }

    /// Escapes a string so it can be placed inside AppleScript double quotes.
    static func appleScriptEscape(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Runs a shell command as administrator. macOS shows its standard password dialog.
    static func runAsAdmin(_ command: String) -> ShellResult {
        let script = "do shell script \"" + appleScriptEscape(command) + "\" with administrator privileges"
        return appleScript([script])
    }
}

// MARK: - Sizes

enum FileSize {
    private static let keys: [URLResourceKey] = [
        .isRegularFileKey, .isSymbolicLinkKey, .isDirectoryKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    static func of(_ url: URL) -> Int64 {
        let keySet = Set(keys)
        guard let values = try? url.resourceValues(forKeys: keySet) else { return 0 }
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }
        for case let file as URL in enumerator {
            if let r = try? file.resourceValues(forKeys: keySet), r.isRegularFile == true {
                total += Int64(r.totalFileAllocatedSize ?? r.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    static func format(_ bytes: Int64) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Cleanup model

struct CleanItem: Identifiable {
    let id: String          // full path
    let url: URL
    let name: String
    let size: Int64
}

struct CleanCategory: Identifiable {
    let id: String
    let title: String
    let explanation: String
    let needsAdmin: Bool
    let preselected: Bool
    var items: [CleanItem]
    var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

private struct CategorySpec {
    enum Mode {
        case children                       // each entry inside the folder is one item
        case whole                          // the folder itself is one item
        case oldChildren(days: Int)         // entries not modified for N days
        case childrenWithExtensions([String], olderThanDays: Int)
    }
    let id: String
    let title: String
    let explanation: String
    let needsAdmin: Bool
    let preselected: Bool
    let sources: [(path: String, mode: Mode)]
}

enum CleanupScanner {
    private static var home: String { NSHomeDirectory() }

    private static func specs() -> [CategorySpec] {
        let tmp = NSTemporaryDirectory()
        return [
            CategorySpec(
                id: "userCaches", title: N("Application caches (your account)"),
                explanation: N("Files apps keep to load faster. Apps rebuild them when needed."),
                needsAdmin: false, preselected: true,
                sources: [(home + "/Library/Caches", .children)]),
            CategorySpec(
                id: "userLogs", title: N("Log files (your account)"),
                explanation: N("Application logs and crash reports. Only useful for troubleshooting."),
                needsAdmin: false, preselected: true,
                sources: [(home + "/Library/Logs", .children)]),
            CategorySpec(
                id: "temp", title: N("Temporary files"),
                explanation: N("Temporary items not modified for more than 2 days."),
                needsAdmin: false, preselected: true,
                sources: [(tmp, .oldChildren(days: 2))]),
            CategorySpec(
                id: "xcode", title: N("Xcode build data"),
                explanation: N("DerivedData, old device support files and simulator caches. Xcode recreates them; the next build is slower."),
                needsAdmin: false, preselected: false,
                sources: [
                    (home + "/Library/Developer/Xcode/DerivedData", .children),
                    (home + "/Library/Developer/Xcode/iOS DeviceSupport", .children),
                    (home + "/Library/Developer/CoreSimulator/Caches", .children)
                ]),
            CategorySpec(
                id: "devCaches", title: N("Developer tool caches"),
                explanation: N("Download caches of npm, Gradle, node-gyp, Android tools and others. They are downloaded again on demand."),
                needsAdmin: false, preselected: false,
                sources: [
                    (home + "/.npm/_cacache", .whole),
                    (home + "/.gradle/caches", .whole),
                    (home + "/.node-gyp", .whole),
                    (home + "/.android/cache", .whole),
                    (home + "/.cache", .children)
                ]),
            CategorySpec(
                id: "installers", title: N("Old installers in Downloads"),
                explanation: N(".dmg, .pkg and .zip files in Downloads older than 30 days. Review each one."),
                needsAdmin: false, preselected: false,
                sources: [(home + "/Downloads", .childrenWithExtensions(["dmg", "pkg", "zip"], olderThanDays: 30))]),
            CategorySpec(
                id: "systemCaches", title: N("System-wide caches"),
                explanation: N("Caches shared by all users in /Library/Caches. Needs your administrator password."),
                needsAdmin: true, preselected: false,
                sources: [("/Library/Caches", .children)]),
            CategorySpec(
                id: "systemLogs", title: N("System-wide logs"),
                explanation: N("Logs in /Library/Logs and rotated archives in /private/var/log. Needs your administrator password."),
                needsAdmin: true, preselected: false,
                sources: [
                    ("/Library/Logs", .children),
                    ("/private/var/log", .childrenWithExtensions(["gz", "bz2", "old"], olderThanDays: 0))
                ])
        ]
    }

    static func scanAll() -> [CleanCategory] {
        let ownBundle = Bundle.main.bundleIdentifier ?? "hu.presoft.desktoppeeler"
        var result: [CleanCategory] = []
        for spec in specs() {
            var items: [CleanItem] = []
            var seen = Set<String>()
            for source in spec.sources {
                for url in candidates(in: source.path, mode: source.mode) {
                    let path = url.path
                    if seen.contains(path) { continue }
                    if url.lastPathComponent == ownBundle { continue }
                    if url.lastPathComponent == ".DS_Store" { continue }
                    seen.insert(path)
                    let size = FileSize.of(url)
                    if size <= 0 { continue }
                    items.append(CleanItem(id: path, url: url, name: displayName(url, source: source.path), size: size))
                }
            }
            items.sort { $0.size > $1.size }
            result.append(CleanCategory(id: spec.id, title: spec.title, explanation: spec.explanation,
                                        needsAdmin: spec.needsAdmin, preselected: spec.preselected, items: items))
        }
        return result
    }

    private static func displayName(_ url: URL, source: String) -> String {
        let parent = URL(fileURLWithPath: source).lastPathComponent
        if url.path == URL(fileURLWithPath: source).path {
            return url.path.replacingOccurrences(of: home, with: "~")
        }
        return parent + "/" + url.lastPathComponent
    }

    private static func candidates(in path: String, mode: CategorySpec.Mode) -> [URL] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else { return [] }

        switch mode {
        case .whole:
            return [root]
        case .children:
            return children(of: root)
        case .oldChildren(let days):
            return children(of: root).filter { isOlder($0, thanDays: days) }
        case .childrenWithExtensions(let exts, let days):
            return children(of: root).filter { url in
                exts.contains(url.pathExtension.lowercased()) && (days == 0 || isOlder(url, thanDays: days))
            }
        }
    }

    private static func children(of root: URL) -> [URL] {
        let urls = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
        return urls ?? []
    }

    private static func isOlder(_ url: URL, thanDays days: Int) -> Bool {
        guard let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            return false
        }
        return date < Date().addingTimeInterval(-Double(days) * 86400)
    }
}

// MARK: - Removal (always to the Trash)

struct RemovalReport {
    var trashed: [String] = []
    var failed: [String] = []

    var logLines: [String] {
        var lines = trashed.map { L("Moved to Trash: ") + $0 }
        lines += failed.map { L("COULD NOT REMOVE (left untouched): ") + $0 }
        return lines
    }
}

enum Remover {
    /// Moves the given items to the Trash. Items the current user may not move are
    /// handed to Finder, which asks for the administrator password itself.
    static func moveToTrash(_ urls: [URL]) -> RemovalReport {
        let fm = FileManager.default
        var report = RemovalReport()
        var needFinder: [URL] = []

        for url in urls {
            // attributesOfItem does not follow symlinks, so broken links are still found.
            if (try? fm.attributesOfItem(atPath: url.path)) == nil { continue }
            do {
                try fm.trashItem(at: url, resultingItemURL: nil)
                report.trashed.append(url.path)
            } catch {
                needFinder.append(url)
            }
        }

        if !needFinder.isEmpty {
            var script: [String] = ["set theItems to {}"]
            for url in needFinder {
                script.append("set end of theItems to (POSIX file \"" + Shell.appleScriptEscape(url.path) + "\")")
            }
            script.append("with timeout of 900 seconds")
            script.append("tell application \"Finder\" to delete theItems")
            script.append("end timeout")
            _ = Shell.appleScript(script)

            for url in needFinder {
                if (try? fm.attributesOfItem(atPath: url.path)) == nil {
                    report.trashed.append(url.path)
                } else {
                    report.failed.append(url.path)
                }
            }
        }
        return report
    }

    /// Empties the whole Trash through Finder. This is permanent.
    static func emptyTrash() -> String {
        let result = Shell.appleScript([
            "with timeout of 900 seconds",
            "tell application \"Finder\" to empty trash",
            "end timeout"
        ])
        return result.ok ? L("Trash emptied.")
                         : L("FAILED: ") + L("Empty the Trash") + (result.output.isEmpty ? "" : " — " + result.output)
    }
}

// MARK: - Startup items

struct StartupItem: Identifiable {
    enum Kind: String {
        case loginItem = "Login item"
        case userAgent = "Launch agent (your account)"
        case globalAgent = "Launch agent (all users)"
        case globalDaemon = "Launch daemon (system)"

        var title: String {
            switch self {
            case .loginItem: return L("Login item")
            case .userAgent: return L("Launch agent (your account)")
            case .globalAgent: return L("Launch agent (all users)")
            case .globalDaemon: return L("Launch daemon (system)")
            }
        }
    }
    let id: String
    let kind: Kind
    let name: String
    let program: String
    let plist: URL?
    let programMissing: Bool
    let runsAtLoad: Bool
}

enum StartupScanner {
    static func scan() -> [StartupItem] {
        var items = loginItems()
        let home = NSHomeDirectory()
        items += launchItems(in: home + "/Library/LaunchAgents", kind: .userAgent)
        items += launchItems(in: "/Library/LaunchAgents", kind: .globalAgent)
        items += launchItems(in: "/Library/LaunchDaemons", kind: .globalDaemon)
        return items
    }

    private static func loginItems() -> [StartupItem] {
        let result = Shell.appleScript([
            "set out to \"\"",
            "tell application \"System Events\"",
            "repeat with li in login items",
            "set p to \"\"",
            "try",
            "set p to path of li",
            "end try",
            "set out to out & (name of li) & tab & p & linefeed",
            "end repeat",
            "end tell",
            "return out"
        ])
        guard result.ok else { return [] }
        var items: [StartupItem] = []
        for line in result.output.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: "\t")
            let name = parts[0].trimmingCharacters(in: .whitespaces)
            if name.isEmpty { continue }
            let path = parts.count > 1 ? parts[1] : ""
            let missing = !path.isEmpty && !FileManager.default.fileExists(atPath: path)
            items.append(StartupItem(id: "login:" + name, kind: .loginItem, name: name, program: path,
                                     plist: nil, programMissing: missing, runsAtLoad: true))
        }
        return items
    }

    private static func launchItems(in directory: String, kind: StartupItem.Kind) -> [StartupItem] {
        let dir = URL(fileURLWithPath: directory)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: []) else { return [] }
        var items: [StartupItem] = []
        for file in files where file.pathExtension == "plist" {
            var label = file.deletingPathExtension().lastPathComponent
            var program = ""
            var runsAtLoad = false
            if let data = try? Data(contentsOf: file),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = plist as? [String: Any] {
                if let l = dict["Label"] as? String { label = l }
                if let p = dict["Program"] as? String {
                    program = p
                } else if let args = dict["ProgramArguments"] as? [String], let first = args.first {
                    program = first
                }
                runsAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
            }
            let missing = program.hasPrefix("/") && !FileManager.default.fileExists(atPath: program)
            items.append(StartupItem(id: file.path, kind: kind, name: label, program: program,
                                     plist: file, programMissing: missing, runsAtLoad: runsAtLoad))
        }
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Removes the selected items from auto-start. Launch agents/daemons are disabled by
    /// moving their .plist to the Trash (restorable); login items are removed from the list.
    static func remove(_ items: [StartupItem]) -> [String] {
        var log: [String] = []
        var plists: [URL] = []
        for item in items {
            if let plist = item.plist {
                plists.append(plist)
            } else {
                let result = Shell.appleScript([
                    "tell application \"System Events\" to delete login item \"" + Shell.appleScriptEscape(item.name) + "\""
                ])
                log.append(result.ok ? L("Removed login item: ") + item.name
                                     : L("COULD NOT remove login item ") + item.name + ": " + result.output)
            }
        }
        if !plists.isEmpty {
            log += Remover.moveToTrash(plists).logLines
        }
        return log
    }
}

// MARK: - System checks

struct Finding: Identifiable {
    let id: String
    let group: String
    let title: String
    let detail: String
    let url: URL
}

enum SystemChecker {
    static let groupBrokenStartup = N("Startup entries pointing to missing programs")
    static let groupBrokenLinks = N("Broken symbolic links")
    static let groupOrphanPrefs = N("Preference files of apps that seem to be uninstalled (review carefully)")

    static func scan(startup: [StartupItem]) -> [Finding] {
        var findings: [Finding] = []

        for item in startup where item.programMissing {
            guard let plist = item.plist else { continue }
            findings.append(Finding(id: "startup:" + plist.path, group: groupBrokenStartup, title: item.name,
                                    detail: L("Program not found: ") + item.program, url: plist))
        }

        let home = NSHomeDirectory()
        let linkDirs = ["/usr/local/bin", "/opt/homebrew/bin", home + "/.homebrew/bin", home + "/.local/bin",
                        "/Applications", home + "/Applications"]
        let fm = FileManager.default
        for dir in linkDirs {
            guard let entries = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: dir), includingPropertiesForKeys: [.isSymbolicLinkKey], options: []) else { continue }
            for entry in entries {
                let isLink = (try? entry.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
                // fileExists follows the link: false means the target is gone.
                if isLink && !fm.fileExists(atPath: entry.path) {
                    let target = (try? fm.destinationOfSymbolicLink(atPath: entry.path)) ?? "?"
                    findings.append(Finding(id: "link:" + entry.path, group: groupBrokenLinks,
                                            title: entry.lastPathComponent,
                                            detail: L("Points to missing target: ") + target, url: entry))
                }
            }
        }

        findings += orphanedPreferences()
        return findings
    }

    private static func installedBundleIDs() -> [String] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let roots = ["/Applications", "/System/Applications", home + "/Applications",
                     "/Library/Application Support", home + "/Library/Application Support",
                     "/Library/PreferencePanes", home + "/Library/PreferencePanes"]
        var ids = Set<String>()

        func record(_ bundle: URL) {
            let info = bundle.appendingPathComponent("Contents/Info.plist")
            if let data = try? Data(contentsOf: info),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = plist as? [String: Any],
               let id = dict["CFBundleIdentifier"] as? String {
                ids.insert(id.lowercased())
            }
        }

        func visit(_ dir: URL, depth: Int) {
            guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: []) else { return }
            for entry in entries {
                let ext = entry.pathExtension.lowercased()
                if ext == "app" || ext == "prefpane" {
                    record(entry)
                } else if depth > 0 {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                        visit(entry, depth: depth - 1)
                    }
                }
            }
        }

        for root in roots {
            visit(URL(fileURLWithPath: root), depth: 2)
        }
        return Array(ids)
    }

    private static func orphanedPreferences() -> [Finding] {
        let installed = installedBundleIDs()
        if installed.isEmpty { return [] }
        let prefsDir = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: prefsDir, includingPropertiesForKeys: nil, options: []) else { return [] }

        var findings: [Finding] = []
        for file in files where file.pathExtension == "plist" {
            let name = file.deletingPathExtension().lastPathComponent.lowercased()
            let parts = name.split(separator: ".")
            if parts.count < 3 { continue }
            if name.hasPrefix("com.apple.") || name.hasPrefix("loginwindow") { continue }
            // Compare on the vendor prefix (e.g. "com.google") so helpers of installed apps are not reported.
            let stem: String = String(parts[0]) + "." + String(parts[1])
            let stemDot: String = stem + "."
            let known = installed.contains { (id: String) -> Bool in
                return id == name || id == stem || id.hasPrefix(stemDot)
            }
            if !known {
                findings.append(Finding(id: "pref:" + file.path, group: groupOrphanPrefs,
                                        title: file.lastPathComponent,
                                        detail: L("No installed app from this vendor was found"), url: file))
            }
        }
        return findings.sorted { $0.title.lowercased() < $1.title.lowercased() }
    }

    static func diskSummary() -> String {
        let info = Shell.run("/usr/sbin/diskutil", ["info", "/"])
        var lines: [String] = []
        for line in info.output.components(separatedBy: .newlines) {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("Volume Name") || t.hasPrefix("File System Personality")
                || t.hasPrefix("SMART Status") || t.hasPrefix("Container Free Space")
                || t.hasPrefix("Volume Free Space") || t.hasPrefix("Container Total Space")
                || t.hasPrefix("Volume Total Space") {
                lines.append(t)
            }
        }
        return lines.isEmpty ? info.output : lines.joined(separator: "\n")
    }

    /// Read-only verification of the startup volume. Changes nothing.
    static func verifyDisk() -> String {
        return Shell.run("/usr/sbin/diskutil", ["verifyVolume", "/"]).output
    }
}

// MARK: - Optimization

struct OptimizeAction: Identifiable {
    let id: String
    let title: String
    let explanation: String
    let command: String
    let needsAdmin: Bool
}

struct ProcessInfoRow: Identifiable {
    let id: Int
    let name: String
    let path: String
    let memory: Int64
    let cpu: Double
}

enum Optimizer {
    static let actions: [OptimizeAction] = [
        OptimizeAction(
            id: "dns", title: N("Flush DNS cache"),
            explanation: N("Clears cached network name lookups. Helps with slow or wrong website resolution."),
            command: "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder",
            needsAdmin: true),
        OptimizeAction(
            id: "purge", title: N("Free inactive memory"),
            explanation: N("Asks macOS to release disk cache held in memory. The effect is temporary."),
            command: "/usr/sbin/purge",
            needsAdmin: true),
        OptimizeAction(
            id: "quicklook", title: N("Reset Quick Look cache"),
            explanation: N("Clears thumbnail and preview caches. They are rebuilt as you browse files."),
            command: "/usr/bin/qlmanage -r cache",
            needsAdmin: false),
        OptimizeAction(
            id: "spotlight", title: N("Rebuild Spotlight index"),
            explanation: N("Erases and rebuilds the search index of the startup disk. Fixes slow or incomplete search; indexing runs in the background for a while afterwards."),
            command: "/usr/bin/mdutil -E /",
            needsAdmin: true)
    ]

    static func run(_ action: OptimizeAction) -> String {
        let result = action.needsAdmin
            ? Shell.runAsAdmin(action.command)
            : Shell.run("/bin/sh", ["-c", action.command])
        let status = result.ok ? L("Done: ") : L("FAILED: ")
        return status + L(action.title) + (result.output.isEmpty ? "" : " — " + result.output)
    }

    static func topProcesses(limit: Int) -> [ProcessInfoRow] {
        let result = Shell.run("/bin/ps", ["-axo", "pid=,rss=,pcpu=,comm="])
        var rows: [ProcessInfoRow] = []
        for line in result.output.components(separatedBy: .newlines) {
            let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            if parts.count < 4 { continue }
            guard let pid = Int(parts[0]), let rssKB = Int64(parts[1]) else { continue }
            let cpu = Double(parts[2].replacingOccurrences(of: ",", with: ".")) ?? 0
            let path = String(parts[3])
            let name = URL(fileURLWithPath: path).lastPathComponent
            rows.append(ProcessInfoRow(id: pid, name: name, path: path, memory: rssKB * 1024, cpu: cpu))
        }
        rows.sort { $0.memory > $1.memory }
        return Array(rows.prefix(limit))
    }
}

// MARK: - Process descriptions (shown when pointing at a process)

enum ProcessCatalog {
    private static let known: [String: String] = [
        "kernel_task": N("The core of macOS. Manages memory, the processor and hardware; it also takes processor time on purpose to keep the Mac cool."),
        "WindowServer": N("Draws everything on screen: windows, menus, the Dock and animations."),
        "launchd": N("Starts and supervises all other processes and background services."),
        "loginwindow": N("Handles logging in and out and keeps your session running."),
        "Finder": N("The Finder: desktop, file windows and the Trash."),
        "Dock": N("The Dock, Launchpad, Mission Control and the desktop background."),
        "SystemUIServer": N("The right side of the menu bar."),
        "ControlCenter": N("Control Center and the menu bar status icons."),
        "NotificationCenter": N("Shows notifications and widgets."),
        "Spotlight": N("Spotlight search window."),
        "mds": N("Spotlight: manages the search index."),
        "mds_stores": N("Spotlight: stores and updates the search index. Busy after many file changes."),
        "mdworker": N("Spotlight: reads files so they can be found in search."),
        "mdworker_shared": N("Spotlight: reads files so they can be found in search."),
        "corespotlightd": N("Spotlight: indexes content that apps provide (mail, messages, notes)."),
        "coreaudiod": N("Plays and records all sound."),
        "bluetoothd": N("Manages Bluetooth devices."),
        "airportd": N("Manages Wi-Fi."),
        "cloudd": N("iCloud: syncs data between your devices."),
        "bird": N("iCloud Drive: syncs your files."),
        "fileproviderd": N("Connects cloud storage (iCloud Drive, Dropbox and others) to the Finder."),
        "photoanalysisd": N("Photos: recognises faces, objects and scenes in the background."),
        "photolibraryd": N("Photos: manages the photo library."),
        "mediaanalysisd": N("Analyses photos and videos in the background (search, Live Text)."),
        "softwareupdated": N("Checks for and downloads macOS updates."),
        "backupd": N("Time Machine backup."),
        "trustd": N("Checks certificates for secure connections and signed apps."),
        "syspolicyd": N("Gatekeeper: checks that apps are safe to open."),
        "XprotectService": N("XProtect: Apple's built-in malware protection."),
        "opendirectoryd": N("Manages user accounts and logins."),
        "configd": N("Manages network settings."),
        "logd": N("Collects the system log."),
        "UserEventAgent": N("Reacts to system events for your account."),
        "cfprefsd": N("Reads and saves app settings."),
        "distnoted": N("Passes messages between processes."),
        "powerd": N("Manages power, sleep and the battery."),
        "sharingd": N("AirDrop, Handoff and sharing."),
        "rapportd": N("Communication between your Apple devices nearby."),
        "nsurlsessiond": N("Downloads and uploads in the background for apps."),
        "secd": N("Keychain: stores passwords securely."),
        "accountsd": N("Manages internet accounts (iCloud, mail, calendars)."),
        "com.apple.WebKit.WebContent": N("A web page open in Safari or in another app."),
        "com.apple.WebKit.GPU": N("Graphics for web pages in Safari and other apps."),
        "com.apple.WebKit.Networking": N("Network traffic for web pages in Safari and other apps."),
        "Safari": N("Safari web browser."),
        "Activity Monitor": N("Activity Monitor: shows running processes."),
        "Terminal": N("Terminal: command line."),
        "Mail": N("Mail app."),
        "Photos": N("Photos app."),
        "Music": N("Music app."),
        "Xcode": N("Xcode development environment.")
    ]

    /// A short explanation of what the process does, for the tooltip.
    static func describe(_ row: ProcessInfoRow) -> String {
        if let text = known[row.name] {
            return L(text)
        }
        // Processes inside an app bundle belong to that app (for example browser helpers).
        if let range = row.path.range(of: ".app/") {
            let appName = URL(fileURLWithPath: String(row.path[..<range.lowerBound])).lastPathComponent
            return L("Part of the app “%@”.", appName)
        }
        let systemPrefixes = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/"]
        if systemPrefixes.contains(where: { row.path.hasPrefix($0) }) {
            return L("A macOS system component.")
        }
        if row.path.hasPrefix("/Library/") || row.path.hasPrefix("/opt/") {
            return L("A background program installed by another app or tool.")
        }
        return L("No description available.")
    }
}

// MARK: - macOS permissions

struct MacPermission: Identifiable {
    enum Status {
        case allowed, notAllowed, notAsked, unknown
    }
    let id: String
    let title: String
    let purpose: String
    let states: [(label: String, status: Status)]
    let tccService: String?      // can be reset with tccutil when set
    let settingsURL: String      // the matching page in System Settings
}

enum PermissionChecker {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "hu.presoft.desktoppeeler" }

    /// Reads the current state without making macOS ask anything.
    static func all() -> [MacPermission] {
        let privacy = "x-apple.systempreferences:com.apple.preference.security?"
        return [
            MacPermission(
                id: "automation",
                title: L("Control System Events and Finder"),
                purpose: L("System Events reads your login items. Finder moves protected files to the Trash and empties the Trash. macOS can only revoke the two together; to switch off one, use System Settings."),
                states: [("System Events", automation("com.apple.systemevents")),
                         ("Finder", automation("com.apple.finder"))],
                tccService: "AppleEvents",
                settingsURL: privacy + "Privacy_Automation"),
            MacPermission(
                id: "downloads",
                title: L("Downloads folder"),
                purpose: L("Needed for the “Old installers in Downloads” category. macOS does not let apps read this state without asking."),
                states: [],
                tccService: "SystemPolicyDownloadsFolder",
                settingsURL: privacy + "Privacy_FilesAndFolders"),
            MacPermission(
                id: "fullDisk",
                title: L("Full Disk Access (optional)"),
                purpose: L("Lets the scan see more folders. It is given and taken back only in System Settings."),
                states: [(L("Full Disk Access"), fullDiskAccess())],
                tccService: nil,
                settingsURL: privacy + "Privacy_AllFiles")
        ]
    }

    private static func automation(_ target: String) -> MacPermission.Status {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: target)
        guard let address = descriptor.aeDesc else { return .unknown }
        let status = AEDeterminePermissionToAutomateTarget(
            address, AEEventClass(typeWildCard), AEEventID(typeWildCard), false)
        switch status {
        case noErr: return .allowed
        case -1743: return .notAllowed   // errAEEventNotPermitted
        case -1744: return .notAsked     // errAEEventWouldRequireUserConsent
        default: return .unknown         // for example the target app is not running
        }
    }

    private static func fullDiskAccess() -> MacPermission.Status {
        // This file can only be opened with Full Disk Access; trying does not make macOS ask.
        let probe = "/Library/Application Support/com.apple.TCC/TCC.db"
        if let handle = FileHandle(forReadingAtPath: probe) {
            handle.closeFile()
            return .allowed
        }
        return .notAllowed
    }

    static func reset(_ service: String) -> ShellResult {
        return Shell.run("/usr/bin/tccutil", ["reset", service, bundleID])
    }
}
