import SwiftUI
import AppKit

@main
struct DesktopPeelerApp: App {
    @StateObject private var state = AppState()
    @StateObject private var localizer = Localizer.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(localizer)
                .frame(minWidth: 980, minHeight: 660)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(L("About Desktop Peeler")) { AboutPanel.show() }
            }
            CommandGroup(replacing: .appSettings) {
                Button(L("Settings…")) { state.pane = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button(L("Desktop Peeler Help")) { state.pane = .help }
                    .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

enum Pane: String, Identifiable {
    case cleanup
    case startup
    case checks
    case optimize
    case log
    case settings
    case help

    static let tools: [Pane] = [.cleanup, .startup, .checks, .optimize, .log]
    static let app: [Pane] = [.settings, .help]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanup: return L("Cleanup")
        case .startup: return L("Auto-start")
        case .checks: return L("System checks")
        case .optimize: return L("Optimize")
        case .log: return L("Activity log")
        case .settings: return L("Settings")
        case .help: return L("Help")
        }
    }

    var symbol: String {
        switch self {
        case .cleanup: return "trash"
        case .startup: return "power"
        case .checks: return "stethoscope"
        case .optimize: return "speedometer"
        case .log: return "list.bullet.rectangle"
        case .settings: return "gearshape"
        case .help: return "questionmark.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var localizer: Localizer
    @AppStorage("theme") private var theme: String = "system"

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Brand.line2).frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Brand.line2).frame(width: 1)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            Rectangle().fill(Brand.line2).frame(height: 1)
            statusBar
        }
        .id(localizer.active)   // redraw every text when the language changes
        .background(Brand.bg)
        .foregroundColor(Brand.text)
        .font(Brand.body(13))
        .toggleStyle(BrandCheckboxStyle())
        .onAppear { Appearance.apply(theme) }
        .onChange(of: theme) { value in Appearance.apply(value) }
        .sheet(isPresented: Binding(
            get: { state.flow != nil },
            set: { shown in if !shown { state.cancelFlow() } }
        )) {
            ApprovalSheet()
                .environmentObject(state)
        }
    }

    /// Top section: app icon, name, and the theme switcher.
    private var topBar: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
            Text("Desktop Peeler")
                .font(Brand.display(17))
                .foregroundColor(Brand.text)
            Text("BY PRESOFT")
                .font(Brand.mono(9))
                .foregroundColor(Brand.muted)
                .padding(.top, 3)
            Spacer()
            ThemeSwitch(theme: $theme)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Brand.bg2)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Pane.tools) { item in
                sidebarButton(item)
            }
            Spacer()
            ForEach(Pane.app) { item in
                sidebarButton(item)
            }
            Text(L("Nothing is changed without your approval. Removed files go to the Trash."))
                .font(Brand.body(11))
                .foregroundColor(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .padding(16)
        .frame(width: 240)
        .background(Brand.bg2)
    }

    private func sidebarButton(_ item: Pane) -> some View {
        let isOn = state.pane == item
        return Button(action: { state.pane = item }) {
            HStack(spacing: 8) {
                Image(systemName: item.symbol).frame(width: 20)
                Text(item.title).font(isOn ? Brand.strong(13) : Brand.body(13)).lineLimit(1)
                Spacer()
            }
            .foregroundColor(isOn ? Brand.text : Brand.text2)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous)
                    .fill(isOn ? Brand.selected : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous)
                    .stroke(isOn ? Brand.line2 : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch state.pane {
        case .cleanup: CleanupView()
        case .startup: StartupView()
        case .checks: ChecksView()
        case .optimize: OptimizeView()
        case .log: LogView()
        case .settings: SettingsView()
        case .help: HelpView()
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let busy = state.busy {
                ProgressView().controlSize(.small)
                Text(busy.uppercased())
            } else {
                Text(L("Ready").uppercased())
            }
            Spacer()
        }
        .font(Brand.mono(10))
        .foregroundColor(Brand.muted)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Brand.bg2)
    }
}

// MARK: - Approval sheet (every change passes through here)

struct ApprovalSheet: View {
    @EnvironmentObject var state: AppState
    @State private var remember = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let flow = state.flow {
                Eyebrow(text: L("Your approval"))
                Text(flow.title)
                    .font(Brand.display(22))
                switch flow.phase {
                case .review:
                    Text(flow.message)
                        .foregroundColor(Brand.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    lineList(flow.lines)
                    HStack(spacing: 10) {
                        if !flow.approvalKeys.isEmpty {
                            Toggle(L("Don't ask again for this kind of action (revocable in Settings)"), isOn: $remember)
                        }
                        Spacer()
                        Button(L("Cancel")) { state.cancelFlow() }
                            .buttonStyle(GhostButtonStyle())
                            .keyboardShortcut(.cancelAction)
                        Button(flow.confirmLabel) { state.confirmFlow(remember: remember) }
                            .buttonStyle(AccentButtonStyle())
                    }
                case .working:
                    if flow.autoApproved {
                        autoApprovedNote
                    }
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L("Working… If macOS or Finder asks for your password, the request may be behind this window."))
                            .foregroundColor(Brand.text2)
                    }
                    lineList(flow.lines)
                case .done:
                    if flow.autoApproved {
                        autoApprovedNote
                    }
                    Text(L("Finished. Result:"))
                        .foregroundColor(Brand.text2)
                    lineList(flow.results.isEmpty ? [L("Nothing was changed.")] : flow.results)
                    HStack {
                        Spacer()
                        Button(L("Close")) { state.flow = nil }
                            .buttonStyle(GhostButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 780, height: 540)
        .background(Brand.surface)
        .foregroundColor(Brand.text)
        .font(Brand.body(13))
        .toggleStyle(BrandCheckboxStyle())
    }

    private var autoApprovedNote: some View {
        Text(L("Approved automatically: you chose “Don't ask again” for this action. You can revoke it in Settings."))
            .foregroundColor(Brand.text2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func isFailure(_ line: String) -> Bool {
        let prefixes = ["COULD NOT", "FAILED", L("COULD NOT REMOVE (left untouched): "),
                        L("COULD NOT remove login item "), L("FAILED: ")]
        return prefixes.contains { line.hasPrefix($0) }
    }

    private func lineList(_ lines: [String]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { entry in
                    // Failures stand out by wording and brightness, not by a warning colour.
                    Text(isFailure(entry.element) ? "▲ " + entry.element : entry.element)
                        .font(Brand.mono(11))
                        .foregroundColor(isFailure(entry.element) ? Brand.text : Brand.text2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
        .background(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous).fill(Brand.bg))
        .overlay(RoundedRectangle(cornerRadius: Brand.radiusSmall, style: .continuous).stroke(Brand.line2, lineWidth: 1))
    }
}

// MARK: - Cleanup

struct CleanupView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PaneHeader(eyebrow: L("Step 1 · grab, step 2 · peel"),
                           title: L("Cleanup"),
                           lead: L("Scan first, tick what may go, then review the full list before anything is moved to the Trash."))
                Spacer()
                Button(state.hasScanned ? L("Scan again") : L("Scan")) { state.scanCleanup() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(state.busy != nil)
            }

            if !state.hasScanned {
                Text(L("Press Scan to look for caches, logs, temporary files and other removable data. Scanning changes nothing."))
                    .foregroundColor(Brand.muted)
                    .padding(.top, 20)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(state.categories) { category in
                            CategoryBlock(category: category)
                        }
                    }
                }
                HStack(spacing: 14) {
                    Text(L("Selected").uppercased())
                        .font(Brand.mono(10))
                        .foregroundColor(Brand.muted)
                    Text(L("%d items · %@", state.selectedItems.count, FileSize.format(state.selectedSize)))
                        .font(Brand.mono(13))
                    Spacer()
                    Toggle(L("Empty Trash afterwards"), isOn: $state.emptyTrashAfterCleanup)
                        .help(L("After the items are moved, the whole Trash is emptied. This is permanent."))
                    Button(L("Review & clean…")) { state.requestCleanup() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(state.selectedItems.isEmpty || state.busy != nil)
                }
            }
        }
        .padding(22)
    }
}

struct CategoryBlock: View {
    @EnvironmentObject var state: AppState
    let category: CleanCategory
    @State private var expanded = false

    private var summary: String {
        if category.items.isEmpty { return L("nothing found") }
        return L("%d items · %@", category.items.count, FileSize.format(category.totalSize))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: Binding(
                    get: { state.isCategoryFullySelected(category) },
                    set: { value in state.setCategory(category, selected: value) }
                ))
                .labelsHidden()
                .disabled(category.items.isEmpty)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(L(category.title)).font(Brand.strong(14))
                        if category.needsAdmin {
                            Pill(text: L("admin password"))
                        }
                    }
                    Text(L(category.explanation))
                        .font(Brand.body(11))
                        .foregroundColor(Brand.text2)
                }
                Spacer()
                Text(summary)
                    .font(Brand.mono(11))
                    .foregroundColor(Brand.text2)
                Button(action: { expanded.toggle() }) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(Brand.text2)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(category.items.isEmpty)
                .help(L("Show the individual items"))
            }

            if expanded {
                Rectangle().fill(Brand.line).frame(height: 1)
                ForEach(category.items) { item in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { state.selectedPaths.contains(item.id) },
                            set: { value in
                                if value {
                                    state.selectedPaths.insert(item.id)
                                } else {
                                    state.selectedPaths.remove(item.id)
                                }
                            }
                        ))
                        .labelsHidden()
                        Text(item.name).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(FileSize.format(item.size))
                            .font(Brand.mono(11))
                            .foregroundColor(Brand.text2)
                        Button(action: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }) {
                            Image(systemName: "magnifyingglass").foregroundColor(Brand.muted)
                        }
                        .buttonStyle(.plain)
                        .help(L("Show in Finder: ") + item.url.path)
                    }
                    .padding(.leading, 26)
                    .help(item.url.path)
                }
            }
        }
        .brandCard()
    }
}

// MARK: - Auto-start

struct StartupView: View {
    @EnvironmentObject var state: AppState

    private let kinds: [StartupItem.Kind] = [.loginItem, .userAgent, .globalAgent, .globalDaemon]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PaneHeader(eyebrow: L("Starts by itself"),
                           title: L("Auto-start"),
                           lead: L("Programs that start by themselves at login or boot. Tick the ones you want to stop from auto-starting."))
                Spacer()
                Button(state.startupLoaded ? L("Refresh") : L("Load list")) { state.loadStartup() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(state.busy != nil)
            }

            if !state.startupLoaded {
                Text(L("Press Load list. macOS may ask once whether Desktop Peeler may control “System Events”; this is needed to read your login items."))
                    .foregroundColor(Brand.muted)
                    .padding(.top, 20)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(kinds, id: \.rawValue) { kind in
                            group(kind)
                        }
                    }
                }
                HStack(spacing: 10) {
                    Button(L("Open Login Items in System Settings")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                    .help(L("Background items that apps register with macOS directly can only be switched off there."))
                    Spacer()
                    Button(L("Remove selected from auto-start…")) { state.requestStartupRemoval() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(state.selectedStartup.isEmpty || state.busy != nil)
                }
            }
        }
        .padding(22)
    }

    private func group(_ kind: StartupItem.Kind) -> some View {
        let items = state.startup.filter { $0.kind == kind }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(kind.title).font(Brand.strong(14))
                Text("\(items.count)").font(Brand.mono(11)).foregroundColor(Brand.muted)
            }
            if items.isEmpty {
                Text(L("none")).foregroundColor(Brand.muted)
            }
            ForEach(items) { item in
                HStack(alignment: .top) {
                    Toggle("", isOn: Binding(
                        get: { state.selectedStartup.contains(item.id) },
                        set: { value in
                            if value {
                                state.selectedStartup.insert(item.id)
                            } else {
                                state.selectedStartup.remove(item.id)
                            }
                        }
                    ))
                    .labelsHidden()
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(item.name)
                            if item.programMissing {
                                Pill(text: L("program missing"))
                            }
                        }
                        Text(item.program.isEmpty ? L("(no program path)") : item.program)
                            .font(Brand.mono(10))
                            .foregroundColor(Brand.muted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .help(item.plist?.path ?? item.program)
            }
        }
        .brandCard()
    }
}

// MARK: - System checks

struct ChecksView: View {
    @EnvironmentObject var state: AppState

    private let groups = [SystemChecker.groupBrokenStartup, SystemChecker.groupBrokenLinks, SystemChecker.groupOrphanPrefs]

    private var allSelected: Binding<Bool> {
        Binding(
            get: { !state.findings.isEmpty && state.selectedFindings.count == state.findings.count },
            set: { value in state.selectedFindings = value ? Set(state.findings.map { $0.id }) : [] }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                PaneHeader(eyebrow: L("Leftovers and inconsistencies"),
                           title: L("System checks"),
                           lead: L("Checking changes nothing, and nothing is preselected."))
                Spacer()
                Button(state.checksRun ? L("Check again") : L("Run checks")) { state.runChecks() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(state.busy != nil)
            }

            if !state.checksRun {
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        diskBox
                        ForEach(groups, id: \.self) { name in
                            group(name)
                        }
                    }
                }
                HStack {
                    Toggle(L("Select all (%d)", state.findings.count), isOn: allSelected)
                        .disabled(state.findings.isEmpty)
                    Spacer()
                    Button(L("Fix selected…")) { state.requestFixFindings() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(state.selectedFindings.isEmpty || state.busy != nil)
                }
            }
        }
        .padding(22)
    }

    private var diskBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Startup disk")).font(Brand.strong(14))
            Text(state.diskSummary)
                .font(Brand.mono(11))
                .foregroundColor(Brand.text2)
                .textSelection(.enabled)
            Button(L("Verify disk structure (read-only)")) { state.verifyDisk() }
                .buttonStyle(GhostButtonStyle())
                .disabled(state.busy != nil)
                .help(L("Runs “diskutil verifyVolume /”. The Mac can feel slow while it runs. Repairs, if needed, are done with Disk Utility."))
            if !state.diskVerifyOutput.isEmpty {
                Text(state.diskVerifyOutput)
                    .font(Brand.mono(11))
                    .foregroundColor(Brand.text2)
                    .textSelection(.enabled)
            }
        }
        .brandCard()
    }

    private func group(_ name: String) -> some View {
        let items = state.findings.filter { $0.group == name }
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(L(name)).font(Brand.strong(14))
                Text("\(items.count)").font(Brand.mono(11)).foregroundColor(Brand.muted)
            }
            if items.isEmpty {
                Text(L("none found")).foregroundColor(Brand.muted)
            }
            ForEach(items) { finding in
                HStack(alignment: .top) {
                    Toggle("", isOn: Binding(
                        get: { state.selectedFindings.contains(finding.id) },
                        set: { value in
                            if value {
                                state.selectedFindings.insert(finding.id)
                            } else {
                                state.selectedFindings.remove(finding.id)
                            }
                        }
                    ))
                    .labelsHidden()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finding.title)
                        Text(finding.detail)
                            .font(Brand.body(11))
                            .foregroundColor(Brand.text2)
                    }
                    Spacer()
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([finding.url]) }) {
                        Image(systemName: "magnifyingglass").foregroundColor(Brand.muted)
                    }
                    .buttonStyle(.plain)
                    .help(L("Show in Finder: ") + finding.url.path)
                }
            }
        }
        .brandCard()
    }
}

// MARK: - Optimize

struct OptimizeView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(eyebrow: L("One command at a time"),
                       title: L("Optimize"),
                       lead: L("Each action shows the exact command and asks for confirmation before it runs."))

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Optimizer.actions) { action in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(L(action.title)).font(Brand.strong(14))
                                    if action.needsAdmin {
                                        Pill(text: L("admin password"))
                                    }
                                }
                                Text(L(action.explanation))
                                    .font(Brand.body(11))
                                    .foregroundColor(Brand.text2)
                            }
                            Spacer()
                            Button(L("Run…")) { state.requestOptimize(action) }
                                .buttonStyle(GhostButtonStyle())
                                .disabled(state.busy != nil)
                        }
                        .brandCard()
                    }

                    HStack {
                        Eyebrow(text: L("Processes using the most memory"))
                        Spacer()
                        Button(L("Refresh")) { state.refreshProcesses() }
                            .buttonStyle(GhostButtonStyle())
                    }
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(state.processes) { row in
                            HStack {
                                Text(row.name).lineLimit(1)
                                Spacer()
                                Text(String(format: "CPU %.1f%%", row.cpu))
                                    .font(Brand.mono(11))
                                    .foregroundColor(Brand.muted)
                                    .frame(width: 100, alignment: .trailing)
                                Text(FileSize.format(row.memory))
                                    .font(Brand.mono(11))
                                    .foregroundColor(Brand.text2)
                                    .frame(width: 100, alignment: .trailing)
                            }
                            .contentShape(Rectangle())
                            .help(ProcessCatalog.describe(row) + "\n" + row.path)
                        }
                    }
                    .brandCard()
                }
            }
        }
        .padding(22)
        .onAppear { state.refreshProcesses() }
    }
}

// MARK: - Log

struct LogView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(eyebrow: L("This session"),
                       title: L("Activity log"),
                       lead: L("Everything Desktop Peeler changed since it was opened."))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if state.log.isEmpty {
                        Text(L("No changes made yet.")).foregroundColor(Brand.muted)
                    }
                    ForEach(Array(state.log.enumerated()), id: \.offset) { entry in
                        Text(entry.element)
                            .font(Brand.mono(11))
                            .foregroundColor(Brand.text2)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .brandCard()
        }
        .padding(22)
    }
}
