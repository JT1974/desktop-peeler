# Desktop Peeler release notes

One entry for every build, newest first. Heading = `## <version> (build <n>)`, then the date, the disk image
file name, and the sections that apply: **New**, **Bug fixes and enhancements**, **Security**, **Known issues**.
Bullets start with a past-tense verb (Added, Changed, Fixed, Improved, Removed) and describe one change each.

Rules:
- `build.sh` stops if the entry for the build it is about to make is missing. Write the entry first.
- The build number rises with every build (automatically). The version (`CFBundleShortVersionString` in
  Info.plist) is raised by hand for a release: patch = fixes, minor = new features, major = big changes.
- When the version changes, the build number keeps counting up; it is never reset.
- The product page publishes this list and the latest version at `latest.json` (see `Sources/Updates.swift`).

## 1.0.0 (build 3)
*2026-11-24*

Disk image: `DesktopPeeler-1.0.0-build3.dmg`

### Bug fixes and enhancements
- Fixed a cleanup that never finished: a few folders in the temporary folder are protected by macOS itself (System Integrity Protection) and cannot be removed even with the administrator password. They were offered under “Temporary files” and handed to Finder, which asked for the password and then never completed, so the app stayed on “Working…”. Such items are no longer offered, and are never handed to Finder.
- Added `tools/run-tests.sh`, a read-only check that reproduces this problem.

## 1.0.0 (build 2)
*2026-11-24*

Disk image: `DesktopPeeler-1.0.0-build2.dmg`

First published build. It is released on GitHub under the tag `v1.0.0-build2`, which marks the exact source it was built from, and on the product page.

### Bug fixes and enhancements
- Fixed the Help answer about data and the internet: it now says that the app connects only when you choose “Check for updates”, and what it reads then.

### Security
- Added a SHA-256 checksum for the disk image, published on the GitHub release and on the product page. “Check for updates” compares a downloaded update with the checksum in `latest.json`.

### Known issues
- The app has no Apple Developer ID signature and is not notarized. macOS blocks the first launch; verify the checksum, then allow it in System Settings › Privacy & Security › Open Anyway.

## 1.0.0 (build 1)
*2026-11-18*

Disk image: `DesktopPeeler-1.0.0-build1.dmg`

First tracked build. Contains the initial public release plus the changes below.

### New
- Added “Check for updates” (Help page and app menu). It compares the installed version with the one on the product page, downloads the new disk image to the Downloads folder and lists the steps to install it. The check reads `https://presoft.hu/desktop-peeler/latest.json`.
- Added the version and build number to the About window, the Help page and the disk image name (`DesktopPeeler-<version>-build<n>.dmg`; the mounted disk is named the same).

### Bug fixes and enhancements
- Changed disabled buttons and checkboxes to a darker shade of their own background with readable text, instead of a transparent grey look.
- Added a pointing-hand mouse cursor over every clickable item (buttons, checkboxes, sidebar items, theme switch, expand arrows, “show in Finder” icons, the Help link, the theme and language pickers) and a “not allowed” cursor over disabled ones.
- Added a slight brightening of enabled buttons on hover.
- Changed `build.sh` to raise the build number on every build and to require a release-notes entry for it.

### Known issues
- “Check for updates” reports that the check did not succeed until the product page publishes `latest.json`.
