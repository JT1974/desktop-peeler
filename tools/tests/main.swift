import Foundation

// Regression test for the cleanup hang of 2026-11-24: macOS keeps a few folders in the user's
// temporary folder under System Integrity Protection (file flags "sunlnk"/"restricted").
// Nobody can remove those, not even with the administrator password, so Finder never finishes
// the request and the app waited on it. They must not be offered, and never be handed to Finder.
// Run: bash tools/run-tests.sh

func fileFlags(_ path: String) -> UInt32 {
    var info = stat()
    return lstat(path, &info) == 0 ? info.st_flags : 0
}
let protectedBits = UInt32(SF_NOUNLINK | SF_RESTRICTED)

var failures = 0
let tmp = NSTemporaryDirectory()
let protectedInTemp = ((try? FileManager.default.contentsOfDirectory(atPath: tmp)) ?? [])
    .map { tmp + $0 }
    .filter { fileFlags($0) & protectedBits != 0 }
print("System-protected items in the temporary folder: \(protectedInTemp.count)")
if protectedInTemp.isEmpty { print("NOTE: nothing to test against on this Mac.") }

for path in CleanupScanner.scanAll().flatMap({ $0.items }).map({ $0.url.path }) where fileFlags(path) & protectedBits != 0 {
    print("FAIL: offered for removal although system-protected: \(path)")
    failures += 1
}

// Asked directly, the remover must refuse at once instead of asking Finder.
if let path = protectedInTemp.first {
    let start = Date()
    let report = Remover.moveToTrash([URL(fileURLWithPath: path)])
    if report.failed != [path] || !report.trashed.isEmpty || Date().timeIntervalSince(start) > 2
        || !FileManager.default.fileExists(atPath: path) {
        print("FAIL: the remover did not refuse a system-protected item at once: \(path)")
        failures += 1
    }
}

print(failures == 0 ? "PASS" : "FAILED: \(failures)")
exit(failures == 0 ? 0 : 1)
