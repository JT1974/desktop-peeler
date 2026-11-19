import SwiftUI
import AppKit
import CryptoKit

// MARK: - Version

/// The installed version, read from the app bundle (set in Info.plist; the build number
/// goes up with every build, see build.sh).
enum AppVersion {
    static var short: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    static var build: Int {
        let text = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return Int(text) ?? 0
    }

    static var display: String {
        return L("Version %@ (build %d)", short, build)
    }

    /// True when `version`/`build` is newer than what is installed. Versions are compared
    /// number by number ("1.10" is newer than "1.9"); the build number breaks a tie.
    static func isNewer(version: String, build newBuild: Int?) -> Bool {
        let theirs = version.split(separator: ".").map { Int($0) ?? 0 }
        let ours = short.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(theirs.count, ours.count) {
            let a = index < theirs.count ? theirs[index] : 0
            let b = index < ours.count ? ours[index] : 0
            if a != b { return a > b }
        }
        return (newBuild ?? 0) > build
    }
}

// MARK: - Update check

/// What the product page publishes at `UpdateChecker.feedURL`:
///   { "version": "1.2.0", "build": 12, "url": "https://presoft.hu/.../DesktopPeeler-1.2.0-build12.dmg",
///     "notes": "What is new (optional)", "sha256": "hex checksum of the dmg (optional)" }
struct ReleaseInfo: Decodable {
    let version: String
    let build: Int?
    let url: URL
    let notes: String?
    let sha256: String?
}

final class UpdateChecker: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = UpdateChecker()
    static let feedURL = URL(string: "https://presoft.hu/desktop-peeler/latest.json")!

    enum Status {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(ReleaseInfo, Double)
        case downloaded(ReleaseInfo, URL)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    private var session: URLSession?

    /// Only one check or download at a time.
    private var isBusy: Bool {
        switch status {
        case .checking, .downloading: return true
        default: return false
        }
    }

    func check() {
        if isBusy { return }
        status = .checking
        var request = URLRequest(url: UpdateChecker.feedURL, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: request) { data, response, error in
            let result: Status
            if error != nil {
                result = .failed(L("Checking for updates did not succeed."))
            } else if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                result = .failed(L("Checking for updates did not succeed."))
            } else if let data = data, let release = try? JSONDecoder().decode(ReleaseInfo.self, from: data),
                      release.url.scheme == "https" {
                result = AppVersion.isNewer(version: release.version, build: release.build) ? .available(release) : .upToDate
            } else {
                result = .failed(L("Checking for updates did not succeed."))
            }
            DispatchQueue.main.async { self.status = result }
        }.resume()
    }

    func download(_ release: ReleaseInfo) {
        if isBusy { return }
        status = .downloading(release, 0)
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        session.downloadTask(with: release.url).resume()
    }

    // MARK: URLSessionDownloadDelegate

    private func currentRelease() -> ReleaseInfo? {
        if case .downloading(let release, _) = status { return release }
        return nil
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let release = currentRelease(), totalBytesExpectedToWrite > 0 else { return }
        status = .downloading(release, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let release = currentRelease() else { return }
        if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
            status = .failed(L("The download did not succeed. Try again."))
            return
        }
        if let expected = release.sha256?.lowercased(), let data = try? Data(contentsOf: location, options: .mappedIfSafe) {
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if actual != expected {
                status = .failed(L("The downloaded file is damaged (checksum does not match). Try again."))
                return
            }
        }
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let target = folder.appendingPathComponent(release.url.lastPathComponent)
        do {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: location, to: target)
            status = .downloaded(release, target)
        } catch {
            status = .failed(L("The download did not succeed. Try again."))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil, currentRelease() != nil {
            status = .failed(L("The download did not succeed. Try again."))
        }
    }

    /// Opens the downloaded disk image, then quits so the old app can be replaced.
    func quitAndOpen(_ file: URL) {
        NSWorkspace.shared.open(file)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { NSApp.terminate(nil) }
    }
}

// MARK: - Card shown in Help

struct UpdateCard: View {
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Updates")).font(Brand.strong(14))
                Spacer()
                Text(AppVersion.display)
                    .font(Brand.mono(11))
                    .foregroundColor(Brand.text2)
            }
            content
        }
        .brandCard()
    }

    @ViewBuilder
    private var content: some View {
        switch updater.status {
        case .idle:
            checkButton
        case .checking:
            Text(L("Checking for updates…")).foregroundColor(Brand.text2)
        case .upToDate:
            Text(L("The installed version is the latest.")).foregroundColor(Brand.text2)
            checkButton
        case .failed(let message):
            Text(message)
                .foregroundColor(Brand.text2)
                .fixedSize(horizontal: false, vertical: true)
            checkButton
        case .available(let release):
            Text(L("A new version is available: %@", versionText(release)))
                .font(Brand.strong(13))
            if let notes = release.notes, !notes.isEmpty {
                Text(notes).foregroundColor(Brand.text2).fixedSize(horizontal: false, vertical: true)
            }
            Button(L("Download update")) { updater.download(release) }
                .buttonStyle(AccentButtonStyle())
        case .downloading(let release, let progress):
            Text(L("Downloading %@… %d%%", versionText(release), Int(progress * 100)))
                .foregroundColor(Brand.text2)
        case .downloaded(let release, let file):
            Text(L("Version %@ is downloaded to your Downloads folder.", versionText(release)))
                .font(Brand.strong(13))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("What to do now:")).foregroundColor(Brand.text2)
                step(1, L("Click “Quit and open disk image”. Desktop Peeler closes, because a running app cannot be replaced."))
                step(2, L("In the window that opens, drag Desktop Peeler onto the Applications folder."))
                step(3, L("When macOS asks, choose Replace."))
                step(4, L("Eject the disk image, then start Desktop Peeler from the Applications folder. Your settings are kept."))
                Text(L("If macOS blocks the first start, allow it in System Settings › Privacy & Security › Open Anyway."))
                    .font(Brand.body(11))
                    .foregroundColor(Brand.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            HStack(spacing: 10) {
                Button(L("Quit and open disk image")) { updater.quitAndOpen(file) }
                    .buttonStyle(AccentButtonStyle())
                Button(L("Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([file]) }
                    .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var checkButton: some View {
        Button(L("Check for updates")) { updater.check() }
            .buttonStyle(GhostButtonStyle())
    }

    private func versionText(_ release: ReleaseInfo) -> String {
        if let build = release.build { return "\(release.version) (build \(build))" }
        return release.version
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number).").font(Brand.mono(11)).foregroundColor(Brand.muted)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
