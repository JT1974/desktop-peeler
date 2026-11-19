import SwiftUI
import AppKit

// MARK: - About

enum AboutPanel {
    static let productURL = URL(string: "https://presoft.hu/desktop-peeler")!

    static var summary: String {
        return L("Desktop Peeler finds caches, logs, temporary files and leftovers, shows you exactly what it found, and removes only what you approve.")
    }

    /// The standard macOS About window, with the app description and the product page link.
    static func show() {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centered
        ]
        let credits = NSMutableAttributedString(
            string: L("Clean up your Mac. Nothing happens without your approval.") + "\n\n" + summary + "\n\n",
            attributes: base)
        var link = base
        link[.link] = productURL
        credits.append(NSAttributedString(string: "presoft.hu/desktop-peeler", attributes: link))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Help

private struct HelpTopic {
    let title: String
    let paragraphs: [String]
    var questions: [(String, String)] = []
}

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaneHeader(eyebrow: L("How it works"),
                       title: L("Help"),
                       lead: L("Desktop Peeler first looks, then shows you a list and waits. Nothing is changed until you approve that list."))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(topics.enumerated()), id: \.offset) { entry in
                        topicCard(entry.element)
                    }
                    aboutCard
                    UpdateCard()
                }
            }
        }
        .padding(22)
    }

    private func topicCard(_ topic: HelpTopic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(topic.title).font(Brand.strong(14))
            ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { entry in
                Text(entry.element)
                    .foregroundColor(Brand.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(topic.questions.enumerated()), id: \.offset) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.element.0).font(Brand.strong(13))
                    Text(entry.element.1)
                        .foregroundColor(Brand.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
        .brandCard()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("About Desktop Peeler")).font(Brand.strong(14))
                Spacer()
                Text(AppVersion.display).font(Brand.mono(11)).foregroundColor(Brand.text2)
            }
            Text(AboutPanel.summary)
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                Link("presoft.hu/desktop-peeler", destination: AboutPanel.productURL)
                    .foregroundColor(Brand.accentText)
                    .hoverCursor()
                Spacer()
                Button(L("About Desktop Peeler")) { AboutPanel.show() }
                    .buttonStyle(GhostButtonStyle())
            }
        }
        .brandCard()
    }

    private var topics: [HelpTopic] {
        return [
            HelpTopic(title: L("Getting started"), paragraphs: [
                L("Desktop Peeler helps you remove files your Mac no longer needs and shows you what starts automatically. It works in two steps everywhere: first it looks, then it shows you a list and waits. Nothing is changed until you approve that list."),
                L("For the first cleanup: quit your other apps, open Cleanup, press Scan, open the categories to see what was found, press Review & clean…, read the list, then confirm.")
            ]),
            HelpTopic(title: L("Cleanup"), paragraphs: [
                L("Scan looks for caches, logs, temporary files and similar data and groups them into categories. Three low-risk categories are ticked for you; the others are left for you to decide. Click the arrow on a category to see every item, and the magnifying glass to see an item in Finder."),
                L("Review & clean… shows every selected item with its size and location. Confirm to go ahead, or Cancel to change nothing. Categories marked “admin password” contain files shared by all users; Finder will ask for your password for those."),
                L("Empty Trash afterwards is ticked by default: after the items are moved to the Trash, the whole Trash is emptied, including anything that was already in it. Emptying is permanent. Untick it if you want to be able to put items back."),
                L("After cleaning, apps recreate their caches as they need them, so some apps open a little slower the first time and part of the space is used again over time.")
            ]),
            HelpTopic(title: L("Auto-start"), paragraphs: [
                L("This pane lists programs that start by themselves when you log in or when the Mac starts. Tick the ones you want to stop and press Remove selected from auto-start…. The programs stay installed; they simply no longer start automatically. The change applies from your next login or restart."),
                L("A “program missing” badge means the entry points to a program that no longer exists; such entries are safe candidates for removal."),
                L("Some apps register background items directly with macOS. Those can only be switched off in System Settings › General › Login Items; use the button at the bottom to go there.")
            ]),
            HelpTopic(title: L("System checks"), paragraphs: [
                L("Run checks looks for startup entries whose program is gone, shortcuts (symbolic links) that point nowhere, and settings files of apps that seem to be uninstalled. It also shows the health and free space of your startup disk. Nothing is ticked for you; Select all ticks every finding at once."),
                L("The settings-file list is an estimate. If you recognize an app you still use, leave its file alone. Removing a settings file resets that app's preferences."),
                L("Verify disk structure checks the startup disk without changing it. If it reports problems, repair the disk with Apple's Disk Utility (First Aid).")
            ]),
            HelpTopic(title: L("Optimize"), paragraphs: [
                L("Each action solves a specific problem; none of them is needed regularly. Run… shows the exact command before anything happens."),
                L("Flush DNS cache helps when websites do not open or open the wrong address. Free inactive memory releases memory macOS uses as cache; the effect is short-lived. Reset Quick Look cache fixes wrong or missing file previews. Rebuild Spotlight index fixes search that misses files; searching is incomplete until indexing finishes, which can take a while."),
                L("The process list shows what is using the most memory right now. Point at a process to see what it does. To close a program, quit it normally or use Activity Monitor.")
            ]),
            HelpTopic(title: L("Activity log"), paragraphs: [
                L("A record of everything Desktop Peeler changed since you opened it. It is cleared when you quit the app.")
            ]),
            HelpTopic(title: L("Settings"), paragraphs: [
                L("Theme: Same as macOS, Dark or Light. The switch in the top bar changes the same setting."),
                L("Language: “Same as macOS” uses the Mac's language if a translation exists, otherwise English."),
                L("Remembered approvals: if you tick “Don't ask again” on an approval sheet, that kind of action runs without waiting for your approval from then on. The result is still shown and logged. Each one can be revoked in Settings."),
                L("macOS permissions: shows what macOS allows Desktop Peeler to do, and lets you revoke each permission. macOS asks again the next time it is needed.")
            ]),
            HelpTopic(title: L("Adding a language"), paragraphs: [
                L("Each language is one file. In Settings › Language press Save English template…, open the file in a text editor, set “code” (for example “de”) and “name” (for example “Deutsch”), and translate every value on the right-hand side under “strings”. Leave the left-hand side and placeholders such as %d and %@ unchanged."),
                L("Then press Add language file… and choose the file. Texts that are missing stay in English. A file with the same code as a built-in language replaces it.")
            ]),
            HelpTopic(title: L("Frequently asked questions"), paragraphs: [], questions: [
                (L("Can I undo a cleanup?"),
                 L("Only if Empty Trash afterwards was not ticked: open the Trash, select the items and choose Put Back. Emptied items cannot be put back.")),
                (L("Why did the free space not change?"),
                 L("Files in the Trash still take space. Empty the Trash, or leave Empty Trash afterwards ticked.")),
                (L("Why does macOS ask whether Desktop Peeler may control Finder or System Events?"),
                 L("System Events is used to read your login items. Finder is used to move protected files to the Trash and to empty the Trash. Desktop Peeler uses them for nothing else.")),
                (L("Why am I asked for my password?"),
                 L("Some files and commands belong to the system. macOS asks for the password; Desktop Peeler never sees or stores it.")),
                (L("Some items “could not be removed”. Is that a problem?"),
                 L("No. macOS protects some files. They were left exactly as they were.")),
                (L("Is it safe to delete caches?"),
                 L("Caches are copies that apps can recreate. Quit the app first; an app that is running may misbehave until restarted.")),
                (L("Does Desktop Peeler run in the background or send data anywhere?"),
                 L("No. It works only while it is open, and it does not connect to the internet.")),
                (L("Should I give it Full Disk Access?"),
                 L("Optional. With it the scan sees more folders. Without it the app still works."))
            ])
        ]
    }
}
