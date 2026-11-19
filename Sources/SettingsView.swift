import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var localizer: Localizer
    @AppStorage("theme") private var theme: String = "system"
    @State private var languageMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(eyebrow: L("Preferences"),
                       title: L("Settings"),
                       lead: L("Theme, language, remembered approvals and the macOS permissions Desktop Peeler uses."))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    themeCard
                    languageCard
                    approvalsCard
                    permissionsCard
                }
            }
        }
        .padding(22)
        .onAppear { state.refreshPermissions() }
    }

    // MARK: Theme

    private var themeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Theme")).font(Brand.strong(14))
            Text(L("“Same as macOS” follows the light or dark appearance set in System Settings."))
                .font(Brand.body(11))
                .foregroundColor(Brand.text2)
            Picker("", selection: $theme) {
                Text(L("Same as macOS")).tag("system")
                Text(L("Dark")).tag("dark")
                Text(L("Light")).tag("light")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .hoverCursor()
        }
        .brandCard()
    }

    // MARK: Language

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Language")).font(Brand.strong(14))
            Text(L("“Same as macOS” uses the Mac's language if a translation exists, otherwise English. Each language is one file; you can add new ones."))
                .font(Brand.body(11))
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
            Picker("", selection: $localizer.choice) {
                Text(L("Same as macOS (%@)", localizer.name(of: localizer.systemLanguage))).tag(Localizer.systemChoice)
                ForEach(localizer.languages) { language in
                    Text(language.name).tag(language.code)
                }
            }
            .labelsHidden()
            .fixedSize()
            .hoverCursor()
            HStack(spacing: 10) {
                Button(L("Add language file…")) { importLanguage() }
                    .buttonStyle(GhostButtonStyle())
                Button(L("Save English template…")) { saveTemplate() }
                    .buttonStyle(GhostButtonStyle())
                    .help(L("A language file with every text in English. Translate it and add it with “Add language file…”. See Help › Adding a language."))
            }
            ForEach(localizer.languages.filter { $0.imported }) { language in
                HStack {
                    Text(language.name)
                    Text(language.code).font(Brand.mono(11)).foregroundColor(Brand.muted)
                    Pill(text: L("added"))
                    Spacer()
                    Button(L("Remove")) { localizer.remove(language) }
                        .buttonStyle(GhostButtonStyle())
                }
            }
            if !languageMessage.isEmpty {
                Text(languageMessage)
                    .font(Brand.body(11))
                    .foregroundColor(Brand.text2)
            }
        }
        .brandCard()
    }

    private func importLanguage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let error = localizer.importFile(url) {
            languageMessage = L("Could not add the file: %@", error)
        } else {
            languageMessage = L("Language file added.")
        }
    }

    private func saveTemplate() {
        guard let template = localizer.templateURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "language-template.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try FileManager.default.copyItem(at: template, to: url)
            languageMessage = L("Template saved: %@", url.path)
        } catch {
            languageMessage = error.localizedDescription
        }
    }

    // MARK: Remembered approvals

    private var approvalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Remembered approvals")).font(Brand.strong(14))
            Text(L("Actions you allowed with “Don't ask again”. They run without waiting for your approval; the result is still shown and logged. Revoke one to be asked again."))
                .font(Brand.body(11))
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
            if state.rememberedApprovals.isEmpty {
                Text(L("None. Every change asks for your approval."))
                    .foregroundColor(Brand.muted)
            }
            ForEach(state.rememberedApprovals, id: \.self) { key in
                HStack {
                    Text(ApprovalKind.title(key))
                    Spacer()
                    Button(L("Revoke")) { state.revokeApproval(key) }
                        .buttonStyle(GhostButtonStyle())
                }
            }
        }
        .brandCard()
    }

    // MARK: macOS permissions

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("macOS permissions")).font(Brand.strong(14))
                Spacer()
                Button(L("Refresh")) { state.refreshPermissions() }
                    .buttonStyle(GhostButtonStyle())
            }
            Text(L("What macOS allows Desktop Peeler to do. After revoking, macOS asks again the next time the permission is needed."))
                .font(Brand.body(11))
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(state.permissions) { permission in
                Rectangle().fill(Brand.line).frame(height: 1)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(permission.title)
                        Text(permission.purpose)
                            .font(Brand.body(11))
                            .foregroundColor(Brand.text2)
                            .fixedSize(horizontal: false, vertical: true)
                        if !permission.states.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(permission.states.indices, id: \.self) { index in
                                    let entry = permission.states[index]
                                    Pill(text: entry.label + ": " + statusText(entry.status))
                                }
                            }
                        }
                    }
                    Spacer()
                    if permission.tccService != nil {
                        Button(L("Revoke…")) { state.requestPermissionReset(permission) }
                            .buttonStyle(GhostButtonStyle())
                            .disabled(state.busy != nil)
                    }
                    Button(L("System Settings")) {
                        if let url = URL(string: permission.settingsURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(GhostButtonStyle())
                }
            }
            Rectangle().fill(Brand.line).frame(height: 1)
            Text(L("Administrator password: macOS asks for it each time it is needed. Desktop Peeler never sees or stores it, so there is nothing to revoke."))
                .font(Brand.body(11))
                .foregroundColor(Brand.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .brandCard()
    }

    private func statusText(_ status: MacPermission.Status) -> String {
        switch status {
        case .allowed: return L("allowed")
        case .notAllowed: return L("not allowed")
        case .notAsked: return L("not asked yet")
        case .unknown: return L("unknown")
        }
    }
}
