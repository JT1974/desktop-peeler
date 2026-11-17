import Foundation
import SwiftUI

/// One change the user is asked to approve. Nothing in `work` runs before the user confirms.
struct ActionFlow {
    enum Phase {
        case review
        case working
        case done
    }
    var title: String
    var message: String
    var lines: [String]
    var confirmLabel: String
    /// Kinds of change this flow performs. When the user ticked "Don't ask again" for all of
    /// them earlier, the flow runs without waiting (the sheet still shows the result).
    var approvalKeys: [String] = []
    var autoApproved = false
    var phase: Phase = .review
    var results: [String] = []
    var work: () -> [String]
    var after: () -> Void
}

/// The kinds of change that can be approved once and for all ("Don't ask again").
enum ApprovalKind {
    static let cleanup = "cleanup"
    static let emptyTrash = "emptyTrash"
    static let startup = "startup"
    static let fixes = "fixes"

    static func optimize(_ action: OptimizeAction) -> String {
        return "optimize." + action.id
    }

    static func title(_ key: String) -> String {
        switch key {
        case cleanup: return L("Move cleanup items to the Trash")
        case emptyTrash: return L("Empty the Trash after a cleanup")
        case startup: return L("Remove items from auto-start")
        case fixes: return L("Move system-check findings to the Trash")
        default:
            if let action = Optimizer.actions.first(where: { optimize($0) == key }) {
                return L("Optimize: %@", L(action.title))
            }
            return key
        }
    }
}

final class AppState: ObservableObject {
    @Published var pane: Pane = .cleanup
    // Cleanup
    @Published var categories: [CleanCategory] = []
    @Published var selectedPaths = Set<String>()
    @Published var hasScanned = false
    @Published var emptyTrashAfterCleanup = true
    // Startup
    @Published var startup: [StartupItem] = []
    @Published var selectedStartup = Set<String>()
    @Published var startupLoaded = false
    // Checks
    @Published var findings: [Finding] = []
    @Published var selectedFindings = Set<String>()
    @Published var checksRun = false
    @Published var diskSummary = ""
    @Published var diskVerifyOutput = ""
    // Optimize
    @Published var processes: [ProcessInfoRow] = []
    // General
    @Published var log: [String] = []
    @Published var busy: String? = nil
    @Published var flow: ActionFlow? = nil
    // Settings
    @Published var rememberedApprovals: [String] = UserDefaults.standard.stringArray(forKey: "rememberedApprovals") ?? [] {
        didSet { UserDefaults.standard.set(rememberedApprovals, forKey: "rememberedApprovals") }
    }
    @Published var permissions: [MacPermission] = []

    // MARK: Helpers

    private func background<T>(_ label: String, work: @escaping () -> T, then: @escaping (T) -> Void) {
        busy = label
        DispatchQueue.global(qos: .userInitiated).async {
            let value = work()
            DispatchQueue.main.async {
                self.busy = nil
                then(value)
            }
        }
    }

    func addLog(_ lines: [String]) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let stamp = formatter.string(from: Date())
        for line in lines {
            log.append(stamp + "  " + line)
        }
    }

    /// Shows the approval sheet, or runs the flow at once if all its kinds were approved for good.
    private func present(_ newFlow: ActionFlow) {
        flow = newFlow
        let keys = newFlow.approvalKeys
        if !keys.isEmpty && keys.allSatisfy({ rememberedApprovals.contains($0) }) {
            flow?.autoApproved = true
            confirmFlow()
        }
    }

    /// Called by the approval sheet when the user presses the confirm button.
    func confirmFlow(remember: Bool = false) {
        guard var current = flow, current.phase == .review else { return }
        if remember {
            for key in current.approvalKeys where !rememberedApprovals.contains(key) {
                rememberedApprovals.append(key)
            }
        }
        current.phase = .working
        flow = current
        let work = current.work
        let after = current.after
        DispatchQueue.global(qos: .userInitiated).async {
            let results = work()
            DispatchQueue.main.async {
                self.addLog(results)
                if var finished = self.flow {
                    finished.phase = .done
                    finished.results = results
                    self.flow = finished
                }
                after()
            }
        }
    }

    func cancelFlow() {
        if let current = flow, current.phase == .working { return }
        flow = nil
    }

    // MARK: Cleanup

    func scanCleanup() {
        background(L("Scanning for removable files…"), work: { CleanupScanner.scanAll() }, then: { result in
            self.categories = result
            var selection = Set<String>()
            for category in result where category.preselected {
                for item in category.items {
                    selection.insert(item.id)
                }
            }
            self.selectedPaths = selection
            self.hasScanned = true
        })
    }

    var selectedItems: [CleanItem] {
        var items: [CleanItem] = []
        for category in categories {
            for item in category.items where selectedPaths.contains(item.id) {
                items.append(item)
            }
        }
        return items
    }

    var selectedSize: Int64 {
        return selectedItems.reduce(0) { $0 + $1.size }
    }

    func setCategory(_ category: CleanCategory, selected: Bool) {
        var copy = selectedPaths
        for item in category.items {
            if selected {
                copy.insert(item.id)
            } else {
                copy.remove(item.id)
            }
        }
        selectedPaths = copy
    }

    func isCategoryFullySelected(_ category: CleanCategory) -> Bool {
        if category.items.isEmpty { return false }
        return category.items.allSatisfy { selectedPaths.contains($0.id) }
    }

    func requestCleanup() {
        let items = selectedItems.sorted { $0.size > $1.size }
        if items.isEmpty { return }
        let urls = items.map { $0.url }
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        let adminInvolved = categories.contains { category in
            category.needsAdmin && category.items.contains { self.selectedPaths.contains($0.id) }
        }
        let emptyTrash = emptyTrashAfterCleanup
        var message = L("%d items (%@) will be moved to the Trash.", items.count, FileSize.format(total)) + " "
        var lines = items.map { FileSize.format($0.size) + "   " + $0.url.path }
        var keys = [ApprovalKind.cleanup]
        if emptyTrash {
            message += L("Then the whole Trash is emptied, including anything that was already in it. This is permanent: emptied items cannot be put back.")
            lines.append(L("Then: empty the Trash (permanent)"))
            keys.append(ApprovalKind.emptyTrash)
        } else {
            message += L("Nothing is deleted permanently: you can put items back from the Trash until you empty it.")
        }
        if adminInvolved {
            message += " " + L("Some items are protected; Finder will ask for your administrator password for those.")
        }
        present(ActionFlow(
            title: L("Review cleanup"),
            message: message,
            lines: lines,
            confirmLabel: emptyTrash ? L("Move %d items to Trash and empty it", items.count)
                                     : L("Move %d items to Trash", items.count),
            approvalKeys: keys,
            work: {
                var log = Remover.moveToTrash(urls).logLines
                if emptyTrash {
                    log.append(Remover.emptyTrash())
                }
                return log
            },
            after: { self.scanCleanup() }))
    }

    // MARK: Startup

    func loadStartup() {
        background(L("Reading auto-start items…"), work: { StartupScanner.scan() }, then: { items in
            self.startup = items
            self.selectedStartup = []
            self.startupLoaded = true
        })
    }

    func requestStartupRemoval() {
        let items = startup.filter { selectedStartup.contains($0.id) }
        if items.isEmpty { return }
        var lines: [String] = []
        for item in items {
            if let plist = item.plist {
                lines.append(L("Move to Trash: ") + plist.path + "   (" + item.name + ")")
            } else {
                lines.append(L("Remove from login items: ") + item.name)
            }
        }
        present(ActionFlow(
            title: L("Review auto-start changes"),
            message: L("The apps themselves are not uninstalled. Launch agent files go to the Trash and can be put back. Changes take effect at the next login or restart. Protected files need your administrator password."),
            lines: lines,
            confirmLabel: L("Remove %d from auto-start", items.count),
            approvalKeys: [ApprovalKind.startup],
            work: { StartupScanner.remove(items) },
            after: { self.loadStartup() }))
    }

    // MARK: Checks

    func runChecks() {
        background(L("Checking the system…"), work: { () -> ([StartupItem], [Finding], String) in
            let startupItems = StartupScanner.scan()
            let found = SystemChecker.scan(startup: startupItems)
            return (startupItems, found, SystemChecker.diskSummary())
        }, then: { result in
            self.startup = result.0
            self.startupLoaded = true
            self.findings = result.1
            self.diskSummary = result.2
            self.selectedFindings = []
            self.checksRun = true
        })
    }

    func verifyDisk() {
        background(L("Verifying the startup disk (read-only, can take a few minutes)…"),
                   work: { SystemChecker.verifyDisk() },
                   then: { output in
            self.diskVerifyOutput = output
            self.addLog([L("Disk verification finished (read-only).")])
        })
    }

    func requestFixFindings() {
        let chosen = findings.filter { selectedFindings.contains($0.id) }
        if chosen.isEmpty { return }
        let urls = chosen.map { $0.url }
        present(ActionFlow(
            title: L("Review fixes"),
            message: L("%d files will be moved to the Trash. You can put them back from the Trash if anything misbehaves.", chosen.count),
            lines: chosen.map { $0.url.path + "   — " + $0.detail },
            confirmLabel: L("Move %d files to Trash", chosen.count),
            approvalKeys: [ApprovalKind.fixes],
            work: { Remover.moveToTrash(urls).logLines },
            after: { self.runChecks() }))
    }

    // MARK: Optimize

    func requestOptimize(_ action: OptimizeAction) {
        var message = L(action.explanation)
        if action.needsAdmin {
            message += " " + L("macOS will ask for your administrator password.")
        }
        present(ActionFlow(
            title: L(action.title),
            message: message,
            lines: [L("Command that will run:"), action.command],
            confirmLabel: L("Run"),
            approvalKeys: [ApprovalKind.optimize(action)],
            work: { [Optimizer.run(action)] },
            after: { self.refreshProcesses() }))
    }

    func refreshProcesses() {
        DispatchQueue.global(qos: .userInitiated).async {
            let rows = Optimizer.topProcesses(limit: 15)
            DispatchQueue.main.async {
                self.processes = rows
            }
        }
    }

    // MARK: Settings

    func revokeApproval(_ key: String) {
        rememberedApprovals.removeAll { $0 == key }
    }

    func refreshPermissions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let list = PermissionChecker.all()
            DispatchQueue.main.async {
                self.permissions = list
            }
        }
    }

    /// Revoking a macOS permission changes a system setting, so it goes through the approval sheet.
    func requestPermissionReset(_ permission: MacPermission) {
        guard let service = permission.tccService else { return }
        let title = permission.title
        present(ActionFlow(
            title: L("Revoke permission"),
            message: L("macOS forgets this permission for Desktop Peeler and asks again the next time it is needed."),
            lines: [title, L("Command that will run:"),
                    "/usr/bin/tccutil reset " + service + " " + PermissionChecker.bundleID],
            confirmLabel: L("Revoke"),
            work: {
                let result = PermissionChecker.reset(service)
                return [(result.ok ? L("Permission revoked: ") : L("FAILED: ")) + title
                        + (result.ok || result.output.isEmpty ? "" : " — " + result.output)]
            },
            after: { self.refreshPermissions() }))
    }
}
